import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../controllers/preferences_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<PreferencesController>().studentName);
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesController>();
    final config = context.watch<AppConfig>();
    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias locales')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tu nombre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              await prefs.setStudentName(_name.text);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre guardado localmente')));
            },
            icon: const Icon(Icons.save),
            label: const Text('Guardar nombre'),
          ),
          const Divider(height: 32),
          SwitchListTile(
            value: prefs.darkMode,
            title: const Text('Tema oscuro'),
            subtitle: const Text('Cierra la app y vuelve a abrir: la preferencia debe permanecer.'),
            onChanged: prefs.setDarkMode,
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.memory),
            title: Text('Modo actual: ${config.modeLabel}'),
            subtitle: Text(config.useSupabase ? 'Datos remotos con autenticación.' : 'Datos demo en memoria.'),
          ),
        ],
      ),
    );
  }
}
