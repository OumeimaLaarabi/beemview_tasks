import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task_priority.dart';
import '../../data/models/task_status.dart';

/// Tinted pill with the task's status. [status] is null for a status this
/// app doesn't know; [label] then carries the raw API value.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, required this.label});

  final TaskStatus? status;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      child: ExcludeSemantics(
        child: _Pill(label: label, color: statusColor(status)),
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

/// Flag + priority label, coloured by urgency.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Priority: ${priority.label}',
      child: ExcludeSemantics(
        child: _Pill(
          label: priority.label,
          color: priorityColor(priority),
          icon: Icons.flag_outlined,
        ),
      ),
    );
  }

  static Color priorityColor(TaskPriority priority) => switch (priority) {
    TaskPriority.low => AppColors.muted,
    TaskPriority.medium => const Color(0xFFB7791F),
    TaskPriority.high => const Color(0xFFDD6B20),
    TaskPriority.urgent => AppColors.danger,
  };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
