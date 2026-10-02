import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/models/asistencia_errors.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';

const _usuarioId = '11111111-1111-4111-8111-111111111111';
const _adminId = '22222222-2222-4222-8222-222222222222';

class _Backend {
  late HttpServer server;
  late SupabaseClient client;
  late GestionRepository repo;
  bool esAdmin = true;
  final requests = <Map<String, dynamic>>[];
  final row = <String, dynamic>{
    'id': 'a1', 'turno_id': 't1', 'personal_id': 'p1', 'rol_en_turno': 'enfermero',
    'observaciones': 'Guardia', 'estado_asistencia': 'pendiente',
    'turnos': {'id': 't1', 'fecha': '2026-10-03', 'tipo': 'noche', 'hora_inicio': '19:00:00', 'hora_fin': '07:00:00', 'area': 'Medicina', 'estado': 'programado'},
    'personal': {'id': 'p1', 'codigo': 'ENF-001', 'nombre': 'AnaM', 'apellido': 'Demo', 'tipo_personal': 'enfermero', 'especialidades': {'nombre': 'Cardiología'}},
  };

  Future<void> iniciar() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_responder);
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false));
    repo = GestionRepository(client);
  }

  Future<void> autenticar() async {
    // Sesión ficticia en memoria, exclusivamente para el cliente del servidor local.
    final expira = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    String segmento(Object valor) => base64Url.encode(utf8.encode(jsonEncode(valor))).replaceAll('=', '');
    final token = '${segmento({'alg': 'HS256', 'typ': 'JWT'})}.${segmento({'sub': _usuarioId, 'exp': expira})}.test';
    await client.auth.recoverSession(jsonEncode({
      'access_token': token, 'refresh_token': 'test-refresh', 'token_type': 'bearer',
      'expires_in': 3600, 'expires_at': expira,
      'user': {'id': _usuarioId, 'aud': 'authenticated', 'app_metadata': {}, 'user_metadata': {}, 'created_at': '2026-01-01T00:00:00Z'},
    }));
  }

  Future<void> cerrar() async {
    await client.dispose();
    await server.close(force: true);
  }

  Future<void> _responder(HttpRequest request) async {
    final texto = await utf8.decoder.bind(request).join();
    final body = texto.isEmpty ? null : jsonDecode(texto);
    requests.add({'method': request.method, 'path': request.uri.path, 'query': request.uri.queryParameters, 'body': body});
    Object data;
    if (request.uri.path.endsWith('/administradores')) {
      data = esAdmin ? [{'id': _adminId, 'user_id': _usuarioId, 'nombre': 'Admin', 'apellido': 'Demo', 'estado': 'activo'}] : [];
    } else if (request.method == 'PATCH') {
      final estadoEsperado = request.uri.queryParameters['estado_asistencia']?.substring(3);
      if (estadoEsperado == row['estado_asistencia']) {
        row.addAll(body as Map<String, dynamic>);
        data = [row];
      } else {
        data = [];
      }
    } else {
      data = [row];
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }
}

void main() {
  late _Backend backend;
  setUp(() async { backend = _Backend(); await backend.iniciar(); });
  tearDown(() => backend.cerrar());

  test('marcación y correcciones registran administrador de negocio y hora UTC', () async {
    await backend.autenticar();
    final antes = DateTime.now().toUtc();
    var estadoAnterior = 'pendiente';
    for (final estado in ['cumplido', 'falta', 'cumplido']) {
      await backend.repo.marcarAsistencia(asignacionId: 'a1', estado: estado, estadoAnterior: estadoAnterior);
      final patch = backend.requests.lastWhere((r) => r['method'] == 'PATCH');
      final body = patch['body'] as Map;
      expect(body.keys, unorderedEquals(['estado_asistencia', 'asistencia_marcada_por', 'asistencia_marcada_at']));
      expect(body['asistencia_marcada_por'], _adminId);
      expect(body['asistencia_marcada_por'], isNot(_usuarioId));
      final fecha = DateTime.parse(body['asistencia_marcada_at'] as String);
      expect(fecha.isUtc, isTrue);
      expect(fecha.isBefore(antes), isFalse);
      expect(fecha.isAfter(DateTime.now().toUtc()), isFalse);
      expect((patch['query'] as Map)['estado_asistencia'], 'eq.$estadoAnterior');
      estadoAnterior = estado;
    }
    expect(backend.row['estado_asistencia'], 'cumplido');
    expect(backend.row['turno_id'], 't1');
    expect(backend.row['personal_id'], 'p1');
    expect(backend.row['observaciones'], 'Guardia');
    expect(backend.requests.any((r) => (r['path'] as String).contains('auditoria')), isFalse);
    expect(backend.requests.where((r) => r['method'] == 'POST' || r['method'] == 'DELETE'), isEmpty);
    final adminQuery = backend.requests.first['query'] as Map;
    expect(adminQuery['user_id'], 'eq.$_usuarioId');
    expect(adminQuery['estado'], 'eq.activo');
  });

  test('sin sesión o sin perfil administrador no se permite marcar', () async {
    await expectLater(backend.repo.marcarAsistencia(asignacionId: 'a1', estado: 'cumplido', estadoAnterior: 'pendiente'),
      throwsA(isA<AsistenciaException>()));
    expect(backend.requests, isEmpty);
    await backend.autenticar();
    backend.esAdmin = false;
    await expectLater(backend.repo.marcarAsistencia(asignacionId: 'a1', estado: 'falta', estadoAnterior: 'pendiente'),
      throwsA(isA<AsistenciaException>().having((e) => e.mensaje, 'mensaje', 'No tienes permisos para controlar asistencia.')));
    await expectLater(backend.repo.listarAsistencias(), throwsA(isA<AsistenciaException>()));
    expect(backend.requests.where((r) => r['method'] == 'PATCH'), isEmpty);
  });

  test('un cambio concurrente no se sobrescribe; exige recargar', () async {
    await backend.autenticar();
    backend.row['estado_asistencia'] = 'cumplido';
    await expectLater(backend.repo.marcarAsistencia(asignacionId: 'a1', estado: 'falta', estadoAnterior: 'pendiente'),
      throwsA(isA<AsistenciaException>().having((e) => e.recargar, 'recargar', isTrue)));
    expect(backend.row['estado_asistencia'], 'cumplido');
    expect(backend.row.containsKey('asistencia_marcada_por'), isFalse);
  });

  test('consulta usa relaciones; no acepta pendiente ni valores inventados al marcar', () async {
    await backend.autenticar();
    final rows = await backend.repo.listarAsistencias();
    expect(rows.single.personal!.especialidadNombre, 'Cardiología');
    expect(rows.single.turno!.area, 'Medicina');
    expect(backend.requests.length, 2);
    final select = (backend.requests.last['query'] as Map)['select'] as String;
    expect(select, contains('especialidades(nombre)'));
    expect(select, contains('turnos('));
    expect(select, contains('personal('));
    for (final estado in ['pendiente', 'inventado']) {
      await expectLater(backend.repo.marcarAsistencia(asignacionId: 'a1', estado: estado, estadoAnterior: 'pendiente'),
        throwsA(isA<AsistenciaException>()));
    }
    expect(backend.requests.where((r) => r['method'] == 'PATCH'), isEmpty);
  });
}
