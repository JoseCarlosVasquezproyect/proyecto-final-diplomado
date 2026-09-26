import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'entity_screen.dart';
import 'personal_module_screen.dart';
import 'turnos_screen.dart';

const especialidadesSpec = EntitySpec(title: 'Especialidades', table: 'especialidades', fields: [FieldSpec('nombre', 'Nombre', required: true), FieldSpec('descripcion', 'Descripción'), FieldSpec('estado', 'Estado', required: true, options: ['activo', 'inactivo'])]);
const emergenciasSpec = EntitySpec(title: 'Emergencias', table: 'emergencias', fields: [FieldSpec('codigo', 'Código', required: true), FieldSpec('fecha', 'Fecha AAAA-MM-DD', required: true), FieldSpec('hora', 'Hora', required: true), FieldSpec('area', 'Área', required: true), FieldSpec('tipo', 'Tipo', required: true, options: ['operacion_emergencia', 'atencion_urgente', 'otro']), FieldSpec('prioridad', 'Prioridad', required: true, options: ['alta', 'media', 'baja']), FieldSpec('descripcion', 'Descripción', required: true), FieldSpec('estado', 'Estado', required: true, options: ['pendiente', 'en_atencion', 'finalizada', 'cancelada'])]);

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int page = 0;
  @override Widget build(BuildContext context) {
    final pages = [Dashboard(onOpen: (p) => setState(() => page = p)), const PersonalModuleScreen(key: ValueKey('medicos'), tipo: 'medico', titulo: 'Médicos'), const PersonalModuleScreen(key: ValueKey('enfermeros'), tipo: 'enfermero', titulo: 'Enfermeros'), const PersonalModuleScreen(key: ValueKey('pasantes'), tipo: 'pasante', titulo: 'Pasantes'), const EntityScreen(key: ValueKey('especialidades'), spec: especialidadesSpec), const TurnosScreen(key: ValueKey('turnos')), const EntityScreen(key: ValueKey('emergencias'), spec: emergenciasSpec)];
    final labels = ['Dashboard', 'Médicos', 'Enfermeros', 'Pasantes', 'Especialidades', 'Turnos', 'Emergencias'];
    final wide = MediaQuery.sizeOf(context).width >= 850;
    Widget menu() => ListView(children: [const DrawerHeader(child: Text('Gestión hospitalaria', style: TextStyle(fontSize: 21))), ...List.generate(labels.length, (i) => ListTile(selected: page == i, title: Text(labels[i]), onTap: () { setState(() => page = i); Navigator.maybePop(context); }))]);
    return Scaffold(appBar: AppBar(title: const Text('Hospital 360'), actions: [IconButton(tooltip: 'Cerrar sesión', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))]), drawer: wide ? null : Drawer(child: menu()), body: Row(children: [if (wide) SizedBox(width: 250, child: menu()), Expanded(child: pages[page]) ]));
  }
}
class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.onOpen});
  final ValueChanged<int> onOpen;
  @override
  Widget build(BuildContext context) {
    const modules = [(1, 'Médicos', Icons.medical_services_outlined), (2, 'Enfermeros', Icons.health_and_safety_outlined), (3, 'Pasantes', Icons.school_outlined), (4, 'Especialidades', Icons.category_outlined), (5, 'Turnos', Icons.schedule_outlined), (6, 'Emergencias', Icons.emergency_outlined)];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Dashboard administrativo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Seleccione un módulo para administrar la información.'), const SizedBox(height: 24),
      Wrap(spacing: 16, runSpacing: 16, children: modules.map((m) {
        return SizedBox(width: 220, child: Card(child: InkWell(onTap: () => onOpen(m.$1), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [Icon(m.$3, size: 42), const SizedBox(height: 12), Text(m.$2, style: const TextStyle(fontWeight: FontWeight.bold))])))));
      }).toList()),
    ]);
  }
}
