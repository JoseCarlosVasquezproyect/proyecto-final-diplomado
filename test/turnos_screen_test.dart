import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/controllers/gestion_controller.dart';
import 'package:gestion_hospitalaria/models/gestion_models.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/screens/turnos_screen.dart';

class TurnosRepositoryPrueba extends GestionRepository {
  TurnosRepositoryPrueba()
      : super(SupabaseClient('https://example.com', 'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));

  List<Turno> rows = [];
  int consultas = 0;
  bool falla = false;
  Completer<List<Turno>>? pendiente;

  @override
  Future<List<Turno>> listarTurnos() async {
    consultas++;
    if (falla) throw Exception('Sin conexión');
    if (pendiente != null) return pendiente!.future;
    return List.of(rows);
  }

  @override
  Future<void> guardarTurno(Turno turno) async {
    final nuevo = Turno.fromMap({...turno.toMap(), 'id': turno.id ?? 'nuevo'});
    rows = [...rows.where((t) => t.id != nuevo.id), nuevo];
  }

  @override
  Future<void> cancelarTurno(String id) async {
    rows = rows.map((t) => t.id == id
        ? Turno.fromMap({...t.toMap(), 'id': id, 'estado': 'cancelado'})
        : t).toList();
  }
}

Future<void> montar(WidgetTester tester, TurnosRepositoryPrueba repo) async {
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => GestionController(repo),
    child: const MaterialApp(home: TurnosScreen()),
  ));
  await tester.pump();
}

void main() {
  testWidgets('crear, editar y cancelar actualizan la lista con una consulta por operación', (tester) async {
    final repo = TurnosRepositoryPrueba();
    await montar(tester, repo);
    expect(find.text('No existen turnos registrados.'), findsOneWidget);
    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Urgencias');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Urgencias'), findsOneWidget);
    expect(repo.consultas, 2);

    await tester.tap(find.byTooltip('Editar turno'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Pediatría');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Pediatría'), findsOneWidget);
    expect(find.text('Urgencias'), findsNothing);
    expect(repo.consultas, 3);

    await tester.tap(find.byTooltip('Editar turno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar turno'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar turno'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Estado: Cancelado'), findsOneWidget);
    expect(repo.consultas, 4);
    expect(repo.rows.length, 1);
  });

  testWidgets('cargando, error, reintento y respuesta después de dispose', (tester) async {
    final repo = TurnosRepositoryPrueba()..falla = true;
    await montar(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    repo.falla = false;
    repo.pendiente = Completer<List<Turno>>();
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.pendiente!.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
