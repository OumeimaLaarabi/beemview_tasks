import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/person.dart';
import '../../data/models/task.dart';
import '../../data/models/task_comment.dart';
import '../../data/repositories/task_repository.dart';
import '../../widgets/error_view.dart';
import '../../widgets/primary_button.dart';
import 'task_badges.dart';
import 'task_details_cubit.dart';
import 'update_status_cubit.dart';
import 'update_status_sheet.dart';

/// Full details of one task. [task] is the list-route version, used for the
/// title and as a fallback for the project name until details arrive.
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
      appBar: AppBar(title: const Text('Task details')),
      bottomNavigationBar: BlocBuilder<TaskDetailsCubit, TaskDetailsState>(
        buildWhen: (previous, current) => previous.task != current.task,
        builder: (context, state) {
          final task = state.task;
          if (task == null) return const SizedBox.shrink();
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: PrimaryButton(
              label: 'Change status',
              onPressed: () => _changeStatus(context, task),
            ),
          );
        },
      ),
      body: BlocConsumer<TaskDetailsCubit, TaskDetailsState>(
        listenWhen: (previous, current) =>
            current.refreshError != null &&
            current.refreshError != previous.refreshError,
        listener: (context, state) =>
            ScaffoldMessenger.of(context)
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
            ),
          ),
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.task, this.fallbackProjectName});

  final Task task;
  final String? fallbackProjectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectName = task.projectName ?? fallbackProjectName;
    final description = task.description;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          task.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusBadge(status: task.status, label: task.statusLabel),
            if (task.priority != null) PriorityBadge(priority: task.priority!),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Project',
          child: _BodyText(projectName ?? 'Unknown project'),
        ),
        _Section(
          title: 'Description',
          child: description == null
              ? const _MutedText('No description')
              : _BodyText(description),
        ),
        _Section(
          title: 'Dates',
          child: _Dates(task: task),
        ),
        _Section(
          title: 'Assignees',
          child: task.assignees.isEmpty
              ? const _MutedText('Unassigned')
              : Column(
                  children: [
                    for (final person in task.assignees)
                      _AssigneeRow(person: person),
                  ],
                ),
        ),
        _Section(
          title: 'Latest comment',
          child: task.latestComment == null
              ? const _MutedText('No comments yet')
              : _CommentView(comment: task.latestComment!),
        ),
      ],
    );
  }
}

/// White card with a small uppercase title.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Start/due dates (calendar days) and created/updated timestamps; rows
/// without a value are left out.
class _Dates extends StatelessWidget {
  const _Dates({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final day = DateFormat.yMMMd();
    final moment = DateFormat.yMMMd().add_jm();
    final overdue = task.isOverdueOn(DateTime.now());
    final rows = [
      if (task.startDate != null) ('Start', day.format(task.startDate!), false),
      if (task.dueDate != null)
        (
          'Due',
          overdue
              ? '${day.format(task.dueDate!)} · Overdue'
              : day.format(task.dueDate!),
          overdue,
        ),
      if (task.createdAt != null)
        ('Created', moment.format(task.createdAt!), false),
      if (task.updatedAt != null)
        ('Updated', moment.format(task.updatedAt!), false),
    ];
    if (rows.isEmpty) return const _MutedText('No dates set');

    return Column(
      children: [
        for (final (label, value, alert) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 72, child: _MutedText(label)),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: alert ? AppColors.danger : AppColors.ink,
                      fontSize: 14,
                      fontWeight: alert ? FontWeight.w700 : FontWeight.w500,
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

class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _Initial(name: person.name),
          const SizedBox(width: 10),
          Expanded(child: _BodyText(person.name)),
        ],
      ),
    );
  }
}

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
        _Initial(name: author),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (createdAt != null)
                _MutedText(DateFormat.yMMMd().add_jm().format(createdAt)),
              const SizedBox(height: 6),
              _BodyText(comment.content),
            ],
          ),
        ),
      ],
    );
  }
}

/// Round avatar with the first letter of [name].
class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.brandSoft,
        foregroundColor: AppColors.brand,
        child: Text(
          trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: AppColors.ink, fontSize: 14, height: 1.45),
  );
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13));
}
