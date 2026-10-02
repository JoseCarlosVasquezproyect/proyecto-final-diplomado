import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';
import 'package:gestion_hospitalaria/repositories/personal_panel_repository.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  final paths = <String>[];
  final queries = <String, Map<String, String>>{};
  var admin = false;
  var personal = true;
  const userId = '11111111-1111-4111-8111-111111111111';
  setUp(() async {
    paths.clear(); queries.clear(); admin = false; personal = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      paths.add(request.uri.path);
      queries[request.uri.path] = request.uri.queryParameters;
      Object? result;
      switch (request.uri.path.split('/').last) {
        case 'es_administrador': result = admin;
        case 'es_personal': result = personal;
        case 'mi_personal_id': result = personal ? 'own-personal' : null;
        case 'personal': result = {
          'id': 'own-personal', 'codigo': 'ENF-001', 'nombre': 'AnaM', 'apellido': 'Demo',
          'tipo_personal': 'enfermero', 'especialidades': {'nombre': 'Cardiología'},
        };
        case 'asignaciones_turno': result = [
          for (final fecha in ['2026-09-26', '2026-10-03']) {
            'turno_id': fecha, 'personal_id': 'own-personal', 'rol_en_turno': 'enfermero',
            'estado_asistencia': 'cumplido', 'observaciones': 'Asignación propia',
            'turnos': {'fecha': fecha, 'tipo': 'noche', 'hora_inicio': '19:00:00', 'hora_fin': '07:00:00', 'area': 'Medicina', 'observaciones': 'Turno propio'},
          },
        ];
        default: fail('Consulta inesperada: ${request.uri.path}');
      }
      expect(request.method, anyOf('GET', 'POST'));
      if (request.method == 'POST') expect(request.uri.path, contains('/rpc/'));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(result));
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false));
  });
  tearDown(() async { await client.dispose(); await server.close(force: true); });

  Future<void> session() async {
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    String encode(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    await client.auth.recoverSession(jsonEncode({
      'access_token': '${encode({'alg': 'HS256'})}.${encode({'sub': userId, 'exp': exp})}.test',
      'refresh_token': 'test', 'token_type': 'bearer', 'expires_in': 3600, 'expires_at': exp,
      'user': {'id': userId, 'aud': 'authenticated', 'app_metadata': {}, 'user_metadata': {}, 'created_at': '2026-01-01T00:00:00Z'},
    }));
  }

  test('Administrador tiene prioridad y no consulta es_personal', () async {
    admin = true;
    expect(await GestionRepository(client).perfilActual(), 'administrador');
    expect(paths, ['/rest/v1/rpc/es_administrador']);
  });
  test('Personal activo entra y un perfil inactivo queda no autorizado', () async {
    final repo = GestionRepository(client);
    expect(await repo.perfilActual(), 'personal');
    personal = false;
    expect(await repo.perfilActual(), 'no_autorizado');
  });
  test('consultas propias usan filtros de servidor, relaciones y solo lectura', () async {
    await session();
    final repo = PersonalPanelRepository(client);
    final datos = await repo.misDatos();
    final turnos = await repo.misTurnos();
    expect(datos.nombreCompleto, 'AnaM Demo');
    expect(datos.especialidadNombre, 'Cardiología');
    expect(queries['/rest/v1/personal']!['id'], 'eq.own-personal');
    expect(queries['/rest/v1/personal']!['user_id'], 'eq.$userId');
    expect(queries['/rest/v1/asignaciones_turno']!['personal_id'], 'eq.own-personal');
    expect(queries['/rest/v1/asignaciones_turno']!['select'], contains('estado_asistencia'));
    expect(turnos.first.turno!.fecha, DateTime(2026, 10, 3));
    expect(turnos.first.estadoAsistencia, 'cumplido');
    expect(turnos.first.turno!.observaciones, 'Turno propio');
    expect(paths.any((p) => p.endsWith('/turnos')), isFalse);
  });
  test('sin sesión o sin identidad activa no consulta tablas', () async {
    final repo = PersonalPanelRepository(client);
    await expectLater(repo.misTurnos(), throwsStateError);
    expect(paths, isEmpty);
    await session(); personal = false;
    await expectLater(repo.misDatos(), throwsStateError);
    expect(paths, ['/rest/v1/rpc/mi_personal_id']);
  });
}
