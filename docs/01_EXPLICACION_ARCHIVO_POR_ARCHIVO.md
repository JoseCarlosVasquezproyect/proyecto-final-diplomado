# Radiografía del proyecto

## Regla de lectura
No intentes memorizar carpetas. Sigue el recorrido de un dato.

`main.dart -> AppConfig -> App -> pantalla -> Repository -> Supabase -> Repository -> pantalla`

## Archivos clave
- `lib/main.dart`: arranque, configuración y dependencias.
- `lib/config/app_config.dart`: decide DEMO o SUPABASE.
- `lib/models/registro.dart`: representa una fila de la tabla.
- `lib/repositories/registro_repository.dart`: contrato CRUD.
- `lib/repositories/demo_registro_repository.dart`: plan B sin Internet.
- `lib/repositories/supabase_registro_repository.dart`: CRUD real.
- `lib/services/preferences_service.dart`: persistencia local simple.
- `lib/controllers/preferences_controller.dart`: estado global de preferencias.
- `lib/screens/auth_gate.dart`: decide login o home según la sesión.
- `lib/screens/login_screen.dart`: registro/login.
- `lib/screens/records_screen.dart`: READ y navegación al formulario.
- `lib/screens/record_form_screen.dart`: CREATE/UPDATE.
- `lib/screens/settings_screen.dart`: prueba de SharedPreferences.
- `supabase/01_schema_y_rls.sql`: tabla + seguridad por usuario.

## Qué NO tocar primero
No cambies nombres de carpetas, Gradle o AndroidManifest antes de comprobar que el proyecto corre.
Primero: correr. Luego: entender. Después: adaptar.
