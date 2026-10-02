import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestion_hospitalaria/models/asignacion_errors.dart';
import 'package:gestion_hospitalaria/repositories/gestion_repository.dart';

// Prueba el contrato HTTP del SDK con datos ficticios, sin conectar a Supabase.
class _Backend {
  late HttpServer server;
  late SupabaseClient client;
  late GestionRepository repo;
  final requests = <Map<String, dynamic>>[];
  final rows = <Map<String, dynamic>>[];
  String tipoPersonal = 'enfermero';
  bool solapamiento = false, duplicadoSimultaneo = false;

  Future<void> iniciar() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_responder);
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false));
    repo = GestionRepository(client);
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
    final table = request.uri.path.split('/').last;
    final single = request.headers.value('accept')?.contains('vnd.pgrst.object') == true;
    if (table == 'personal') {
      final persona = {'id': 'persona-1', 'tipo_personal': tipoPersonal, 'estado': 'activo'};
      data = single ? persona : [persona];
    } else if (table == 'turnos') {
      final turno = {'id': 'turno-1', 'estado': 'programado'};
      data = single ? turno : [turno];
    } else if (request.method == 'GET') {
      final query = request.uri.queryParameters;
      final resultados = rows.where((row) {
        for (final key in ['id', 'turno_id', 'personal_id']) {
          final filtro = query[key];
          if (filtro == null) continue;
          if (filtro.startsWith('eq.') && row[key] != filtro.substring(3)) return false;
          if (filtro.startsWith('neq.') && row[key] == filtro.substring(4)) return false;
        }
        return true;
      }).toList();
      data = single ? resultados.single : resultados;
    } else if (request.method == 'POST') {
      if (duplicadoSimultaneo) {
        rows.add({'id': 'otro', ...body as Map<String, dynamic>});
      }
      if (solapamiento || duplicadoSimultaneo) {
        request.response.statusCode = 400;
        data = {'code': 'P0001', 'message': 'El personal ya posee otro turno que se solapa con el horario seleccionado.'};
      } else {
        final row = {'id': 'nuevo', 'estado_asistencia': 'pendiente', ...body as Map<String, dynamic>};
        rows.add(row);
        data = single ? row : [row];
      }
    } else if (request.method == 'PATCH') {
      final id = request.uri.queryParameters['id']!.substring(3);
      final row = rows.singleWhere((row) => row['id'] == id)..addAll(body as Map<String, dynamic>);
      data = single ? row : [row];
    } else {
      request.response.statusCode = 405;
      data = {'message': 'Método no esperado'};
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

  test('INSERT deriva rol de la lectura actual y omite asistencia y trazabilidad', () async {
    backend.tipoPersonal = 'pasante';
    await backend.repo.guardarAsignacion(turnoId: 'turno-1', personalId: 'persona-1', observaciones: ' Guardia ');
    final post = backend.requests.singleWhere((r) => r['method'] == 'POST');
    expect(post['path'], '/rest/v1/asignaciones_turno');
    expect(post['body'], {'turno_id': 'turno-1', 'personal_id': 'persona-1', 'rol_en_turno': 'pasante', 'observaciones': 'Guardia'});
    expect(backend.rows.single['estado_asistencia'], 'pendiente');
  });

  test('duplicado exacto se detecta antes del INSERT que activaría el trigger', () async {
    backend.rows.add({'id': 'existente', 'turno_id': 'turno-1', 'personal_id': 'persona-1'});
    await expectLater(backend.repo.guardarAsignacion(turnoId: 'turno-1', personalId: 'persona-1', observaciones: ''),
      throwsA(isA<AsignacionException>().having((e) => e.mensaje, 'mensaje', 'Este personal ya está asignado al turno seleccionado.')));
    expect(backend.requests.where((r) => r['method'] == 'POST'), isEmpty);
  });

  test('duplicado simultáneo se distingue del rechazo por otro turno solapado', () async {
    backend.duplicadoSimultaneo = true;
    await expectLater(backend.repo.guardarAsignacion(turnoId: 'turno-1', personalId: 'persona-1', observaciones: ''),
      throwsA(isA<AsignacionException>().having((e) => e.mensaje, 'mensaje', 'Este personal ya está asignado al turno seleccionado.')));
    backend.rows.clear();
    backend.duplicadoSimultaneo = false;
    backend.solapamiento = true;
    await expectLater(backend.repo.guardarAsignacion(turnoId: 'turno-2', personalId: 'persona-1', observaciones: ''),
      throwsA(isA<PostgrestException>().having(mensajeErrorAsignacion, 'mensaje', 'El personal ya tiene otro turno que se solapa con el horario seleccionado.')));
  });

  test('UPDATE de relaciones conserva asistencia; observaciones solas no envían FK', () async {
    backend.rows.add({'id': 'existente', 'turno_id': 'turno-1', 'personal_id': 'persona-1',
      'estado_asistencia': 'cumplido', 'asistencia_marcada_por': 'admin-1'});
    await backend.repo.guardarAsignacion(id: 'existente', turnoId: 'turno-2', personalId: 'persona-1', observaciones: 'Cambio');
    final patch = backend.requests.lastWhere((r) => r['method'] == 'PATCH')['body'] as Map;
    expect(patch, {'turno_id': 'turno-2', 'rol_en_turno': 'enfermero', 'observaciones': 'Cambio'});
    expect(backend.rows.single['estado_asistencia'], 'cumplido');
    expect(backend.rows.single['asistencia_marcada_por'], 'admin-1');
    await backend.repo.guardarAsignacion(id: 'existente', turnoId: 'turno-2', personalId: 'persona-1', observaciones: 'Solo observación');
    final soloObservacion = backend.requests.lastWhere((r) => r['method'] == 'PATCH')['body'] as Map;
    expect(soloObservacion.keys, unorderedEquals(['rol_en_turno', 'observaciones']));
    expect(backend.requests.where((r) => r['method'] == 'DELETE'), isEmpty);
  });
}
