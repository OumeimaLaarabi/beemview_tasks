import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/user.dart';
import '../auth/auth_cubit.dart';

/// Placeholder: the project list is implemented in a later step.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: context.read<AuthCubit>().logout,
          ),
        ],
      ),
      body: Center(child: Text('Signed in as ${user.fullName}')),
    );
  }
}
