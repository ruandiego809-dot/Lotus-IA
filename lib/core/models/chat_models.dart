import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system }

class ChatUsage {
  const ChatUsage({this.promptTokens, this.completionTokens, this.totalTokens});
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  Map<String, dynamic> toJson() => {
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
  };

  factory ChatUsage.fromJson(Map<String, dynamic> j) => ChatUsage(
    promptTokens: j['promptTokens'] as int?,
    completionTokens: j['completionTokens'] as int?,
    totalTokens: j['totalTokens'] as int?,
  );
}

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.mimeType,
    this.path,
    this.bytesBase64,
    this.isImage = false,
  });
  final String name;
  final String mimeType;
  final String? path;
  final String? bytesBase64;
  final bool isImage;

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'path': path,
    'bytesBase64': bytesBase64,
    'isImage': isImage,
  };

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
    name: j['name'] as String? ?? 'file',
    mimeType: j['mimeType'] as String? ?? 'application/octet-stream',
    path: j['path'] as String?,
    bytesBase64: j['bytesBase64'] as String?,
    isImage: j['isImage'] as bool? ?? false,
  );
}

class ChatMessage {
  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.isStreaming = false,
    this.error,
    this.modelId,
    this.providerId,
    this.usage,
    this.attachments = const [],
    this.replyTo,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final bool isStreaming;
  final String? error;
  final String? modelId;
  final String? providerId;
  final ChatUsage? usage;
  final List<ChatAttachment> attachments;
  final ChatMessage? replyTo;

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    Object? error = _unset,
    ChatUsage? usage,
    List<ChatAttachment>? attachments,
    ChatMessage? replyTo,
  }) => ChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    createdAt: createdAt,
    isStreaming: isStreaming ?? this.isStreaming,
    error: identical(error, _unset) ? this.error : error as String?,
    modelId: modelId,
    providerId: providerId,
    usage: usage ?? this.usage,
    attachments: attachments ?? this.attachments,
    replyTo: replyTo ?? this.replyTo,
  );

  static const Object _unset = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'isStreaming': isStreaming,
    'error': error,
    'modelId': modelId,
    'providerId': providerId,
    'usage': usage?.toJson(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'replyTo': replyTo?.toJson(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String?,
    role: MessageRole.values.byName(j['role'] as String),
    content: j['content'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    error:
        (j['error'] as String?) ??
        (j['isStreaming'] == true
            ? 'Resposta interrompida antes da conclusão.'
            : null),
    modelId: j['modelId'] as String?,
    providerId: j['providerId'] as String?,
    usage: j['usage'] is Map<String, dynamic>
        ? ChatUsage.fromJson(j['usage'] as Map<String, dynamic>)
        : null,
    attachments: (j['attachments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    replyTo: j['replyTo'] is Map<String, dynamic>
        ? ChatMessage.fromJson(j['replyTo'] as Map<String, dynamic>)
        : null,
  );
}

class Conversation {
  Conversation({
    String? id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    this.providerId,
    this.modelId,
    this.systemPrompt,
    this.archived = false,
  }) : id = id ?? const Uuid().v4(),
       messages = messages ?? [],
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime updatedAt;
  final String? providerId;
  final String? modelId;
  final String? systemPrompt;
  final bool archived;

  Conversation copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    Object? providerId = _sentinel,
    Object? modelId = _sentinel,
    Object? systemPrompt = _sentinel,
    bool? archived,
  }) => Conversation(
    id: id,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    updatedAt: updatedAt ?? this.updatedAt,
    providerId: identical(providerId, _sentinel)
        ? this.providerId
        : providerId as String?,
    modelId: identical(modelId, _sentinel) ? this.modelId : modelId as String?,
    systemPrompt: identical(systemPrompt, _sentinel)
        ? this.systemPrompt
        : systemPrompt as String?,
    archived: archived ?? this.archived,
  );

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'providerId': providerId,
    'modelId': modelId,
    'systemPrompt': systemPrompt,
    'archived': archived,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'] as String?,
    title: j['title'] as String? ?? 'Nova conversa',
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    providerId: j['providerId'] as String?,
    modelId: j['modelId'] as String?,
    systemPrompt: j['systemPrompt'] as String?,
    archived: j['archived'] as bool? ?? false,
    messages: (j['messages'] as List? ?? [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
