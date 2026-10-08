import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task.dart';
import '../../data/models/task_comment.dart';
import '../../data/repositories/task_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/error_view.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/primary_button.dart';
import 'task_badges.dart';
import 'task_details_cubit.dart';
import 'update_status_cubit.dart';
import 'update_status_sheet.dart';

/// Full details of one task. [task] is the list-route version, used as a
/// fallback for the project name until details arrive.
class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({super.key, required this.task, this.onStatusSaved});

  final Task task;

  /// Called after a new status was saved, so the caller can reload its list.
  final VoidCallback? onStatusSaved;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TaskDetailsCubit(context.read<TaskRepository>(), task.id)..load(),
      child: _TaskDetailsView(listTask: task, onStatusSaved: onStatusSaved),
    );
  }
}

class _TaskDetailsView extends StatelessWidget {
  const _TaskDetailsView({required this.listTask, this.onStatusSaved});

  final Task listTask;
  final VoidCallback? onStatusSaved;

  /// Opens the status sheet; afterwards re-fetches details if the status was
  /// saved and tells the user what happened to the note.
  Future<void> _changeStatus(BuildContext context, Task task) async {
    final details = context.read<TaskDetailsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final form = UpdateStatusCubit(
      context.read<TaskRepository>(),
      taskId: task.id,
      current: task.status,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => BlocProvider.value(
        value: form,
        child: UpdateStatusSheet(taskName: task.name),
      ),
    );
    final result = form.state;
    await form.close();
    // Also covers a 401 meanwhile, which pops every route back to login.
    if (!result.statusSaved || !context.mounted) return;

    onStatusSaved?.call();
    unawaited(details.refresh());
    final label = result.selected?.label ?? 'the new status';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.phase == UpdateStatusPhase.done
              ? 'Status changed to $label.'
              : 'Status changed to $label. Your note was not posted.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskDetailsCubit>();
    return Scaffold(
      bottomNavigationBar: BlocBuilder<TaskDetailsCubit, TaskDetailsState>(
        buildWhen: (previous, current) => previous.task != current.task,
        builder: (context, state) {
          final task = state.task;
          if (task == null) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: PrimaryButton(
                label: 'Change status',
                onPressed: () => _changeStatus(context, task),
              ),
            ),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GradientHeader(child: HeaderBar(title: 'Task details')),
          Expanded(
            child: BlocConsumer<TaskDetailsCubit, TaskDetailsState>(
              listenWhen: (previous, current) =>
                  current.refreshError != null &&
                  current.refreshError != previous.refreshError,
              listener: (context, state) => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.refreshError!))),
              builder: (context, state) => switch (state.status) {
                TaskDetailsStatus.initial || TaskDetailsStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                TaskDetailsStatus.failure => ErrorView(
                  message: state.error ?? 'Could not load the task.',
                  onRetry: cubit.load,
                ),
                TaskDetailsStatus.success => RefreshIndicator(
                  onRefresh: cubit.refresh,
                  child: _Details(
                    task: state.task!,
                    fallbackProjectName: listTask.projectName,
                    onChangeStatus: () => _changeStatus(context, state.task!),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.task,
    required this.onChangeStatus,
    this.fallbackProjectName,
  });

  final Task task;
  final VoidCallback onChangeStatus;
  final String? fallbackProjectName;

  @override
  Widget build(BuildContext context) {
    final projectName = task.projectName ?? fallbackProjectName;
    final description = task.description;
    final day = DateFormat.yMMMd();
    final moment = DateFormat.yMMMd().add_jm();
    final today = DateUtils.dateOnly(DateTime.now());
    final due = task.dueDate;
    final overdue = task.isOverdueOn(today);
    final names = [for (final person in task.assignees) person.name];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          projectName ?? 'Unknown project',
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          task.name,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // The status tag is a shortcut to "Change status".
            Semantics(
              button: true,
              hint: 'Change status',
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onChangeStatus,
                child: StatusBadge(
                  status: task.status,
                  label: task.statusLabel,
                  trailing: Icons.chevron_right,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoGrid(
          tiles: [
            _InfoTile(
              label: 'Assignees',
              child: names.isEmpty
                  ? const _Value('Unassigned', muted: true)
                  : Row(
                      children: [
                        AvatarStack(names: names, size: 26, max: 2),
                        const SizedBox(width: 8),
                        Expanded(child: _Value(names.join(', '), maxLines: 2)),
                      ],
                    ),
            ),
            _InfoTile(
              label: 'Due date',
              child: due == null
                  ? const _Value('Not set', muted: true)
                  : Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: overdue ? AppColors.danger : AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Value(
                                day.format(due),
                                color: overdue ? AppColors.danger : null,
                              ),
                              if (overdue)
                                const Text(
                                  'Overdue',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            _InfoTile(
              label: 'Priority',
              child: task.priority == null
                  ? const _Value('Not set', muted: true)
                  : PriorityBadge(priority: task.priority!),
            ),
            _InfoTile(
              label: 'Start date',
              child: task.startDate == null
                  ? const _Value('Not set', muted: true)
                  : _Value(day.format(task.startDate!)),
            ),
            _InfoTile(
              label: 'Created',
              child: task.createdAt == null
                  ? const _Value('Not set', muted: true)
                  : _Value(moment.format(task.createdAt!)),
            ),
            _InfoTile(
              label: 'Updated',
              child: task.updatedAt == null
                  ? const _Value('Not set', muted: true)
                  : _Value(moment.format(task.updatedAt!)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Description'),
        const SizedBox(height: 8),
        Text(
          description ?? 'No description',
          style: TextStyle(
            color: description == null ? AppColors.subtle : AppColors.muted,
            fontSize: 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Latest comment'),
        const SizedBox(height: 10),
        if (task.latestComment == null)
          const Text(
            'No comments yet',
            style: TextStyle(color: AppColors.subtle, fontSize: 14),
          )
        else
          _CommentView(comment: task.latestComment!),
      ],
    );
  }
}

/// Lays tiles out two per row, each row as tall as its taller tile.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[i]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < tiles.length
                        ? tiles[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.muted = false, this.color, this.maxLines});

  final String text;
  final bool muted;
  final Color? color;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: TextStyle(
      color: color ?? (muted ? AppColors.subtle : AppColors.ink),
      fontSize: 13,
      fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Avatar, author and time, then the text in a soft bubble.
class _CommentView extends StatelessWidget {
  const _CommentView({required this.comment});

  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    final author = comment.author?.name ?? 'Unknown user';
    final createdAt = comment.createdAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(name: author, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    author,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      DateFormat.yMMMd().add_jm().format(createdAt),
                      style: const TextStyle(
                        color: AppColors.subtle,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0F5),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    topLeft: Radius.circular(4),
                  ),
                ),
                child: Text(
                  comment.content,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
