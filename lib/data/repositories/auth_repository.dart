import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/session_storage.dart';
import '../models/json_utils.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository({
    required this._api,
    required this._session,
    required this._config,
  });

  final ApiClient _api;
  final SessionStorage _session;
  final AppConfig _config;

  /// `POST /auth/login`. The tenant subdomain comes from [AppConfig], not
  /// from the user. 400 = invalid credentials, 403 = inactive account; both
  /// surface as [ApiException]. On success the token is kept for this run,
  /// and also persisted across launches when [rememberMe] is true.
  Future<User> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (!_config.isConfigured) {
      throw const ApiException(
        ApiErrorType.unknown,
        'App is not configured: TENANT_SUBDOMAIN is missing.',
      );
    }
    final json = await _api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
      'subdomain': _config.tenantSubdomain.trim(),
    }, authenticated: false);
    final token = readString(json['token']);
    final user = readMap(json['user']);
    if (token == null || user == null) {
      throw const ApiException(
        ApiErrorType.unknown,
        'Login response did not include a session.',
      );
    }
    await _session.saveToken(token, persist: rememberMe);
    return User.fromJson(user);
  }

  /// Validates a stored token with `GET /users/me/profile`.
  ///
  /// Returns null when there is no stored session. A 401 clears the session
  /// (via [ApiClient]) and is rethrown; network errors are rethrown with the
  /// token kept, so the user can retry instead of being logged out offline.
  Future<User?> restoreSession() async {
    final token = await _session.readToken();
    if (token == null || token.isEmpty) return null;
    final json = await _api.get('/users/me/profile');
    final user = readMap(json['user']);
    if (user == null) {
      throw const ApiException(
        ApiErrorType.unknown,
        'Profile response did not include a user.',
      );
    }
    return User.fromJson(user);
  }

  /// Local logout only: the contract has no server-side logout route.
  Future<void> logout() => _session.clear();

  Stream<void> get sessionExpired => _api.onUnauthorized;
}
