import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/project.dart';
import '../../data/models/user.dart';
import '../../data/repositories/project_repository.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../auth/auth_cubit.dart';
import '../tasks/project_tasks_screen.dart';
import 'projects_cubit.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProjectsCubit(context.read<ProjectRepository>())..load(),
      child: _ProjectsView(user: user),
    );
  }
}

class _ProjectsView extends StatelessWidget {
  const _ProjectsView({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectsCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [_AccountMenu(user: user)],
      ),
      body: BlocConsumer<ProjectsCubit, ProjectsState>(
        listenWhen: (previous, current) =>
            current.refreshError != null &&
            current.refreshError != previous.refreshError,
        listener: (context, state) =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.refreshError!))),
        builder: (context, state) => switch (state.status) {
          ProjectsStatus.initial || ProjectsStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          ProjectsStatus.failure => ErrorView(
            message: state.error ?? 'Could not load projects.',
            onRetry: cubit.load,
          ),
          ProjectsStatus.success => RefreshIndicator(
            onRefresh: cubit.refresh,
            child: state.projects.isEmpty
                ? const ScrollableFill(
                    child: EmptyView(
                      icon: Icons.folder_off_outlined,
                      title: 'No projects available',
                      message:
                          'Projects shared with your account will appear '
                          'here. Pull down to refresh.',
                    ),
                  )
                : _ProjectList(state: state),
          ),
        },
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.state});

  final ProjectsState state;

  @override
  Widget build(BuildContext context) {
    final projects = state.projects;
    final theme = Theme.of(context);
    // Header + projects + footer.
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: projects.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Showing ${projects.length} of ${state.total} projects',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        if (index == projects.length + 1) {
          return _ListFooter(state: state);
        }
        return _ProjectCard(project: projects[index - 1]);
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final name = project.name.trim();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
        ),
        title: Text(project.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: project.description == null
            ? null
            : Text(
                project.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectTasksScreen(project: project),
          ),
        ),
      ),
    );
  }
}

/// Load-more button, its loading/error states, or the end-of-list note.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});

  final ProjectsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ProjectsCubit>();

    final Widget child;
    if (state.isLoadingMore) {
      child = const CircularProgressIndicator();
    } else if (state.loadMoreError != null) {
      child = Column(
        children: [
          Text(
            state.loadMoreError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: cubit.loadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    } else if (state.hasMore) {
      child = OutlinedButton(
        onPressed: cubit.loadMore,
        child: const Text('Load more'),
      );
    } else {
      child = Text(
        'All projects loaded',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: child),
    );
  }
}

enum _AccountAction { signOut }

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) => switch (action) {
        _AccountAction.signOut => context.read<AuthCubit>().logout(),
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.fullName),
            subtitle: user.email == null ? null : Text(user.email!),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
