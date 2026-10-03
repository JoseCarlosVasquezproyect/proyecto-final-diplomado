import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'controllers/preferences_controller.dart';
import 'screens/auth_gate.dart';
import 'screens/home_screen.dart';
import 'screens/setup_required_screen.dart';
import 'theme/app_theme.dart';

class ProyectoFinalApp extends StatelessWidget {
  const ProyectoFinalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesController>();
    final config = context.watch<AppConfig>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestion Hospitalaria',
      themeMode: prefs.themeMode,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: config.demoMode
          ? const HomeScreen()
          : config.hasSupabaseConfig
              ? const AuthGate()
              : const SetupRequiredScreen(),
    );
  }
}
