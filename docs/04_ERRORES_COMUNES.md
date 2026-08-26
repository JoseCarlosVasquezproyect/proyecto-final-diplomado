# Errores comunes y respuesta corta

## La app abre en MODO DEMO
Estás ejecutando `config/demo.json` o no pasaste el archivo de configuración.

## Supabase no inicia
Revisa URL, clave y comando `--dart-define-from-file=config/local.json`.

## Registro creado pero no aparece
Pulsa refrescar. Si persiste, revisa la sesión y las políticas RLS.

## `new row violates row-level security policy`
El usuario no está autenticado o la política/`user_id` no coincide.

## Registro/login pide confirmar correo
La confirmación de email está activa. Para aula, el docente puede desactivarla temporalmente o usar cuentas precreadas.

## `flutter pub get` falla
Primero `flutter --version` y `flutter doctor`. No empieces a cambiar versiones al azar.

## Un estudiante rompió el código
Volver al checkpoint anterior y continuar. El error se estudia después del bloque.
