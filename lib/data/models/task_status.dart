/// Task statuses from the API contract. [apiValue] is what gets sent back
/// when saving; never send [label].
enum TaskStatus {
  toDo('to_do', 'To do'),
  inProgress('in_progress', 'In progress'),
  onHold('on_hold', 'On hold'),
  review('review', 'Review'),
  changesRequested('changes_requested', 'Changes requested'),
  blocked('blocked', 'Blocked'),
  done('done', 'Done'),
  canceled('canceled', 'Canceled');

  const TaskStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Returns null for missing or unrecognised values instead of throwing.
  static TaskStatus? fromApi(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in values) {
      if (status.apiValue == normalized) return status;
    }
    return null;
  }
}
