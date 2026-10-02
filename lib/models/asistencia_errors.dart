import 'package:supabase_flutter/supabase_flutter.dart';

class AsistenciaException implements Exception {
  const AsistenciaException(this.mensaje, {this.recargar = false});
  final String mensaje;
  final bool recargar;
  @override
  String toString() => mensaje;
}

String mensajeErrorAsistencia(Object error) {
  if (error is AsistenciaException) return error.mensaje;
  if (error is AuthException) return 'La sesión no es válida. Vuelve a iniciar sesión.';
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'No tienes permisos para controlar asistencia.';
    }
    if (error.code == '23503' || error.code == 'PGRST116') {
      return 'La asignación o el administrador ya no están disponibles. Recarga los datos.';
    }
    if (error.code == '23514') {
      return 'El estado de asistencia seleccionado no es válido.';
    }
  }
  return 'No se pudo completar la operación de asistencia. Revisa tu conexión e inténtalo nuevamente.';
}
