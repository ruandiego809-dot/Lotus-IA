import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotus_ai/core/models/chat_models.dart';
import 'package:lotus_ai/core/models/provider_models.dart';
import 'package:lotus_ai/core/storage/local_store.dart';
import 'package:lotus_ai/core/storage/secure_store.dart';
import 'package:lotus_ai/features/chat/data/chat_repository.dart';
import 'package:lotus_ai/features/chat/domain/chat_service.dart';
import 'package:lotus_ai/features/providers/data/provider_registry.dart';
import 'package:lotus_ai/features/providers/data/provider_repository.dart';
import 'package:lotus_ai/features/providers/domain/provider_adapter.dart';

class MemoryStore extends LocalStore {
  List<Conversation> saved = [];
  Completer<void>? firstWriteGate;
  int writes = 0;

  @override
  Future<List<Conversation>> loadConversations() async => List.of(saved);
  @override
  Future<List<ProviderConfig>> loadProviders() async => [
    const ProviderConfig(
      id: 'openai',
      type: ProviderType.openai,
      enabled: true,
      selectedModel: 'model',
    ),
  ];
  @override
  Future<void> saveConversations(List<Conversation> items) async {
    writes++;
    if (writes == 1 && firstWriteGate != null) await firstWriteGate!.future;
    saved = List.of(items);
  }
}

class UnreadableStore extends MemoryStore {
  @override
  Future<List<Conversation>> loadConversations() async =>
      throw const FormatException('unreadable history');
}

class FakeSecureStore extends SecureStore {
  @override
  Future<String?> readApiKey(String providerId) async => 'test';
}

class FakeAdapter implements ProviderAdapter {
  final events = StreamController<ChatStreamEvent>();
  List<ChatMessage>? received;
  String? receivedModel;
  @override
  ProviderType get type => ProviderType.openai;
  @override
  Stream<ChatStreamEvent> streamChat({
    required ProviderConfig config,
    required String? apiKey,
    required String model,
    required List<ChatMessage> messages,
    Object? cancelToken,
  }) {
    received = messages;
    receivedModel = model;
    return events.stream;
  }

  @override
  Future<List<ModelInfo>> listModels({
    required ProviderConfig config,
    required String? apiKey,
  }) async => [];
  @override
  Future<ProviderTestResult> testConnection({
    required ProviderConfig config,
    required String? apiKey,
  }) async => const ProviderTestResult(ok: true, message: 'ok');
}

class FakeRegistry extends ProviderRegistry {
  FakeRegistry(this.adapter);
  final FakeAdapter adapter;
  @override
  ProviderAdapter forType(ProviderType type) => adapter;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<void> waitForRequest(FakeAdapter adapter) async {
  for (var i = 0; i < 100 && adapter.received == null; i++) {
    await settle();
  }
  expect(adapter.received, isNotNull, reason: 'request did not start');
}

void main() {
  test('message error survives JSON, copy can clear provider and model', () {
    final message = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      error: 'offline',
    );
    expect(ChatMessage.fromJson(message.toJson()).error, 'offline');
    final c = Conversation(title: 'c', providerId: 'p', modelId: 'm');
    expect(c.copyWith().modelId, 'm');
    expect(c.copyWith(providerId: null, modelId: null).modelId, isNull);
    expect(c.copyWith(providerId: null).providerId, isNull);
  });

  test('an interrupted persisted stream becomes retryable on reload', () {
    final message = ChatMessage(
      role: MessageRole.assistant,
      content: 'partial',
      isStreaming: true,
    );
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.content, 'partial');
    expect(restored.isStreaming, false);
    expect(restored.error, isNotNull);
    final old = message.toJson()..remove('isStreaming');
    expect(ChatMessage.fromJson(old).error, isNull);
  });

  test('load failure cannot be overwritten by creating a new chat', () async {
    final store = UnreadableStore();
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(chatControllerProvider.notifier);
    await settle();
    expect(container.read(chatControllerProvider).hasError, true);
    await expectLater(controller.createConversation(), throwsFormatException);
    expect(store.writes, 0);
  });

  test(
    'writes are ordered and deleting another chat preserves selection',
    () async {
      final store = MemoryStore()..firstWriteGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(chatControllerProvider.notifier);
      await settle();
      final first = controller.createConversation();
      final firstId = container.read(chatControllerProvider).value!.activeId!;
      final second = controller.createConversation(
        providerId: 'openai',
        modelId: 'old-model',
      );
      final secondId = container.read(chatControllerProvider).value!.activeId!;
      expect(store.writes, 0); // writes begin in a microtask
      await settle();
      expect(store.writes, 1);
      store.firstWriteGate!.complete();
      await Future.wait([first, second]);
      expect(store.saved.length, 2);
      await controller.delete(firstId);
      expect(container.read(chatControllerProvider).value!.activeId, secondId);
      await controller.updateActiveSelection(
        providerId: 'other',
        modelId: null,
      );
      expect(
        container.read(chatControllerProvider).value!.active!.modelId,
        isNull,
      );
    },
  );

  test(
    'stream errors finish generation, retain identity and survive reload',
    () async {
      final store = MemoryStore();
      final adapter = FakeAdapter();
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
          providerRegistryProvider.overrideWithValue(FakeRegistry(adapter)),
        ],
      );
      addTearDown(container.dispose);
      final chat = container.read(chatControllerProvider.notifier);
      container.read(providerControllerProvider);
      await settle();
      final id = await chat.createConversation(
        providerId: 'openai',
        modelId: 'model',
      );
      final service = container.read(chatServiceProvider);
      final pending = service.sendMessage('hello');
      await waitForRequest(adapter);
      final messageId = container
          .read(chatControllerProvider)
          .value!
          .active!
          .messages
          .last
          .id;
      adapter.events.add(const ChatStreamEvent(delta: 'partial'));
      await settle();
      adapter.events.addError(
        DioException(
          requestOptions: RequestOptions(
            path: 'https://example.invalid/chat?key=secret-key',
          ),
          message: 'offline secret-key',
        ),
      );
      await adapter.events.close();
      await pending;
      final state = container.read(chatControllerProvider).value!;
      final last = state.active!.messages.last;
      expect(last.id, messageId);
      expect(last.content, 'partial');
      expect(last.error, isNotNull);
      expect(last.error, isNot(contains('secret-key')));
      expect(
        store.saved.single.messages.last.error,
        isNot(contains('secret-key')),
      );
      expect(last.isStreaming, false);
      expect(state.generating, false);
      expect(service.isGenerating, false);
      expect(
        Conversation.fromJson(store.saved.single.toJson()).messages.last.error,
        isNotNull,
      );
      expect(state.activeId, id);
    },
  );

  test('regeneration validation preserves previous answer', () async {
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final chat = container.read(chatControllerProvider.notifier);
    container.read(providerControllerProvider);
    await settle();
    await chat.createConversation(providerId: 'missing', modelId: 'model');
    final conv = container.read(chatControllerProvider).value!.active!;
    final answer = ChatMessage(
      role: MessageRole.assistant,
      content: 'original',
    );
    await chat.upsertConversation(
      conv.copyWith(
        messages: [
          ChatMessage(role: MessageRole.user, content: 'hello'),
          answer,
        ],
      ),
    );
    await expectLater(
      container.read(chatServiceProvider).regenerateLast(),
      throwsException,
    );
    final state = container.read(chatControllerProvider).value!;
    expect(state.active!.messages.last.id, answer.id);
    expect(state.active!.messages.last.content, 'original');
    expect(state.generating, false);
  });

  test('regeneration uses the model currently selected in the chat', () async {
    final store = MemoryStore();
    final adapter = FakeAdapter();
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        secureStoreProvider.overrideWithValue(FakeSecureStore()),
        providerRegistryProvider.overrideWithValue(FakeRegistry(adapter)),
      ],
    );
    addTearDown(container.dispose);
    final chat = container.read(chatControllerProvider.notifier);
    container.read(providerControllerProvider);
    await settle();
    await chat.createConversation(providerId: 'openai', modelId: 'new-model');
    final conv = container.read(chatControllerProvider).value!.active!;
    const attachment = ChatAttachment(
      name: 'image.png',
      mimeType: 'image/png',
      isImage: true,
      bytesBase64: 'dGVzdA==',
    );
    await chat.upsertConversation(
      conv.copyWith(
        messages: [
          ChatMessage(
            role: MessageRole.user,
            content: 'hello',
            providerId: 'openai',
            modelId: 'old-model',
            attachments: [attachment],
          ),
          ChatMessage(role: MessageRole.assistant, content: 'old answer'),
        ],
      ),
    );
    final pending = container.read(chatServiceProvider).regenerateLast();
    await waitForRequest(adapter);
    expect(adapter.receivedModel, 'new-model');
    expect(adapter.received!.last.attachments.single.name, 'image.png');
    await adapter.events.close();
    await pending;
  });

  test(
    'editing validates provider before truncating the conversation',
    () async {
      final store = MemoryStore();
      final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final chat = container.read(chatControllerProvider.notifier);
      container.read(providerControllerProvider);
      await settle();
      await chat.createConversation(providerId: 'missing', modelId: 'model');
      final conv = container.read(chatControllerProvider).value!.active!;
      final user = ChatMessage(role: MessageRole.user, content: 'original');
      final answer = ChatMessage(
        role: MessageRole.assistant,
        content: 'answer',
      );
      await chat.upsertConversation(conv.copyWith(messages: [user, answer]));
      await expectLater(
        container
            .read(chatServiceProvider)
            .sendMessage(
              'changed',
              conversationId: conv.id,
              isRegenerate: true,
              editMessageId: user.id,
            ),
        throwsException,
      );
      final messages = container
          .read(chatControllerProvider)
          .value!
          .active!
          .messages;
      expect(messages.length, 2);
      expect(messages.first.content, 'original');
      expect(messages.last.id, answer.id);
    },
  );

  test(
    'cancellation blocks overlapping sends and finalizes partial output',
    () async {
      final store = MemoryStore();
      final adapter = FakeAdapter();
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
          providerRegistryProvider.overrideWithValue(FakeRegistry(adapter)),
        ],
      );
      addTearDown(container.dispose);
      final chat = container.read(chatControllerProvider.notifier);
      container.read(providerControllerProvider);
      await settle();
      await chat.createConversation(providerId: 'openai', modelId: 'model');
      final service = container.read(chatServiceProvider);
      final pending = service.sendMessage('hello');
      await waitForRequest(adapter);
      adapter.events.add(const ChatStreamEvent(delta: 'partial'));
      await settle();
      service.requestCancel();
      await expectLater(service.sendMessage('duplicate'), throwsException);
      await adapter.events.close();
      await pending;
      final state = container.read(chatControllerProvider).value!;
      expect(state.active!.messages.length, 2);
      expect(state.active!.messages.last.content, 'partial');
      expect(state.active!.messages.last.error, 'Resposta interrompida.');
      expect(state.active!.messages.last.isStreaming, false);
      expect(state.generating, false);
    },
  );

  test(
    'updates to a background conversation do not change active selection',
    () async {
      final store = MemoryStore();
      final container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final chat = container.read(chatControllerProvider.notifier);
      await settle();
      final firstId = await chat.createConversation(
        providerId: 'openai',
        modelId: 'model',
      );
      final message = ChatMessage(role: MessageRole.assistant, content: '');
      final first = container.read(chatControllerProvider).value!.active!;
      await chat.upsertConversation(first.copyWith(messages: [message]));
      final secondId = await chat.createConversation();
      await chat.updateMessage(firstId, message.copyWith(content: 'answer'));
      expect(container.read(chatControllerProvider).value!.activeId, secondId);
      expect(
        container
            .read(chatControllerProvider)
            .value!
            .conversations
            .firstWhere((c) => c.id == firstId)
            .messages
            .single
            .content,
        'answer',
      );
    },
  );
}
