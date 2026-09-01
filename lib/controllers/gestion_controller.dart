import 'package:flutter/foundation.dart';
import '../models/gestion_models.dart';
import '../repositories/gestion_repository.dart';

class GestionController extends ChangeNotifier {
  GestionController(this.repository);
  final GestionRepository repository;
  Administrador? administrador;
  Future<bool> verificarAdministrador() async { administrador = await repository.administradorActual(); notifyListeners(); return administrador != null; }
  Future<List<Json>> listar(String tabla, {String order = 'created_at'}) => repository.list(tabla, order: order);
  Future<int> contar(String tabla, {String? campo, Object? valor}) => repository.count(tabla, column: campo, value: valor);
  Future<void> guardar(String tabla, Json values, {String? id, String? descripcion}) async { final row = id == null ? await repository.insert(tabla, values) : await repository.update(tabla, id, values); await repository.audit(action: id == null ? 'INSERT' : 'UPDATE', table: tabla, recordId: row['id'].toString(), description: descripcion); }
}
