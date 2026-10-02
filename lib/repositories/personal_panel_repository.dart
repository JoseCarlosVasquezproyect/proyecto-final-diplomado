import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gestion_models.dart';

/// Consultas de solo lectura, acotadas al perfil de la sesión y a RLS.
class PersonalPanelRepository {
  PersonalPanelRepository(this.client);
  final SupabaseClient client;

  Future<String> _miId() async {
    if (client.auth.currentUser == null) throw StateError('Sesión no válida.');
    final id = await client.rpc('mi_personal_id');
    if (id is! String || id.isEmpty) throw StateError('Perfil no disponible.');
    return id;
  }

  Future<Personal> misDatos() async {
    final id = await _miId();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sesión no válida.');
    final row = await client.from('personal').select(
      'id,codigo,nombre,apellido,ci,sexo,telefono,tipo_personal,estado,especialidad_id,especialidades(nombre)',
    ).eq('id', id).eq('user_id', userId).single();
    return Personal.fromMap(row);
  }

  Future<List<AsignacionTurno>> misTurnos() async {
    final id = await _miId();
    final rows = await client.from('asignaciones_turno').select(
      'id,turno_id,personal_id,rol_en_turno,observaciones,estado_asistencia,'
      'turnos(id,fecha,tipo,hora_inicio,hora_fin,area,estado,observaciones)',
    ).eq('personal_id', id);
    final result = rows.map(AsignacionTurno.fromMap).toList();
    if (result.any((a) => a.turno == null)) {
      throw StateError('No se pudo obtener un turno asignado.');
    }
    result.sort((a, b) {
      final fecha = b.turno!.fecha.compareTo(a.turno!.fecha);
      return fecha != 0 ? fecha : a.turno!.horaInicio.compareTo(b.turno!.horaInicio);
    });
    return result;
  }
}
