import 'package:flutter_test/flutter_test.dart';
import 'package:lotus_ai/core/models/provider_models.dart';
import 'package:lotus_ai/features/settings/domain/config_import.dart';

void main() {
  test('copyWith preserves omitted values and clears explicit nulls', () {
    final original = ProviderConfig.defaults(ProviderType.openai)
        .copyWith(selectedModel: 'model');
    final unchanged = original.copyWith(enabled: true);
    expect(unchanged.endpoint, original.endpoint);
    expect(unchanged.selectedModel, 'model');
    final cleared = original.copyWith(endpoint: null, selectedModel: null);
    expect(cleared.endpoint, isNull);
    expect(cleared.selectedModel, isNull);
  });

  Map<String, dynamic> data(List<Map<String, dynamic>> providers) => {
    'version': 1,
    'settings': {'themeMode': 'light', 'terminal_ai_consent': true},
    'providers': providers,
  };

  test('valid import reads theme and fills missing providers', () {
    final config = ProviderConfig.defaults(ProviderType.openai)
        .copyWith(enabled: true, isDefault: true);
    final imported = ConfigImport.parse(data([config.toJson()]));
    expect(imported.themeMode, 'light');
    expect(imported.providers, hasLength(ProviderType.values.length));
    expect(
      imported.providers.singleWhere((p) => p.id == 'openai').enabled,
      isTrue,
    );
  });

  test('imports legacy settings without a theme as dark', () {
    final provider = ProviderConfig.defaults(ProviderType.openai).toJson();
    final imported = ConfigImport.parse({
      ...data([provider]),
      'settings': {'terminal_ai_consent': true},
    });
    expect(imported.themeMode, 'dark');
  });

  test('aceita o tema sistema', () {
    final provider = ProviderConfig.defaults(ProviderType.openai).toJson();
    final imported = ConfigImport.parse({
      ...data([provider]),
      'settings': {'themeMode': 'system'},
    });
    expect(imported.themeMode, 'system');
  });

  test(
    'rejects empty, mismatched, duplicated or multiple default providers',
    () {
      final one = ProviderConfig.defaults(ProviderType.openai)
          .copyWith(isDefault: true)
          .toJson();
      final other = ProviderConfig.defaults(ProviderType.groq)
          .copyWith(isDefault: true)
          .toJson();
      expect(() => ConfigImport.parse(data([])), throwsFormatException);
      expect(() => ConfigImport.parse(data([one, one])), throwsFormatException);
      expect(
        () => ConfigImport.parse(data([one, other])),
        throwsFormatException,
      );
      expect(
        () => ConfigImport.parse(
          data([
            {...one, 'type': 'groq'},
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => ConfigImport.parse({
          ...data([one]),
          'version': 2,
        }),
        throwsFormatException,
      );
    },
  );
}
