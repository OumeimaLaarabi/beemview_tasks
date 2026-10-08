import 'package:beemview_tasks/core/config/app_config.dart';
import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/core/theme/app_theme.dart';
import 'package:beemview_tasks/data/models/user.dart';
import 'package:beemview_tasks/data/repositories/auth_repository.dart';
import 'package:beemview_tasks/features/auth/auth_cubit.dart';
import 'package:beemview_tasks/features/auth/login_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  const user = User(id: 12, fullName: 'Candidate');

  late MockAuthRepository repository;
  late MockAuthCubit auth;

  setUp(() {
    repository = MockAuthRepository();
    auth = MockAuthCubit();
    when(() => auth.state).thenReturn(const AuthUnauthenticated());
  });

  void stubLogin(Future<User> Function() answer) => when(
    () => repository.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
      rememberMe: any(named: 'rememberMe'),
    ),
  ).thenAnswer((_) => answer());

  Future<void> pump(
    WidgetTester tester, {
    String subdomain = 'acme',
    String devEmail = '',
    String devPassword = '',
  }) => tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(
          value: AppConfig(
            apiOrigin: 'https://beemview.com',
            tenantSubdomain: subdomain,
            devLoginEmail: devEmail,
            devLoginPassword: devPassword,
          ),
        ),
        RepositoryProvider<AuthRepository>.value(value: repository),
      ],
      child: BlocProvider<AuthCubit>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    ),
  );

  Finder field(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(field('Email address'), 'c@example.com');
    await tester.enterText(field('Password'), 'secret1');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
  }

  testWidgets('pre-fills the configured test account', (tester) async {
    await pump(tester, devEmail: 'dev@example.com', devPassword: 'Dev 123');
    expect(
      tester.widget<TextField>(field('Email address')).controller!.text,
      'dev@example.com',
    );
    expect(
      tester.widget<TextField>(field('Password')).controller!.text,
      'Dev 123',
    );
  });

  testWidgets('renders the design copy', (tester) async {
    await pump(tester);
    expect(find.text('Move work forward, together.'), findsOneWidget);
    expect(find.text('Sign in to your workspace'), findsOneWidget);
    expect(find.text('Keep me signed in'), findsOneWidget);
    expect(
      find.text('Protected with enterprise-grade security'),
      findsOneWidget,
    );
  });

  testWidgets('shows field errors only after submitting', (tester) async {
    await pump(tester);
    expect(find.text('Enter your email'), findsNothing);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
        rememberMe: any(named: 'rememberMe'),
      ),
    );
  });

  testWidgets('submits with "keep me signed in" on by default', (tester) async {
    stubLogin(() async => user);
    await pump(tester);
    await fillAndSubmit(tester);

    verify(
      () => repository.login(
        email: 'c@example.com',
        password: 'secret1',
        rememberMe: true,
      ),
    ).called(1);
    verify(() => auth.loggedIn(user)).called(1);
  });

  testWidgets('unchecking "keep me signed in" is sent to the repository', (
    tester,
  ) async {
    stubLogin(() async => user);
    await pump(tester);
    await tester.ensureVisible(find.text('Keep me signed in'));
    await tester.tap(find.text('Keep me signed in'));
    await fillAndSubmit(tester);

    verify(
      () => repository.login(
        email: 'c@example.com',
        password: 'secret1',
        rememberMe: false,
      ),
    ).called(1);
  });

  testWidgets('a failed sign-in shows a banner that clears on edit', (
    tester,
  ) async {
    stubLogin(
      () => throw const ApiException(
        ApiErrorType.badRequest,
        'Invalid credentials',
        statusCode: 400,
      ),
    );
    await pump(tester);
    await fillAndSubmit(tester);
    await tester.pump();

    expect(find.text('Invalid credentials'), findsOneWidget);

    await tester.enterText(field('Password'), 'secret12');
    await tester.pump();
    expect(find.text('Invalid credentials'), findsNothing);
  });

  testWidgets('the password visibility toggle', (tester) async {
    await pump(tester);
    TextField password() => tester.widget<TextField>(field('Password'));

    expect(password().obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('forgot password explains who resets it', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
  });

  testWidgets('an unconfigured build explains why sign-in is disabled', (
    tester,
  ) async {
    await pump(tester, subdomain: '');
    expect(find.text('App not configured'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsNothing);
  });

  testWidgets('fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await pump(tester);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
