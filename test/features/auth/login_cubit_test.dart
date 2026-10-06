import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/data/models/user.dart';
import 'package:beemview_tasks/data/repositories/auth_repository.dart';
import 'package:beemview_tasks/features/auth/login_cubit.dart';
import 'package:beemview_tasks/features/auth/login_validators.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const user = User(id: 12, fullName: 'Candidate');
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  void stubLogin(Future<User> Function() answer) => when(
    () => repository.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  blocTest<LoginCubit, LoginState>(
    'emits submitting then success',
    setUp: () => stubLogin(() async => user),
    build: () => LoginCubit(repository),
    act: (cubit) => cubit.submit(email: 'c@example.com', password: 'secret1'),
    expect: () => [
      const LoginState(status: LoginStatus.submitting),
      const LoginState(status: LoginStatus.success, user: user),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'shows the server message for invalid credentials (400)',
    setUp: () => stubLogin(
      () => throw const ApiException(
        ApiErrorType.badRequest,
        'Invalid credentials',
        statusCode: 400,
      ),
    ),
    build: () => LoginCubit(repository),
    act: (cubit) => cubit.submit(email: 'c@example.com', password: 'wrong12'),
    expect: () => [
      const LoginState(status: LoginStatus.submitting),
      const LoginState(
        status: LoginStatus.failure,
        error: 'Invalid credentials',
      ),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'explains an inactive account (403) distinctly',
    setUp: () => stubLogin(
      () => throw const ApiException(
        ApiErrorType.forbidden,
        'Forbidden',
        statusCode: 403,
      ),
    ),
    build: () => LoginCubit(repository),
    act: (cubit) => cubit.submit(email: 'c@example.com', password: 'secret1'),
    expect: () => [
      const LoginState(status: LoginStatus.submitting),
      isA<LoginState>()
          .having((s) => s.status, 'status', LoginStatus.failure)
          .having((s) => s.error, 'error', contains('inactive')),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'ignores a second submit while one is in flight',
    setUp: () => stubLogin(() async => user),
    build: () => LoginCubit(repository),
    seed: () => const LoginState(status: LoginStatus.submitting),
    act: (cubit) => cubit.submit(email: 'c@example.com', password: 'secret1'),
    expect: () => <LoginState>[],
    verify: (_) => verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ),
  );

  group('LoginValidators', () {
    test('email', () {
      expect(LoginValidators.email(''), isNotNull);
      expect(LoginValidators.email('not-an-email'), isNotNull);
      expect(LoginValidators.email(' c@example.com '), isNull);
    });

    test('password needs at least 6 characters', () {
      expect(LoginValidators.password('12345'), isNotNull);
      expect(LoginValidators.password('123456'), isNull);
    });
  });
}
