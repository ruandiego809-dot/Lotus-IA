import '../../../core/models/provider_models.dart';

/// Validates the complete portable configuration before anything is written.
class ConfigImport {
  const ConfigImport({required this.providers, required this.themeMode});

  final List<ProviderConfig> providers;
  final String themeMode;

  factory ConfigImport.parse(dynamic value) {
    if (value is! Map || value['version'] != 1 || value['providers'] is! List) {
      throw const FormatException(
        'Arquivo de configuração inválido ou versão não suportada.',
      );
    }
    if ((value['providers'] as List).isEmpty) {
      throw const FormatException('A lista de provedores está vazia.');
    }
    final settings = value['settings'];
    if (settings is! Map ||
        (settings['themeMode'] != null &&
            settings['themeMode'] != 'light' &&
            settings['themeMode'] != 'dark' &&
            settings['themeMode'] != 'system')) {
      throw const FormatException('Tema inválido.');
    }
    final saved = <String, ProviderConfig>{};
    for (final entry in value['providers'] as List) {
      if (entry is! Map) throw const FormatException('Provedor inválido.');
      final json = Map<String, dynamic>.from(entry);
      final id = json['id'];
      if (id is! String || saved.containsKey(id)) {
        throw const FormatException('ID de provedor inválido ou duplicado.');
      }
      final matches = ProviderType.values.where((type) => type.name == id);
      if (matches.isEmpty || json['type'] != id) {
        throw const FormatException('Tipo e ID do provedor não correspondem.');
      }
      final models = json['availableModels'];
      final limits = json['modelContextLimits'];
      if (models != null &&
          (models is! List || models.any((model) => model is! String))) {
        throw const FormatException('Lista de modelos inválida.');
      }
      if (limits != null &&
          (limits is! Map ||
              limits.entries.any(
                (entry) =>
                    entry.key is! String ||
                    entry.value is! int ||
                    entry.value <= 0,
              ))) {
        throw const FormatException('Limites de contexto inválidos.');
      }
      final config = ProviderConfig.fromJson(json);
      saved[id] = config;
    }
    final providers = [
      for (final type in ProviderType.values)
        saved[type.name] ?? ProviderConfig.defaults(type),
    ];
    if (providers.where((p) => p.isDefault).length > 1) {
      throw const FormatException('Mais de um provedor padrão.');
    }
    return ConfigImport(
      providers: providers,
      themeMode: settings['themeMode'] as String? ?? 'dark',
    );
  }
}
