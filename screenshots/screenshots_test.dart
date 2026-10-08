/// Renders every screen and its main states with sample data and saves a
/// phone-sized PNG of each to `screenshots/goldens/`.
///
/// Kept outside `test/` so the normal `flutter test` doesn't run it.
/// Regenerate the images with:
///
/// ```
/// flutter test screenshots --update-goldens
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:beemview_tasks/core/config/app_config.dart';
import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/core/theme/app_theme.dart';
import 'package:beemview_tasks/data/models/person.dart';
import 'package:beemview_tasks/data/models/project.dart';
import 'package:beemview_tasks/data/models/task.dart';
import 'package:beemview_tasks/data/models/task_comment.dart';
import 'package:beemview_tasks/data/models/task_priority.dart';
import 'package:beemview_tasks/data/models/task_status.dart';
import 'package:beemview_tasks/data/models/user.dart';
import 'package:beemview_tasks/data/repositories/auth_repository.dart';
import 'package:beemview_tasks/data/repositories/project_repository.dart';
import 'package:beemview_tasks/data/repositories/task_repository.dart';
import 'package:beemview_tasks/features/auth/auth_cubit.dart';
import 'package:beemview_tasks/features/auth/login_screen.dart';
import 'package:beemview_tasks/features/auth/session_error_screen.dart';
import 'package:beemview_tasks/features/auth/splash_screen.dart';
import 'package:beemview_tasks/features/projects/projects_screen.dart';
import 'package:beemview_tasks/features/tasks/project_tasks_screen.dart';
import 'package:beemview_tasks/features/tasks/task_details_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _user = User(
  id: 12,
  fullName: 'Candidate User',
  email: 'candidate@example.com',
);

const _projects = [
  Project(
    id: 101,
    name: 'Interview Project',
    description: 'Site inspection and reporting for the new office wing.',
  ),
  Project(
    id: 102,
    name: 'Warehouse Renovation',
    description: 'Roof repairs, lighting upgrade and safety signage.',
  ),
  Project(id: 103, name: 'Client Onboarding'),
];

const _candidate = Person(id: 12, name: 'Candidate User');
const _reviewer = Person(id: 13, name: 'Sara Haddad');

final _tasks = [
  Task(
    id: 501,
    name: 'Site inspection',
    status: TaskStatus.inProgress,
    rawStatus: 'in_progress',
    priority: TaskPriority.high,
    dueDate: DateTime(2099, 10, 20),
    assignees: const [_candidate],
    projectName: 'Interview Project',
  ),
  Task(
    id: 502,
    name: 'Write inspection report',
    status: TaskStatus.toDo,
    rawStatus: 'to_do',
    priority: TaskPriority.medium,
    dueDate: DateTime(2026, 9, 30),
    assignees: const [_candidate, _reviewer],
    projectName: 'Interview Project',
  ),
  Task(
    id: 503,
    name: 'Order replacement fixtures',
    status: TaskStatus.blocked,
    rawStatus: 'blocked',
    priority: TaskPriority.urgent,
    dueDate: DateTime(2099, 11, 3),
    assignees: const [_reviewer],
    projectName: 'Interview Project',
  ),
  Task(
    id: 504,
    name: 'Review safety checklist',
    status: TaskStatus.review,
    rawStatus: 'review',
    priority: TaskPriority.low,
    projectName: 'Interview Project',
  ),
  Task(
    id: 505,
    name: 'Book access to the roof',
    status: TaskStatus.done,
    rawStatus: 'done',
    priority: TaskPriority.medium,
    dueDate: DateTime(2026, 9, 12),
    assignees: const [_candidate],
    projectName: 'Interview Project',
  ),
];

final _detail = Task(
  id: 501,
  name: 'Site inspection',
  description:
      'Inspect the assigned site area, photograph any damage and note the '
      'access points for the contractor.',
  status: TaskStatus.inProgress,
  rawStatus: 'in_progress',
  priority: TaskPriority.high,
  startDate: DateTime(2026, 10, 6),
  dueDate: DateTime(2099, 10, 20),
  createdAt: DateTime(2026, 10, 1, 9, 30),
  updatedAt: DateTime(2026, 10, 7, 16, 5),
  projectId: 101,
  projectName: 'Interview Project',
  assignees: const [_candidate, _reviewer],
  comments: [
    TaskComment(
      id: 77,
      content: 'Ready for inspection. Keys are at the front desk.',
      author: _reviewer,
      createdAt: DateTime(2026, 10, 7, 16, 5),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Loads the app fonts (Manrope, Material Icons) from the test asset bundle;
/// without this, tests draw every glyph as a box.
Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  late MockAuthCubit auth;
  late MockAuthRepository authRepository;
  late MockProjectRepository projectRepository;
  late MockTaskRepository taskRepository;

  setUpAll(() async {
    registerFallbackValue(TaskStatus.toDo);
    await _loadFonts();
  });

  setUp(() {
    auth = MockAuthCubit();
    authRepository = MockAuthRepository();
    projectRepository = MockProjectRepository();
    taskRepository = MockTaskRepository();
    when(() => auth.state).thenReturn(const AuthUnauthenticated());
  });

  /// Renders [home] on a 390×844 phone (iPhone 14 size) at 3x, with status
  /// bar and home-indicator insets. [home] is pushed on top of a blank page
  /// so screens show their back button as they do in the app.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget home, {
    String subdomain = 'acme',
    bool settle = true,
    bool pushed = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(
            value: AppConfig(
              apiOrigin: 'https://beemview.com',
              tenantSubdomain: subdomain,
            ),
          ),
          RepositoryProvider<AuthRepository>.value(value: authRepository),
          RepositoryProvider<ProjectRepository>.value(value: projectRepository),
          RepositoryProvider<TaskRepository>.value(value: taskRepository),
        ],
        child: BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: pushed ? const SizedBox.shrink() : home,
          ),
        ),
      ),
    );
    if (pushed) {
      unawaited(
        navigator.currentState!.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => home,
            transitionDuration: Duration.zero,
          ),
        ),
      );
      await tester.pump();
    }
    // A spinner never settles, so loading screens just pump one frame.
    if (settle) await tester.pumpAndSettle();
  }

  /// Hides the text cursor and saves the screen as `goldens/<name>.png`.
  Future<void> capture(WidgetTester tester, String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  /// Runs [body] with shadows drawn (tests disable them by default) and
  /// restores the test default afterwards.
  void screenshot(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      painting.debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        painting.debugDisableShadows = true;
      }
    });
  }

  Finder field(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------

  group('Auth', () {
    screenshot('splash', (tester) async {
      await pumpScreen(tester, const SplashScreen(), settle: false);
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/01_splash.png'),
      );
    });

    screenshot('login', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await capture(tester, '02_login');
    });

    screenshot('login validation errors', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.enterText(field('Email address'), 'candidate@');
      await tester.enterText(field('Password'), '123');
      await tapVisible(tester, find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 1000),
      );
      await capture(tester, '03_login_validation');
    });

    screenshot('login signing in', (tester) async {
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          rememberMe: any(named: 'rememberMe'),
        ),
      ).thenAnswer((_) => Completer<User>().future);
      await pumpScreen(tester, const LoginScreen());
      await tester.enterText(field('Email address'), 'candidate@example.com');
      await tester.enterText(field('Password'), 'secret123');
      await tapVisible(tester, find.text('Sign in'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/04_login_loading.png'),
      );
    });

    screenshot('login failed', (tester) async {
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          rememberMe: any(named: 'rememberMe'),
        ),
      ).thenThrow(
        const ApiException(
          ApiErrorType.badRequest,
          'Invalid email or password.',
          statusCode: 400,
        ),
      );
      await pumpScreen(tester, const LoginScreen());
      await tester.enterText(field('Email address'), 'candidate@example.com');
      await tester.enterText(field('Password'), 'wrong-password');
      await tapVisible(tester, find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 1000),
      );
      await capture(tester, '05_login_error');
    });

    screenshot('login not configured', (tester) async {
      await pumpScreen(tester, const LoginScreen(), subdomain: '');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await capture(tester, '06_login_not_configured');
    });

    screenshot('forgot password', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tapVisible(tester, find.text('Forgot password?'));
      await capture(tester, '07_login_forgot_password');
    });

    screenshot('session restore failed', (tester) async {
      await pumpScreen(
        tester,
        const SessionErrorScreen(
          message:
              'Could not reach the server. Check your connection and try '
              'again.',
        ),
      );
      await capture(tester, '08_session_error');
    });
  });

  // -------------------------------------------------------------------------
  // Projects
  // -------------------------------------------------------------------------

  group('Projects', () {
    void stubProjects(Future<ProjectPage> Function() answer) => when(
      () => projectRepository.fetchProjects(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => answer());

    screenshot('projects list', (tester) async {
      stubProjects(
        () async => const ProjectPage(items: _projects, total: 12, offset: 0),
      );
      await pumpScreen(tester, const ProjectsScreen(user: _user));
      await capture(tester, '10_projects');
    });

    screenshot('projects searched', (tester) async {
      stubProjects(
        () async => const ProjectPage(items: _projects, total: 12, offset: 0),
      );
      await pumpScreen(tester, const ProjectsScreen(user: _user));
      await tester.enterText(find.byType(TextField), 'ware');
      await capture(tester, '11_projects_search');
    });

    screenshot('account menu', (tester) async {
      stubProjects(
        () async => const ProjectPage(items: _projects, total: 3, offset: 0),
      );
      await pumpScreen(tester, const ProjectsScreen(user: _user));
      await tester.tap(find.byTooltip('Account'));
      await capture(tester, '12_projects_account_menu');
    });

    screenshot('projects empty', (tester) async {
      stubProjects(
        () async => const ProjectPage(items: [], total: 0, offset: 0),
      );
      await pumpScreen(tester, const ProjectsScreen(user: _user));
      await capture(tester, '13_projects_empty');
    });

    screenshot('projects error', (tester) async {
      stubProjects(
        () => throw const ApiException(
          ApiErrorType.network,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
      await pumpScreen(tester, const ProjectsScreen(user: _user));
      await capture(tester, '14_projects_error');
    });
  });

  // -------------------------------------------------------------------------
  // Project tasks
  // -------------------------------------------------------------------------

  group('Project tasks', () {
    void stubTasks(List<Task> tasks) =>
        when(() => taskRepository.fetchProjectTasks(101)).thenAnswer(
          (_) async => ProjectTasks(project: _projects.first, tasks: tasks),
        );

    Future<void> pumpTasks(WidgetTester tester) => pumpScreen(
      tester,
      ProjectTasksScreen(project: _projects.first),
      pushed: true,
    );

    screenshot('tasks list', (tester) async {
      stubTasks(_tasks);
      await pumpTasks(tester);
      await capture(tester, '20_tasks');
    });

    screenshot('tasks scrolled', (tester) async {
      stubTasks(_tasks);
      await pumpTasks(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await capture(tester, '21_tasks_scrolled');
    });

    screenshot('tasks searched', (tester) async {
      stubTasks(_tasks);
      await pumpTasks(tester);
      await tester.enterText(find.byType(TextField), 'inspection');
      await capture(tester, '22_tasks_search');
    });

    screenshot('tasks filtered by status', (tester) async {
      stubTasks(_tasks);
      await pumpTasks(tester);
      await tester.scrollUntilVisible(
        find.text('Blocked · 1'),
        100,
        scrollable: find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal,
          ),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Blocked · 1'));
      await capture(tester, '23_tasks_status_filter');
    });

    screenshot('tasks no match', (tester) async {
      stubTasks(_tasks);
      await pumpTasks(tester);
      await tester.enterText(find.byType(TextField), 'electrical');
      await capture(tester, '24_tasks_no_match');
    });

    screenshot('tasks empty', (tester) async {
      stubTasks(const []);
      await pumpTasks(tester);
      await capture(tester, '25_tasks_empty');
    });

    screenshot('tasks error', (tester) async {
      when(() => taskRepository.fetchProjectTasks(101)).thenThrow(
        const ApiException(
          ApiErrorType.forbidden,
          'You do not have permission to access this resource.',
          statusCode: 403,
        ),
      );
      await pumpTasks(tester);
      await capture(tester, '26_tasks_error');
    });
  });

  // -------------------------------------------------------------------------
  // Task details and status update
  // -------------------------------------------------------------------------

  group('Task details', () {
    setUp(() {
      when(() => taskRepository.fetchTask(501))
          .thenAnswer((_) async => _detail);
      when(() => taskRepository.updateStatus(501, any()))
          .thenAnswer((_) async {});
    });

    Future<void> pumpDetails(WidgetTester tester, Task task) =>
        pumpScreen(tester, TaskDetailsScreen(task: task), pushed: true);

    Future<void> openSheet(WidgetTester tester) async {
      await pumpDetails(tester, _tasks.first);
      await tester.tap(find.text('Change status'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseDoneWithNote(WidgetTester tester) async {
      await tapVisible(tester, find.text('Done'));
      await tester.pump();
      final note = find.widgetWithText(TextField, 'Note (optional)');
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Inspection finished, report attached.');
    }

    screenshot('task details', (tester) async {
      await pumpDetails(tester, _tasks.first);
      await capture(tester, '30_task_details');
    });

    screenshot('task details scrolled', (tester) async {
      await pumpDetails(tester, _tasks.first);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await capture(tester, '31_task_details_scrolled');
    });

    screenshot('task details with missing values', (tester) async {
      when(() => taskRepository.fetchTask(504)).thenAnswer(
        (_) async => const Task(
          id: 504,
          name: 'Review safety checklist',
          status: TaskStatus.review,
          rawStatus: 'review',
          priority: TaskPriority.low,
          projectName: 'Interview Project',
        ),
      );
      await pumpDetails(tester, _tasks[3]);
      await capture(tester, '32_task_details_empty_values');
    });

    screenshot('task details error', (tester) async {
      when(() => taskRepository.fetchTask(501)).thenThrow(
        const ApiException(ApiErrorType.notFound, 'Not found', statusCode: 404),
      );
      await pumpDetails(tester, _tasks.first);
      await capture(tester, '33_task_details_not_found');
    });

    screenshot('change status sheet', (tester) async {
      await openSheet(tester);
      await capture(tester, '40_change_status');
    });

    screenshot('change status with note', (tester) async {
      await openSheet(tester);
      await chooseDoneWithNote(tester);
      await capture(tester, '41_change_status_note');
    });

    screenshot('status save failed', (tester) async {
      when(() => taskRepository.updateStatus(501, any())).thenThrow(
        const ApiException(
          ApiErrorType.badRequest,
          'Validation failed\nstatus: Invalid value',
          statusCode: 400,
        ),
      );
      await openSheet(tester);
      await chooseDoneWithNote(tester);
      await tapVisible(tester, find.text('Save status'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -2000),
      );
      await capture(tester, '42_change_status_failed');
    });

    screenshot('status saved, note failed', (tester) async {
      when(() => taskRepository.addComment(501, any())).thenThrow(
        const ApiException(
          ApiErrorType.timeout,
          'The request timed out. Please try again.',
          mayHaveReachedServer: true,
        ),
      );
      await openSheet(tester);
      await chooseDoneWithNote(tester);
      await tapVisible(tester, find.text('Save status'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -2000),
      );
      await capture(tester, '43_change_status_note_failed');
    });

    screenshot('status updated', (tester) async {
      when(() => taskRepository.addComment(501, any()))
          .thenAnswer((_) async => null);
      await openSheet(tester);
      await chooseDoneWithNote(tester);
      when(() => taskRepository.fetchTask(501)).thenAnswer(
        (_) async => Task(
          id: 501,
          name: _detail.name,
          description: _detail.description,
          status: TaskStatus.done,
          rawStatus: 'done',
          priority: _detail.priority,
          startDate: _detail.startDate,
          dueDate: _detail.dueDate,
          createdAt: _detail.createdAt,
          updatedAt: DateTime(2026, 10, 8, 10, 12),
          projectId: 101,
          projectName: _detail.projectName,
          assignees: _detail.assignees,
          comments: [
            ..._detail.comments,
            TaskComment(
              id: 78,
              content: 'Inspection finished, report attached.',
              author: _candidate,
              createdAt: DateTime(2026, 10, 8, 10, 12),
            ),
          ],
        ),
      );
      await tapVisible(tester, find.text('Save status'));
      await capture(tester, '44_status_updated');
    });
  });
}
