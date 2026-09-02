# Gestion Hospitalaria

## Descripción del proyecto

Gestion Hospitalaria es una aplicación multiplataforma para administrar información del personal hospitalario. Centraliza el registro y consulta de médicos, enfermeros y pasantes, además de sus especialidades, turnos y emergencias.

Puede ejecutarse en modo demostración o conectarse a Supabase para usar autenticación y datos persistentes.

## Problema u objetivo de la aplicación

La administración manual o dispersa del personal dificulta conocer quién integra el equipo, cuál es su especialidad y qué turnos o emergencias están registrados. El sistema busca facilitar la gestión de médicos, enfermeros, pasantes, turnos y situaciones de emergencia, organizando la información para administradores autorizados.

## Funcionalidades implementadas

Las siguientes funciones se verifican directamente en el código actual:

- Autenticación con correo y contraseña mediante Supabase: inicio de sesión, registro de cuenta y cierre de sesión.
- Control de acceso: la cuenta autenticada debe corresponder a un administrador activo para acceder a los módulos administrativos.
- Gestión de médicos: alta, consulta de detalle, edición y cambio de estado; incluye datos personales, especialidad y matrícula profesional.
- Gestión de enfermeros: alta, consulta de detalle, edición y cambio de estado; incluye datos personales, especialidad y código de enfermero.
- Gestión de pasantes: alta, consulta de detalle, edición y cambio de estado; incluye universidad, carrera, área de práctica, fechas y supervisor médico opcional.
- Gestión de especialidades: creación, edición, consulta, búsqueda y activación o desactivación.
- Gestión de turnos: creación, edición, consulta, búsqueda y cambio de estado; incluye fecha, horarios, área, tipo y observaciones.
- Gestión de emergencias: creación, edición, consulta, búsqueda y cambio de estado; incluye código, fecha, hora, área, tipo, prioridad y descripción.
- Consulta de días y horarios de trabajo asociados al personal.
- Registro de auditoría de altas y modificaciones realizadas por administradores en Supabase.
- Validación de campos obligatorios y mensajes de carga o error en formularios.

## Tecnologías utilizadas

- Flutter y Dart.
- Provider para estado e inyección de dependencias.
- Supabase Flutter para autenticación y acceso a datos.
- PostgreSQL, provisto por Supabase.
- SharedPreferences para preferencias locales.
- Android, Gradle y Kotlin para compilación móvil.
- Soporte Flutter para web, Windows y Linux.
- Git/GitHub para control de versiones y alojamiento.

## Requisitos para ejecutar el proyecto

- Flutter SDK compatible con Dart `>=3.4.0 <4.0.0`, según `pubspec.yaml`. Compruebe el entorno con `flutter doctor`.
- Para web: un navegador compatible, por ejemplo Google Chrome.
- Para Android: Android Studio, Android SDK y un emulador o dispositivo físico con depuración USB. El mínimo configurado es Android API 24 (`minSdk = 24`).
- Java 17, requerido por la configuración Android.
- Git, si se obtendrá el código desde GitHub.
- Un proyecto Supabase solo para ejecutar el modo conectado a datos reales.

## Instalación y ejecución

### 1. Obtener el proyecto

```powershell
git clone https://github.com/JoseCarlosVasquezproyect/modulo-3.git
Set-Location modulo-3
```

Si ya cuenta con el código, abra una terminal en la raíz, donde se encuentra `pubspec.yaml`.

### 2. Instalar dependencias

```powershell
flutter pub get
```

### 3. Ejecutar en modo demostración

```powershell
flutter run --dart-define-from-file=config/demo.json
```

### 4. Ejecutar con Supabase

Complete primero la [Configuración de Supabase](#configuración-de-supabase) y luego ejecute:

```powershell
flutter run --dart-define-from-file=config/local.json
```

### 5. Ejecutar en Android

Con un emulador iniciado o un dispositivo conectado:

```powershell
flutter devices
flutter run -d <ID_DEL_DISPOSITIVO> --dart-define-from-file=config/local.json
```

Para el modo demostración, sustituya `config/local.json` por `config/demo.json`.

### 6. Ejecutar en web

La plataforma web está disponible en el repositorio. Con Chrome instalado:

```powershell
flutter run -d chrome --dart-define-from-file=config/local.json
```

También puede usar `config/demo.json` para iniciar en modo demostración.

## Configuración de Supabase

1. Cree un proyecto en Supabase.
2. Ejecute `supabase/01_schema_y_rls.sql` en el SQL Editor de Supabase. El script crea la estructura de datos y las políticas de acceso.
3. Cree la configuración local a partir del ejemplo:

   ```powershell
   Copy-Item config/local.example.json config/local.json
   ```

4. Edite solo `config/local.json`: complete `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` con los valores públicos de su proyecto y mantenga `DEMO_MODE` en `false`.
5. Cree una cuenta desde la pantalla de acceso o Supabase Auth y asegúrese de que tenga un registro activo en la tabla `administradores`, ya que el acceso administrativo depende de esa condición.

No incluya contraseñas, tokens, claves privadas ni la clave `service_role` en la aplicación. `config/local.json` es configuración local sensible y no debe subirse al repositorio.

## Estructura general del proyecto

| Ruta | Contenido |
| --- | --- |
| `lib/` | Código fuente principal de Flutter. |
| `lib/screens/` | Pantallas de acceso, autorización, inicio y módulos de gestión. |
| `lib/models/` | Modelos de administradores, personal, especialidades, turnos y emergencias. |
| `lib/controllers/` | Controladores para datos y preferencias. |
| `lib/repositories/` | Acceso a Supabase y repositorios de demostración. |
| `lib/services/` | Servicios de autenticación y preferencias locales. |
| `lib/config/` | Lectura de configuración enviada con `--dart-define`. |
| `supabase/` | Script SQL del esquema y políticas RLS. |
| `config/` | Configuración de ejemplo y demostración; `local.json` se crea localmente. |
| `android/` | Configuración y código nativo Android. |
| `web/` | Archivos de soporte de la versión web. |
| `windows/` y `linux/` | Archivos de soporte para escritorio. |
| `test/` | Pruebas automatizadas. |
| `iconos/` | Recursos gráficos de la aplicación. |
| `scripts/` | Scripts de verificación, demostración y preparación. |
| `docs/` | Documentación complementaria. |
| `pubspec.yaml` | Metadatos, restricciones de Dart y dependencias. |

## Generación del APK

Desde la raíz, para generar el APK release conectado a Supabase ejecute:

```powershell
flutter build apk --release --dart-define-from-file=config/local.json
```

El APK se genera en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Una compilación release firmada requiere la configuración privada de firma Android: `android/key.properties` y el keystore indicado allí. Use `android/key.properties.example` únicamente como referencia. No incluya contraseñas, el keystore ni `android/key.properties` en el repositorio. La configuración de Gradle impide la compilación release si falta `android/key.properties`.

## Versión entregada

La versión actual configurada en `pubspec.yaml` es **1.0.0+1**.

## Limitaciones conocidas

- El esquema de Supabase define asignaciones de turnos y equipos de emergencia, pero la interfaz actual no incluye pantallas ni acciones para administrar esas asignaciones o equipos.
- Los módulos de gestión implementan cambios de estado; no ofrecen eliminación física de registros.
- La operación completa de los módulos administrativos requiere Supabase configurado, una sesión iniciada y un administrador activo. El modo demostración no sustituye esa configuración para la gestión persistente.

## Autor

**Jose Carlos Vásquez Yurquina**
