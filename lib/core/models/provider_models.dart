enum ProviderType {
  gemini,
  groq,
  openai,
  openrouter,
  deepseek,
  mistral,
  cohere,
  huggingface,
  zaiGlm,
  kiloGateway,
  opencode,
  openclaw,
  customOpenAiCompatible,
}

extension ProviderTypeMeta on ProviderType {
  String get label => switch (this) {
    ProviderType.gemini => 'Google Gemini',
    ProviderType.groq => 'Groq',
    ProviderType.openai => 'OpenAI / ChatGPT',
    ProviderType.openrouter => 'OpenRouter',
    ProviderType.deepseek => 'DeepSeek',
    ProviderType.mistral => 'Mistral',
    ProviderType.cohere => 'Cohere',
    ProviderType.huggingface => 'Hugging Face',
    ProviderType.zaiGlm => 'Z.ai / GLM',
    ProviderType.kiloGateway => 'Kilo Gateway',
    ProviderType.opencode => 'OpenCode',
    ProviderType.openclaw => 'OpenClaw',
    ProviderType.customOpenAiCompatible => 'API OpenAI-compatible',
  };

  bool get supportsCustomEndpoint => switch (this) {
    ProviderType.openai ||
    ProviderType.openrouter ||
    ProviderType.deepseek ||
    ProviderType.mistral ||
    ProviderType.groq ||
    ProviderType.zaiGlm ||
    ProviderType.kiloGateway ||
    ProviderType.opencode ||
    ProviderType.openclaw ||
    ProviderType.huggingface ||
    ProviderType.cohere ||
    ProviderType.customOpenAiCompatible => true,
    _ => false,
  };

  String? get defaultEndpoint => switch (this) {
    ProviderType.openai => 'https://api.openai.com/v1',
    ProviderType.groq => 'https://api.groq.com/openai/v1',
    ProviderType.openrouter => 'https://openrouter.ai/api/v1',
    ProviderType.deepseek => 'https://api.deepseek.com/v1',
    ProviderType.mistral => 'https://api.mistral.ai/v1',
    ProviderType.huggingface => 'https://router.huggingface.co/v1',
    ProviderType.cohere => 'https://api.cohere.com',
    ProviderType.kiloGateway => 'https://api.kilo.ai/v1',
    ProviderType.opencode => 'https://api.opencode.ai/v1',
    ProviderType.openclaw => 'https://api.openclaw.ai/v1',
    ProviderType.customOpenAiCompatible => null,
    _ => null,
  };
}

class ProviderConfig {
  const ProviderConfig({
    required this.id,
    required this.type,
    required this.enabled,
    this.endpoint,
    this.selectedModel,
    this.availableModels = const [],
    this.modelContextLimits = const {},
    this.isDefault = false,
  });

  final String id;
  final ProviderType type;
  final bool enabled;
  final String? endpoint;
  final String? selectedModel;
  final List<String> availableModels;
  final Map<String, int> modelContextLimits;
  final bool isDefault;

  String get name => type.label;

  int? contextLimitFor(String? modelId) =>
      modelId == null ? null : modelContextLimits[modelId];

  static const _unchanged = Object();

  ProviderConfig copyWith({
    bool? enabled,
    Object? endpoint = _unchanged,
    Object? selectedModel = _unchanged,
    List<String>? availableModels,
    Map<String, int>? modelContextLimits,
    bool? isDefault,
  }) => ProviderConfig(
    id: id,
    type: type,
    enabled: enabled ?? this.enabled,
    endpoint: identical(endpoint, _unchanged)
        ? this.endpoint
        : endpoint as String?,
    selectedModel: identical(selectedModel, _unchanged)
        ? this.selectedModel
        : selectedModel as String?,
    availableModels: availableModels ?? this.availableModels,
    modelContextLimits: modelContextLimits ?? this.modelContextLimits,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'enabled': enabled,
    'endpoint': endpoint,
    'selectedModel': selectedModel,
    'availableModels': availableModels,
    'modelContextLimits': modelContextLimits,
    'isDefault': isDefault,
  };

  factory ProviderConfig.fromJson(Map<String, dynamic> j) {
    final limitsRaw = j['modelContextLimits'];
    final limits = <String, int>{};
    if (limitsRaw is Map) {
      for (final e in limitsRaw.entries) {
        final v = e.value;
        if (v is int) limits[e.key.toString()] = v;
      }
    }
    return ProviderConfig(
      id: j['id'] as String,
      type: ProviderType.values.byName(j['type'] as String),
      enabled: j['enabled'] as bool? ?? false,
      endpoint: j['endpoint'] as String?,
      selectedModel: j['selectedModel'] as String?,
      availableModels: (j['availableModels'] as List? ?? []).cast<String>(),
      modelContextLimits: limits,
      isDefault: j['isDefault'] as bool? ?? false,
    );
  }

  factory ProviderConfig.defaults(ProviderType type) => ProviderConfig(
    id: type.name,
    type: type,
    enabled: false,
    endpoint: type.defaultEndpoint,
  );
}

class ModelInfo {
  const ModelInfo({required this.id, this.displayName, this.contextLimit});
  final String id;
  final String? displayName;
  final int? contextLimit;
}

class ProviderTestResult {
  const ProviderTestResult({
    required this.ok,
    required this.message,
    this.models,
  });
  final bool ok;
  final String message;
  final List<ModelInfo>? models;
}

class TokenUsageInfo {
  const TokenUsageInfo({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.contextLimit,
    this.remainingTokens,
    this.usagePercent,
    this.creditsRemaining,
  });
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int? contextLimit;
  final int? remainingTokens;
  final double? usagePercent;
  final String? creditsRemaining;
}
