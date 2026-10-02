import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gestion_models.dart';
import '../models/personal_errors.dart';

class GestionRepository {
  GestionRepository(this.client);
  final SupabaseClient client;
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
