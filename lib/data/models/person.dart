import 'package:equatable/equatable.dart';

import 'json_utils.dart';

/// A user reference: a task assignee (`full_name`) or a comment author
/// (`name`).
class Person extends Equatable {
  const Person({this.id, required this.name});

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: readInt(json['id']),
    name:
        readString(firstOf(json, const ['full_name', 'name'])) ??
        'Unknown user',
  );

  final int? id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
