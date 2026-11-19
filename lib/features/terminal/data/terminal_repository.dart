import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../providers/data/provider_repository.dart';
import '../domain/terminal_models.dart';

final terminalRepositoryProvider = Provider<TerminalRepository>((ref) {
  return TerminalRepository();
});

class TerminalRepository {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final app = Directory(p.join(dir.path, 'lotus_ai'));
    if (!await app.exists()) await app.create(recursive: true);
    return File(p.join(app.path, 'terminal_sessions.json'));
  }

  Future<List<TerminalSession>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = jsonDecode(await f.readAsString()) as List;
      return raw
          .whereType<Map>()
          .map((e) => TerminalSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TerminalSession> items) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}

final terminalAiConsentProvider =
    StateNotifierProvider<TerminalAiConsentController, bool>((ref) {
      return TerminalAiConsentController(ref);
    });

class TerminalAiConsentController extends StateNotifier<bool> {
  TerminalAiConsentController(this.ref) : super(false) {
    _load();
  }
  final Ref ref;
  static const _k = 'terminal_ai_consent';

  Future<void> _load() async {
    try {
      final store = ref.read(localStoreProvider);
      final s = await store.loadSettings();
      state = s[_k] == true;
    } catch (_) {}
  }

  Future<void> setConsent(bool v) async {
    state = v;
    try {
      final store = ref.read(localStoreProvider);
      final s = await store.loadSettings();
      s[_k] = v;
      await store.saveSettings(s);
    } catch (_) {}
  }
}
