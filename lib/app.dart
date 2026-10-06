import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/auth_cubit.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_error_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/projects/projects_screen.dart';

class BeemviewApp extends StatefulWidget {
  const BeemviewApp({super.key});

  @override
  State<BeemviewApp> createState() => _BeemviewAppState();
}

class _BeemviewAppState extends State<BeemviewApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      // Drop pushed routes when the session changes, so a 401 on a detail
      // screen lands the user on the login screen rather than behind it.
      listenWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      listener: (context, state) =>
          _navigatorKey.currentState?.popUntil((route) => route.isFirst),
      child: MaterialApp(
        title: 'Beemview Tasks',
        navigatorKey: _navigatorKey,
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
        home: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) => switch (state) {
            AuthUnknown() => const SplashScreen(),
            AuthUnauthenticated() => const LoginScreen(),
            AuthAuthenticated(:final user) => ProjectsScreen(user: user),
            AuthRestoreFailed(:final message) => SessionErrorScreen(
              message: message,
            ),
          },
        ),
      ),
    );
  }
}
