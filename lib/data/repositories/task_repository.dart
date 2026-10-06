import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/json_utils.dart';
import '../models/task.dart';
import '../models/task_comment.dart';
import '../models/task_status.dart';

class TaskRepository {
  TaskRepository(this._api);

  final ApiClient _api;

  /// `GET /tasks/project/:projectId`: the full, unpaginated task list.
  /// Search and status filtering happen client-side on this result.
  Future<ProjectTasks> fetchProjectTasks(int projectId) async {
    _checkId(projectId);
    return ProjectTasks.fromJson(await _api.get('/tasks/project/$projectId'));
  }

  /// `GET /tasks/:id` → `{"task": {...}}`.
  Future<Task> fetchTask(int taskId) async {
    _checkId(taskId);
    final json = await _api.get('/tasks/$taskId');
    final task = readMap(json['task']);
    if (task == null) {
      throw const ApiException(ApiErrorType.notFound, 'Task not found.');
    }
    return Task.fromJson(task);
  }

  /// `PUT /tasks/:id` with only the status. Callers should re-fetch details
  /// afterwards, since the response task has a different shape.
  Future<void> updateStatus(int taskId, TaskStatus status) async {
    _checkId(taskId);
    await _api.put('/tasks/$taskId', {'status': status.apiValue});
  }

  /// `POST /tasks/comment`. Not idempotent: never call this automatically
  /// again after an ambiguous failure.
  Future<TaskComment?> addComment(int taskId, String content) async {
    _checkId(taskId);
    final text = content.trim();
    if (text.isEmpty) {
      throw ArgumentError.value(content, 'content', 'must not be empty');
    }
    final json = await _api.post('/tasks/comment', {
      'task_id': taskId,
      'content': text,
      'mentioned_user_ids': <int>[],
    });
    final comment = readMap(json['comment']);
    return comment == null ? null : TaskComment.fromJson(comment);
  }

  static void _checkId(int id) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'must be positive');
  }
}
