import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_state.dart';

/// App-wide session state. Any 401 reported through
/// [AuthRepository.sessionExpired] returns the app to [AuthUnauthenticated].
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthUnknown()) {
    _expiredSubscription = _repository.sessionExpired.listen(
      (_) => _onSessionExpired(),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _expiredSubscription;

  /// Validates the stored token. Called on startup and from the retry UI.
  Future<void> restoreSession() async {
    if (state is! AuthUnknown) emit(const AuthUnknown());
    try {
      final user = await _repository.restoreSession();
      emit(
        user == null ? const AuthUnauthenticated() : AuthAuthenticated(user),
      );
    } on ApiException catch (e) {
      // On 401 ApiClient has already cleared the stored token.
      emit(
        e.isUnauthorized
            ? const AuthUnauthenticated()
            : AuthRestoreFailed(e.message),
      );
    } catch (_) {
      emit(const AuthRestoreFailed('Could not restore your session.'));
    }
  }

  void loggedIn(User user) => emit(AuthAuthenticated(user));

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      emit(const AuthUnauthenticated());
    }
  }

  void _onSessionExpired() {
    if (!isClosed) emit(const AuthUnauthenticated());
  }

  @override
  Future<void> close() async {
    await _expiredSubscription.cancel();
    return super.close();
  }
}
