import '../models/registro.dart';
import 'registro_repository.dart';

class DemoRegistroRepository implements RegistroRepository {
  final List<Registro> _items = [
    Registro(
      id: 'demo-1',
      titulo: 'Registro de ejemplo',
      descripcion: 'Este dato vive solo en memoria. Sirve para levantar la app sin Internet.',
      estado: 'activo',
      createdAt: DateTime.now(),
    ),
  ];

  Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<List<Registro>> fetchAll() async {
    await _wait();
    return List.unmodifiable(_items);
  }

  @override
  Future<void> create(Registro registro) async {
    await _wait();
    _items.insert(
      0,
      registro.copyWith(
        id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> update(Registro registro) async {
    await _wait();
    final index = _items.indexWhere((e) => e.id == registro.id);
    if (index == -1) throw StateError('Registro demo no encontrado');
    _items[index] = registro;
  }

  @override
  Future<void> delete(String id) async {
    await _wait();
    _items.removeWhere((e) => e.id == id);
  }
}
