import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/project.dart';
import '../../data/models/user.dart';
import '../../data/repositories/project_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/search_field.dart';
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

class _ProjectsView extends StatefulWidget {
  const _ProjectsView({required this.user});

  final User user;

  @override
  State<_ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<_ProjectsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    context.read<ProjectsCubit>().search('');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectsCubit>();
    return Scaffold(
      body: BlocConsumer<ProjectsCubit, ProjectsState>(
        listenWhen: (previous, current) =>
            current.refreshError != null &&
            current.refreshError != previous.refreshError,
        listener: (context, state) =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.refreshError!))),
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(user: widget.user, state: state),
            // The search box overlaps the bottom of the header.
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchField(
                  controller: _search,
                  hint: 'Search loaded projects',
                  onChanged: cubit.search,
                ),
              ),
            ),
            Expanded(
              child: switch (state.status) {
                ProjectsStatus.initial || ProjectsStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
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
                                'Projects shared with your account will '
                                'appear here. Pull down to refresh.',
                          ),
                        )
                      : _ProjectList(state: state, onClearSearch: _clearSearch),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo, account avatar and the "Projects" title on the gradient.
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.state});

  final User user;
  final ProjectsState state;

  @override
  Widget build(BuildContext context) {
    final total = state.total;
    final subtitle = state.status == ProjectsStatus.success
        ? '$total ${total == 1 ? 'project' : 'projects'} available to you'
        : 'Your projects';
    return GradientHeader(
      bottomPadding: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(),
              const Spacer(),
              _AccountMenu(user: user),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'YOUR WORKSPACE',
            style: TextStyle(
              color: AppColors.brandOnDark,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: const Text(
              'Projects',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                letterSpacing: -1,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.state, required this.onClearSearch});

  final ProjectsState state;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final projects = state.visibleProjects;
    final searching = state.query.trim().isNotEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your projects',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                searching
                    ? '${projects.length} of ${state.projects.length} '
                          'loaded projects match'
                    : 'Showing ${state.projects.length} of ${state.total} '
                          'projects',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (projects.isEmpty)
          EmptyView(
            icon: Icons.search_off,
            title: 'No matching projects',
            message: state.hasMore
                ? 'Only loaded projects are searched. Load more to '
                      'search the rest.'
                : 'Try a different name.',
            action: TextButton(
              onPressed: onClearSearch,
              child: const Text('Clear search'),
            ),
          ),
        for (final project in projects) _ProjectCard(project: project),
        _ListFooter(state: state),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  /// Icon tile colours, picked from the project id so they stay stable.
  static const _tints = [
    (AppColors.brandSoft, AppColors.brand),
    (Color(0xFFE0ECFF), Color(0xFF2563EB)),
    (Color(0xFFFFE9D6), Color(0xFFC05621)),
    (Color(0xFFDDF4EC), Color(0xFF2F855A)),
  ];

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _tints[project.id % _tints.length];
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProjectTasksScreen(project: project),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.work_outline, color: foreground, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (project.description != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          project.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.subtle),
              ],
            ),
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
    final cubit = context.read<ProjectsCubit>();
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.brand,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
      ),
    );

    final Widget child;
    if (state.isLoadingMore) {
      child = const CircularProgressIndicator();
    } else if (state.loadMoreError != null) {
      child = Column(
        children: [
          Text(
            state.loadMoreError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: cubit.loadMore,
            style: buttonStyle,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      );
    } else if (state.hasMore) {
      child = OutlinedButton(
        onPressed: cubit.loadMore,
        style: buttonStyle,
        child: const Text('Load more'),
      );
    } else {
      child = const Text(
        'All projects loaded',
        style: TextStyle(color: AppColors.subtle, fontSize: 12),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: child),
    );
  }
}

enum _AccountAction { signOut }

/// The user's initials; opens a menu with their name and "Sign out".
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) => switch (action) {
        _AccountAction.signOut => context.read<AuthCubit>().logout(),
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              user.fullName,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
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
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: InitialsAvatar(name: user.fullName, size: 36),
      ),
    );
  }
}
