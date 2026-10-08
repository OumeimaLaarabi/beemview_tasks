import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/core/theme/app_theme.dart';
import 'package:beemview_tasks/data/models/person.dart';
import 'package:beemview_tasks/data/models/project.dart';
import 'package:beemview_tasks/data/models/task.dart';
import 'package:beemview_tasks/data/models/task_priority.dart';
import 'package:beemview_tasks/data/models/task_status.dart';
import 'package:beemview_tasks/data/repositories/task_repository.dart';
import 'package:beemview_tasks/features/tasks/project_tasks_screen.dart';
import 'package:beemview_tasks/features/tasks/task_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

const _project = Project(id: 101, name: 'Interview Project');

final _tasks = [
  Task(
    id: 1,
    name: 'Site inspection',
    status: TaskStatus.toDo,
    rawStatus: 'to_do',
    priority: TaskPriority.high,
    dueDate: DateTime(2020, 1, 15),
    assignees: const [Person(id: 12, name: 'Candidate')],
  ),
  Task(
    id: 2,
    name: 'Write report',
    status: TaskStatus.done,
    rawStatus: 'done',
    dueDate: DateTime(2020, 1, 15),
  ),
  Task(
    id: 3,
    name: 'Order parts',
    status: TaskStatus.inProgress,
    rawStatus: 'in_progress',
    dueDate: DateTime(2099, 3, 1),
  ),
];

void main() {
  late MockTaskRepository repository;

  setUp(() => repository = MockTaskRepository());

  void stubTasks(Future<ProjectTasks> Function() answer) =>
      when(() => repository.fetchProjectTasks(101)).thenAnswer((_) => answer());

  /// [tall] gives the list room to build every card without scrolling.
  Future<void> pump(WidgetTester tester, {bool tall = true}) async {
    if (tall) {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      RepositoryProvider<TaskRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProjectTasksScreen(project: _project),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists tasks with status, priority, due date and assignee', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    stubTasks(() async => ProjectTasks(project: _project, tasks: _tasks));
    await pump(tester);

    expect(find.text('Interview Project'), findsOneWidget);
    expect(find.text('3 tasks'), findsOneWidget);
    expect(find.text('Site inspection'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    // Cards show initials; the full names are in the accessibility label,
    // which the tappable card merges with the rest of its content.
    expect(
      find.bySemanticsLabel(RegExp('Assigned to Candidate')),
      findsOneWidget,
    );
    // Open and past due: overdue. Done and past due: not overdue.
    expect(find.text('Overdue · Jan 15, 2020'), findsOneWidget);
    expect(find.text('Due Jan 15, 2020'), findsOneWidget);
    expect(find.text('Due Mar 1, 2099'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tapping a task opens its details', (tester) async {
    stubTasks(() async => ProjectTasks(project: _project, tasks: _tasks));
    when(() => repository.fetchTask(3)).thenAnswer((_) async => _tasks[2]);
    await pump(tester);

    await tester.tap(find.text('Order parts'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailsScreen), findsOneWidget);
    verify(() => repository.fetchTask(3)).called(1);
  });

  testWidgets('search narrows the list', (tester) async {
    stubTasks(() async => ProjectTasks(project: _project, tasks: _tasks));
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'report');
    await tester.pump();

    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Site inspection'), findsNothing);
    expect(find.text('Showing 1 of 3 tasks'), findsOneWidget);
  });

  testWidgets('status chips filter, and tapping again shows all', (
    tester,
  ) async {
    stubTasks(() async => ProjectTasks(project: _project, tasks: _tasks));
    await pump(tester);

    expect(find.text('All · 3'), findsOneWidget);
    await tester.tap(find.text('Done · 1'));
    await tester.pump();
    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Order parts'), findsNothing);

    await tester.tap(find.text('Done · 1'));
    await tester.pump();
    expect(find.text('Order parts'), findsOneWidget);
  });

  testWidgets('no match offers to clear the filters', (tester) async {
    stubTasks(() async => ProjectTasks(project: _project, tasks: _tasks));
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump();
    expect(find.text('No matching tasks'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('3 tasks'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a project without tasks shows the empty state', (tester) async {
    stubTasks(() async => const ProjectTasks(project: _project, tasks: []));
    await pump(tester);

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a failed load shows the error and retries', (tester) async {
    var calls = 0;
    stubTasks(() async {
      if (calls++ == 0) {
        throw const ApiException(ApiErrorType.network, 'Offline');
      }
      return ProjectTasks(project: _project, tasks: _tasks);
    });
    await pump(tester);
    expect(find.text('Offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Site inspection'), findsOneWidget);
  });

  testWidgets('fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    stubTasks(
      () async => ProjectTasks(
        project: _project,
        tasks: [
          Task(
            id: 9,
            name: 'A very long task name that will not fit on a single line',
            status: TaskStatus.changesRequested,
            rawStatus: 'changes_requested',
            priority: TaskPriority.urgent,
            dueDate: DateTime(2099, 12, 31),
            assignees: const [
              Person(name: 'Alexandra Montgomery-Smith'),
              Person(name: 'Bartholomew Jones'),
            ],
          ),
        ],
      ),
    );
    await pump(tester, tall: false);

    expect(tester.takeException(), isNull);
  });
}
