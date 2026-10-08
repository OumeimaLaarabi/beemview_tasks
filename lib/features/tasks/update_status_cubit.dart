import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/task_status.dart';
import '../../data/repositories/task_repository.dart';

part 'update_status_state.dart';

/// Saves a new status, then posts the optional note as a separate comment.
///
/// The two requests are not atomic. If the status is saved but the comment
/// fails, the form keeps the note and only the comment can be retried; the
/// status is never sent twice. Nothing is retried automatically, so an
/// ambiguous failure can't create a duplicate comment.
class UpdateStatusCubit extends Cubit<UpdateStatusState> {
  UpdateStatusCubit(
    this._repository, {
    required this.taskId,
    TaskStatus? current,
  }) : super(UpdateStatusState(current: current, selected: current));

  final TaskRepository _repository;
  final int taskId;

  void select(TaskStatus status) {
    if (state.phase != UpdateStatusPhase.editing) return;
    emit(state.copyWith(selected: status, clearError: true));
  }

  /// Saves the selected status, then posts [note] if it isn't blank.
  /// Ignored while a request is in flight or once the status was saved.
  Future<void> submit(String note) async {
    if (!state.canSave) return;
    final status = state.selected!;
    emit(
      state.copyWith(phase: UpdateStatusPhase.savingStatus, clearError: true),
    );
    try {
      await _repository.updateStatus(taskId, status);
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: UpdateStatusPhase.editing,
          error: _message(e, 'Could not save the status. Please try again.'),
        ),
      );
      return;
    }
    if (isClosed) return;
    emit(state.copyWith(statusSaved: true));
    await _postComment(note);
  }

  /// Posts the note again after a failed comment. The status is not resent.
  Future<void> retryComment(String note) async {
    if (state.phase != UpdateStatusPhase.commentFailed) return;
    await _postComment(note);
  }

  Future<void> _postComment(String note) async {
    final text = note.trim();
    if (text.isEmpty) {
      emit(state.copyWith(phase: UpdateStatusPhase.done, clearError: true));
      return;
    }
    emit(
      state.copyWith(phase: UpdateStatusPhase.postingComment, clearError: true),
    );
    try {
      await _repository.addComment(taskId, text);
      if (isClosed) return;
      emit(state.copyWith(phase: UpdateStatusPhase.done, commentPosted: true));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: UpdateStatusPhase.commentFailed,
          error: _message(e, 'Could not post the note.'),
          commentMayHavePosted: e is ApiException && e.mayHaveReachedServer,
          commentFailedBefore: true,
        ),
      );
    }
  }

  static String _message(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;
}
