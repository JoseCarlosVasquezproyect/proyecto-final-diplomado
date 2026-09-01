import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gestion_models.dart';

class GestionRepository {
  GestionRepository(this.client);
  final SupabaseClient client;
  Future<Administrador?> administradorActual() async {
    final id = client.auth.currentUser?.id;
    if (id == null) return null;
    final row = await client.from('administradores').select().eq('user_id', id).eq('estado', 'activo').maybeSingle();
    return row == null ? null : Administrador.fromMap(row);
  }
  Future<List<Json>> list(String table, {String order = 'created_at', bool ascending = false}) async => List<Json>.from(await client.from(table).select().order(order, ascending: ascending));
  Future<int> count(String table, {String? column, Object? value}) async {
    var query = client.from(table).select();
    if (column != null && value != null) query = query.eq(column, value);
    final response = await query.count(CountOption.exact);
    return response.count;
  }
  Future<Json> insert(String table, Json values) async => await client.from(table).insert(await _trace(values, true)).select().single();
  Future<Json> update(String table, String id, Json values) async => await client.from(table).update(await _trace(values, false)).eq('id', id).select().single();
  /// Devuelve el personal junto con su tabla de detalle. El id expuesto es el
  /// de `personal`, que es el que se usa para estado y datos generales.
  Future<List<Json>> personalPorTipo(String tipo) async {
    final table = _tablaDetalle(tipo);
    // `pasantes` tiene dos referencias a personal. Se especifica la FK de
    // personal_id para no confundirla con supervisor_personal_id.
    final select = switch (tipo) {
      'pasante' => '*, personal!pasantes_personal_id_fkey(*), supervisor:personal!pasantes_supervisor_personal_id_fkey(nombre, apellido)',
      _ => '*, personal!inner(*), especialidades(*)',
    };
    final rows = List<Json>.from(await client
        .from(table)
        .select(select)
        .eq('personal.tipo_personal', tipo)
        .order('nombre', referencedTable: 'personal'));
    return rows.map((detail) {
      final personal = Json.from(detail['personal'] as Map);
      final result = Json.from(detail)
        ..remove('personal')
        ..remove('especialidades')
        ..remove('supervisor')
        ..['_detalle_id'] = detail['id']
        ..addAll(personal);
      final especialidad = detail['especialidades'];
      if (especialidad is Map) result['especialidad_nombre'] = especialidad['nombre'];
      final supervisor = detail['supervisor'];
      if (supervisor is Map) {
        result['supervisor_nombre'] = [supervisor['nombre'], supervisor['apellido']]
            .whereType<String>()
            .join(' ');
      }
      return result;
    }).toList();
  }
  Future<List<Json>> especialidades() async => List<Json>.from(await client.from('especialidades').select().eq('estado', 'activo').order('nombre'));
  Future<List<Json>> detallesPersonal(String tabla) async => List<Json>.from(await client.from(tabla).select());
  Future<void> crearPersonalConDetalle({required Json personal, required String tablaDetalle, required Json detalle, required String descripcion}) async {
    try {
      await _verificarEspecialidad(tablaDetalle, detalle['especialidad_id']);
      // El id de personal, no el id de auth.users, es la FK del detalle.
      final creado = await insert('personal', personal);
      await client.from(tablaDetalle).insert(_sinNulos({...detalle, 'personal_id': creado['id']})).select().single();
      await audit(action: 'INSERT', table: tablaDetalle, recordId: creado['id'].toString(), description: descripcion);
    } catch (error, stackTrace) {
      _registrarErrorSupabase(error, stackTrace);
      // No se borra el personal para no perder trazabilidad si el detalle falla.
      rethrow;
    }
  }
  Future<void> desactivarPersonal(String id, String descripcion) async {
    await cambiarEstadoPersonal(id, 'inactivo', descripcion);
  }
  Future<void> cambiarEstadoPersonal(String id, String estado, String descripcion) async {
    await update('personal', id, {'estado': estado});
    await audit(action: 'UPDATE', table: 'personal', recordId: id, description: descripcion);
  }
  Future<void> actualizarPersonalConDetalle({required String personalId, required String detalleId, required String tipo, required Json personal, required Json detalle, required String descripcion}) async {
    try {
      final tablaDetalle = _tablaDetalle(tipo);
      await _verificarEspecialidad(tablaDetalle, detalle['especialidad_id']);
      await update('personal', personalId, personal);
      await client.from(tablaDetalle).update(_sinNulos(detalle)).eq('id', detalleId).select().single();
      await audit(action: 'UPDATE', table: tablaDetalle, recordId: personalId, description: descripcion);
    } catch (error, stackTrace) {
      _registrarErrorSupabase(error, stackTrace);
      rethrow;
    }
  }
  Future<List<Json>> diasTrabajo(String personalId) async => List<Json>.from(await client.from('personal_dias_trabajo').select().eq('personal_id', personalId).order('dia_semana'));
  String _tablaDetalle(String tipo) => switch (tipo) { 'medico' => 'medicos', 'enfermero' => 'enfermeros', 'pasante' => 'pasantes', _ => throw ArgumentError('Tipo de personal no válido: $tipo') };
  Json _sinNulos(Json values) => Json.from(values)..removeWhere((key, value) => value == null);
  Future<void> _verificarEspecialidad(String tablaDetalle, Object? especialidadId) async {
    if (tablaDetalle != 'medicos' && tablaDetalle != 'enfermeros') return;
    if (especialidadId == null || especialidadId.toString().isEmpty) {
      throw ArgumentError('Debe seleccionarse una especialidad válida.');
    }
    final especialidad = await client.from('especialidades').select('id').eq('id', especialidadId).maybeSingle();
    if (especialidad == null) throw StateError('La especialidad seleccionada no existe.');
  }
  void _registrarErrorSupabase(Object error, StackTrace stackTrace) {
    if (error is PostgrestException) {
      debugPrint('Error Supabase: ${error.message}');
      debugPrint('Details: ${error.details}');
      debugPrint('Hint: ${error.hint}');
      debugPrint('Code: ${error.code}');
    } else {
      debugPrint('Error al guardar en Supabase: $error');
    }
    debugPrintStack(stackTrace: stackTrace);
  }
  Future<void> audit({required String action, required String table, required String recordId, String? description}) async { final admin = await administradorActual(); if (admin == null) return; try { await client.from('auditoria').insert(Auditoria(administradorId: admin.id, accion: action, tabla: table, registroId: recordId, descripcion: description).toMap()); } catch (_) {} }
  Future<Json> _trace(Json values, bool creating) async { final admin = await administradorActual(); final result = Json.from(values)..removeWhere((k,v) => v == null); if (admin != null) result[creating ? 'created_by' : 'updated_by'] = admin.id; return result; }
}
