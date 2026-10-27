import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gestion_hospitalaria/models/gestion_models.dart';
import 'package:gestion_hospitalaria/repositories/personal_panel_repository.dart';
import 'package:gestion_hospitalaria/screens/personal_home_screen.dart';

class _Repository extends PersonalPanelRepository {
  _Repository()
      : super(SupabaseClient('https://example.com', 'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));

  bool falla = false;
  Completer<PersonalDashboardData>? pendiente;
  PersonalDashboardData data = _sampleData();

  @override
  Future<PersonalDashboardData> miDashboard() async {
    if (falla) throw StateError('Sensitive internal error');
    if (pendiente != null) return pendiente!.future;
    return data;
  }
}

PersonalDashboardData _sampleData({List<AsignacionTurno>? assignments}) {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final later = DateTime(now.year, now.month, now.day + 3);
  final history = now.subtract(const Duration(days: 2));
  return PersonalDashboardData(
    personal: const Personal(
      codigo: 'ENF-001',
      nombre: 'Ana',
      apellido: 'Demo',
      tipoPersonal: 'enfermero',
      especialidadNombre: 'Cardiología',
    ),
    assignments: assignments ??
        [
          AsignacionTurno(
            turnoId: 'turno-1',
            personalId: 'personal-1',
            rolTurno: 'enfermero',
            estadoAsistencia: 'pendiente',
            turno: Turno(
              fecha: tomorrow,
              tipo: 'noche',
              horaInicio: '19:00:00',
              horaFin: '07:00:00',
              area: 'Medicina',
              estado: 'programado',
            ),
          ),
          AsignacionTurno(
            turnoId: 'turno-2',
            personalId: 'personal-1',
            rolTurno: 'enfermero',
            estadoAsistencia: 'pendiente',
            turno: Turno(
              fecha: later,
              tipo: 'manana',
              horaInicio: '08:00:00',
              horaFin: '16:00:00',
              area: 'Consulta externa',
              estado: 'programado',
            ),
          ),
          AsignacionTurno(
            turnoId: 'turno-history',
            personalId: 'personal-1',
            rolTurno: 'enfermero',
            estadoAsistencia: 'cumplido',
            turno: Turno(
              fecha: history,
              tipo: 'tarde',
              horaInicio: '12:00:00',
              horaFin: '18:00:00',
              area: 'Medicina',
              estado: 'finalizado',
            ),
          ),
        ],
  );
}

void main() {
  Future<void> mount(WidgetTester tester, _Repository repository) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: PersonalHomeScreen(repository: repository),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('muestra el resumen personal, agenda e historial propios',
      (tester) async {
    await mount(tester, _Repository());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('¡Hola, Ana!'), findsOneWidget);
    expect(find.text('Enfermero'), findsWidgets);
    expect(find.text('Cardiología'), findsWidgets);
    expect(find.text('Mi próximo turno'), findsOneWidget);
    expect(find.text('Mi semana'), findsOneWidget);
    expect(find.text('Próximos turnos'), findsWidgets);
    await tester.tap(find.text('Ver todos mis turnos'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Todos tus turnos'), findsOneWidget);
    expect(find.text('Ocultar todos'), findsOneWidget);
    expect(find.text('Mi actividad'), findsOneWidget);
    expect(find.textContaining('Asistencia: Cumplido'), findsWidgets);
    expect(find.text('Accesos rápidos'), findsOneWidget);
    for (final forbidden in [
      'Especialidades',
      'Asignaciones',
      'Control de asistencia',
      'Auditoría',
      'technical-personal',
    ]) {
      expect(find.text(forbidden), findsNothing);
    }
  });

  testWidgets('muestra estado vacío cuando no hay turnos próximos',
      (tester) async {
    final repository = _Repository()..data = _sampleData(assignments: []);
    await mount(tester, repository);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No tienes turnos próximos asignados.'), findsOneWidget);
    expect(find.text('Aún no hay turnos finalizados en tu historial.'),
        findsOneWidget);
  });

  testWidgets('muestra carga, error seguro y permite reintentar',
      (tester) async {
    final repository = _Repository()
      ..pendiente = Completer<PersonalDashboardData>();
    await mount(tester, repository);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.pendiente!.complete(_sampleData(assignments: []));
    await tester.pump(const Duration(milliseconds: 100));
    repository.pendiente = null;
    repository.falla = true;
    await tester.tap(find.byTooltip('Actualizar resumen'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('No se pudo cargar tu espacio personal'),
        findsOneWidget);
    expect(find.textContaining('Sensitive'), findsNothing);

    repository.falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Mi semana'), findsOneWidget);
  });
}
