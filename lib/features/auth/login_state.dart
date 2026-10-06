part of 'login_cubit.dart';

enum LoginStatus { idle, submitting, success, failure }

final class LoginState extends Equatable {
  const LoginState({this.status = LoginStatus.idle, this.error, this.user});

  final LoginStatus status;
  final String? error;
  final User? user;

  bool get isSubmitting => status == LoginStatus.submitting;

  @override
  List<Object?> get props => [status, error, user];
}
