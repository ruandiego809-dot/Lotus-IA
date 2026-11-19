// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_models.dart';
import '../../../design/design.dart';
import '../../providers/data/provider_repository.dart';
import '../data/chat_repository.dart';
import '../domain/chat_service.dart';
import 'chat_actions.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_empty_state.dart';
import 'widgets/chat_history_sheet.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/model_bar.dart';

class ChatShellPage extends ConsumerStatefulWidget {
  const ChatShellPage({super.key});

  @override
  ConsumerState<ChatShellPage> createState() => _ChatShellPageState();
}

class _ChatShellPageState extends ConsumerState<ChatShellPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _creatingConversation = false;
  ChatMessage? _replyTo;
  final List<ChatAttachment> _pendingAttachments = [];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _plainError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _newConversation() async {
    if (_creatingConversation) return;
    _creatingConversation = true;
    try {
      final defaults = ref
          .read(providerControllerProvider)
          .value
          ?.defaultConfig;
      await ref
          .read(chatControllerProvider.notifier)
          .createConversation(
            providerId: defaults?.id,
            modelId: defaults?.selectedModel,
          );
      if (mounted) {
        HapticFeedback.selectionClick();
        _focus.requestFocus();
      }
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          _plainError(error),
          tone: LotusSnackTone.error,
        );
      }
    } finally {
      _creatingConversation = false;
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;
    final replyTo = _replyTo;
    final attachments = List<ChatAttachment>.of(_pendingAttachments);
    _input.clear();
    _replyTo = null;
    _pendingAttachments.clear();
    try {
      await ref.read(chatServiceProvider).sendMessage(
            text,
            replyToId: replyTo?.id,
            attachments: attachments,
          );
    } catch (error) {
      if (mounted) {
        if (_input.text.isEmpty) {
          _input.text = text;
          _input.selection = TextSelection.collapsed(offset: text.length);
        }
        // Devolve os anexos à fila para nova tentativa
        _pendingAttachments.addAll(attachments);
        _replyTo = replyTo;
        LotusFeedback.show(
          context,
          _plainError(error),
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  Future<void> _regenerate() async {
    try {
      await ref.read(chatServiceProvider).regenerateLast();
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          _plainError(error),
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final conversation = ref.read(chatControllerProvider).value?.active;
    if (conversation == null) return;
    final text = await showLotusPrompt(
      context,
      title: 'Editar mensagem',
      message: 'A resposta seguinte será regenerada a partir desta edição.',
      hint: 'Mensagem',
      initialValue: message.content,
      maxLines: 8,
      confirmLabel: 'Salvar e reenviar',
      icon: Icons.edit_outlined,
    );
    if (text == null || !mounted) return;
    if (ref.read(chatControllerProvider).value?.generating == true) return;
    try {
      await ref
          .read(chatServiceProvider)
          .sendMessage(
            text,
            conversationId: conversation.id,
            isRegenerate: true,
            editMessageId: message.id,
          );
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          _plainError(error),
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  void _replyToMessage(ChatMessage message) {
    setState(() => _replyTo = message);
    _focus.requestFocus();
  }

  void _clearReply() {
    setState(() => _replyTo = null);
  }

  Future<void> _pickAndAttachImage() async {
    final attachment = await ChatActions.pickImage(context);
    if (attachment == null || !mounted) return;
    setState(() {
      _pendingAttachments.add(attachment);
    });
    if (mounted) {
      LotusFeedback.show(
        context,
        '${attachment.name} anexado (${_pendingAttachments.length} arquivo(s)).',
        tone: LotusSnackTone.success,
      );
    }
  }

  void _removePendingAttachment(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  void _useSuggestion(String prompt) {
    _input.text = prompt;
    _input.selection = TextSelection.collapsed(offset: prompt.length);
    _focus.requestFocus();
  }

  Future<void> _handleConversationAction(String action) async {
    final conversation = ref.read(chatControllerProvider).value?.active;
    if (conversation == null) return;
    await ChatActions.run(context, ref, action, conversation);
  }

  @override
  Widget build(BuildContext context) {
    // 0 = error, 1 = loading, 2 = ready. Selecting a scalar keeps this page
    // from rebuilding for every streamed token.
    final phase = ref.watch(
      chatControllerProvider.select(
        (state) => state.hasError ? 0 : (state.value == null ? 1 : 2),
      ),
    );
    if (phase == 1) {
      return const _ChatLoading();
    }
    return LotusScaffold(
      appBar: _ChatAppBarSlot(
        onNew: _newConversation,
        onHistory: () => showChatHistory(context),
        onAction: _handleConversationAction,
      ),
      body: Column(
        children: [
          _ChatModelBarSlot(),
          Expanded(
            child: phase == 0
                ? _ChatError(
                    onRetry: () =>
                        ref.read(chatControllerProvider.notifier).load(),
                  )
                : _ChatBody(
                    onNew: _newConversation,
                    onSuggestion: _useSuggestion,
                    onEdit: _editMessage,
                    onRegenerate: _regenerate,
                    onReply: _replyToMessage,
                    scrollController: _scroll,
                  ),
          ),
          _ChatComposerSlot(
            controller: _input,
            focusNode: _focus,
            replyTo: _replyTo,
            pendingAttachments: _pendingAttachments,
            onClearReply: _clearReply,
            onRemoveAttachment: _removePendingAttachment,
            onSend: _send,
            onStop: () => ref.read(chatServiceProvider).requestCancel(),
            onAttach: () => ChatActions.showAttachments(
              context,
              _input,
              onImagePicked: _pickAndAttachImage,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAppBarSlot extends ConsumerWidget implements PreferredSizeWidget {
  const _ChatAppBarSlot({
    required this.onNew,
    required this.onHistory,
    required this.onAction,
  });

  final VoidCallback onNew;
  final VoidCallback onHistory;
  final ValueChanged<String> onAction;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(
      chatControllerProvider.select((state) {
        final active = state.value?.active;
        return (
          active?.id,
          active?.title,
          active?.messages.length ?? 0,
          state.value?.generating ?? false,
        );
      }),
    );
    return ChatAppBar(
      title: info.$2,
      messageCount: info.$3,
      hasConversation: info.$1 != null,
      generating: info.$4,
      onNew: onNew,
      onHistory: onHistory,
      onAction: onAction,
    );
  }
}

class _ChatModelBarSlot extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(
      chatControllerProvider.select((state) {
        final active = state.value?.active;
        return (
          active?.id,
          active?.providerId,
          active?.modelId,
          state.value?.generating ?? false,
        );
      }),
    );
    if (info.$1 == null) return const SizedBox.shrink();
    return ChatModelBar(
      providerId: info.$2,
      modelId: info.$3,
      disabled: info.$4,
    );
  }
}

class _ChatBody extends ConsumerWidget {
  const _ChatBody({
    required this.onNew,
    required this.onSuggestion,
    required this.onEdit,
    required this.onRegenerate,
    required this.onReply,
    required this.scrollController,
  });

  final VoidCallback onNew;
  final ValueChanged<String> onSuggestion;
  final ValueChanged<ChatMessage> onEdit;
  final VoidCallback onRegenerate;
  final ValueChanged<ChatMessage> onReply;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(
      chatControllerProvider.select((state) => state.value?.active),
    );
    final generating = ref.watch(
      chatControllerProvider.select(
        (state) => state.value?.generating ?? false,
      ),
    );
    if (conversation == null || conversation.messages.isEmpty) {
      return ChatEmptyState(
        onNew: generating ? null : onNew,
        onSuggestion: onSuggestion,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LotusBreakpoints.chatMaxWidth,
        ),
        child: ChatMessageList(
          conversation: conversation,
          generating: generating,
          controller: scrollController,
          onEdit: onEdit,
          onRegenerate: onRegenerate,
          onReply: onReply,
        ),
      ),
    );
  }
}

class _ChatComposerSlot extends ConsumerWidget {
  const _ChatComposerSlot({
    required this.controller,
    required this.focusNode,
    this.replyTo,
    this.pendingAttachments = const [],
    this.onClearReply,
    this.onRemoveAttachment,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatMessage? replyTo;
  final List<ChatAttachment> pendingAttachments;
  final ValueChanged<int>? onRemoveAttachment;
  final VoidCallback? onClearReply;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generating = ref.watch(
      chatControllerProvider.select(
        (state) => state.value?.generating ?? false,
      ),
    );
    return ChatComposer(
      controller: controller,
      focusNode: focusNode,
      replyTo: replyTo,
      pendingAttachments: pendingAttachments,
      onClearReply: onClearReply,
      onRemoveAttachment: onRemoveAttachment,
      generating: generating,
      onSend: onSend,
      onStop: onStop,
      onAttach: onAttach,
    );
  }
}

class _ChatLoading extends StatelessWidget {
  const _ChatLoading();

  @override
  Widget build(BuildContext context) {
    return const LotusScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LotusBrandMark(size: 56, radius: 18),
            SizedBox(height: LotusSpace.xl),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(height: LotusSpace.xl),
            LotusSkeleton(width: 200, height: 16),
            SizedBox(height: LotusSpace.sm),
            LotusSkeleton(width: 320, height: 16),
            SizedBox(height: LotusSpace.sm),
            LotusSkeleton(width: 240, height: 16),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LotusEmptyState(
      title: 'Não foi possível abrir o histórico',
      message: 'Os dados salvos não puderam ser lidos. Nada foi sobrescrito. Tente novamente.',
      actionLabel: 'Tentar novamente',
      onAction: onRetry,
    );
  }
}
