import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';

part 'projects_state.dart';

/// Paginated project list with a "load more" action.
///
/// Each first-page load (initial or refresh) starts a new generation; a page
/// that arrives for an older generation is dropped, so a refresh can't be
/// mixed with a slower "load more" that was already in flight.
class ProjectsCubit extends Cubit<ProjectsState> {
  ProjectsCubit(
    this._repository, {
    this.pageSize = ProjectRepository.defaultPageSize,
  }) : super(const ProjectsState());

  final ProjectRepository _repository;
  final int pageSize;

  int _generation = 0;

  /// Raw items received so far: the next request's offset. Kept separately
  /// from `projects.length` because duplicates are dropped when appending.
  int _nextOffset = 0;

  /// Initial load, and retry from the full-screen error.
  Future<void> load() async {
    if (state.status == ProjectsStatus.loading) return;
    final generation = ++_generation;
    emit(const ProjectsState(status: ProjectsStatus.loading));
    try {
      final page = await _repository.fetchProjects(limit: pageSize);
      if (_isStale(generation)) return;
      emit(_firstPage(page));
    } catch (e) {
      if (_isStale(generation)) return;
      emit(ProjectsState(status: ProjectsStatus.failure, error: _message(e)));
    }
  }

  /// Pull-to-refresh: reloads page one while the current list stays visible.
  Future<void> refresh() async {
    if (state.status != ProjectsStatus.success) return load();
    final generation = ++_generation;
    emit(
      state.copyWith(
        isLoadingMore: false,
        clearLoadMoreError: true,
        clearRefreshError: true,
      ),
    );
    try {
      final page = await _repository.fetchProjects(limit: pageSize);
      if (_isStale(generation)) return;
      emit(_firstPage(page));
    } catch (e) {
      if (_isStale(generation)) return;
      emit(state.copyWith(refreshError: _message(e)));
    }
  }

  /// Appends the next page. Ignored while a page is loading or when
  /// everything has been loaded.
  Future<void> loadMore() async {
    if (state.status != ProjectsStatus.success ||
        !state.hasMore ||
        state.isLoadingMore) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    try {
      final page = await _repository.fetchProjects(
        limit: pageSize,
        offset: _nextOffset,
      );
      if (_isStale(generation)) return;
      _nextOffset += page.items.length;
      final seen = {for (final p in state.projects) p.id};
      final merged = [
        ...state.projects,
        ...page.items.where((p) => seen.add(p.id)),
      ];
      emit(
        state.copyWith(
          projects: merged,
          total: page.total,
          hasMore: page.items.isNotEmpty && _nextOffset < page.total,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (_isStale(generation)) return;
      emit(state.copyWith(isLoadingMore: false, loadMoreError: _message(e)));
    }
  }

  ProjectsState _firstPage(ProjectPage page) {
    _nextOffset = page.items.length;
    return ProjectsState(
      status: ProjectsStatus.success,
      projects: page.items,
      total: page.total,
      hasMore: page.items.isNotEmpty && _nextOffset < page.total,
    );
  }

  /// True when the cubit was closed (e.g. logged out by a 401) or a newer
  /// load replaced this request.
  bool _isStale(int generation) => isClosed || generation != _generation;

  static String _message(Object error) => error is ApiException
      ? error.message
      : 'Could not load projects. Please try again.';
}
