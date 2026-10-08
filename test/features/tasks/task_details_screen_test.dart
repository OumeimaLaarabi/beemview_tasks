import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/core/theme/app_theme.dart';
import 'package:beemview_tasks/data/models/task.dart';
import 'package:beemview_tasks/data/repositories/task_repository.dart';
import 'package:beemview_tasks/features/tasks/task_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

/// The task as the list route returns it (what the user tapped).
const _listTask = Task(
  id: 501,
  name: 'Site inspection',
  projectName: 'Interview Project',
);

/// The detail route shape, parsed by the real model.
final _detail = Task.fromJson({
  'id': 501,
  'name': 'Site inspection',
  'description': 'Inspect the assigned site area',
  'status': 'in_progress',
  'priority': 'high',
  'start_date': '2026-10-01T00:00:00Z',
  'due_date': '2099-10-10T00:00:00Z',
  'Project': {'id': 101, 'name': 'Interview Project'},
  'Assignees': [
    {'id': 12, 'full_name': 'Candidate'},
  ],
  'Comments': [
    {
      'id': 77,
      'content': 'Older comment',
      'user': {'id': 12, 'name': 'Candidate'},
      'created_at': '2026-10-05T09:00:00Z',
    },
    {
      'id': 78,
      'content': 'Ready for inspection',
      'user': {'id': 13, 'name': 'Reviewer'},
      'created_at': '2026-10-06T09:00:00Z',
    },
  ],
});

void main() {
  late MockTaskRepository repository;

  setUp(() => repository = MockTaskRepository());

  void stubTask(Future<Task> Function() answer) =>
      when(() => repository.fetchTask(501)).thenAnswer((_) => answer());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<TaskRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TaskDetailsScreen(task: _listTask),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every detail field and the latest comment', (
    tester,
  ) async {
    stubTask(() async => _detail);
    await pump(tester);

    expect(find.text('Site inspection'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Interview Project'), findsOneWidget);
    expect(find.text('Inspect the assigned site area'), findsOneWidget);
    expect(find.text('Oct 1, 2026'), findsOneWidget);
    expect(find.text('Oct 10, 2099'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Ready for inspection'), 200);
    expect(find.text('Candidate'), findsOneWidget);
    expect(find.text('Reviewer'), findsOneWidget);
    expect(find.text('Older comment'), findsNothing);
  });

  testWidgets('shows placeholders for missing optional values', (tester) async {
    stubTask(() async => const Task(id: 501, name: 'Site inspection'));
    await pump(tester);

    // Project name falls back to the list task until details include it.
    expect(find.text('Interview Project'), findsOneWidget);
    expect(find.text('No description'), findsOneWidget);
    expect(find.text('No dates set'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No comments yet'), 200);
    expect(find.text('Unassigned'), findsOneWidget);
  });

  testWidgets('a failed load shows the error and retries', (tester) async {
    var calls = 0;
    stubTask(() async {
      if (calls++ == 0) {
        throw const ApiException(ApiErrorType.network, 'Offline');
      }
      return _detail;
    });
    await pump(tester);
    expect(find.text('Offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Inspect the assigned site area'), findsOneWidget);
  });
}
