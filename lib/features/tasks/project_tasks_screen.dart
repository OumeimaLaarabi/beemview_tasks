import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/project.dart';
import '../../data/models/task.dart';
import '../../data/models/task_status.dart';
import '../../data/repositories/task_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/search_field.dart';
import 'project_tasks_cubit.dart';
import 'task_badges.dart';
import 'task_details_screen.dart';

/// Every task of one project, with search and a status filter.
class ProjectTasksScreen extends StatelessWidget {
  const ProjectTasksScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProjectTasksCubit(context.read<TaskRepository>(), project.id)..load(),
      child: _ProjectTasksView(project: project),
    );
  }
}

class _ProjectTasksView extends StatefulWidget {
  const _ProjectTasksView({required this.project});

  final Project project;

  @override
  State<_ProjectTasksView> createState() => _ProjectTasksViewState();
}

class _ProjectTasksViewState extends State<_ProjectTasksView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    context.read<ProjectTasksCubit>().clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectTasksCubit>();
    return Scaffold(
      body: BlocConsumer<ProjectTasksCubit, ProjectTasksState>(
        listenWhen: (previous, current) =>
            current.refreshError != null &&
            current.refreshError != previous.refreshError,
        listener: (context, state) =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.refreshError!))),
        builder: (context, state) {
          final total = state.tasks.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientHeader(
                child: HeaderBar(
                  title: state.project?.name ?? widget.project.name,
                  subtitle: state.status == ProjectTasksStatus.success
                      ? '$total ${total == 1 ? 'task' : 'tasks'} loaded'
                      : 'Project tasks',
                ),
              ),
              Expanded(
                child: switch (state.status) {
                  ProjectTasksStatus.initial || ProjectTasksStatus.loading =>
                    const Center(child: CircularProgressIndicator()),
                  ProjectTasksStatus.failure => ErrorView(
                    message: state.error ?? 'Could not load tasks.',
                    onRetry: cubit.load,
                  ),
                  ProjectTasksStatus.success when state.tasks.isEmpty =>
                    RefreshIndicator(
                      onRefresh: cubit.refresh,
                      child: const ScrollableFill(
                        child: EmptyView(
                          icon: Icons.task_alt,
                          title: 'No tasks yet',
                          message:
                              'Tasks added to this project will appear '
                              'here. Pull down to refresh.',
                        ),
                      ),
                    ),
                  ProjectTasksStatus.success => RefreshIndicator(
                    onRefresh: cubit.refresh,
                    child: _TaskList(
                      state: state,
                      search: _search,
                      onClearFilters: _clearFilters,
                    ),
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Overview, filters and task cards in one scrolling list.
class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.state,
    required this.search,
    required this.onClearFilters,
  });

  final ProjectTasksState state;
  final TextEditingController search;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectTasksCubit>();
    final tasks = state.visibleTasks;
    final total = state.tasks.length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Overview(tasks: state.tasks),
        const SizedBox(height: 14),
        // Search and chips only narrow the tasks already loaded for this
        // project; they never query the server.
        SearchField(
          controller: search,
          hint: 'Filter loaded tasks by name',
          onChanged: cubit.search,
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            'Filter loaded tasks by status',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _StatusFilters(state: state),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            state.isFiltered
                ? 'Showing ${tasks.length} of $total tasks'
                : '$total ${total == 1 ? 'task' : 'tasks'}',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (tasks.isEmpty)
          EmptyView(
            icon: Icons.search_off,
            title: 'No matching tasks',
            message: 'Try a different search or status.',
            action: TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear filters'),
            ),
          ),
        for (final task in tasks) _TaskCard(task: task),
      ],
    );
  }
}

/// Counts worked out from the loaded statuses. No percentage is shown:
/// progress is tracked through status only.
class _Overview extends StatelessWidget {
  const _Overview({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final open = tasks
        .where(
          (t) => t.status != TaskStatus.done && t.status != TaskStatus.canceled,
        )
        .length;
    final overdue = tasks.where((t) => t.isOverdueOn(today)).length;
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(value: open, label: 'Open'),
              _Stat(value: done, label: 'Done'),
              _Stat(
                value: overdue,
                label: 'Overdue',
                color: overdue > 0 ? AppColors.danger : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: color ?? AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "All" plus one pill per status present in the project.
class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.state});

  final ProjectTasksState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectTasksCubit>();
    final counts = state.statusCounts;
    final statuses = [
      for (final status in TaskStatus.values)
        if ((counts[status] ?? 0) > 0 || status == state.statusFilter) status,
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterPill(
            label: 'All',
            count: state.tasks.length,
            selected: state.statusFilter == null,
            onTap: () => cubit.filterByStatus(null),
          ),
          for (final status in statuses)
            _FilterPill(
              label: status.label,
              count: counts[status] ?? 0,
              selected: state.statusFilter == status,
              // Tapping the selected pill again goes back to "All".
              onTap: () => cubit.filterByStatus(
                state.statusFilter == status ? null : status,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.brand : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? AppColors.brand : AppColors.line,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Text(
                  '$label · $count',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  /// Opens the details; if a status was saved there, reloads the list once
  /// the user comes back so the card shows the new status.
  Future<void> _openDetails(BuildContext context) async {
    final tasks = context.read<ProjectTasksCubit>();
    var statusSaved = false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailsScreen(
          task: task,
          onStatusSaved: () => statusSaved = true,
        ),
      ),
    );
    if (statusSaved && !tasks.isClosed) await tasks.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        onTap: () => _openDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wraps to two lines on narrow screens or with large text.
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(status: task.status, label: task.statusLabel),
                if (task.priority != null)
                  PriorityBadge(priority: task.priority!),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _DueDate(task: task)),
                AvatarStack(
                  names: [for (final person in task.assignees) person.name],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Nov 16, 2026", "Today", a red "Overdue · Sep 30, 2026", or
/// "No due date".
class _DueDate extends StatelessWidget {
  const _DueDate({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate;
    final today = DateUtils.dateOnly(DateTime.now());
    final String text;
    var color = AppColors.muted;
    if (due == null) {
      text = 'No due date';
      color = AppColors.subtle;
    } else if (task.isOverdueOn(today)) {
      text = 'Overdue · ${DateFormat.yMMMd().format(due)}';
      color = AppColors.danger;
    } else if (DateUtils.isSameDay(due, today)) {
      text = 'Due today';
      color = AppColors.danger;
    } else {
      text = 'Due ${DateFormat.yMMMd().format(due)}';
    }
    return Row(
      children: [
        Icon(Icons.event_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// White rounded card with a hairline border; tappable when [onTap] is set.
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
