import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/models/gestion_models.dart';
import 'package:gestion_hospitalaria/repositories/personal_panel_repository.dart';
import 'package:gestion_hospitalaria/screens/personal_home_screen.dart';

class _Repository extends PersonalPanelRepository {
  _Repository() : super(SupabaseClient('https://example.com', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)));
  bool falla = false;
  Completer<List<AsignacionTurno>>? pendiente;
  List<AsignacionTurno> rows = [AsignacionTurno(turnoId: 'technical-turno', personalId: 'technical-personal', rolTurno: 'enfermero', estadoAsistencia: 'cumplido', observaciones: 'Guardia propia', turno: Turno(fecha: DateTime(2026, 9, 26), tipo: 'noche', horaInicio: '19:00:00', horaFin: '07:00:00', area: 'Medicina', observaciones: 'Turno nocturno'))];
  @override
  Future<Personal> misDatos() async => const Personal(codigo: 'ENF-001', nombre: 'AnaM', apellido: 'Demo', tipoPersonal: 'enfermero');
  @override
  Future<List<AsignacionTurno>> misTurnos() async {
    if (falla) throw StateError('Sensitive internal error');
    if (pendiente != null) return pendiente!.future;
    return rows;
  }
}

void main() {
  Future<void> mount(WidgetTester tester, _Repository repo) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: PersonalHomeScreen(repository: repo)));
    await tester.pump();
  }
  testWidgets('muestra datos, turno y asistencia sin menú ni acciones administrativas', (tester) async {
    await mount(tester, _Repository());
    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Nombre: AnaM'), findsOneWidget);
    expect(find.text('Sin especialidad asignada.'), findsOneWidget);
    expect(find.text('26/09/2026 · Noche'), findsOneWidget);
    expect(find.text('19:00 - 07:00'), findsOneWidget);
    expect(find.text('Asistencia: Cumplido'), findsOneWidget);
    expect(find.text('Observaciones del turno: Turno nocturno'), findsOneWidget);
    expect(find.text('Observaciones de la asignación: Guardia propia'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    for (final text in ['Editar', 'Cumplido', 'Falta', 'Personal', 'Especialidades', 'Asignaciones', 'Asistencia', 'Auditoría', 'Emergencias', 'technical-personal', 'technical-turno']) {
      expect(find.text(text), findsNothing);
    }
  });
  testWidgets('cargando, vacío, error seguro y reintento', (tester) async {
    final repo = _Repository()..pendiente = Completer<List<AsignacionTurno>>();
    await mount(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.pendiente!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No tienes turnos asignados.'), findsOneWidget);
    repo.pendiente = null; repo.falla = true;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar tus turnos.'), findsOneWidget);
    expect(find.textContaining('Sensitive'), findsNothing);
    repo.falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Asistencia: Cumplido'), findsOneWidget);
  });
}
