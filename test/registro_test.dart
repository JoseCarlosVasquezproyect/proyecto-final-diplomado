import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_360/models/registro.dart';

void main() {
  test('Registro.fromMap convierte datos correctamente', () {
    final registro = Registro.fromMap({
      'id': 'abc',
      'titulo': 'Prueba',
      'descripcion': 'Dato',
      'estado': 'activo',
      'created_at': '2026-08-23T12:00:00Z',
    });
    expect(registro.id, 'abc');
    expect(registro.titulo, 'Prueba');
    expect(registro.estado, 'activo');
  });

  test('toUpdateMap no incluye id ni user_id', () {
    const registro = Registro(titulo: 'Prueba', descripcion: 'Dato', estado: 'activo');
    final map = registro.toUpdateMap();
    expect(map.containsKey('id'), isFalse);
    expect(map.containsKey('user_id'), isFalse);
  });
}
