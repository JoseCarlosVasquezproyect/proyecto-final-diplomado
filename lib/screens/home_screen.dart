import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dashboard.dart';
import 'personal_module_screen.dart';
import 'turnos_screen.dart';
import 'especialidades_screen.dart';
import 'asignaciones_screen.dart';
import 'asistencia_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboard(onOpen: (p) => setState(() => page = p)),
      const PersonalModuleScreen(key: ValueKey('personal')),
      const EspecialidadesScreen(key: ValueKey('especialidades')),
      const TurnosScreen(key: ValueKey('turnos')),
      const AsignacionesScreen(key: ValueKey('asignaciones')),
      const AsistenciaScreen(key: ValueKey('asistencia'))
    ];
    final labels = [
      'Dashboard',
      'Personal',
      'Especialidades',
      'Turnos',
      'Asignaciones',
      'Asistencia'
    ];
    const icons = [
      Icons.dashboard_outlined,
      Icons.people_outline,
      Icons.medical_services_outlined,
      Icons.schedule,
      Icons.assignment_ind_outlined,
      Icons.fact_check_outlined
    ];
    final wide = MediaQuery.sizeOf(context).width >= 850;
    Widget menu() => ListView(padding: const EdgeInsets.all(12), children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_hospital_outlined,
                        size: 36, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Gestión hospitalaria',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Administración',
                        style: Theme.of(context).textTheme.bodySmall)
                  ])),
          ...List.generate(
              labels.length,
              (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                      selected: page == i,
                      leading: Icon(icons[i]),
                      title: Text(labels[i]),
                      onTap: () {
                        setState(() => page = i);
                        Navigator.maybePop(context);
                      })))
        ]);
    return Scaffold(
        appBar: AppBar(title: const Text('Hospital 360'), actions: [
          IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout))
        ]),
        drawer: wide ? null : Drawer(child: menu()),
        body: Row(children: [
          if (wide) SizedBox(width: 250, child: menu()),
          Expanded(child: pages[page])
        ]));
  }
}
