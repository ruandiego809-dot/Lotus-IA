// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../features/providers/data/provider_repository.dart';

export '../design/lotus_theme.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    return ThemeModeController(ref);
  },
);

/// Persists the user's appearance choice (light, dark or system).
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this.ref) : super(ThemeMode.dark) {
    _load();
  }

  final Ref ref;
  int _revision = 0;

  static ThemeMode parse(Object? value) => switch (value) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };

  static String encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    ThemeMode.dark => 'dark',
  };

  Future<void> _load() async {
    final revision = _revision;
    try {
      final settings = await ref.read(localStoreProvider).loadSettings();
      if (mounted && revision == _revision) {
        state = parse(settings['themeMode']);
      }
    } catch (_) {
      if (mounted && revision == _revision) state = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _revision++;
    state = mode;
    try {
      final store = ref.read(localStoreProvider);
      final settings = await store.loadSettings();
      settings['themeMode'] = encode(mode);
      await store.saveSettings(settings);
    } catch (_) {
      // Appearance still applies for the session if persistence fails.
    }
  }

  Future<void> toggle() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
