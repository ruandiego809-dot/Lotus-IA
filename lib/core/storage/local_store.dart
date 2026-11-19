import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';
import '../models/provider_models.dart';

/// Small JSON-backed store. Writes are atomic (temp file + rename) so a crash
/// mid-save cannot corrupt the user's history, and the app directory is
/// resolved once instead of on every read.
class LocalStore {
  Directory? _cachedDir;

  Future<Directory> _dir() async {
    final cached = _cachedDir;
    if (cached != null) return cached;
    final documents = await getApplicationDocumentsDirectory();
    final app = Directory('${documents.path}/lotus_ai');
    if (!await app.exists()) await app.create(recursive: true);
    _cachedDir = app;
    return app;
  }

  Future<File> _file(String name) async => File('${(await _dir()).path}/$name');

  Future<void> _writeJson(File file, Object data) async {
    final encoded = jsonEncode(data);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(encoded, flush: true);
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await file.writeAsString(encoded, flush: true);
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  Future<List<Conversation>> loadConversations() async {
    final f = await _file('conversations.json');
    if (!await f.exists()) return [];
    try {
      final raw = jsonDecode(await f.readAsString()) as List;
      return raw
          .whereType<Map>()
          .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      throw FormatException('Não foi possível ler as conversas salvas: $e');
    }
  }

  Future<void> saveConversations(List<Conversation> items) async {
    final f = await _file('conversations.json');
    await _writeJson(f, items.map((e) => e.toJson()).toList());
  }

  Future<List<ProviderConfig>> loadProviders() async {
    final f = await _file('providers.json');
    if (!await f.exists()) {
      return ProviderType.values.map(ProviderConfig.defaults).toList();
    }
    try {
      final raw = jsonDecode(await f.readAsString()) as List;
      final saved = {
        for (final e in raw.whereType<Map>())
          (e['id'] as String): ProviderConfig.fromJson(
            Map<String, dynamic>.from(e),
          ),
      };
      return [
        for (final t in ProviderType.values)
          saved[t.name] ?? ProviderConfig.defaults(t),
      ];
    } catch (e) {
      throw FormatException('Não foi possível ler os provedores salvos: $e');
    }
  }

  Future<void> saveProviders(List<ProviderConfig> items) async {
    final f = await _file('providers.json');
    await _writeJson(f, items.map((e) => e.toJson()).toList());
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final f = await _file('settings.json');
    if (!await f.exists()) return {'themeMode': 'dark'};
    try {
      final raw = jsonDecode(await f.readAsString());
      return raw is Map
          ? Map<String, dynamic>.from(raw)
          : {'themeMode': 'dark'};
    } catch (_) {
      return {'themeMode': 'dark'};
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final f = await _file('settings.json');
    await _writeJson(f, settings);
  }
}
