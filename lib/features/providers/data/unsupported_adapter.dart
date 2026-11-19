import '../../../core/models/chat_models.dart';
import '../../../core/models/provider_models.dart';
import '../domain/provider_adapter.dart';

class UnsupportedAdapter implements ProviderAdapter {
  UnsupportedAdapter(this.type, this.note);
  @override
  final ProviderType type;
  final String note;

  @override
  Future<ProviderTestResult> testConnection({
    required ProviderConfig config,
    required String? apiKey,
  }) async {
    return ProviderTestResult(ok: false, message: note);
  }

  @override
  Future<List<ModelInfo>> listModels({
    required ProviderConfig config,
    required String? apiKey,
  }) async {
    throw Exception(note);
  }

  @override
  Stream<ChatStreamEvent> streamChat({
    required ProviderConfig config,
    required String? apiKey,
    required String model,
    required List<ChatMessage> messages,
    Object? cancelToken,
  }) async* {
    throw Exception(note);
  }
}
