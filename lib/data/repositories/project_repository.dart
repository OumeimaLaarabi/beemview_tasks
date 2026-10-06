import '../../core/network/api_client.dart';
import '../models/project.dart';

class ProjectRepository {
  ProjectRepository(this._api);

  static const defaultPageSize = 10;

  final ApiClient _api;

  /// `GET /projects?limit=&offset=`.
  Future<ProjectPage> fetchProjects({
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final json = await _api.get(
      '/projects',
      query: {'limit': limit, 'offset': offset},
    );
    return ProjectPage.fromJson(json);
  }
}
