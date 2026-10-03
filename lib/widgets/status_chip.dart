import 'package:flutter/material.dart';

/// Presentation only: the original state and label are supplied by the screen.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'activo' || 'cumplido' => const Color(0xFF28734D),
      'pendiente' || 'suspendido' || 'en_curso' => const Color(0xFF8A620F),
      'inactivo' || 'falta' || 'error' => const Color(0xFFB04444),
      'programado' => const Color(0xFF25638A),
      _ => const Color(0xFF626D79),
    };
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Chip(
      label: Text(label),
      avatar: Icon(Icons.circle,
          size: 8, color: dark ? Color.lerp(color, Colors.white, 0.5) : color),
      backgroundColor: Color.alphaBlend(
          color.withValues(alpha: dark ? 0.22 : 0.10),
          Theme.of(context).colorScheme.surface),
      labelStyle: TextStyle(
          color: dark ? Color.lerp(color, Colors.white, 0.5) : color,
          fontSize: 13,
          fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
