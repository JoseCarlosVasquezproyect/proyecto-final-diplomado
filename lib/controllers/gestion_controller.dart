import 'package:flutter/foundation.dart';
import '../models/gestion_models.dart';
import '../repositories/gestion_repository.dart';

class GestionController extends ChangeNotifier {
  GestionController(this.repository);
  final GestionRepository repository;
  Future<List<AsignacionTurno>> listarAsignaciones() => repository.listarAsignaciones();
  Future<List<Turno>> turnosParaAsignacion() => repository.turnosParaAsignacion();
  Future<List<Personal>> personalParaAsignacion() => repository.personalParaAsignacion();
  Future<void> guardarAsignacion({String? id, required String turnoId, required String personalId, required String observaciones}) => repository.guardarAsignacion(id: id, turnoId: turnoId, personalId: personalId, observaciones: observaciones);
  Future<List<Personal>> listarPersonal() => repository.listarPersonal();
  Future<void> crearPersonal(Personal personal, {required String email, required String password}) => repository.crearPersonal(personal, email: email, password: password);
  Future<void> actualizarPersonal(Personal personal) => repository.actualizarPersonal(personal);
  Future<void> darDeBajaPersonal(String id) => repository.darDeBajaPersonal(id);
  Future<List<Especialidad>> especialidadesParaPersonal({String? actualId}) => repository.especialidadesParaPersonal(actualId: actualId);
  Future<List<Especialidad>> listarEspecialidades() => repository.listarEspecialidades();
  Future<void> guardarEspecialidad(Especialidad especialidad) => repository.guardarEspecialidad(especialidad);
  Future<void> darDeBajaEspecialidad(String id) => repository.darDeBajaEspecialidad(id);
  Administrador? administrador;
  Future<bool> verificarAdministrador() async { administrador = await repository.administradorActual(); notifyListeners(); return administrador != null; }
  Future<List<Json>> listar(String tabla, {String order = 'created_at'}) => repository.list(tabla, order: order);
  Future<List<Turno>> listarTurnos() => repository.listarTurnos();
  Future<void> guardarTurno(Turno turno) => repository.guardarTurno(turno);
  Future<void> cancelarTurno(String id) => repository.cancelarTurno(id);
  Future<int> contar(String tabla, {String? campo, Object? valor}) => repository.count(tabla, column: campo, value: valor);
  Future<void> guardar(String tabla, Json values, {String? id, String? descripcion}) async { final row = id == null ? await repository.insert(tabla, values) : await repository.update(tabla, id, values); await repository.audit(action: id == null ? 'INSERT' : 'UPDATE', table: tabla, recordId: row['id'].toString(), description: descripcion); }
}
