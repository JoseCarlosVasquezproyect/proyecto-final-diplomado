import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/controllers/gestion_controller.dart';
import 'package:gestion_hospitalaria/models/gestion_models.dart';
import 'package:gestion_hospitalaria/models/personal_errors.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/screens/personal_module_screen.dart';

class _Repository extends GestionRepository {
  _Repository()
      : super(SupabaseClient('https://example.com', 'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  List<Personal> rows = [];
  int consultas = 0, altas = 0, ediciones = 0;
  String? correoRecibido, especialidadActual;
  bool falla = false;
  Object? errorAlta;
  Completer<List<Personal>>? pendiente;

  @override
  Future<List<Personal>> listarPersonal() async {
    consultas++;
    if (falla) throw Exception('Conexión');
    if (pendiente != null) return pendiente!.future;
    return List.of(rows);
  }

  @override
  Future<List<Especialidad>> especialidadesParaPersonal(
      {String? actualId}) async {
    especialidadActual = actualId;
    return [
      const Especialidad(id: 'activa', nombre: 'Cardiología'),
      if (actualId == 'inactiva')
        const Especialidad(
            id: 'inactiva',
            nombre: 'Especialidad anterior',
            estado: 'inactivo'),
    ];
  }

  @override
  Future<void> crearPersonal(Personal personal,
      {required String email, required String password}) async {
    altas++;
    correoRecibido = email;
    expect(password.length, greaterThanOrEqualTo(10));
    if (errorAlta != null) throw errorAlta!;
    rows.add(Personal.fromMap({...personal.toMap(), 'id': 'nuevo'}));
  }

  @override
  Future<void> actualizarPersonal(Personal personal) async {
    ediciones++;
    rows = rows
        .map((p) => p.id == personal.id
            ? Personal.fromMap({...personal.toMap(), 'id': p.id})
            : p)
        .toList();
  }

  @override
  Future<void> darDeBajaPersonal(String id) async {
    rows = rows
        .map((p) => p.id == id
            ? Personal.fromMap({...p.toMap(), 'id': id, 'estado': 'inactivo'})
            : p)
        .toList();
  }
}

Finder _campo(String label) => find.widgetWithText(TextFormField, label);
Finder _selector(String label) => find.byWidgetPredicate((w) =>
    w is DropdownButtonFormField<String> && w.decoration.labelText == label);

Future<void> _montar(WidgetTester tester, _Repository repo) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => GestionController(repo),
      child: const MaterialApp(home: PersonalModuleScreen())));
  await tester.pumpAndSettle();
}

Future<void> _seleccionar(
    WidgetTester tester, String label, String valor) async {
  await tester.ensureVisible(_selector(label));
  await tester.tap(_selector(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(valor).last);
  await tester.pumpAndSettle();
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
  await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'alta, edición, baja, reactivación y suspensión refrescan la lista',
      (tester) async {
    final repo = _Repository();
    await _montar(tester, repo);
    expect(find.text('No existe personal registrado.'), findsOneWidget);
    await tester.tap(find.text('Nuevo Personal'));
    await tester.pumpAndSettle();
    await tester.enterText(_campo('Código'), 'MED-001');
    await tester.enterText(_campo('Nombre'), 'Carlos');
    await tester.enterText(_campo('Apellido'), 'Pérez');
    await tester.enterText(_campo('Correo'), ' TEST@EXAMPLE.COM ');
    await tester.enterText(_campo('Contraseña temporal'), 'Temporal123!');
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: _campo('Contraseña temporal'),
                matching: find.byType(TextField)))
            .obscureText,
        isTrue);
    await _guardar(tester);
    expect(repo.correoRecibido, 'test@example.com');
    expect(repo.altas, 1);
    expect(repo.consultas, 2);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('Personal creado correctamente.'), findsOneWidget);
    expect(find.text('test@example.com'), findsNothing);
    expect(find.text('Temporal123!'), findsNothing);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(_campo('Correo'), findsNothing);
    expect(_campo('Contraseña temporal'), findsNothing);
    await tester.enterText(_campo('Nombre'), 'Carla');
    await _seleccionar(tester, 'Tipo de personal', 'Enfermero');
    await _guardar(tester);
    expect(find.text('Carla Pérez'), findsOneWidget);
    expect(find.text('Tipo: Enfermero'), findsOneWidget);
    expect(repo.consultas, 3);
    expect(repo.altas, 1);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dar de baja'));
    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();
    expect(find.text('¿Confirmas que deseas dar de baja a este personal?'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Dar de baja'));
    await tester.pumpAndSettle();
    expect(find.text('Estado: Inactivo'), findsOneWidget);
    expect(repo.consultas, 4);
    expect(repo.rows.length, 1);

    for (final estado in ['Activo', 'Suspendido']) {
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await _seleccionar(tester, 'Estado', estado);
      await _guardar(tester);
      expect(find.text('Estado: $estado'), findsOneWidget);
    }
    expect(repo.consultas, 6);
    expect(repo.altas, 1);
    expect(repo.ediciones, 3);
  });

  testWidgets(
      'conserva especialidad inactiva, busca nombre y permite cambiarla',
      (tester) async {
    final repo = _Repository()
      ..rows = [
        const Personal(
            id: 'p1',
            codigo: 'MED-001',
            nombre: 'Carlos',
            apellido: 'Pérez',
            tipoPersonal: 'medico',
            especialidadId: 'inactiva',
            especialidadNombre: 'Especialidad anterior')
      ];
    await _montar(tester, repo);
    await tester.enterText(
        find.byType(TextField).first, 'especialidad anterior');
    expect(find.text('Carlos Pérez'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(repo.especialidadActual, 'inactiva');
    expect(find.text('Especialidad anterior (Inactiva)'), findsOneWidget);
    await _seleccionar(tester, 'Especialidad', 'Cardiología');
    await _guardar(tester);
    expect(repo.rows.single.especialidadId, 'activa');
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(repo.consultas, 2);
  });

  testWidgets('validación, duplicado y limpieza de contraseña tras fallo',
      (tester) async {
    final repo = _Repository()
      ..errorAlta = const FunctionException(
          status: 409, details: {'error': 'email already exists'});
    await _montar(tester, repo);
    await tester.tap(find.text('Nuevo Personal'));
    await tester.pumpAndSettle();
    await _guardar(tester);
    expect(find.text('Código es obligatorio.'), findsOneWidget);
    expect(repo.altas, 0);
    await tester.enterText(_campo('Código'), 'AB');
    await tester.enterText(_campo('Nombre'), 'Ana');
    await tester.enterText(_campo('Apellido'), 'Pérez');
    await tester.enterText(_campo('Correo'), 'ana@example.com');
    await tester.enterText(_campo('Contraseña temporal'), 'Temporal123!');
    await _guardar(tester);
    expect(find.text('Ya existe una cuenta registrada con ese correo.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(_campo('Contraseña temporal'))
            .controller!
            .text,
        isEmpty);
    expect(repo.rows, isEmpty);
    expect(repo.consultas, 1);
  });

  testWidgets('error, reintento, carga y respuesta tras cerrar',
      (tester) async {
    final repo = _Repository()..falla = true;
    await _montar(tester, repo);
    expect(find.text('Reintentar'), findsOneWidget);
    repo.falla = false;
    repo.pendiente = Completer<List<Personal>>();
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.pendiente!.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('mensajes de función seguros y payload funcional sin credenciales', () {
    expect(mensajeErrorAltaPersonal(401, null),
        'La sesión no es válida. Vuelve a iniciar sesión.');
    expect(mensajeErrorAltaPersonal(403, null),
        'No tienes permisos para crear personal.');
    expect(mensajeErrorAltaPersonal(409, {'error': 'codigo duplicado'}),
        'Ya existe un personal con ese código o CI.');
    expect(mensajeErrorAltaPersonal(500, {'error': 'JWT secret token interno'}),
        'No se pudo registrar el personal.');
    final datos = const Personal(
            codigo: ' AB ',
            nombre: ' Ana ',
            apellido: ' Pérez ',
            tipoPersonal: 'medico',
            ci: ' ')
        .toMap();
    expect(datos['ci'], isNull);
    expect(datos['codigo'], 'AB');
    expect(
        datos.keys,
        unorderedEquals([
          'codigo',
          'nombre',
          'apellido',
          'ci',
          'sexo',
          'telefono',
          'tipo_personal',
          'estado',
          'especialidad_id'
        ]));
  });
}
