import '../../../core/models/provider_models.dart';
import '../domain/provider_adapter.dart';
import 'cohere_adapter.dart';
import 'gemini_adapter.dart';
import 'openai_compatible_adapter.dart';

class ProviderRegistry {
  ProviderAdapter forType(ProviderType type) => switch (type) {
    ProviderType.gemini => GeminiAdapter(),
    ProviderType.cohere => CohereAdapter(),
    ProviderType.openai ||
    ProviderType.groq ||
    ProviderType.openrouter ||
    ProviderType.deepseek ||
    ProviderType.mistral ||
    ProviderType.huggingface ||
    ProviderType.zaiGlm ||
    ProviderType.kiloGateway ||
    ProviderType.opencode ||
    ProviderType.openclaw ||
    ProviderType.customOpenAiCompatible => OpenAiCompatibleAdapter(type),
  };
}
