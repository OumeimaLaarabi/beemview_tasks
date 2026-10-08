import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task_priority.dart';
import '../../data/models/task_status.dart';

/// Tinted tag with the task's status. [status] is null for a status this app
/// doesn't know; [label] then carries the raw API value.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.trailing,
  });

  final TaskStatus? status;
  final String label;

  /// Optional icon after the label, e.g. a chevron when the tag is tappable.
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Semantics(
      label: 'Status: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 4, trailing == null ? 8 : 4, 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) Icon(trailing, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  static Color statusColor(TaskStatus? status) => switch (status) {
    TaskStatus.toDo => AppColors.muted,
    TaskStatus.inProgress => AppColors.brand,
    TaskStatus.onHold => const Color(0xFFB7791F),
    TaskStatus.review => const Color(0xFF7C3AED),
    TaskStatus.changesRequested => const Color(0xFFDD6B20),
    TaskStatus.blocked => AppColors.danger,
    TaskStatus.done => const Color(0xFF2F855A),
    TaskStatus.canceled => AppColors.subtle,
    null => AppColors.muted,
  };
}

/// Coloured dot and priority label.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    return Semantics(
      label: 'Priority: ${priority.label}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              priority.label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color priorityColor(TaskPriority priority) => switch (priority) {
    TaskPriority.low => const Color(0xFF3B82F6),
    TaskPriority.medium => const Color(0xFFE6A23C),
    TaskPriority.high => const Color(0xFFE05263),
    TaskPriority.urgent => const Color(0xFFB42335),
  };
}
