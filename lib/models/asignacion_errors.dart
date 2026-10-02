import 'package:supabase_flutter/supabase_flutter.dart';

class AsignacionException implements Exception {
  const AsignacionException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

String mensajeErrorAsignacion(Object error) {
  if (error is AsignacionException) return error.mensaje;
  if (error is AuthException) return 'La sesión no es válida. Vuelve a iniciar sesión.';
  if (error is PostgrestException) {
    if (error.message.toLowerCase().contains('solap')) {
      return 'El personal ya tiene otro turno que se solapa con el horario seleccionado.';
    }
    if (error.code == '23505') {
      return 'Este personal ya está asignado al turno seleccionado.';
    }
    if (error.code == '42501') {
      return 'No tienes permisos para realizar esta operación.';
    }
    if (error.code == '23503' || error.code == 'PGRST116') {
      return 'El turno, el personal o la asignación ya no están disponibles. Recarga los datos.';
    }
    if (error.code == '23514') {
      return 'Los datos de la asignación no cumplen las reglas permitidas.';
    }
  }
  return 'No se pudo completar la operación de asignaciones. Revisa tu conexión e inténtalo nuevamente.';
}
