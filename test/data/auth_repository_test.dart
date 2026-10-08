import 'package:beemview_tasks/core/config/app_config.dart';
import 'package:beemview_tasks/core/network/api_client.dart';
import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/core/storage/session_storage.dart';
import 'package:beemview_tasks/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockSessionStorage extends Mock implements SessionStorage {}

void main() {
  late MockApiClient api;
  late MockSessionStorage session;

  setUp(() {
    api = MockApiClient();
    session = MockSessionStorage();
    when(() => session.saveToken(any(), persist: any(named: 'persist')))
        .thenAnswer((_) async {});
  });

  AuthRepository repository(String subdomain) => AuthRepository(
    api: api,
    session: session,
    config: AppConfig(
      apiOrigin: 'https://beemview.com',
      tenantSubdomain: subdomain,
    ),
  );

  test('login sends the configured subdomain and stores the token', () async {
    when(
      () => api.post(any(), any(), authenticated: any(named: 'authenticated')),
    ).thenAnswer(
      (_) async => {
        'token': 'abc',
        'user': {'id': 12, 'full_name': 'Candidate'},
      },
    );

    final user = await repository('acme')
        .login(email: ' c@example.com ', password: 'secret1');

    expect(user.fullName, 'Candidate');
    verify(
      () => api.post('/auth/login', {
        'email': 'c@example.com',
        'password': 'secret1',
        'subdomain': 'acme',
      }, authenticated: false),
    ).called(1);
    verify(() => session.saveToken('abc', persist: true)).called(1);
  });

  test('login fails before any request when no subdomain is configured', () {
    expect(
      () => repository('').login(email: 'c@example.com', password: 'secret1'),
      throwsA(isA<ApiException>()),
    );
    verifyZeroInteractions(api);
  });
}
