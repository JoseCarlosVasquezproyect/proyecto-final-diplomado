class Registro {
  const Registro({
    this.id,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    this.createdAt,
  });

  final String? id;
  final String titulo;
  final String descripcion;
  final String estado;
  final DateTime? createdAt;

  factory Registro.fromMap(Map<String, dynamic> map) {
    return Registro(
      id: map['id']?.toString(),
      titulo: (map['titulo'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      estado: (map['estado'] ?? 'activo').toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toInsertMap(String userId) => {
        'user_id': userId,
        'titulo': titulo.trim(),
        'descripcion': descripcion.trim(),
        'estado': estado,
      };

  Map<String, dynamic> toUpdateMap() => {
        'titulo': titulo.trim(),
        'descripcion': descripcion.trim(),
        'estado': estado,
      };

  Registro copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    String? estado,
    DateTime? createdAt,
  }) {
    return Registro(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
