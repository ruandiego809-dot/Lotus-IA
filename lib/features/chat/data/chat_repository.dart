import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/storage/local_store.dart';
import '../../providers/data/provider_repository.dart';

class ChatState {
  const ChatState({
    required this.conversations,
    this.activeId,
    this.generating = false,
  });
  final List<Conversation> conversations;
  final String? activeId;
  final bool generating;

  Conversation? get active =>
      conversations.where((c) => c.id == activeId).firstOrNull;

  List<Conversation> get activeConversations =>
      conversations.where((c) => !c.archived).toList();
}

class ChatController extends StateNotifier<AsyncValue<ChatState>> {
  ChatController(this.ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref ref;

  LocalStore get _store => ref.read(localStoreProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _store.loadConversations();
      final activeId =
          items.where((c) => !c.archived).isNotEmpty
              ? items.where((c) => !c.archived).first.id
              : null;
      state = AsyncValue.data(
        ChatState(conversations: items, activeId: activeId),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _writes = Future.value();

  Future<void> _persist(ChatState s) async {
    // Publish immediately; queue disk writes so older snapshots cannot win.
    state = AsyncValue.data(s);
    final write = _writes.then(
      (_) => _store.saveConversations(s.conversations),
    );
    _writes = write.catchError((Object _) {});
    await write;
  }

  Future<String> createConversation({
    String? providerId,
    String? modelId,
  }) async {
    final s = state.value;
    if (s == null) throw StateError('Conversas não carregadas.');
    final c = Conversation(
      title: 'Nova conversa',
      providerId: providerId,
      modelId: modelId,
    );
    final next = ChatState(
      conversations: [c, ...s.conversations],
      activeId: c.id,
      generating: s.generating,
    );
    await _persist(next);
    return c.id;
  }

  Future<void> select(String id) async {
    final s = state.value;
    if (s == null) return;
    state = AsyncValue.data(
      ChatState(
        conversations: s.conversations,
        activeId: id,
        generating: s.generating,
      ),
    );
  }

  Future<void> delete(String id) async {
    final s = state.value;
    if (s == null) return;
    final list = s.conversations.where((c) => c.id != id).toList();
    final activeId = s.activeId == id
        ? (list.isNotEmpty ? list.first.id : null)
        : s.activeId;
    await _persist(
      ChatState(
        conversations: list,
        activeId: activeId,
        generating: s.generating,
      ),
    );
  }

  Future<void> archive(String id, bool archived) async {
    final s = state.value;
    if (s == null) return;
    final list = [
      for (final c in s.conversations)
        if (c.id == id)
          c.copyWith(archived: archived, updatedAt: DateTime.now())
        else
        c,
    ];
    list.sort((a, b) {
      if (a.archived == b.archived) {
        return b.updatedAt.compareTo(a.updatedAt);
      }
      return a.archived ? 1 : -1;
    });
    final nextActiveId = s.activeId == id && archived
        ? (list.where((c) => !c.archived).isNotEmpty
            ? list.where((c) => !c.archived).first.id
            : null)
        : s.activeId;
    await _persist(
      ChatState(
        conversations: list,
        activeId: nextActiveId,
        generating: s.generating,
      ),
    );
  }

  Future<void> renameConversation(String id, String title) async {
    final s = state.value;
    if (s == null) return;
    final list = [
      for (final c in s.conversations)
        if (c.id == id)
          c.copyWith(title: title, updatedAt: DateTime.now())
        else
          c,
    ];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist(
      ChatState(
        conversations: list,
        activeId: s.activeId,
        generating: s.generating,
      ),
    );
  }

  Future<void> upsertConversation(Conversation c) async {
    final s = state.value;
    if (s == null) throw StateError('Conversas não carregadas.');
    final exists = s.conversations.any((x) => x.id == c.id);
    final list = exists
        ? [
            for (final x in s.conversations)
              if (x.id == c.id) c else x,
          ]
        : [c, ...s.conversations];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist(
      ChatState(
        conversations: list,
        activeId: s.activeId ?? c.id,
        generating: s.generating,
      ),
    );
  }

  // A stream updates only its own message, never a stale conversation snapshot.
  // Intermediate stream chunks pass [persist] = false: the UI updates, the list
  // order stays stable and the whole history is not serialised per token.
  Future<void> updateMessage(
    String conversationId,
    ChatMessage message, {
    bool persist = true,
  }) async {
    final s = state.value;
    final c = s?.conversations
        .where((item) => item.id == conversationId)
        .firstOrNull;
    if (s == null || c == null || !c.messages.any((m) => m.id == message.id)) {
      return;
    }
    final updated = c.copyWith(
      messages: [
        for (final m in c.messages)
          if (m.id == message.id) message else m,
      ],
      updatedAt: DateTime.now(),
    );
    if (!persist) {
      state = AsyncValue.data(
        ChatState(
          conversations: [
            for (final item in s.conversations)
              if (item.id == conversationId) updated else item,
          ],
          activeId: s.activeId,
          generating: s.generating,
        ),
      );
      return;
    }
    await upsertConversation(updated);
  }

  void setGenerating(bool v) {
    final s = state.value;
    if (s == null) return;
    state = AsyncValue.data(
      ChatState(
        conversations: s.conversations,
        activeId: s.activeId,
        generating: v,
      ),
    );
  }

  Future<void> updateActiveSelection({
    String? providerId,
    String? modelId,
  }) async {
    final s = state.value;
    final c = s?.active;
    if (s == null || c == null) return;
    final nextProvider = providerId ?? c.providerId;
    final nextModel = providerId != null && providerId != c.providerId
        ? modelId
        : modelId ?? c.modelId;
    await upsertConversation(
      c.copyWith(
        providerId: nextProvider,
        modelId: nextModel,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateSystemPrompt(String conversationId, String? prompt) async {
    final s = state.value;
    if (s == null) return;
    final c = s.conversations.where((x) => x.id == conversationId).firstOrNull;
    if (c == null) return;
    await upsertConversation(
      c.copyWith(systemPrompt: prompt, updatedAt: DateTime.now()),
    );
  }

  Future<void> clearMessages(String conversationId) async {
    final s = state.value;
    if (s == null) return;
    final c = s.conversations.where((x) => x.id == conversationId).firstOrNull;
    if (c == null) return;
    await upsertConversation(
      c.copyWith(messages: [], updatedAt: DateTime.now()),
    );
  }

  Future<void> editMessageAndTruncate(
    String conversationId,
    String messageId,
    String newContent,
  ) async {
    final s = state.value;
    if (s == null) return;
    final c = s.conversations.where((x) => x.id == conversationId).firstOrNull;
    if (c == null) return;
    final idx = c.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final edited = c.messages[idx].copyWith(content: newContent);
    final kept = [...c.messages.sublist(0, idx), edited];
    await upsertConversation(
      c.copyWith(messages: kept, updatedAt: DateTime.now()),
    );
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<ChatState>>(
      (ref) => ChatController(ref),
    );
