import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'personal_module_screen.dart';
import 'turnos_screen.dart';
import 'especialidades_screen.dart';
import 'asignaciones_screen.dart';
import 'asistencia_screen.dart';


class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int page = 0;
  @override Widget build(BuildContext context) {
    final pages = [Dashboard(onOpen: (p) => setState(() => page = p)), const PersonalModuleScreen(key: ValueKey('personal')), const EspecialidadesScreen(key: ValueKey('especialidades')), const TurnosScreen(key: ValueKey('turnos')), const AsignacionesScreen(key: ValueKey('asignaciones')), const AsistenciaScreen(key: ValueKey('asistencia'))];
    final labels = ['Dashboard', 'Personal', 'Especialidades', 'Turnos', 'Asignaciones', 'Asistencia'];
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
    const modules = [(1, 'Personal', Icons.medical_services_outlined), (2, 'Especialidades', Icons.category_outlined), (3, 'Turnos', Icons.schedule_outlined), (4, 'Asignaciones', Icons.assignment_ind_outlined), (5, 'Asistencia', Icons.fact_check_outlined)];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Dashboard administrativo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Seleccione un módulo para administrar la información.'), const SizedBox(height: 24),
      Wrap(spacing: 16, runSpacing: 16, children: modules.map((m) {
        return SizedBox(width: 220, child: Card(child: InkWell(onTap: () => onOpen(m.$1), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [Icon(m.$3, size: 42), const SizedBox(height: 12), Text(m.$2, style: const TextStyle(fontWeight: FontWeight.bold))])))));
      }).toList()),
    ]);
  }
}
