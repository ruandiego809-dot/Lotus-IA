import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../../core/models/chat_models.dart';
import '../../providers/data/provider_repository.dart';
import '../data/chat_repository.dart';

final chatServiceProvider = Provider((ref) => ChatService(ref));

class ChatService {
  ChatService(this.ref);
  final Ref ref;

  CancelToken? _cancelToken;
  bool get isGenerating => _cancelToken != null;

  void requestCancel() {
    _cancelToken?.cancel('Interrompido pelo usuário');
  }

  Future<void> sendMessage(
    String text, {
    String? overrideProviderId,
    String? overrideModelId,
    String? conversationId,
    bool isRegenerate = false,
    String? editMessageId,
    String? replyToId,
    List<ChatAttachment> attachments = const [],
  }) async {
    if (isGenerating) throw Exception('Uma resposta já está sendo gerada.');
    final token = CancelToken();
    _cancelToken = token;
    final chat = ref.read(chatControllerProvider.notifier);
    chat.setGenerating(true);
    Conversation? conv;
    ChatMessage? assistantMsg;
    final buffer = StringBuffer();
    ChatUsage? usage;
    var inserted = false;
    try {
      final chatState = ref.read(chatControllerProvider).value;
      if (chatState == null) throw Exception('Conversas não carregadas.');
      final selected = conversationId == null
          ? chatState.active
          : chatState.conversations
                .where((c) => c.id == conversationId)
                .firstOrNull;
      if (conversationId != null && selected == null) {
        throw Exception('Conversa não encontrada.');
      }
      final providers = ref.read(providerControllerProvider).value;
      if (providers == null) throw Exception('Provedores não carregados.');
      final providerId =
          overrideProviderId ??
          selected?.providerId ??
          providers.defaultConfig?.id;
      if (providerId == null) {
        throw Exception(
          'Nenhum provedor configurado. Configure um provedor em Configurações.',
        );
      }
      final pconf = providers.byIdOrNull(providerId);
      if (pconf == null || !pconf.enabled) {
        throw Exception('Provedor não encontrado ou desativado.');
      }
      final model = overrideModelId ?? selected?.modelId ?? pconf.selectedModel;
      if (model == null || model.trim().isEmpty) {
        throw Exception('Nenhum modelo selecionado para ${pconf.name}.');
      }
      if (!isRegenerate && text.trim().isEmpty && attachments.isEmpty) {
        throw Exception('A mensagem está vazia.');
      }
      if (isRegenerate && selected == null) return;
      if (selected != null) {
        conv = selected;
      } else {
        final id = await chat.createConversation(
          providerId: providerId,
          modelId: model,
        );
        conv = ref
            .read(chatControllerProvider)
            .value
            ?.conversations
            .where((c) => c.id == id)
            .firstOrNull;
        if (conv == null) throw Exception('Falha ao criar conversa.');
      }

      var messages = [...conv.messages];
      ChatMessage? repliedMessage;
      if (replyToId != null) {
        repliedMessage = conv.messages.where((m) => m.id == replyToId).firstOrNull;
      }
      if (isRegenerate) {
        if (editMessageId != null) {
          final index = messages.indexWhere((m) => m.id == editMessageId);
          if (index < 0 || messages[index].role != MessageRole.user) {
            throw Exception('Mensagem não encontrada.');
          }
          if (text.trim().isEmpty) throw Exception('A mensagem está vazia.');
          messages = [
            ...messages.sublist(0, index),
            messages[index].copyWith(content: text),
          ];
        } else if (messages.isNotEmpty &&
            messages.last.role == MessageRole.assistant) {
          messages.removeLast();
        }
        if (messages.isEmpty || messages.last.role != MessageRole.user) return;
      } else {
        messages.add(
          ChatMessage(
            role: MessageRole.user,
            content: text,
            providerId: providerId,
            modelId: model,
            attachments: attachments,
            replyTo: repliedMessage,
          ),
        );
      }
      assistantMsg = ChatMessage(
        role: MessageRole.assistant,
        content: '',
        isStreaming: true,
        providerId: providerId,
        modelId: model,
      );
      messages.add(assistantMsg);
      var title = conv.title;
      if (!isRegenerate && conv.messages.isEmpty && text.trim().isNotEmpty) {
        title = text.trim().split('\n').first;
        if (title.length > 40) title = '${title.substring(0, 40)}…';
      }
      conv = conv.copyWith(
        messages: messages,
        title: title,
        updatedAt: DateTime.now(),
        providerId: providerId,
        modelId: model,
      );
      // upsert publishes synchronously before its disk write completes.
      inserted = true;
      await chat.upsertConversation(conv);

      final adapter = ref
          .read(providerControllerProvider.notifier)
          .adapterFor(pconf.type);
      final apiKey = await ref.read(secureStoreProvider).readApiKey(pconf.id);
      if (token.isCancelled) {
        await chat.updateMessage(
          conv.id,
          assistantMsg.copyWith(
            content: '',
            isStreaming: false,
            error: 'Resposta interrompida.',
          ),
        );
        return;
      }
      final requestMessages = <ChatMessage>[
        if (conv.systemPrompt != null && conv.systemPrompt!.trim().isNotEmpty)
          ChatMessage(
            role: MessageRole.system,
            content: conv.systemPrompt!.trim(),
          ),
        ...messages.where((m) => !m.isStreaming && m.error == null),
      ];
      final clock = Stopwatch()..start();
      var lastPublish = -1000;
      await for (final ev in adapter.streamChat(
        config: pconf,
        apiKey: apiKey,
        model: model,
        messages: requestMessages,
        cancelToken: token,
      )) {
        if (token.isCancelled) break;
        if (ev.delta != null) buffer.write(ev.delta);
        if (ev.usage != null) usage = ev.usage;
        // Coalesce token chunks: rebuilding the chat at ~20 fps instead of once
        // per SSE line keeps streaming smooth and avoids disk writes entirely
        // until the answer is complete.
        final now = clock.elapsedMilliseconds;
        if (now - lastPublish < 50 && ev.usage == null) continue;
        lastPublish = now;
        await chat.updateMessage(
          conv.id,
          assistantMsg.copyWith(
            content: buffer.toString(),
            isStreaming: true,
            usage: usage,
          ),
          persist: false,
        );
      }
      await chat.updateMessage(
        conv.id,
        assistantMsg.copyWith(
          content: buffer.toString(),
          isStreaming: false,
          error: token.isCancelled ? 'Resposta interrompida.' : null,
          usage: usage,
        ),
      );
    } catch (e) {
      if (!inserted || conv == null || assistantMsg == null) rethrow;
      final cancelled =
          token.isCancelled || (e is DioException && CancelToken.isCancel(e));
      await chat.updateMessage(
        conv.id,
        assistantMsg.copyWith(
          content: buffer.toString(),
          isStreaming: false,
          error: cancelled ? 'Resposta interrompida.' : _safeError(e),
          usage: usage,
        ),
      );
    } finally {
      _cancelToken = null;
      chat.setGenerating(false);
    }
  }

  // Never persist or display raw transport errors: URLs and response bodies can
  // contain API keys, notably for providers that put credentials in the URL.
  String _safeError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) return 'Erro do provedor (HTTP $status).';
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Tempo de conexão esgotado.';
      }
      return 'Falha de conexão com o provedor.';
    }
    return 'Não foi possível gerar a resposta. Verifique a configuração do provedor.';
  }

  Future<void> regenerateLast() async {
    final conv = ref.read(chatControllerProvider).value?.active;
    if (conv == null || conv.messages.isEmpty) return;
    final messages = conv.messages;
    final index = messages.last.role == MessageRole.assistant
        ? messages.length - 2
        : messages.length - 1;
    if (index < 0 || messages[index].role != MessageRole.user) return;
    final lastUser = messages[index];
    await sendMessage(
      lastUser.content,
      conversationId: conv.id,
      overrideProviderId: conv.providerId ?? lastUser.providerId,
      overrideModelId: conv.providerId == null
          ? (conv.modelId ?? lastUser.modelId)
          : conv.modelId,
      isRegenerate: true,
    );
  }

  Future<void> retryLast() async {
    final conv = ref.read(chatControllerProvider).value?.active;
    if (conv != null &&
        conv.messages.isNotEmpty &&
        conv.messages.last.error != null) {
      await regenerateLast();
    }
  }
}
