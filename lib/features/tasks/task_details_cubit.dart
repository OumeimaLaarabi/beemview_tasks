import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';

part 'task_details_state.dart';

/// One task from `GET /tasks/:id`.
///
/// Each load starts a new generation; a response for an older generation is
/// dropped, so a slow first load can't overwrite a newer refresh.
class TaskDetailsCubit extends Cubit<TaskDetailsState> {
  TaskDetailsCubit(this._repository, this.taskId)
    : super(const TaskDetailsState());

  final TaskRepository _repository;
  final int taskId;

  int _generation = 0;

  /// Initial load, and retry from the full-screen error.
  Future<void> load() async {
    if (state.status == TaskDetailsStatus.loading) return;
    final generation = ++_generation;
    emit(const TaskDetailsState(status: TaskDetailsStatus.loading));
    try {
      final task = await _repository.fetchTask(taskId);
      if (_isStale(generation)) return;
      emit(TaskDetailsState(status: TaskDetailsStatus.success, task: task));
    } catch (e) {
      if (_isStale(generation)) return;
      emit(
        TaskDetailsState(status: TaskDetailsStatus.failure, error: _message(e)),
      );
    }
  }

  /// Pull-to-refresh: reloads while the current task stays visible.
  Future<void> refresh() async {
    if (state.status != TaskDetailsStatus.success) return load();
    final generation = ++_generation;
    emit(state.copyWith(clearRefreshError: true));
    try {
      final task = await _repository.fetchTask(taskId);
      if (_isStale(generation)) return;
      emit(state.copyWith(task: task));
    } catch (e) {
      if (_isStale(generation)) return;
      emit(state.copyWith(refreshError: _message(e)));
    }
  }

  /// True when the cubit was closed (e.g. the screen was left) or a newer
  /// load replaced this request.
  bool _isStale(int generation) => isClosed || generation != _generation;

  static String _message(Object error) => switch (error) {
    ApiException(type: ApiErrorType.notFound) =>
      'This task no longer exists or was moved.',
    ApiException(:final message) => message,
    _ => 'Could not load the task. Please try again.',
  };
}
