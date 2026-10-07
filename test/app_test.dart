import 'package:beemview_tasks/app.dart';
import 'package:beemview_tasks/core/config/app_config.dart';
import 'package:beemview_tasks/data/models/project.dart';
import 'package:beemview_tasks/data/models/user.dart';
import 'package:beemview_tasks/data/repositories/auth_repository.dart';
import 'package:beemview_tasks/data/repositories/project_repository.dart';
import 'package:beemview_tasks/features/auth/auth_cubit.dart';
import 'package:beemview_tasks/features/auth/login_screen.dart';
import 'package:beemview_tasks/features/auth/session_error_screen.dart';
import 'package:beemview_tasks/features/auth/splash_screen.dart';
import 'package:beemview_tasks/features/projects/projects_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late MockAuthCubit cubit;

  late MockProjectRepository projects;

  setUp(() {
    cubit = MockAuthCubit();
    projects = MockProjectRepository();
    when(() => projects.fetchProjects()).thenAnswer(
      (_) async => const ProjectPage(
        items: [Project(id: 101, name: 'Interview Project')],
        total: 1,
        offset: 0,
      ),
    );
  });

  Future<void> pumpApp(WidgetTester tester, AuthState state) {
    when(() => cubit.state).thenReturn(state);
    return tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(
            value: const AppConfig(
              apiOrigin: 'https://beemview.com',
              tenantSubdomain: 'acme',
            ),
          ),
          RepositoryProvider<AuthRepository>.value(value: MockAuthRepository()),
          RepositoryProvider<ProjectRepository>.value(value: projects),
        ],
        child: BlocProvider<AuthCubit>.value(
          value: cubit,
          child: const BeemviewApp(),
        ),
      ),
    );
  }

  testWidgets('unknown shows the splash screen', (tester) async {
    await pumpApp(tester, const AuthUnknown());
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('unauthenticated shows the login screen', (tester) async {
    await pumpApp(tester, const AuthUnauthenticated());
    expect(find.byType(LoginScreen), findsOneWidget);
    // Only email and password: the subdomain comes from configuration.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.textContaining('ubdomain'), findsNothing);
  });

  testWidgets('authenticated shows the projects screen', (tester) async {
    await pumpApp(
      tester,
      const AuthAuthenticated(User(id: 1, fullName: 'Ana')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(find.text('Interview Project'), findsOneWidget);
    expect(find.text('All projects loaded'), findsOneWidget);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('restoreFailed shows the error with retry', (tester) async {
    await pumpApp(tester, const AuthRestoreFailed('Offline'));
    expect(find.byType(SessionErrorScreen), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    when(() => cubit.restoreSession()).thenAnswer((_) async {});
    await tester.tap(find.text('Retry'));
    verify(() => cubit.restoreSession()).called(1);
  });
}
