part of 'project_tasks_cubit.dart';

enum ProjectTasksStatus { initial, loading, success, failure }

final class ProjectTasksState extends Equatable {
  const ProjectTasksState({
    this.status = ProjectTasksStatus.initial,
    this.project,
    this.tasks = const [],
    this.query = '',
    this.statusFilter,
    this.error,
    this.refreshError,
  });

  final ProjectTasksStatus status;

  /// The project as returned with its tasks; null until loaded.
  final Project? project;

  /// Every task of the project, in API order.
  final List<Task> tasks;

  /// Search text, matched against task name and description.
  final String query;

  /// Only tasks with this status are shown; null shows all.
  final TaskStatus? statusFilter;

  /// Loading failed: shown full-screen with retry.
  final String? error;

  /// Pull-to-refresh failed while a list was already shown.
  final String? refreshError;

  bool get isFiltered => query.trim().isNotEmpty || statusFilter != null;

  /// Tasks matching [query] and [statusFilter], in API order.
  List<Task> get visibleTasks {
    final needle = query.trim().toLowerCase();
    return [
      for (final task in tasks)
        if ((statusFilter == null || task.status == statusFilter) &&
            (needle.isEmpty ||
                task.name.toLowerCase().contains(needle) ||
                (task.description?.toLowerCase().contains(needle) ?? false)))
          task,
    ];
  }

  /// Number of tasks per known status, for the filter chips. Tasks with an
  /// unrecognised status are only counted under "All".
  Map<TaskStatus, int> get statusCounts {
    final counts = <TaskStatus, int>{};
    for (final task in tasks) {
      final status = task.status;
      if (status != null) counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  ProjectTasksState copyWith({
    ProjectTasksStatus? status,
    Project? project,
    List<Task>? tasks,
    String? query,
    TaskStatus? statusFilter,
    String? refreshError,
    bool clearStatusFilter = false,
    bool clearRefreshError = false,
  }) => ProjectTasksState(
    status: status ?? this.status,
    project: project ?? this.project,
    tasks: tasks ?? this.tasks,
    query: query ?? this.query,
    statusFilter: clearStatusFilter ? null : statusFilter ?? this.statusFilter,
    error: error,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );

  @override
  List<Object?> get props => [
    status,
    project,
    tasks,
    query,
    statusFilter,
    error,
    refreshError,
  ];
}
