import 'package:equatable/equatable.dart';

import 'json_utils.dart';

class Project extends Equatable {
  const Project({required this.id, required this.name, this.description});

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: readInt(json['id']) ?? 0,
    name: readString(json['name']) ?? 'Untitled project',
    description: readString(json['description']),
  );

  final int id;
  final String name;
  final String? description;

  @override
  List<Object?> get props => [id, name, description];
}

/// One page of `GET /projects`.
class ProjectPage extends Equatable {
  const ProjectPage({
    required this.items,
    required this.total,
    required this.offset,
  });

  /// Accepts the normal `{data, total, count, limit, offset}` envelope and the
  /// empty-visibility `{result: [], count: 0}` variant.
  factory ProjectPage.fromJson(Map<String, dynamic> json) {
    final items = readMapList(firstOf(json, const ['data', 'result']))
        .map(Project.fromJson)
        .where((p) => p.id > 0)
        .toList();
    return ProjectPage(
      items: items,
      total: readInt(firstOf(json, const ['total', 'count'])) ?? items.length,
      offset: readInt(json['offset']) ?? 0,
    );
  }

  final List<Project> items;

  /// Total projects available to the user across all pages.
  final int total;
  final int offset;

  @override
  List<Object?> get props => [items, total, offset];
}
