import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  SecureStore() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _keyForProvider(String providerId) => 'api_key_$providerId';

  Future<void> saveApiKey(String providerId, String key) =>
      _storage.write(key: _keyForProvider(providerId), value: key);

  Future<String?> readApiKey(String providerId) =>
      _storage.read(key: _keyForProvider(providerId));

  Future<void> deleteApiKey(String providerId) =>
      _storage.delete(key: _keyForProvider(providerId));
}
