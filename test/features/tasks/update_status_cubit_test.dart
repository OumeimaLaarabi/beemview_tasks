import 'dart:async';

import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/data/models/task_comment.dart';
import 'package:beemview_tasks/data/models/task_status.dart';
import 'package:beemview_tasks/data/repositories/task_repository.dart';
import 'package:beemview_tasks/features/tasks/update_status_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

const _offline = ApiException(ApiErrorType.network, 'Offline');

/// No response after the request was sent: the server may have stored it.
const _timeout = ApiException(
  ApiErrorType.timeout,
  'Timed out',
  mayHaveReachedServer: true,
);

void main() {
  late MockTaskRepository repository;

  setUpAll(() => registerFallbackValue(TaskStatus.toDo));
  setUp(() => repository = MockTaskRepository());

  void stubStatus(Future<void> Function() answer) =>
      when(() => repository.updateStatus(501, TaskStatus.done))
          .thenAnswer((_) => answer());

  void stubComment(Future<TaskComment?> Function() answer) =>
      when(() => repository.addComment(501, any())).thenAnswer((_) => answer());

  /// A form for a "to do" task with "done" already chosen.
  UpdateStatusCubit build() =>
      UpdateStatusCubit(repository, taskId: 501, current: TaskStatus.toDo)
        ..select(TaskStatus.done);

  const chosen = UpdateStatusState(
    current: TaskStatus.toDo,
    selected: TaskStatus.done,
  );

  test('starts with the current status selected and nothing to save', () {
    final cubit = UpdateStatusCubit(
      repository,
      taskId: 501,
      current: TaskStatus.toDo,
    );
    expect(cubit.state.selected, TaskStatus.toDo);
    expect(cubit.state.canSave, isFalse);
    cubit.close();
  });

  blocTest<UpdateStatusCubit, UpdateStatusState>(
    'saves the status and finishes when there is no note',
    setUp: () => stubStatus(() async {}),
    build: build,
    act: (cubit) => cubit.submit('   '),
    expect: () => [
      chosen.copyWith(phase: UpdateStatusPhase.savingStatus),
      chosen.copyWith(phase: UpdateStatusPhase.savingStatus, statusSaved: true),
      chosen.copyWith(phase: UpdateStatusPhase.done, statusSaved: true),
    ],
    verify: (_) => verifyNever(() => repository.addComment(any(), any())),
  );

  blocTest<UpdateStatusCubit, UpdateStatusState>(
    'saves the status first, then posts the trimmed note',
    setUp: () {
      stubStatus(() async {});
      stubComment(() async => null);
    },
    build: build,
    act: (cubit) => cubit.submit('  Inspection started  '),
    expect: () => [
      chosen.copyWith(phase: UpdateStatusPhase.savingStatus),
      chosen.copyWith(phase: UpdateStatusPhase.savingStatus, statusSaved: true),
      chosen.copyWith(
        phase: UpdateStatusPhase.postingComment,
        statusSaved: true,
      ),
      chosen.copyWith(
        phase: UpdateStatusPhase.done,
        statusSaved: true,
        commentPosted: true,
      ),
    ],
    verify: (_) => verifyInOrder([
      () => repository.updateStatus(501, TaskStatus.done),
      () => repository.addComment(501, 'Inspection started'),
    ]),
  );

  blocTest<UpdateStatusCubit, UpdateStatusState>(
    'a failed status save posts no comment and lets the user try again',
    setUp: () => stubStatus(() => throw _offline),
    build: build,
    act: (cubit) => cubit.submit('A note'),
    expect: () => [
      chosen.copyWith(phase: UpdateStatusPhase.savingStatus),
      chosen.copyWith(error: 'Offline'),
    ],
    verify: (cubit) {
      expect(cubit.state.statusSaved, isFalse);
      expect(cubit.state.canSave, isTrue);
      verifyNever(() => repository.addComment(any(), any()));
    },
  );

  blocTest<UpdateStatusCubit, UpdateStatusState>(
    'status saved but comment failed: only the comment can be retried',
    setUp: () {
      stubStatus(() async {});
      var calls = 0;
      stubComment(() async {
        if (calls++ == 0) throw _offline;
        return null;
      });
    },
    build: build,
    act: (cubit) async {
      await cubit.submit('A note');
      expect(cubit.state.phase, UpdateStatusPhase.commentFailed);
      expect(cubit.state.statusSaved, isTrue);
      expect(cubit.state.error, 'Offline');

      // Saving the status again is not possible from here.
      await cubit.submit('A note');
      await cubit.retryComment('A note');
    },
    verify: (cubit) {
      expect(cubit.state.phase, UpdateStatusPhase.done);
      expect(cubit.state.commentPosted, isTrue);
      verify(() => repository.updateStatus(501, TaskStatus.done)).called(1);
      verify(() => repository.addComment(501, 'A note')).called(2);
    },
  );

  blocTest<UpdateStatusCubit, UpdateStatusState>(
    'an ambiguous comment failure is flagged and never retried by itself',
    setUp: () {
      stubStatus(() async {});
      stubComment(() => throw _timeout);
    },
    build: build,
    act: (cubit) => cubit.submit('A note'),
    verify: (cubit) {
      expect(cubit.state.phase, UpdateStatusPhase.commentFailed);
      expect(cubit.state.commentMayHavePosted, isTrue);
      verify(() => repository.addComment(501, 'A note')).called(1);
    },
  );

  blocTest<UpdateStatusCubit, UpdateStatusState>(
    'ignores a second submit while saving',
    setUp: () {
      final pending = Completer<void>();
      stubStatus(() => pending.future);
      // Let the first request finish after both taps.
      Future<void>.delayed(Duration.zero, pending.complete);
    },
    build: build,
    act: (cubit) => Future.wait([cubit.submit(''), cubit.submit('')]),
    verify: (_) =>
        verify(() => repository.updateStatus(501, TaskStatus.done)).called(1),
  );

  blocTest<UpdateStatusCubit, UpdateStatusState>(
    'does not send the unchanged current status',
    build: () =>
        UpdateStatusCubit(repository, taskId: 501, current: TaskStatus.toDo),
    act: (cubit) => cubit.submit('A note'),
    expect: () => <UpdateStatusState>[],
    verify: (_) => verifyNever(() => repository.updateStatus(any(), any())),
  );
}
