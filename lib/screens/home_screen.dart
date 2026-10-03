import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      Dashboard(onOpen: (p) => setState(() => page = p)),
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

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.onOpen});
  final ValueChanged<int> onOpen;
  @override
  Widget build(BuildContext context) {
    const modules = [
      (1, 'Personal', Icons.people_outline),
      (2, 'Especialidades', Icons.medical_services_outlined),
      (3, 'Turnos', Icons.schedule_outlined),
      (4, 'Asignaciones', Icons.assignment_ind_outlined),
      (5, 'Asistencia', Icons.fact_check_outlined)
    ];
    const descriptions = [
      'Equipo y especialidades asignadas',
      'Especialidades del hospital',
      'Fechas, horarios y áreas',
      'Personal asignado a cada turno',
      'Registro y control de asistencia'
    ];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Dashboard administrativo',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Seleccione un módulo para administrar la información.'),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: modules.map((m) {
              final scheme = Theme.of(context).colorScheme;
              return SizedBox(
                  width: width,
                  child: Card(
                      child: InkWell(
                          onTap: () => onOpen(m.$1),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: scheme.primaryContainer
                                                .withValues(alpha: 0.5),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Icon(m.$3,
                                            size: 28, color: scheme.primary)),
                                    const SizedBox(height: 16),
                                    Text(m.$2,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    Text(descriptions[m.$1 - 1],
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: scheme.onSurfaceVariant))
                                  ])))));
            }).toList());
      }),
    ]);
  }
}
