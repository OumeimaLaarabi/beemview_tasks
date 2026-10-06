import 'package:equatable/equatable.dart';

import 'json_utils.dart';
import 'person.dart';

class TaskComment extends Equatable {
  const TaskComment({
    this.id,
    required this.content,
    this.author,
    this.createdAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    final user = readMap(firstOf(json, const ['user', 'User', 'author']));
    return TaskComment(
      id: readInt(json['id']),
      content: readString(json['content']) ?? '',
      author: user == null ? null : Person.fromJson(user),
      createdAt: readDate(firstOf(json, const ['created_at', 'createdAt'])),
    );
  }

  final int? id;
  final String content;
  final Person? author;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, content, author, createdAt];
}
