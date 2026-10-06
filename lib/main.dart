import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/task_repository.dart';
import 'features/auth/auth_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // API_ORIGIN and TENANT_SUBDOMAIN come from --dart-define(-from-file).
  final config = AppConfig.fromEnvironment();
  final session = SessionStorage();
  final api = ApiClient(config: config, session: session);
  final authRepository = AuthRepository(
    api: api,
    session: session,
    config: config,
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: config),
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider(create: (_) => ProjectRepository(api)),
        RepositoryProvider(create: (_) => TaskRepository(api)),
      ],
      child: BlocProvider(
        create: (_) => AuthCubit(authRepository)..restoreSession(),
        child: const BeemviewApp(),
      ),
    ),
  );
}
