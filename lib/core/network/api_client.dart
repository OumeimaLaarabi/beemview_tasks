import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/session_storage.dart';
import 'api_exception.dart';

typedef Json = Map<String, dynamic>;

/// Thin wrapper around Dio: base URL, headers, bearer token, and translation
/// of every failure into an [ApiException].
///
/// A 401 on an authenticated request clears the stored session and emits on
/// [onUnauthorized] so the app can return to the login screen. 403 is left
/// alone: it means "no access", not "session expired".
class ApiClient {
  ApiClient({required AppConfig config, required this._session, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              headers: const {
                'Accept': 'application/json',
                'Accept-Language': 'en',
              },
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra[_authKey] != false) {
            final token = await _session.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  static const _authKey = 'requiresAuth';

  final Dio _dio;
  final SessionStorage _session;
  final _unauthorized = StreamController<void>.broadcast();

  /// Fires after a protected request returned 401 and the session was cleared.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  Future<Json> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Json> post(String path, Object body, {bool authenticated = true}) =>
      _send(
        () => _dio.post<dynamic>(
          path,
          data: body,
          options: Options(extra: {_authKey: authenticated}),
        ),
        authenticated: authenticated,
      );

  Future<Json> put(String path, Object body) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<Json> _send(
    Future<Response<dynamic>> Function() request, {
    bool authenticated = true,
  }) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw ApiException(
        ApiErrorType.unknown,
        'Unexpected response from the server.',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (authenticated && error.isUnauthorized) {
        await _session.clear();
        _unauthorized.add(null);
      }
      throw error;
    }
  }

  void dispose() => _unauthorized.close();
}
