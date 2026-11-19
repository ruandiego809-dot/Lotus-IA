import '../../../core/models/chat_models.dart';
import '../../../core/models/provider_models.dart';

class ChatStreamEvent {
  const ChatStreamEvent({this.delta, this.usage});
  final String? delta;
  final ChatUsage? usage;
}

abstract class ProviderAdapter {
  ProviderType get type;
  Future<ProviderTestResult> testConnection({
    required ProviderConfig config,
    required String? apiKey,
  });
  Future<List<ModelInfo>> listModels({
    required ProviderConfig config,
    required String? apiKey,
  });
  Stream<ChatStreamEvent> streamChat({
    required ProviderConfig config,
    required String? apiKey,
    required String model,
    required List<ChatMessage> messages,
    Object? cancelToken,
  });
}
