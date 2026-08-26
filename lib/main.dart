import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'controllers/preferences_controller.dart';
import 'repositories/demo_registro_repository.dart';
import 'repositories/registro_repository.dart';
import 'repositories/supabase_registro_repository.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final sharedPreferences = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(sharedPreferences);
  final preferencesController = PreferencesController(preferencesService);

  RegistroRepository repository = DemoRegistroRepository();

  if (config.useSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseKey,
    );
    repository = SupabaseRegistroRepository(Supabase.instance.client);
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),
        ChangeNotifierProvider<PreferencesController>.value(value: preferencesController),
        Provider<RegistroRepository>.value(value: repository),
      ],
      child: const ProyectoFinalApp(),
    ),
  );
}
