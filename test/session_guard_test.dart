import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/controllers/gestion_controller.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/screens/auth_gate.dart';
import 'package:gestion_hospitalaria/screens/login_screen.dart';
import 'package:gestion_hospitalaria/services/session_guard.dart';

void main() {
  late SupabaseClient client;
  late SessionGuard guard;
  var status = 200;
  var logouts = 0;
  var networkFailure = false;

  setUp(() async {
    status = 200;
    logouts = 0;
    networkFailure = false;
    final transport = SessionHttpClient(
      baseUrl: Uri.parse('https://example.com'),
      guard: () => guard,
      inner: MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') {
          logouts++;
          return http.Response('', 204, request: request);
        }
        if (networkFailure) throw http.ClientException('Offline');
        if (request.url.path.endsWith('es_administrador')) {
          return http.Response('true', 200, request: request);
        }
        return http.Response(
          status == 200
              ? '[]'
              : '{"message":"request failed","code":"$status"}',
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    client = SupabaseClient('https://example.com', 'test-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    guard = SessionGuard(client);
    final expires =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    String encode(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    await client.auth.recoverSession(jsonEncode({
      'access_token': '${encode({'alg': 'HS256'})}.${encode({
            'sub': 'test-user',
            'exp': expires
          })}.test',
      'refresh_token': 'refresh-test',
      'token_type': 'bearer',
      'expires_at': expires,
      'user': {
        'id': 'test-user',
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z'
      },
    }));
  });
  tearDown(() => client.dispose());

  test('operación válida conserva la sesión', () async {
    await GestionRepository(client).listarPersonal();
    expect(client.auth.currentSession, isNotNull);
    expect(logouts, 0);
  });
  for (final code in [400, 403, 409]) {
    test('HTTP $code conserva la sesión', () async {
      status = code;
      await expectLater(GestionRepository(client).listarPersonal(),
          throwsA(isA<PostgrestException>()));
      expect(client.auth.currentSession, isNotNull);
      expect(logouts, 0);
    });
  }
  test('HTTP 401 cierra sesión una sola vez ante peticiones concurrentes',
      () async {
    status = 401;
    await Future.wait(List.generate(2, (_) async {
      await expectLater(GestionRepository(client).listarPersonal(),
          throwsA(isA<PostgrestException>()));
    }));
    expect(client.auth.currentSession, isNull);
    expect(logouts, 1);
  });
  test('errores temporales de red no cierran sesión', () async {
    networkFailure = true;
    await expectLater(GestionRepository(client).listarPersonal(),
        throwsA(isA<http.ClientException>()));
    await guard.handleError(AuthRetryableFetchException());
    expect(client.auth.currentSession, isNotNull);
    expect(logouts, 0);
  });
  test('errores tipados de JWT invalidan; validación y permisos no', () async {
    await guard
        .handleError(const AuthException('validation', statusCode: '400'));
    await guard
        .handleError(const AuthException('forbidden', statusCode: '403'));
    await guard.handleError(
        const PostgrestException(message: 'permission denied', code: '42501'));
    expect(logouts, 0);
    await guard.handleError(
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'));
    expect(client.auth.currentSession, isNull);
    expect(logouts, 1);
  });

  for (final via401 in [true, false]) {
    testWidgets(
        '${via401 ? '401' : 'sesión null'} muestra login y elimina formulario y diálogo',
        (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => GestionController(GestionRepository(client)),
        child: MaterialApp(
            navigatorKey: navigator, home: AuthGate(client: client)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard administrativo'), findsOneWidget);
      navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Formulario protegido')),
      ));
      await tester.pumpAndSettle();
      showDialog<void>(
          context: tester.element(find.text('Formulario protegido')),
          builder: (_) =>
              const AlertDialog(content: Text('Diálogo protegido')));
      await tester.pumpAndSettle();
      if (via401) {
        status = 401;
        await expectLater(GestionRepository(client).listarPersonal(),
            throwsA(isA<PostgrestException>()));
      } else {
        await client.auth.signOut();
      }
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Dashboard administrativo'), findsNothing);
      expect(find.text('Formulario protegido'), findsNothing);
      expect(find.text('Diálogo protegido'), findsNothing);
      expect(navigator.currentState!.canPop(), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
