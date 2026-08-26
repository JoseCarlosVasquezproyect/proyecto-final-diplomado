import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../controllers/preferences_controller.dart';
import '../widgets/status_banner.dart';
import 'about_adaptation_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();
    final prefs = context.watch<PreferencesController>();
    final name = prefs.studentName.isEmpty ? 'Diplomante' : prefs.studentName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyecto Final 360'),
        actions: [
          if (config.useSupabase)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Column(
        children: [
          StatusBanner(demoMode: !config.useSupabase),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Hola, $name', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Esta app es una base académica. Tu trabajo es convertir RegistroDemo en una entidad real de tu proyecto.'),
                const SizedBox(height: 20),
                _MenuCard(
                  icon: Icons.storage_outlined,
                  title: '1. Mis registros',
                  subtitle: 'CRUD: crear, consultar, editar y eliminar.',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen())),
                ),
                _MenuCard(
                  icon: Icons.tune,
                  title: '2. Preferencias',
                  subtitle: 'Persistencia local: nombre y tema oscuro.',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                _MenuCard(
                  icon: Icons.design_services_outlined,
                  title: '3. Adaptar a mi proyecto',
                  subtitle: 'Qué debes cambiar para que esta base sea TU Trabajo Final.',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAdaptationScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
