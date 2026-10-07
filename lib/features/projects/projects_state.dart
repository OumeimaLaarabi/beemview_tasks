part of 'projects_cubit.dart';

enum ProjectsStatus { initial, loading, success, failure }

final class ProjectsState extends Equatable {
  const ProjectsState({
    this.status = ProjectsStatus.initial,
    this.projects = const [],
    this.total = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.refreshError,
  });

  final ProjectsStatus status;
  final List<Project> projects;

  /// Total projects available to the user, as reported by the API.
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  /// First page failed: shown full-screen with retry.
  final String? error;

  /// A "load more" page failed: shown under the list; loaded items stay.
  final String? loadMoreError;

  /// Pull-to-refresh failed while a list was already shown.
  final String? refreshError;

  ProjectsState copyWith({
    List<Project>? projects,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
    String? refreshError,
    bool clearLoadMoreError = false,
    bool clearRefreshError = false,
  }) => ProjectsState(
    status: status,
    projects: projects ?? this.projects,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: error,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );

  @override
  List<Object?> get props => [
    status,
    projects,
    total,
    hasMore,
    isLoadingMore,
    error,
    loadMoreError,
    refreshError,
  ];
}
