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

  /// With [persist] false ("Keep me signed in" unchecked) the token lives in
  /// memory only, and any previously stored token is removed, so the next
  /// app launch starts at the login screen.
  Future<void> saveToken(String token, {bool persist = true}) async {
    if (persist) {
      await _storage.write(key: _tokenKey, value: token);
    } else {
      await _storage.delete(key: _tokenKey);
    }
    _cachedToken = token;
    _loaded = true;
  }

  Future<void> clear() async {
    _cachedToken = null;
    _loaded = true;
    await _storage.delete(key: _tokenKey);
  }
}
