import 'package:dio/dio.dart';

enum ApiErrorType {
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  server,
  timeout,
  network,
  unknown,
}

/// One entry of a validation error's `details` array.
class ValidationDetail {
  const ValidationDetail({this.path, required this.message, this.code});

  final String? path;
  final String message;
  final String? code;
}

/// Typed error surfaced by the data layer. UI code only ever sees this,
/// never a raw [DioException].
class ApiException implements Exception {
  const ApiException(
    this.type,
    this.message, {
    this.statusCode,
    this.details = const [],
    this.mayHaveReachedServer = false,
  });

  factory ApiException.fromStatus(int? statusCode, dynamic body) {
    final type = _typeForStatus(statusCode);
    final details = _detailsFrom(body);
    return ApiException(
      type,
      _messageFrom(body, details) ?? _defaultMessage(type),
      statusCode: statusCode,
      details: details,
    );
  }

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.badResponse:
        return ApiException.fromStatus(
          e.response?.statusCode,
          e.response?.data,
        );
      case DioExceptionType.connectionTimeout:
        // The connection was never established, so nothing was sent.
        return ApiException(
          ApiErrorType.timeout,
          _defaultMessage(ApiErrorType.timeout),
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          ApiErrorType.timeout,
          _defaultMessage(ApiErrorType.timeout),
          mayHaveReachedServer: true,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return ApiException(
          ApiErrorType.network,
          _defaultMessage(ApiErrorType.network),
        );
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorType.unknown, 'Request cancelled.');
      case DioExceptionType.unknown:
        return ApiException(
          ApiErrorType.network,
          _defaultMessage(ApiErrorType.network),
          mayHaveReachedServer: true,
        );
    }
  }

  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final List<ValidationDetail> details;

  /// True when the request may have been processed even though no response
  /// arrived (e.g. receive timeout). Callers must not auto-retry
  /// non-idempotent requests such as posting a comment in that case.
  final bool mayHaveReachedServer;

  bool get isUnauthorized => type == ApiErrorType.unauthorized;

  @override
  String toString() => 'ApiException($type, $statusCode): $message';

  static ApiErrorType _typeForStatus(int? status) {
    if (status == null) return ApiErrorType.unknown;
    if (status == 401) return ApiErrorType.unauthorized;
    if (status == 403) return ApiErrorType.forbidden;
    if (status == 404) return ApiErrorType.notFound;
    if (status == 429) return ApiErrorType.rateLimited;
    if (status >= 500) return ApiErrorType.server;
    if (status >= 400) return ApiErrorType.badRequest;
    return ApiErrorType.unknown;
  }

  static List<ValidationDetail> _detailsFrom(dynamic body) {
    if (body is! Map || body['details'] is! List) return const [];
    return [
      for (final item in body['details'] as List)
        if (item is Map && item['message'] is String)
          ValidationDetail(
            path: item['path']?.toString(),
            message: item['message'] as String,
            code: item['code']?.toString(),
          ),
    ];
  }

  /// Reads `error` or `message` from the body; text varies by locale, so it
  /// is displayed as-is and never matched against.
  static String? _messageFrom(dynamic body, List<ValidationDetail> details) {
    if (body is! Map) return null;
    String? base;
    for (final key in const ['error', 'message']) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) {
        base = value.trim();
        break;
      }
    }
    if (details.isEmpty) return base;
    final detailText = details
        .map((d) => d.path == null ? d.message : '${d.path}: ${d.message}')
        .join('\n');
    return base == null ? detailText : '$base\n$detailText';
  }

  static String _defaultMessage(ApiErrorType type) => switch (type) {
    ApiErrorType.badRequest => 'The request was invalid.',
    ApiErrorType.unauthorized =>
      'Your session has expired. Please sign in again.',
    ApiErrorType.forbidden =>
      'You do not have permission to access this resource.',
    ApiErrorType.notFound => 'The requested item was not found.',
    ApiErrorType.rateLimited =>
      'Too many requests. Please wait a moment and try again.',
    ApiErrorType.server =>
      'The server ran into a problem. Please try again later.',
    ApiErrorType.timeout => 'The request timed out. Please try again.',
    ApiErrorType.network =>
      'Could not reach the server. Check your connection and try again.',
    ApiErrorType.unknown => 'Something went wrong. Please try again.',
  };
}
