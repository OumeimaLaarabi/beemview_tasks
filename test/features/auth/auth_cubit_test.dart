import 'dart:async';

import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/data/models/user.dart';
import 'package:beemview_tasks/data/repositories/auth_repository.dart';
import 'package:beemview_tasks/features/auth/auth_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const user = User(id: 12, fullName: 'Candidate', email: 'c@example.com');

  late MockAuthRepository repository;
  late StreamController<void> expired;

  setUp(() {
    repository = MockAuthRepository();
    expired = StreamController<void>.broadcast();
    when(() => repository.sessionExpired).thenAnswer((_) => expired.stream);
    when(() => repository.logout()).thenAnswer((_) async {});
  });

  tearDown(() => expired.close());

  test('starts in AuthUnknown', () {
    final cubit = AuthCubit(repository);
    expect(cubit.state, const AuthUnknown());
    cubit.close();
  });

  group('restoreSession', () {
    blocTest<AuthCubit, AuthState>(
      'emits authenticated when the stored session is valid',
      setUp: () =>
          when(() => repository.restoreSession()).thenAnswer((_) async => user),
      build: () => AuthCubit(repository),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [const AuthAuthenticated(user)],
    );

    blocTest<AuthCubit, AuthState>(
      'emits unauthenticated when there is no stored session',
      setUp: () =>
          when(() => repository.restoreSession()).thenAnswer((_) async => null),
      build: () => AuthCubit(repository),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [const AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits unauthenticated when the token is rejected with 401',
      setUp: () => when(() => repository.restoreSession()).thenThrow(
        const ApiException(
          ApiErrorType.unauthorized,
          'Expired',
          statusCode: 401,
        ),
      ),
      build: () => AuthCubit(repository),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [const AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits restoreFailed on a network error and keeps the session',
      setUp: () =>
          when(() => repository.restoreSession())
              .thenThrow(const ApiException(ApiErrorType.network, 'Offline')),
      build: () => AuthCubit(repository),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [const AuthRestoreFailed('Offline')],
      verify: (_) => verifyNever(() => repository.logout()),
    );

    blocTest<AuthCubit, AuthState>(
      'emits restoreFailed on an unexpected error',
      setUp: () =>
          when(() => repository.restoreSession())
              .thenThrow(Exception('storage')),
      build: () => AuthCubit(repository),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [isA<AuthRestoreFailed>()],
    );

    blocTest<AuthCubit, AuthState>(
      'retry goes back through AuthUnknown',
      setUp: () =>
          when(() => repository.restoreSession()).thenAnswer((_) async => user),
      build: () => AuthCubit(repository),
      seed: () => const AuthRestoreFailed('Offline'),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [const AuthUnknown(), const AuthAuthenticated(user)],
    );
  });

  blocTest<AuthCubit, AuthState>(
    'loggedIn emits authenticated',
    build: () => AuthCubit(repository),
    seed: () => const AuthUnauthenticated(),
    act: (cubit) => cubit.loggedIn(user),
    expect: () => [const AuthAuthenticated(user)],
  );

  blocTest<AuthCubit, AuthState>(
    'logout clears the session and emits unauthenticated',
    build: () => AuthCubit(repository),
    seed: () => const AuthAuthenticated(user),
    act: (cubit) => cubit.logout(),
    expect: () => [const AuthUnauthenticated()],
    verify: (_) => verify(() => repository.logout()).called(1),
  );

  blocTest<AuthCubit, AuthState>(
    'session expiry (401) emits unauthenticated',
    build: () => AuthCubit(repository),
    seed: () => const AuthAuthenticated(user),
    act: (_) => expired.add(null),
    expect: () => [const AuthUnauthenticated()],
  );

  test('close cancels the session-expired subscription', () async {
    final cubit = AuthCubit(repository);
    expect(expired.hasListener, isTrue);

    await cubit.close();

    expect(expired.hasListener, isFalse);
  });
}
