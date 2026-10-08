import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/project.dart';
import '../../data/models/task.dart';
import '../../data/models/task_status.dart';
import '../../data/repositories/task_repository.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
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
      appBar: AppBar(
        title: BlocSelector<ProjectTasksCubit, ProjectTasksState, String>(
          selector: (state) => state.project?.name ?? widget.project.name,
          builder: (context, name) =>
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
      body: BlocConsumer<ProjectTasksCubit, ProjectTasksState>(
        listenWhen: (previous, current) =>
            current.refreshError != null &&
            current.refreshError != previous.refreshError,
        listener: (context, state) =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.refreshError!))),
        builder: (context, state) => switch (state.status) {
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
                      'Tasks added to this project will appear here. '
                      'Pull down to refresh.',
                ),
              ),
            ),
          ProjectTasksStatus.success => Column(
            children: [
              _Filters(state: state, controller: _search),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.refresh,
                  child: _TaskList(state: state, onClearFilters: _clearFilters),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// Search box and one chip per status present in the project.
class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.controller});

  final ProjectTasksState state;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectTasksCubit>();
    final counts = state.statusCounts;
    final statuses = [
      for (final status in TaskStatus.values)
        if ((counts[status] ?? 0) > 0 || status == state.statusFilter) status,
    ];

    // Search and chips only narrow the tasks already loaded for this
    // project; they never query the server.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: controller,
            onChanged: cubit.search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Filter loaded tasks by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        cubit.search('');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 16, 0),
          child: Text(
            'Filter loaded tasks by status',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _StatusChip(
                label: 'All',
                count: state.tasks.length,
                selected: state.statusFilter == null,
                onSelected: (_) => cubit.filterByStatus(null),
              ),
              for (final status in statuses)
                _StatusChip(
                  label: status.label,
                  count: counts[status] ?? 0,
                  selected: state.statusFilter == status,
                  // Tapping the selected chip again goes back to "All".
                  onSelected: (selected) =>
                      cubit.filterByStatus(selected ? status : null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.state, required this.onClearFilters});

  final ProjectTasksState state;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final tasks = state.visibleTasks;
    if (tasks.isEmpty) {
      return ScrollableFill(
        child: EmptyView(
          icon: Icons.search_off,
          title: 'No matching tasks',
          message: 'Try a different search or status.',
          action: TextButton(
            onPressed: onClearFilters,
            child: const Text('Clear filters'),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final total = state.tasks.length;
    // Header + tasks.
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: tasks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              state.isFiltered
                  ? 'Showing ${tasks.length} of $total tasks'
                  : '$total ${total == 1 ? 'task' : 'tasks'}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return _TaskCard(task: tasks[index - 1]);
      },
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
    final theme = Theme.of(context);
    final assignees = task.assignees.map((p) => p.name).join(', ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (task.priority != null) ...[
                    const SizedBox(width: 8),
                    PriorityBadge(priority: task.priority!),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(status: task.status, label: task.statusLabel),
                  if (task.dueDate != null) _DueDate(task: task),
                  if (assignees.isNotEmpty)
                    _Meta(icon: Icons.person_outline, text: assignees),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Due Oct 10, 2026", "Due today", or a red "Overdue · Oct 10, 2026".
class _DueDate extends StatelessWidget {
  const _DueDate({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate!;
    final today = DateUtils.dateOnly(DateTime.now());
    final formatted = DateFormat.yMMMd().format(due);
    final overdue = task.isOverdueOn(today);
    final String text;
    if (overdue) {
      text = 'Overdue · $formatted';
    } else if (DateUtils.isSameDay(due, today)) {
      text = 'Due today';
    } else {
      text = 'Due $formatted';
    }
    return _Meta(
      icon: Icons.event_outlined,
      text: text,
      color: overdue ? AppColors.danger : null,
    );
  }
}

/// Small icon + text line used for due date and assignees.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
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
