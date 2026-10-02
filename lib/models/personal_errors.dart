import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalOperationException implements Exception {
  const PersonalOperationException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

String mensajeErrorAltaPersonal(int status, Object? data) {
  if (data is String) {
    try {
      data = jsonDecode(data);
    } catch (_) {
      data = null;
    }
  }
  final mensaje = data is Map ? data['error'] : null;
  if (status == 401) return 'La sesión no es válida. Vuelve a iniciar sesión.';
  if (status == 403) return 'No tienes permisos para crear personal.';
  if (status == 409) {
    final texto = mensaje is String ? mensaje.toLowerCase() : '';
    if (texto.contains('correo') ||
        texto.contains('email') ||
        texto.contains('account') ||
        texto.contains('user already')) {
      return 'Ya existe una cuenta registrada con ese correo.';
    }
    return 'Ya existe un personal con ese código o CI.';
  }
  // Solo mostrar mensajes públicos reconocidos; nunca respuestas internas arbitrarias.
  const seguros = {
    'Ya existe una cuenta registrada con ese correo.',
    'Ya existe un personal con ese código o CI.',
    'El correo no es válido.',
    'La contraseña debe tener al menos 10 caracteres.',
    'La especialidad seleccionada no está disponible.',
    'Los datos del personal no son válidos.',
  };
  if (mensaje is String && seguros.contains(mensaje)) return mensaje;
  return 'No se pudo registrar el personal.';
}

String mensajeErrorPersonal(Object error) {
  if (error is PersonalOperationException) return error.mensaje;
  if (error is FunctionException) {
    return mensajeErrorAltaPersonal(error.status, error.details);
  }
  if (error is AuthException) {
    return 'La sesión no es válida. Vuelve a iniciar sesión.';
  }
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return 'Ya existe un personal con ese código o CI.';
    }
    if (error.code == '42501') {
      return 'No tienes permisos para realizar esta operación.';
    }
    if (error.code == '23514') {
      return 'Revisa los datos y los valores seleccionados del personal.';
    }
    if (error.code == '23503') {
      return 'La especialidad seleccionada no está disponible. Recarga las opciones.';
    }
    if (error.code == 'PGRST116') {
      return 'El personal no está disponible. Recarga el listado.';
    }
  }
  return 'No se pudo completar la operación. Revisa tu conexión e inténtalo nuevamente.';
}
