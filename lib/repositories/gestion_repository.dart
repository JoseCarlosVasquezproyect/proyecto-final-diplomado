import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gestion_models.dart';
import '../models/personal_errors.dart';
import '../models/asignacion_errors.dart';
import '../models/asistencia_errors.dart';

class GestionRepository {
  GestionRepository(this.client);
  final SupabaseClient client;
  Future<List<AsignacionTurno>> listarAsistencias() async {
    final admin = await administradorActual();
    if (admin == null) {
      throw const AsistenciaException('No tienes permisos para controlar asistencia.');
    }
    final rows = await listarAsignaciones();
    rows.sort((a, b) {
      if (a.turno == null) return b.turno == null ? 0 : 1;
      if (b.turno == null) return -1;
      final fecha = b.turno!.fecha.compareTo(a.turno!.fecha);
      if (fecha != 0) return fecha;
      final hora = a.turno!.horaInicio.compareTo(b.turno!.horaInicio);
      if (hora != 0) return hora;
      return (a.personal?.nombreCompleto ?? '').compareTo(b.personal?.nombreCompleto ?? '');
    });
    return rows;
  }

  Future<void> marcarAsistencia({required String asignacionId, required String estado, required String estadoAnterior}) async {
    if (!['cumplido', 'falta'].contains(estado) ||
        !['pendiente', 'cumplido', 'falta'].contains(estadoAnterior)) {
      throw const AsistenciaException('El estado de asistencia seleccionado no es válido.');
    }
    final authId = client.auth.currentUser?.id;
    if (authId == null) {
      throw const AsistenciaException('La sesión no es válida. Vuelve a iniciar sesión.');
    }
    final admin = await administradorActual();
    if (admin?.id == null) {
      throw const AsistenciaException('No tienes permisos para controlar asistencia.');
    }
    if (admin!.userId != authId || client.auth.currentUser?.id != authId) {
      throw const AsistenciaException('La sesión no es válida. Vuelve a iniciar sesión.');
    }
    final rows = await client.from('asignaciones_turno').update({
      'estado_asistencia': estado,
      'asistencia_marcada_por': admin.id!,
      'asistencia_marcada_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', asignacionId).eq('estado_asistencia', estadoAnterior).select('id');
    if (rows.isEmpty) {
      throw const AsistenciaException(
        'La asistencia cambió o ya no está disponible. Revisa el estado actualizado antes de marcarla.',
        recargar: true,
      );
    }
  }
  Future<List<AsignacionTurno>> listarAsignaciones() async {
    final rows = await client.from('asignaciones_turno').select(
      'id, turno_id, personal_id, rol_en_turno, observaciones, estado_asistencia, '
      'turnos(id, fecha, tipo, hora_inicio, hora_fin, area, estado), '
      'personal(id, codigo, nombre, apellido, tipo_personal, estado, especialidad_id, especialidades(nombre))',
    ).order('created_at', ascending: false);
    return rows.map(AsignacionTurno.fromMap).toList();
  }

  Future<List<Turno>> turnosParaAsignacion() async {
    final rows = await client.from('turnos')
        .select('id, fecha, tipo, hora_inicio, hora_fin, area, estado')
        .neq('estado', 'cancelado').order('fecha').order('hora_inicio');
    return rows.map(Turno.fromMap).toList();
  }

  Future<List<Personal>> personalParaAsignacion() async {
    final rows = await client.from('personal')
        .select('id, codigo, nombre, apellido, tipo_personal, estado, especialidad_id, especialidades(nombre)')
        .eq('estado', 'activo').order('apellido').order('nombre');
    return rows.map(Personal.fromMap).toList();
  }

  Future<void> guardarAsignacion({String? id, required String turnoId, required String personalId, required String observaciones}) async {
    final anterior = id == null ? null : await client.from('asignaciones_turno')
        .select('turno_id, personal_id').eq('id', id).single();
    // Volver a leer el tipo real evita guardar un rol desactualizado del selector.
    final persona = await client.from('personal').select('tipo_personal, estado')
        .eq('id', personalId).maybeSingle();
    if (persona == null || (persona['estado'] != 'activo' && anterior?['personal_id'] != personalId)) {
      throw const AsignacionException('Selecciona un personal activo. Recarga las opciones.');
    }
    final rol = persona['tipo_personal'];
    if (!['medico', 'enfermero', 'pasante'].contains(rol)) {
      throw const AsignacionException('El tipo del personal seleccionado no es válido.');
    }
    final turno = await client.from('turnos').select('estado').eq('id', turnoId).maybeSingle();
    if (turno == null || (turno['estado'] == 'cancelado' && anterior?['turno_id'] != turnoId)) {
      throw const AsignacionException('El turno seleccionado no está disponible. Recarga las opciones.');
    }
    // El trigger BEFORE puede detectar solapamiento antes de que se evalúe UNIQUE.
    // Consultar el par exacto permite distinguir duplicidad de otro turno solapado.
    if (await _asignacionDuplicada(turnoId, personalId, id)) {
      throw const AsignacionException('Este personal ya está asignado al turno seleccionado.');
    }
    final values = {'rol_en_turno': rol, 'observaciones': observaciones.trim()};
    try {
      if (id == null) {
        await client.from('asignaciones_turno').insert({
          ...values, 'turno_id': turnoId, 'personal_id': personalId,
        }).select('id').single();
      } else {
        // Enviar las FK cuando cambian activa la validación del trigger existente.
        if (anterior!['turno_id'] != turnoId) values['turno_id'] = turnoId;
        if (anterior['personal_id'] != personalId) values['personal_id'] = personalId;
        await client.from('asignaciones_turno').update(values).eq('id', id).select('id').single();
      }
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('solap')) {
        // Una asignación simultánea al mismo turno puede haberse creado tras la consulta.
        var duplicada = false;
        try {
          duplicada = await _asignacionDuplicada(turnoId, personalId, id);
        } catch (_) {
          // Conservar el error original si no se puede verificar el par exacto.
        }
        if (duplicada) {
          throw const AsignacionException('Este personal ya está asignado al turno seleccionado.');
        }
      }
      rethrow;
    }
  }

  Future<bool> _asignacionDuplicada(String turnoId, String personalId, String? excluirId) async {
    var query = client.from('asignaciones_turno').select('id')
        .eq('turno_id', turnoId).eq('personal_id', personalId);
    if (excluirId != null) query = query.neq('id', excluirId);
    return await query.maybeSingle() != null;
  }
  Future<List<Personal>> listarPersonal() async {
    final rows = await client.from('personal').select(
      'id, codigo, nombre, apellido, ci, sexo, telefono, tipo_personal, estado, especialidad_id, especialidades(nombre)',
    ).order('nombre').order('apellido');
    return rows.map(Personal.fromMap).toList();
  }

  Future<List<Especialidad>> especialidadesParaPersonal({String? actualId}) async {
    var query = client.from('especialidades').select('id, nombre, descripcion, estado');
    query = actualId == null
        ? query.eq('estado', 'activo')
        : query.or('estado.eq.activo,id.eq.$actualId');
    final rows = await query.order('nombre');
    return rows.map(Especialidad.fromMap).toList();
  }

  Future<void> crearPersonal(Personal personal, {required String email, required String password}) async {
    final body = {...personal.toMap(), 'email': email.trim().toLowerCase(), 'password': password};
    try {
      final response = await client.functions.invoke('crear-personal', body: body);
      final data = response.data;
      if (response.status < 200 || response.status >= 300 ||
          (data is Map && (data['error'] != null || data['success'] == false))) {
        throw PersonalOperationException(mensajeErrorAltaPersonal(response.status, data));
      }
    } on FunctionException catch (error) {
      throw PersonalOperationException(mensajeErrorAltaPersonal(error.status, error.details));
    } on PersonalOperationException {
      rethrow;
    } catch (_) {
      throw const PersonalOperationException('No se pudo registrar el personal.');
    } finally {
      // No conservar credenciales en estructuras del repositorio.
      body.clear();
      password = '';
      email = '';
    }
  }

  Future<void> actualizarPersonal(Personal personal) async {
    if (personal.id == null) throw const PersonalOperationException('No se pudo identificar el personal.');
    await client.from('personal').update(personal.toMap())
        .eq('id', personal.id!).select('id').single();
  }

  Future<void> darDeBajaPersonal(String id) async {
    await client.from('personal').update({'estado': 'inactivo'})
        .eq('id', id).select('id').single();
  }
  Future<List<Especialidad>> listarEspecialidades() async {
    final rows = await client.from('especialidades')
        .select('id, nombre, descripcion, estado').order('nombre');
    return rows.map(Especialidad.fromMap).toList();
  }

  Future<void> guardarEspecialidad(Especialidad especialidad) async {
    final nombre = especialidad.nombre.trim();
    if (nombre.length < 2 || nombre.length > 100 ||
        !['activo', 'inactivo'].contains(especialidad.estado)) {
      throw ArgumentError('Los datos de la especialidad no son válidos.');
    }
    final values = {
      'nombre': nombre,
      'descripcion': especialidad.descripcion?.trim() ?? '',
      'estado': especialidad.estado,
    };
    if (especialidad.id == null) {
      await client.from('especialidades').insert(values).select('id').single();
    } else {
      await client.from('especialidades').update(values)
          .eq('id', especialidad.id!).select('id').single();
    }
  }

  Future<void> darDeBajaEspecialidad(String id) async {
    await client.from('especialidades').update({'estado': 'inactivo'})
        .eq('id', id).select('id').single();
  }
  Future<Administrador?> administradorActual() async {
    final id = client.auth.currentUser?.id;
    if (id == null) return null;
    final row = await client.from('administradores').select().eq('user_id', id).eq('estado', 'activo').maybeSingle();
    return row == null ? null : Administrador.fromMap(row);
  }
  Future<List<Json>> list(String table, {String order = 'created_at', bool ascending = false}) async => List<Json>.from(await client.from(table).select().order(order, ascending: ascending));
  Future<List<Turno>> listarTurnos() async {
    final rows = List<Json>.from(await client
        .from('turnos')
        .select()
        .order('fecha', ascending: true)
        .order('hora_inicio', ascending: true));
    return rows.map(Turno.fromMap).toList();
  }
  Future<void> guardarTurno(Turno turno) async {
    final row = turno.id == null
        ? await insert('turnos', turno.toMap())
        : await update('turnos', turno.id!, turno.toMap());
    await audit(action: turno.id == null ? 'INSERT' : 'UPDATE', table: 'turnos', recordId: row['id'].toString(), description: turno.id == null ? 'Creó un turno' : 'Actualizó un turno');
  }
  Future<void> cancelarTurno(String id) async {
    final row = await update('turnos', id, {'estado': 'cancelado'});
    await audit(action: 'UPDATE', table: 'turnos', recordId: row['id'].toString(), description: 'Canceló un turno');
  }
  Future<int> count(String table, {String? column, Object? value}) async {
    var query = client.from(table).select();
    if (column != null && value != null) query = query.eq(column, value);
    final response = await query.count(CountOption.exact);
    return response.count;
  }
  Future<Json> insert(String table, Json values) async => await client.from(table).insert(await _trace(values, true)).select().single();
  Future<Json> update(String table, String id, Json values) async => await client.from(table).update(await _trace(values, false)).eq('id', id).select().single();
  Future<void> audit({required String action, required String table, required String recordId, String? description}) async { final admin = await administradorActual(); if (admin == null) return; try { await client.from('auditoria').insert(Auditoria(administradorId: admin.id, accion: action, tabla: table, registroId: recordId, descripcion: description).toMap()); } catch (_) {} }
  Future<Json> _trace(Json values, bool creating) async { final admin = await administradorActual(); final result = Json.from(values)..removeWhere((k,v) => v == null); if (admin != null) result[creating ? 'created_by' : 'updated_by'] = admin.id; return result; }
}
