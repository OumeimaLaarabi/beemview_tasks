import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/project.dart';
import '../../data/models/task.dart';
import '../../data/models/task_status.dart';
import '../../data/repositories/task_repository.dart';

part 'project_tasks_state.dart';

/// Tasks of one project. The route is not paginated, so search and the
/// status filter run on the loaded list, and survive a refresh.
///
/// Each load starts a new generation; a response for an older generation is
/// dropped, so a slow first load can't overwrite a newer refresh.
class ProjectTasksCubit extends Cubit<ProjectTasksState> {
  ProjectTasksCubit(this._repository, this.projectId)
    : super(const ProjectTasksState());

  final TaskRepository _repository;
  final int projectId;

  int _generation = 0;

  /// Initial load, and retry from the full-screen error.
  Future<void> load() async {
    if (state.status == ProjectTasksStatus.loading) return;
    final generation = ++_generation;
    emit(
      ProjectTasksState(
        status: ProjectTasksStatus.loading,
        query: state.query,
        statusFilter: state.statusFilter,
      ),
    );
    try {
      final result = await _repository.fetchProjectTasks(projectId);
      if (_isStale(generation)) return;
      emit(
        state.copyWith(
          status: ProjectTasksStatus.success,
          project: result.project,
          tasks: result.tasks,
        ),
      );
    } catch (e) {
      if (_isStale(generation)) return;
      emit(
        ProjectTasksState(
          status: ProjectTasksStatus.failure,
          query: state.query,
          statusFilter: state.statusFilter,
          error: _message(e),
        ),
      );
    }
  }

  /// Pull-to-refresh: reloads while the current list stays visible.
  Future<void> refresh() async {
    if (state.status != ProjectTasksStatus.success) return load();
    final generation = ++_generation;
    emit(state.copyWith(clearRefreshError: true));
    try {
      final result = await _repository.fetchProjectTasks(projectId);
      if (_isStale(generation)) return;
      emit(state.copyWith(project: result.project, tasks: result.tasks));
    } catch (e) {
      if (_isStale(generation)) return;
      emit(state.copyWith(refreshError: _message(e)));
    }
  }

  void search(String query) {
    if (query != state.query) emit(state.copyWith(query: query));
  }

  /// Null shows every status.
  void filterByStatus(TaskStatus? status) => emit(
    status == null
        ? state.copyWith(clearStatusFilter: true)
        : state.copyWith(statusFilter: status),
  );

  void clearFilters() =>
      emit(state.copyWith(query: '', clearStatusFilter: true));

  /// True when the cubit was closed (e.g. the screen was left) or a newer
  /// load replaced this request.
  bool _isStale(int generation) => isClosed || generation != _generation;

  static String _message(Object error) => error is ApiException
      ? error.message
      : 'Could not load tasks. Please try again.';
}
