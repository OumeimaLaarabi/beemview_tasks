part of 'task_details_cubit.dart';

enum TaskDetailsStatus { initial, loading, success, failure }

final class TaskDetailsState extends Equatable {
  const TaskDetailsState({
    this.status = TaskDetailsStatus.initial,
    this.task,
    this.error,
    this.refreshError,
  });

  final TaskDetailsStatus status;

  /// The task in the detail-route shape; set once loaded.
  final Task? task;

  /// Loading failed: shown full-screen with retry.
  final String? error;

  /// Pull-to-refresh failed while the task was already shown.
  final String? refreshError;

  TaskDetailsState copyWith({
    TaskDetailsStatus? status,
    Task? task,
    String? refreshError,
    bool clearRefreshError = false,
  }) => TaskDetailsState(
    status: status ?? this.status,
    task: task ?? this.task,
    error: error,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
  );

  @override
  List<Object?> get props => [status, task, error, refreshError];
}
