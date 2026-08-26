import '../models/registro.dart';

abstract class RegistroRepository {
  Future<List<Registro>> fetchAll();
  Future<void> create(Registro registro);
  Future<void> update(Registro registro);
  Future<void> delete(String id);
}
