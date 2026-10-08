import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/data/models/task.dart';
import 'package:beemview_tasks/data/models/task_status.dart';
import 'package:beemview_tasks/data/repositories/task_repository.dart';
import 'package:beemview_tasks/features/tasks/task_details_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

const _task = Task(
  id: 501,
  name: 'Site inspection',
  status: TaskStatus.toDo,
  rawStatus: 'to_do',
);

const _offline = ApiException(ApiErrorType.network, 'Offline');

void main() {
  late MockTaskRepository repository;

  setUp(() => repository = MockTaskRepository());

  void stubTask(Future<Task> Function() answer) =>
      when(() => repository.fetchTask(501)).thenAnswer((_) => answer());

  TaskDetailsCubit build() => TaskDetailsCubit(repository, 501);

  blocTest<TaskDetailsCubit, TaskDetailsState>(
    'emits loading then the task',
    setUp: () => stubTask(() async => _task),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const TaskDetailsState(status: TaskDetailsStatus.loading),
      const TaskDetailsState(status: TaskDetailsStatus.success, task: _task),
    ],
  );

  blocTest<TaskDetailsCubit, TaskDetailsState>(
    'emits failure with the API message',
    setUp: () => stubTask(() => throw _offline),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const TaskDetailsState(status: TaskDetailsStatus.loading),
      const TaskDetailsState(
        status: TaskDetailsStatus.failure,
        error: 'Offline',
      ),
    ],
  );

  blocTest<TaskDetailsCubit, TaskDetailsState>(
    'explains a missing task (404)',
    setUp: () => stubTask(
      () => throw const ApiException(
        ApiErrorType.notFound,
        'Not found',
        statusCode: 404,
      ),
    ),
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<TaskDetailsState>().having(
        (s) => s.error,
        'error',
        contains('no longer exists'),
      ),
    ],
  );

  blocTest<TaskDetailsCubit, TaskDetailsState>(
    'a failed refresh keeps the task and reports the error',
    setUp: () {
      var calls = 0;
      stubTask(() async {
        if (calls++ == 0) return _task;
        throw _offline;
      });
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.refresh();
    },
    verify: (cubit) {
      expect(cubit.state.status, TaskDetailsStatus.success);
      expect(cubit.state.task, _task);
      expect(cubit.state.refreshError, 'Offline');
    },
  );
}
