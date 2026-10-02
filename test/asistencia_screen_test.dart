import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/controllers/gestion_controller.dart';
import 'package:gestion_hospitalaria/models/gestion_models.dart';
import 'package:gestion_hospitalaria/models/asistencia_errors.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/screens/asistencia_screen.dart';

class _Repository extends GestionRepository {
  _Repository() : super(SupabaseClient('https://example.com', 'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false)));
  List<AsignacionTurno> rows = [AsignacionTurno(id: 'a1', turnoId: 't1', personalId: 'p1', rolTurno: 'enfermero',
    observaciones: 'Guardia', personal: const Personal(id: 'p1', codigo: 'ENF-DEMO-01', nombre: 'AnaM', apellido: 'Demo', tipoPersonal: 'enfermero', especialidadNombre: 'Cardiología'),
    turno: Turno(id: 't1', fecha: DateTime(2026, 9, 26), tipo: 'noche', horaInicio: '19:00:00', horaFin: '07:00:00', area: 'Medicina'))];
  int consultas = 0, marcaciones = 0;
  bool falla = false;
  Object? errorMarcacion;
  Completer<List<AsignacionTurno>>? pendiente;
  Completer<void>? guardadoPendiente;
  @override
  Future<List<AsignacionTurno>> listarAsistencias() async {
    consultas++;
    if (falla) throw Exception('Conexión');
    if (pendiente != null) return pendiente!.future;
    return List.of(rows);
  }
  @override
  Future<void> marcarAsistencia({required String asignacionId, required String estado, required String estadoAnterior}) async {
    marcaciones++;
    if (errorMarcacion != null) throw errorMarcacion!;
    if (guardadoPendiente != null) await guardadoPendiente!.future;
    final a = rows.single;
    expect(a.estadoAsistencia, estadoAnterior);
    rows = [AsignacionTurno(id: a.id, turnoId: a.turnoId, personalId: a.personalId, rolTurno: a.rolTurno,
      observaciones: a.observaciones, estadoAsistencia: estado, turno: a.turno, personal: a.personal)];
  }
}

Future<void> _montar(WidgetTester tester, _Repository repo) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider(create: (_) => GestionController(repo),
    child: const MaterialApp(home: AsistenciaScreen())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('marca cumplido; cancelar corrección no escribe; corrige en ambos sentidos', (tester) async {
    final repo = _Repository();
    await _montar(tester, repo);
    expect(find.text('AnaM Demo'), findsOneWidget);
    expect(find.text('Asistencia: Pendiente'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.textContaining('19:00 - 07:00 (día siguiente)'), findsOneWidget);
    await tester.tap(find.text('Marcar cumplido'));
    await tester.pumpAndSettle();
    expect(find.text('Asistencia: Cumplido'), findsOneWidget);
    expect(find.text('Asistencia registrada como cumplida.'), findsOneWidget);
    expect(repo.consultas, 2);

    await tester.tap(find.text('Cambiar a Falta'));
    await tester.pumpAndSettle();
    expect(find.text('Esta asistencia ya fue marcada como Cumplido.\n¿Deseas cambiarla a Falta?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.marcaciones, 1);
    for (final estado in ['Falta', 'Cumplido']) {
      await tester.tap(find.text('Cambiar a $estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar a $estado'));
      await tester.pumpAndSettle();
      expect(find.text('Asistencia: $estado'), findsOneWidget);
      expect(find.text('Asistencia actualizada correctamente.'), findsWidgets);
    }
    expect(repo.marcaciones, 3);
    expect(repo.consultas, 4);
  });

  testWidgets('marca falta desde pendientes y limpia filtro para mostrar el cambio', (tester) async {
    final repo = _Repository();
    await _montar(tester, repo);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solo pendientes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar falta'));
    await tester.pumpAndSettle();
    expect(find.text('Asistencia: Falta'), findsOneWidget);
    expect(find.text('Asistencia registrada como falta.'), findsOneWidget);
    expect(find.text('Todas las asistencias'), findsOneWidget);
    for (final query in ['AnaM', 'ENF-DEMO-01', 'Enfermero', 'Cardiología', '26/09/2026', 'Medicina', 'Falta']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
      expect(find.text('AnaM Demo'), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), 'Sin coincidencia');
    await tester.pump();
    expect(find.text('No hay asistencias que coincidan con los filtros.'), findsOneWidget);
  });

  testWidgets('conflicto recarga; error no altera estado; evita marcaciones duplicadas', (tester) async {
    final repo = _Repository();
    await _montar(tester, repo);
    repo.errorMarcacion = const AsistenciaException('La asistencia cambió.', recargar: true);
    await tester.tap(find.text('Marcar cumplido'));
    await tester.pumpAndSettle();
    expect(repo.consultas, 2);
    expect(find.text('La asistencia cambió.'), findsOneWidget);
    repo.errorMarcacion = const PostgrestException(code: '42501', message: 'detalle interno');
    await tester.tap(find.text('Marcar falta'));
    await tester.pumpAndSettle();
    expect(find.text('No tienes permisos para controlar asistencia.'), findsOneWidget);
    expect(repo.rows.single.estadoAsistencia, 'pendiente');
    repo.errorMarcacion = null;
    repo.guardadoPendiente = Completer<void>();
    await tester.tap(find.text('Marcar cumplido'));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Marcar falta')).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Marcar cumplido')).onPressed, isNull);
    repo.guardadoPendiente!.complete();
    await tester.pumpAndSettle();
    expect(repo.marcaciones, 3);
    expect(find.text('Asistencia: Cumplido'), findsOneWidget);
  });

  testWidgets('vacío, error, reintento y carga después de cerrar', (tester) async {
    final repo = _Repository()..rows = [];
    await _montar(tester, repo);
    expect(find.text('No existen asignaciones para controlar asistencia.'), findsOneWidget);
    repo.falla = true;
    await tester.pumpWidget(const SizedBox());
    await _montar(tester, repo);
    expect(find.text('Reintentar'), findsOneWidget);
    repo.falla = false;
    repo.pendiente = Completer<List<AsignacionTurno>>();
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.pendiente!.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
