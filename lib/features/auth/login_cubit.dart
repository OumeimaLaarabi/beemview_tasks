import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

part 'login_state.dart';

/// Submits credentials. On success the screen hands the user to
/// [AuthCubit.loggedIn]; this cubit only owns the form's request state.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginState());

  final AuthRepository _repository;

  Future<void> submit({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    // Ignore repeated taps while a request is in flight.
    if (state.isSubmitting) return;
    emit(const LoginState(status: LoginStatus.submitting));
    try {
      final user = await _repository.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      emit(LoginState(status: LoginStatus.success, user: user));
    } on ApiException catch (e) {
      emit(LoginState(status: LoginStatus.failure, error: _messageFor(e)));
    } catch (_) {
      emit(
        const LoginState(
          status: LoginStatus.failure,
          error: 'Sign in failed. Please try again.',
        ),
      );
    }
  }

  /// Hides a failed sign-in message once the user edits the form.
  void clearError() {
    if (state.status == LoginStatus.failure) emit(const LoginState());
  }

  static String _messageFor(ApiException e) => switch (e.type) {
    // 403 on login means the account is inactive, not an expired session.
    ApiErrorType.forbidden =>
      'This account is inactive or has no access. '
          'Contact your administrator.',
    _ => e.message,
  };
}
