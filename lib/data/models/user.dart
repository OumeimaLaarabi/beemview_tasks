import 'package:equatable/equatable.dart';

import 'json_utils.dart';

/// The signed-in user. Display name is `full_name` per the contract.
class User extends Equatable {
  const User({required this.id, required this.fullName, this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: readInt(json['id']) ?? 0,
    fullName:
        readString(firstOf(json, const ['full_name', 'name'])) ??
        readString(json['email']) ??
        'User',
    email: readString(json['email']),
  );

  final int id;
  final String fullName;
  final String? email;

  @override
  List<Object?> get props => [id, fullName, email];
}
