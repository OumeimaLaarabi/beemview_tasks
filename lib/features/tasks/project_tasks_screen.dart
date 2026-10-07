import 'package:flutter/material.dart';

import '../../data/models/project.dart';

/// Placeholder: the task list is implemented in the next step.
class ProjectTasksScreen extends StatelessWidget {
  const ProjectTasksScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: const Center(child: Text('Tasks')),
    );
  }
}
