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
    this.query = '',
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

  /// Search text, matched against the names of the projects loaded so far.
  final String query;

  /// Loaded projects whose name contains [query], ignoring case.
  List<Project> get visibleProjects {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return projects;
    return [
      for (final project in projects)
        if (project.name.toLowerCase().contains(needle)) project,
    ];
  }

  ProjectsState copyWith({
    List<Project>? projects,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
    String? refreshError,
    String? query,
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
    query: query ?? this.query,
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
    query,
  ];
}
