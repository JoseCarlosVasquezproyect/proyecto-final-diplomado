import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/controllers/gestion_controller.dart';
import 'package:gestion_hospitalaria/models/gestion_models.dart';
import 'package:gestion_hospitalaria/models/asignacion_errors.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/screens/asignaciones_screen.dart';

class _Repository extends GestionRepository {
  _Repository() : super(SupabaseClient('https://example.com', 'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final turnos = [
    Turno(id: 'turno-1', fecha: DateTime(2026, 10, 3), tipo: 'noche', horaInicio: '19:00:00', horaFin: '07:00:00', area: 'Emergencias'),
    Turno(id: 'turno-2', fecha: DateTime(2026, 10, 4), tipo: 'tarde', horaInicio: '14:00:00', horaFin: '18:00:00', area: 'Consultas'),
  ];
  final personal = [const Personal(id: 'personal-1', codigo: 'ENF-DEMO-01', nombre: 'Ana', apellido: 'Demo', tipoPersonal: 'enfermero', especialidadNombre: 'Cardiología')];
  List<AsignacionTurno> rows = [];
  int consultas = 0;
  Object? errorGuardar;
  bool falla = false;
  Completer<List<AsignacionTurno>>? pendiente;

  @override
  Future<List<AsignacionTurno>> listarAsignaciones() async {
    consultas++;
    if (falla) throw Exception('Sin conexión');
    if (pendiente != null) return pendiente!.future;
    return List.of(rows);
  }
  @override
  Future<List<Turno>> turnosParaAsignacion() async => List.of(turnos);
  @override
  Future<List<Personal>> personalParaAsignacion() async => List.of(personal);
  @override
  Future<void> guardarAsignacion({String? id, required String turnoId, required String personalId, required String observaciones}) async {
    if (errorGuardar != null) throw errorGuardar!;
    final persona = personal.singleWhere((p) => p.id == personalId);
    final anterior = rows.where((a) => a.id == id).firstOrNull;
    final asignacion = AsignacionTurno(id: id ?? 'asignacion-${rows.length}', turnoId: turnoId, personalId: personalId,
      rolTurno: persona.tipoPersonal, observaciones: observaciones,
      turno: turnos.singleWhere((t) => t.id == turnoId), personal: persona,
      estadoAsistencia: anterior?.estadoAsistencia ?? 'pendiente');
    rows = [...rows.where((a) => a.id != asignacion.id), asignacion];
  }
}

Future<void> _montar(WidgetTester tester, _Repository repo) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider(create: (_) => GestionController(repo),
    child: const MaterialApp(home: AsignacionesScreen())));
  await tester.pumpAndSettle();
}

Finder _selector(String label) => find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> && w.decoration.labelText == label);
Future<void> _seleccionar(WidgetTester tester, String label, String texto) async {
  await tester.tap(_selector(label));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(texto).last);
  await tester.pumpAndSettle();
}
Future<void> _nuevo(WidgetTester tester) async {
  await tester.tap(find.text('Nueva asignación'));
  await tester.pumpAndSettle();
  await _seleccionar(tester, 'Turno', '03/10/2026');
  await _seleccionar(tester, 'Personal', 'Ana Demo');
}

void main() {
  testWidgets('crear y editar refrescan; nocturno y rol visibles sin UUID', (tester) async {
    final repo = _Repository();
    await _montar(tester, repo);
    expect(find.text('No existen asignaciones registradas.'), findsOneWidget);
    await _nuevo(tester);
    expect(find.text('Rol en turno: Enfermero').last, findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Guardia inicial');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Personal asignado al turno correctamente.'), findsOneWidget);
    expect(find.text('Personal: Ana Demo'), findsOneWidget);
    expect(find.text('Especialidad: Cardiología'), findsOneWidget);
    expect(find.text('Asistencia: Pendiente'), findsOneWidget);
    expect(find.textContaining('19:00 - 07:00 (día siguiente)'), findsOneWidget);
    expect(find.text('personal-1'), findsNothing);
    expect(repo.consultas, 2);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await _seleccionar(tester, 'Turno', '04/10/2026');
    await tester.enterText(find.byType(TextFormField), 'Guardia corregida');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Área: Consultas'), findsOneWidget);
    expect(find.text('Observaciones: Guardia corregida'), findsOneWidget);
    expect(repo.consultas, 3);
    expect(repo.rows.single.estadoAsistencia, 'pendiente');

    await tester.enterText(find.byType(TextField).first, 'ENF-DEMO-01');
    await tester.pump();
    expect(find.text('Personal: Ana Demo'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'sin coincidencia');
    await tester.pump();
    expect(find.text('No hay asignaciones que coincidan con la búsqueda.'), findsOneWidget);
  });

  testWidgets('duplicidad y solapamiento no cierran formulario ni recargan', (tester) async {
    final repo = _Repository();
    await _montar(tester, repo);
    await _nuevo(tester);
    repo.errorGuardar = const PostgrestException(message: 'duplicate key', code: '23505');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Este personal ya está asignado al turno seleccionado.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    repo.errorGuardar = const PostgrestException(message: 'El personal ya posee otro turno que se solapa con el horario seleccionado.', code: 'P0001');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El personal ya tiene otro turno que se solapa con el horario seleccionado.'), findsOneWidget);
    expect(repo.rows, isEmpty);
    expect(repo.consultas, 1);
    repo.errorGuardar = null;
    await _seleccionar(tester, 'Turno', '04/10/2026');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.rows.single.turnoId, 'turno-2');
    expect(repo.consultas, 2);
  });

  testWidgets('validación de selectores y estados carga, error, reintento', (tester) async {
    final repo = _Repository()..falla = true;
    await _montar(tester, repo);
    expect(find.text('Reintentar'), findsOneWidget);
    repo.falla = false;
    repo.pendiente = Completer<List<AsignacionTurno>>();
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.pendiente!.complete([]);
    repo.pendiente = null;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva asignación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona un turno.'), findsOneWidget);
    expect(find.text('Selecciona un personal.'), findsOneWidget);
    expect(repo.rows, isEmpty);
  });

  test('payload no incluye asistencia ni trazabilidad; errores internos se ocultan', () {
    final a = AsignacionTurno.fromMap({'id': 'a', 'turno_id': 't', 'personal_id': 'p', 'rol_en_turno': 'enfermero', 'estado_asistencia': 'cumplido'});
    expect(a.rolTurno, 'enfermero');
    expect(a.estadoAsistencia, 'cumplido');
    expect(a.toMap().keys, unorderedEquals(['turno_id', 'personal_id', 'rol_en_turno', 'observaciones']));
    expect(mensajeErrorAsignacion(const PostgrestException(message: 'token interno', code: '500')), isNot(contains('token interno')));
  });
}
