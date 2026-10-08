import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/data/models/project.dart';
import 'package:beemview_tasks/data/models/task.dart';
import 'package:beemview_tasks/data/models/task_priority.dart';
import 'package:beemview_tasks/data/models/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectTasks.fromJson (list route shape)', () {
    final json = {
      'project': {'id': 101, 'name': 'Interview Project'},
      'tasks': [
        {
          'id': 501,
          'name': 'Site inspection',
          'status': 'to_do',
          'priority': 'High',
          'dueDate': null,
          'startedDate': '2026-10-06T09:00:00Z',
          'projectId': 101,
          'assignedTo': 'Candidate',
          'Assignees': [
            {'id': 12, 'full_name': 'Candidate'},
          ],
          'progress': 40,
        },
      ],
      'statistics': {},
      'count': 1,
    };

    test('maps camelCase dates, capitalised priority and project', () {
      final result = ProjectTasks.fromJson(json);
      final task = result.tasks.single;

      expect(result.project?.name, 'Interview Project');
      expect(task.id, 501);
      expect(task.name, 'Site inspection');
      expect(task.status, TaskStatus.toDo);
      expect(task.priority, TaskPriority.high);
      expect(task.dueDate, isNull);
      expect(task.startDate, DateTime(2026, 10, 6));
      expect(task.projectId, 101);
      expect(task.projectName, 'Interview Project');
      expect(task.assignees.single.name, 'Candidate');
    });
  });

  group('Task.fromJson (detail route shape)', () {
    final json = {
      'id': 501,
      'name': 'Site inspection',
      'description': 'Inspect the assigned site area',
      'status': 'in_progress',
      'priority': 'high',
      'due_date': '2026-10-10T00:00:00Z',
      'start_date': null,
      'project_id': 101,
      'Project': {'id': 101, 'name': 'Interview Project'},
      'Assignees': [
        {'id': 12, 'full_name': 'Candidate'},
      ],
      'Comments': [
        {
          'id': 77,
          'content': 'Older',
          'user': {'id': 12, 'name': 'Candidate'},
          'created_at': '2026-10-05T09:00:00Z',
        },
        {
          'id': 78,
          'content': 'Newest',
          'user': {'id': 12, 'name': 'Candidate'},
          'created_at': '2026-10-06T09:00:00Z',
        },
      ],
    };

    test('maps snake_case dates, lowercase priority and associations', () {
      final task = Task.fromJson(json);

      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.high);
      expect(task.dueDate, DateTime(2026, 10, 10));
      expect(task.startDate, isNull);
      expect(task.projectName, 'Interview Project');
      expect(task.description, 'Inspect the assigned site area');
    });

    test('latestComment picks the newest by created_at, not list order', () {
      final comment = Task.fromJson(json).latestComment;
      expect(comment?.content, 'Newest');
      expect(comment?.author?.name, 'Candidate');
    });

    test('due/start dates keep the calendar day in any time zone', () {
      final task = Task.fromJson({
        'id': 9,
        'name': 'Dates',
        'due_date': '2026-10-10T00:00:00Z',
        'start_date': '2026-10-01',
      });
      expect(task.dueDate, DateTime(2026, 10, 10));
      expect(task.startDate, DateTime(2026, 10, 1));
    });

    test('isOverdueOn: open tasks past their due day only', () {
      final today = DateTime(2026, 10, 10, 15, 30);
      Task task(String status, String? due) => Task.fromJson({
        'id': 1,
        'name': 'T',
        'status': status,
        'due_date': due,
      });

      expect(task('to_do', '2026-10-09T00:00:00Z').isOverdueOn(today), isTrue);
      expect(task('to_do', '2026-10-10T00:00:00Z').isOverdueOn(today), isFalse);
      expect(task('done', '2026-10-01T00:00:00Z').isOverdueOn(today), isFalse);
      expect(
        task('canceled', '2026-10-01T00:00:00Z').isOverdueOn(today),
        isFalse,
      );
      expect(task('to_do', null).isOverdueOn(today), isFalse);
    });

    test('tolerates missing optional fields and unknown status', () {
      final task = Task.fromJson({'id': 9, 'name': 'Bare', 'status': 'new'});
      expect(task.status, isNull);
      expect(task.statusLabel, 'new');
      expect(task.priority, isNull);
      expect(task.assignees, isEmpty);
      expect(task.latestComment, isNull);
    });
  });

  group('ProjectPage.fromJson', () {
    test('reads the paginated data envelope', () {
      final page = ProjectPage.fromJson({
        'total': 12,
        'count': 10,
        'limit': 10,
        'offset': 0,
        'data': [
          {'id': 101, 'name': 'Interview Project'},
        ],
      });
      expect(page.total, 12);
      expect(page.items.single.name, 'Interview Project');
    });

    test('treats the empty-visibility {result: [], count: 0} as empty', () {
      final page = ProjectPage.fromJson({'result': [], 'count': 0});
      expect(page.items, isEmpty);
      expect(page.total, 0);
    });
  });

  group('ApiException.fromStatus', () {
    test('combines error with validation details', () {
      final e = ApiException.fromStatus(400, {
        'error': 'Validation failed',
        'details': [
          {
            'path': 'status',
            'message': 'Invalid value',
            'code': 'invalid_enum_value',
          },
        ],
      });
      expect(e.type, ApiErrorType.badRequest);
      expect(e.message, contains('Validation failed'));
      expect(e.message, contains('status: Invalid value'));
      expect(e.details.single.code, 'invalid_enum_value');
    });

    test('keeps 403 distinct from 401', () {
      expect(
        ApiException.fromStatus(401, null).type,
        ApiErrorType.unauthorized,
      );
      expect(ApiException.fromStatus(403, null).type, ApiErrorType.forbidden);
    });
  });
}
