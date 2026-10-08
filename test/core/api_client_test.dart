import 'dart:typed_data';

import 'package:beemview_tasks/core/config/app_config.dart';
import 'package:beemview_tasks/core/network/api_client.dart';
import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/core/storage/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionStorage extends Mock implements SessionStorage {}

/// Answers every request with a fixed status and raw body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockSessionStorage session;

  setUp(() {
    session = MockSessionStorage();
    when(() => session.readToken()).thenAnswer((_) async => 'abc');
  });

  ApiClient client(int status, String body) => ApiClient(
    config: const AppConfig(
      apiOrigin: 'https://beemview.com',
      tenantSubdomain: 'acme',
    ),
    session: session,
    dio: Dio(BaseOptions(responseType: ResponseType.json))
      ..httpClientAdapter = _FakeAdapter(status, body),
  );

  test('a PUT with an empty 204 body succeeds', () async {
    expect(await client(204, '').put('/tasks/1', {'status': 'done'}), isEmpty);
  });

  test('a POST with an empty 200 body succeeds', () async {
    expect(await client(200, '').post('/tasks/comment', {}), isEmpty);
  });

  test('a GET with an empty body is still an error', () async {
    await expectLater(
      client(200, '').get('/projects'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a JSON object body is returned as-is', () async {
    expect(await client(200, '{"ok":true}').put('/tasks/1', {}), {'ok': true});
  });
}
