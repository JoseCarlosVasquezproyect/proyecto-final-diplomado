import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gestion_models.dart';

class PersonalDashboardData {
  const PersonalDashboardData(
      {required this.personal, required this.assignments});

  final Personal personal;
  final List<AsignacionTurno> assignments;
}

/// Consultas de solo lectura, acotadas al perfil de la sesión y a RLS.
class PersonalPanelRepository {
  PersonalPanelRepository(this.client);
  final SupabaseClient client;

  Future<String> _miId(String userId) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Sesión no válida.');
    }
    final id = await client.rpc('mi_personal_id');
    if (id is! String || id.isEmpty) throw StateError('Perfil no disponible.');
    return id;
  }

  Future<Personal> misDatos() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sesión no válida.');
    final id = await _miId(userId);
    return _cargarDatos(id, userId);
  }

  /// Loads the profile and its assignments after resolving the session identity once.
  Future<PersonalDashboardData> miDashboard() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sesión no válida.');
    final id = await _miId(userId);
    final result = await Future.wait<Object>([
      _cargarDatos(id, userId),
      _cargarTurnos(id, userId),
    ]);
    return PersonalDashboardData(
      personal: result[0] as Personal,
      assignments: result[1] as List<AsignacionTurno>,
    );
  }

  Future<Personal> _cargarDatos(String id, String userId) async {
    final row = await client
        .from('personal')
        .select(
          'id,codigo,nombre,apellido,ci,sexo,telefono,tipo_personal,estado,especialidad_id,especialidades(nombre)',
        )
        .eq('id', id)
        .eq('user_id', userId)
        .single();
    return Personal.fromMap(row);
  }

  Future<List<AsignacionTurno>> misTurnos() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sesión no válida.');
    final id = await _miId(userId);
    return _cargarTurnos(id, userId);
  }

  Future<List<AsignacionTurno>> _cargarTurnos(String id, String userId) async {
    final rows = await client
        .from('asignaciones_turno')
        .select(
          'id,turno_id,personal_id,rol_en_turno,observaciones,estado_asistencia,'
          'turnos(id,fecha,tipo,hora_inicio,hora_fin,area,estado,observaciones),'
          'personal!inner(user_id)',
        )
        .eq('personal_id', id)
        .eq('personal.user_id', userId);
    final result = rows.map(AsignacionTurno.fromMap).toList();
    if (result.any((a) => a.turno == null)) {
      throw StateError('No se pudo obtener un turno asignado.');
    }
    result.sort((a, b) {
      final fecha = b.turno!.fecha.compareTo(a.turno!.fecha);
      return fecha != 0
          ? fecha
          : a.turno!.horaInicio.compareTo(b.turno!.horaInicio);
    });
    return result;
  }
}
