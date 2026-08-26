import 'package:flutter/material.dart';

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración pendiente')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.settings_suggest_outlined, size: 64),
            SizedBox(height: 20),
            Text('Supabase todavía no está configurado.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('1. Copia config/local.example.json como config/local.json.'),
            Text('2. Completa SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.'),
            Text('3. Ejecuta con --dart-define-from-file=config/local.json.'),
            SizedBox(height: 18),
            Text('Para levantar la app sin backend usa config/demo.json.'),
          ],
        ),
      ),
    );
  }
}
