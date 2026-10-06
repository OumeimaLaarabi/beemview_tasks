/// Task priority. The project-tasks route returns it capitalised ("High"),
/// the task-details route lowercase ("high"); [fromApi] accepts both.
enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent');

  const TaskPriority(this.label);

  final String label;

  static TaskPriority? fromApi(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final priority in values) {
      if (priority.name == normalized) return priority;
    }
    return null;
  }
}
