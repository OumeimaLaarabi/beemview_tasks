part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Startup: the stored session hasn't been checked yet.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// The stored session couldn't be verified (e.g. offline). The token is kept
/// so the user can retry instead of being signed out.
final class AuthRestoreFailed extends AuthState {
  const AuthRestoreFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
