import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_lang.dart';
import 'l10n/locale_controller.dart';
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
      child: ListenableBuilder(
        listenable: LocaleController.instance,
        builder: (context, _) {
          final loc = LocaleController.instance;
          return MaterialApp(
            title: 'LGS+積算',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: loc.locale,
            supportedLocales: AppLang.values.map((e) => e.locale).toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => LocaleScope(
              controller: loc,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().checkDeviceSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S.of(context);
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
              Text(
                s.appTagline,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
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
