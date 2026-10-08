part of 'update_status_cubit.dart';

enum UpdateStatusPhase {
  /// Choosing a status and note; also after a failed status save.
  editing,
  savingStatus,
  postingComment,

  /// The status was saved but the note was not posted.
  commentFailed,

  /// Status saved and the note (if any) posted.
  done,
}

final class UpdateStatusState extends Equatable {
  const UpdateStatusState({
    this.current,
    this.selected,
    this.phase = UpdateStatusPhase.editing,
    this.statusSaved = false,
    this.commentPosted = false,
    this.error,
    this.commentMayHavePosted = false,
    this.commentFailedBefore = false,
  });

  /// The task's status when the form opened; null if unrecognised.
  final TaskStatus? current;
  final TaskStatus? selected;
  final UpdateStatusPhase phase;

  /// True once the server acknowledged the status. From then on the status
  /// is never sent again; only the comment can be retried.
  final bool statusSaved;
  final bool commentPosted;

  /// Why the last step failed.
  final String? error;

  /// The comment request failed without a response (e.g. timeout), so the
  /// server may have stored it anyway.
  final bool commentMayHavePosted;

  /// A comment attempt failed earlier; the form now offers "retry comment"
  /// instead of "save status".
  final bool commentFailedBefore;

  bool get isBusy =>
      phase == UpdateStatusPhase.savingStatus ||
      phase == UpdateStatusPhase.postingComment;

  /// Saving needs a status different from the current one.
  bool get canSave =>
      phase == UpdateStatusPhase.editing &&
      selected != null &&
      selected != current;

  UpdateStatusState copyWith({
    TaskStatus? selected,
    UpdateStatusPhase? phase,
    bool? statusSaved,
    bool? commentPosted,
    String? error,
    bool? commentMayHavePosted,
    bool? commentFailedBefore,
    bool clearError = false,
  }) => UpdateStatusState(
    current: current,
    selected: selected ?? this.selected,
    phase: phase ?? this.phase,
    statusSaved: statusSaved ?? this.statusSaved,
    commentPosted: commentPosted ?? this.commentPosted,
    error: clearError ? null : error ?? this.error,
    commentMayHavePosted: clearError
        ? false
        : commentMayHavePosted ?? this.commentMayHavePosted,
    commentFailedBefore: commentFailedBefore ?? this.commentFailedBefore,
  );

  @override
  List<Object?> get props => [
    current,
    selected,
    phase,
    statusSaved,
    commentPosted,
    error,
    commentMayHavePosted,
    commentFailedBefore,
  ];
}
