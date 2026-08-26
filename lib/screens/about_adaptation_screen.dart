import 'package:flutter/material.dart';

class AboutAdaptationScreen extends StatelessWidget {
  const AboutAdaptationScreen({super.key});

  static const items = [
    ('1. Problema', 'Define el problema real que resolverás.'),
    ('2. Entidad', 'Cambia Registro por Mascota, Reserva, Producto, Incidencia, etc.'),
    ('3. Campos', 'Sustituye título/descripción/estado por los datos reales.'),
    ('4. Reglas', 'Define qué se puede crear, editar, cerrar o eliminar.'),
    ('5. Pantallas', 'Renombra y ajusta las pantallas al flujo real.'),
    ('6. Base de datos', 'Crea tablas y restricciones propias del dominio.'),
    ('7. Validaciones', 'Valida lo que tenga sentido para tu problema.'),
    ('8. Evidencias', 'Guarda capturas y pruebas de cada hito.'),
    ('9. Identidad', 'Colores, textos y experiencia deben corresponder al proyecto.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adaptar a mi proyecto')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('La plantilla ayuda a empezar. La adaptación demuestra que el proyecto es tuyo.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            );
          }
          final item = items[index - 1];
          return ListTile(
            leading: CircleAvatar(child: Text('${index}')),
            title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item.$2),
          );
        },
      ),
    );
  }
}
