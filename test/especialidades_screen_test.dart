import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/controllers/gestion_controller.dart';
import 'package:gestion_hospitalaria/models/gestion_models.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/screens/especialidades_screen.dart';

class _Repository extends GestionRepository {
  _Repository() : super(SupabaseClient('https://example.com', 'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false)));
  List<Especialidad> rows = [];
  int consultas = 0;
  bool duplicado = false;
  bool falla = false;

  @override
  Future<List<Especialidad>> listarEspecialidades() async {
    consultas++;
    if (falla) throw Exception('Sin conexión');
    return List.of(rows);
  }

  @override
  Future<void> guardarEspecialidad(Especialidad item) async {
    if (duplicado) throw const PostgrestException(message: 'duplicate', code: '23505');
    final nuevo = Especialidad.fromMap({...item.toMap(), 'id': item.id ?? 'nuevo'});
    rows = [...rows.where((row) => row.id != nuevo.id), nuevo];
  }

  @override
  Future<void> darDeBajaEspecialidad(String id) async {
    rows = rows.map((row) => row.id == id
        ? Especialidad.fromMap({...row.toMap(), 'id': id, 'estado': 'inactivo'})
        : row).toList();
  }
}

Future<void> _montar(WidgetTester tester, _Repository repo) async {
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => GestionController(repo),
    child: const MaterialApp(home: EspecialidadesScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('crear, editar y baja confirmada consultan y refrescan sin salir', (tester) async {
    final repo = _Repository();
    await _montar(tester, repo);
    expect(find.text('No existen especialidades registradas.'), findsOneWidget);
    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cardiología');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.text('Especialidad creada correctamente.'), findsOneWidget);
    expect(repo.consultas, 2);

    await tester.enterText(find.byType(TextField).first, 'Cardiología');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Pediatría');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Pediatría'), findsOneWidget);
    expect(find.text('Cardiología'), findsNothing);
    expect(repo.consultas, 3);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();
    expect(find.text('¿Confirmas que deseas dar de baja esta especialidad?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Dar de baja'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Estado: Inactivo'), findsOneWidget);
    expect(repo.consultas, 4);
    expect(repo.rows.length, 1);
  });

  testWidgets('reintento, validación y duplicado conservan formulario', (tester) async {
    final repo = _Repository()..falla = true;
    await _montar(tester, repo);
    expect(find.text('Reintentar'), findsOneWidget);
    repo.falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El nombre es obligatorio.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'A');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El nombre debe tener al menos 2 caracteres.'), findsOneWidget);
    repo.duplicado = true;
    await tester.enterText(find.byType(TextFormField).first, 'Cardiología');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ya existe una especialidad con ese nombre.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repo.rows, isEmpty);
  });
}
