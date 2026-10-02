import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/controllers/gestion_controller.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/screens/admin_gate.dart';

class _Repository extends GestionRepository {
  _Repository(this.perfil) : super(SupabaseClient('https://example.com', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final String perfil;
  bool falla = false;
  @override
  Future<String> perfilActual() async {
    if (falla) throw StateError('Error interno');
    return perfil;
  }
}

void main() {
  Future<void> mount(WidgetTester tester, _Repository repo, Future<void> Function() rechazar) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => GestionController(repo),
      child: MaterialApp(home: AdminGate(onUnauthorized: rechazar))));
    await tester.pump();
  }
  testWidgets('Admin mantiene dashboard y todos los módulos vigentes sin Emergencias', (tester) async {
    await mount(tester, _Repository('administrador'), () async => fail('No debe rechazar Admin'));
    expect(find.text('Dashboard administrativo'), findsOneWidget);
    for (final module in ['Personal', 'Especialidades', 'Turnos', 'Asignaciones', 'Asistencia']) {
      expect(find.text(module), findsNWidgets(2));
    }
    expect(find.text('Emergencias'), findsNothing);
  });
  testWidgets('Personal tiene panel propio sin dashboard administrativo', (tester) async {
    await mount(tester, _Repository('personal'), () async => fail('No debe rechazar Personal'));
    await tester.pump();
    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Dashboard administrativo'), findsNothing);
  });
  testWidgets('no autorizado pide cerrar sesión; error transitorio permite reintentar', (tester) async {
    var rechazos = 0;
    final repo = _Repository('no_autorizado')..falla = true;
    await mount(tester, repo, () async { rechazos++; });
    expect(rechazos, 0);
    expect(find.text('No se pudo verificar el perfil de la cuenta.'), findsOneWidget);
    repo.falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(rechazos, 1);
    expect(find.text('Mi cuenta'), findsNothing);
    expect(find.text('Dashboard administrativo'), findsNothing);
  });
}
