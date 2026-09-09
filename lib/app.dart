import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/project_list_screen.dart';
import 'theme/app_theme.dart';

class LgsPlusApp extends StatelessWidget {
  const LgsPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: MaterialApp(
        title: 'LGS+積算',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.booting) {
      return Scaffold(
        backgroundColor: AppTheme.navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.safetyYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LGS+積算',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '現場積算・注文をオフラインで',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),
              const CircularProgressIndicator(color: AppTheme.safetyYellow),
            ],
          ),
        ),
      );
    }
    if (state.user == null) return const LoginScreen();
    return const ProjectListScreen();
  }
}
