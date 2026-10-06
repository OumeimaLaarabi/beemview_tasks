import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth token in platform secure storage (Keychain / Keystore).
/// The token is cached in memory so the request interceptor doesn't hit the
/// platform channel on every call.
class SessionStorage {
  SessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;
  String? _cachedToken;
  bool _loaded = false;

  Future<String?> readToken() async {
    if (!_loaded) {
      _cachedToken = await _storage.read(key: _tokenKey);
      _loaded = true;
    }
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _cachedToken = token;
    _loaded = true;
  }

  Future<void> clear() async {
    _cachedToken = null;
    _loaded = true;
    await _storage.delete(key: _tokenKey);
  }
}
