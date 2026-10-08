import 'package:equatable/equatable.dart';

import 'json_utils.dart';
import 'person.dart';
import 'project.dart';
import 'task_comment.dart';
import 'task_priority.dart';
import 'task_status.dart';

/// A task, normalised from either API shape:
///
/// | field    | GET /tasks/project/:id | GET /tasks/:id        |
/// |----------|------------------------|-----------------------|
/// | due      | `dueDate`              | `due_date`            |
/// | start    | `startedDate`          | `start_date`          |
/// | priority | `"High"`               | `"high"`              |
/// | project  | `projectId`            | `project_id`/`Project`|
///
/// The list route's `progress` value is deliberately ignored: progress is
/// tracked through [status] only.
class Task extends Equatable {
  const Task({
    required this.id,
    required this.name,
    this.description,
    this.status,
    this.rawStatus,
    this.priority,
    this.startDate,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.projectId,
    this.projectName,
    this.assignees = const [],
    this.comments = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    final project = readMap(firstOf(json, const ['Project', 'project']));
    final rawStatus = readString(json['status']);

    var assignees = readMapList(firstOf(json, const ['Assignees', 'assignees']))
        .map(Person.fromJson)
        .toList();
    final assignedTo = readString(json['assignedTo']);
    if (assignees.isEmpty && assignedTo != null) {
      assignees = [Person(name: assignedTo)];
    }

    return Task(
      id: readInt(json['id']) ?? 0,
      name: readString(json['name']) ?? 'Untitled task',
      description: readString(json['description']),
      status: TaskStatus.fromApi(rawStatus),
      rawStatus: rawStatus,
      priority: TaskPriority.fromApi(readString(json['priority'])),
      startDate: readDateOnly(
        firstOf(json, const ['start_date', 'startedDate', 'startDate']),
      ),
      dueDate: readDateOnly(firstOf(json, const ['due_date', 'dueDate'])),
      createdAt: readDate(firstOf(json, const ['created_at', 'createdAt'])),
      updatedAt: readDate(firstOf(json, const ['updated_at', 'updatedAt'])),
      projectId:
          readInt(firstOf(json, const ['project_id', 'projectId'])) ??
          (project == null ? null : readInt(project['id'])),
      projectName: project == null ? null : readString(project['name']),
      assignees: assignees,
      comments: readMapList(firstOf(json, const ['Comments', 'comments']))
          .map(TaskComment.fromJson)
          .toList(),
    );
  }

  final int id;
  final String name;
  final String? description;

  /// Null when the API sent a status this app doesn't know; see [rawStatus].
  final TaskStatus? status;
  final String? rawStatus;
  final TaskPriority? priority;

  /// Calendar dates (local midnight, no time): see [readDateOnly].
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? projectId;
  final String? projectName;
  final List<Person> assignees;

  /// Up to 10 recent comments (details route only).
  final List<TaskComment> comments;

  /// Human-readable status, falling back to the raw API value.
  String get statusLabel => status?.label ?? rawStatus ?? 'Unknown';

  /// True when [dueDate] is before [today]'s date and the task is still
  /// open (not done or canceled).
  bool isOverdueOn(DateTime today) {
    final due = dueDate;
    if (due == null ||
        status == TaskStatus.done ||
        status == TaskStatus.canceled) {
      return false;
    }
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// The newest returned comment. Order is not assumed from the API.
  TaskComment? get latestComment {
    if (comments.isEmpty) return null;
    return comments.reduce((latest, c) {
      final a = latest.createdAt, b = c.createdAt;
      if (a == null) return b == null ? latest : c;
      return (b != null && b.isAfter(a)) ? c : latest;
    });
  }

  Task copyWith({String? projectName}) => Task(
    id: id,
    name: name,
    description: description,
    status: status,
    rawStatus: rawStatus,
    priority: priority,
    startDate: startDate,
    dueDate: dueDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
    projectId: projectId,
    projectName: projectName ?? this.projectName,
    assignees: assignees,
    comments: comments,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    rawStatus,
    priority,
    startDate,
    dueDate,
    createdAt,
    updatedAt,
    projectId,
    projectName,
    assignees,
    comments,
  ];
}

/// Result of `GET /tasks/project/:projectId` (not paginated).
class ProjectTasks extends Equatable {
  const ProjectTasks({this.project, required this.tasks});

  factory ProjectTasks.fromJson(Map<String, dynamic> json) {
    final projectJson = readMap(json['project']);
    final project = projectJson == null ? null : Project.fromJson(projectJson);
    return ProjectTasks(
      project: project,
      tasks: readMapList(json['tasks'])
          .map(Task.fromJson)
          .where((t) => t.id > 0)
          .map(
            (t) => t.projectName == null && project != null
                ? t.copyWith(projectName: project.name)
                : t,
          )
          .toList(),
    );
  }

  final Project? project;
  final List<Task> tasks;

  @override
  List<Object?> get props => [project, tasks];
}
