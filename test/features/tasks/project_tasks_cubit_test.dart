import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/data/models/project.dart';
import 'package:beemview_tasks/data/models/task.dart';
import 'package:beemview_tasks/data/models/task_status.dart';
import 'package:beemview_tasks/data/repositories/task_repository.dart';
import 'package:beemview_tasks/features/tasks/project_tasks_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

const _project = Project(id: 101, name: 'Interview Project');

const _tasks = [
  Task(
    id: 1,
    name: 'Site inspection',
    status: TaskStatus.toDo,
    rawStatus: 'to_do',
  ),
  Task(
    id: 2,
    name: 'Write report',
    description: 'Summarise the inspection findings',
    status: TaskStatus.inProgress,
    rawStatus: 'in_progress',
  ),
  Task(id: 3, name: 'Order parts', status: TaskStatus.done, rawStatus: 'done'),
];

const _offline = ApiException(ApiErrorType.network, 'Offline');

void main() {
  late MockTaskRepository repository;

  setUp(() => repository = MockTaskRepository());

  void stubTasks(Future<ProjectTasks> Function() answer) =>
      when(() => repository.fetchProjectTasks(101)).thenAnswer((_) => answer());

  ProjectTasksCubit build() => ProjectTasksCubit(repository, 101);

  Future<ProjectTasks> loaded() async =>
      const ProjectTasks(project: _project, tasks: _tasks);

  group('load', () {
    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'emits loading then the tasks',
      setUp: () => stubTasks(loaded),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const ProjectTasksState(status: ProjectTasksStatus.loading),
        const ProjectTasksState(
          status: ProjectTasksStatus.success,
          project: _project,
          tasks: _tasks,
        ),
      ],
    );

    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'emits failure with the API message',
      setUp: () => stubTasks(() => throw _offline),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const ProjectTasksState(status: ProjectTasksStatus.loading),
        const ProjectTasksState(
          status: ProjectTasksStatus.failure,
          error: 'Offline',
        ),
      ],
    );

    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'ignores a second load while one is in flight',
      setUp: () => stubTasks(loaded),
      build: build,
      act: (cubit) => Future.wait([cubit.load(), cubit.load()]),
      verify: (_) => verify(() => repository.fetchProjectTasks(101)).called(1),
    );
  });

  group('refresh', () {
    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'a failed refresh keeps the current list and reports the error',
      setUp: () {
        var calls = 0;
        stubTasks(() async {
          if (calls++ == 0) return loaded();
          throw _offline;
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.refresh();
      },
      verify: (cubit) {
        expect(cubit.state.status, ProjectTasksStatus.success);
        expect(cubit.state.tasks, _tasks);
        expect(cubit.state.refreshError, 'Offline');
      },
    );

    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'keeps the search and filter across a refresh',
      setUp: () => stubTasks(loaded),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..search('report')
          ..filterByStatus(TaskStatus.inProgress);
        await cubit.refresh();
      },
      verify: (cubit) {
        expect(cubit.state.query, 'report');
        expect(cubit.state.statusFilter, TaskStatus.inProgress);
        expect(cubit.state.visibleTasks.single.id, 2);
      },
    );

    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'before a successful load, refresh does a full load',
      setUp: () => stubTasks(loaded),
      build: build,
      act: (cubit) => cubit.refresh(),
      expect: () => [
        const ProjectTasksState(status: ProjectTasksStatus.loading),
        isA<ProjectTasksState>().having(
          (s) => s.status,
          'status',
          ProjectTasksStatus.success,
        ),
      ],
    );
  });

  group('filtering', () {
    const state = ProjectTasksState(
      status: ProjectTasksStatus.success,
      tasks: [
        ..._tasks,
        Task(id: 4, name: 'Legacy item', rawStatus: 'archived'),
      ],
    );

    test('search matches the task name only, ignoring case', () {
      expect(state.copyWith(query: 'SITE').visibleTasks.map((t) => t.id), [1]);
      // "findings" only appears in a description.
      expect(state.copyWith(query: 'findings').visibleTasks, isEmpty);
      expect(state.copyWith(query: '   ').visibleTasks, hasLength(4));
    });

    test('status filter and search combine', () {
      final filtered = state.copyWith(
        query: 'o',
        statusFilter: TaskStatus.done,
      );
      expect(filtered.visibleTasks.map((t) => t.id), [3]);
      expect(filtered.isFiltered, isTrue);
    });

    test('counts known statuses; unknown ones only count under All', () {
      expect(state.statusCounts, {
        TaskStatus.toDo: 1,
        TaskStatus.inProgress: 1,
        TaskStatus.done: 1,
      });
    });

    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'clearFilters resets search and status',
      build: build,
      seed: () => state.copyWith(query: 'x', statusFilter: TaskStatus.blocked),
      act: (cubit) => cubit.clearFilters(),
      expect: () => [state],
    );

    blocTest<ProjectTasksCubit, ProjectTasksState>(
      'filterByStatus(null) shows every status again',
      build: build,
      seed: () => state.copyWith(statusFilter: TaskStatus.done),
      act: (cubit) => cubit.filterByStatus(null),
      expect: () => [state],
    );
  });
}
