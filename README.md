# Gestión Hospitalaria

**Desarrollo de una aplicación multiplataforma para la gestión y asignación de turnos de doctores, enfermeros y pasantes**

## 1. Descripción del proyecto

Gestión Hospitalaria es una aplicación multiplataforma desarrollada con Flutter y Supabase, orientada a facilitar la administración del personal en el ámbito hospitalario.

El sistema permite gestionar la información de médicos, enfermeros y pasantes, sus especialidades, los turnos de trabajo y los registros de emergencias. Cuenta con control de acceso según el rol del usuario, de manera que los administradores pueden gestionar la información y el personal puede consultar sus datos y los turnos que tiene asignados.

La aplicación puede ejecutarse en modo demostración o conectarse a Supabase para trabajar con autenticación y datos persistentes.

## 2. Objetivo del sistema

Facilitar la gestión y asignación de turnos del personal hospitalario mediante una aplicación multiplataforma que centraliza la información, reduce la dependencia de registros físicos y permite consultar los datos de manera organizada.

## 3. Pantallas y funcionalidades implementadas

### 3.1. Pantalla de inicio de sesión

- Inicio de sesión mediante correo electrónico y contraseña.
- Acceso mediante Supabase Auth en el modo conectado.
- Validación de credenciales y visualización de mensajes de error.
- Acceso según el rol y los permisos de la cuenta.

### 3.2. Panel del administrador

El administrador dispone de las funciones de gestión del sistema:

- **Gestión de médicos:** registro, consulta, edición y cambio de estado.
- **Gestión de enfermeros:** registro, consulta, edición y cambio de estado.
- **Gestión de pasantes:** registro, consulta, edición y cambio de estado.
- **Gestión de especialidades:** creación, edición, búsqueda y activación o desactivación.
- **Gestión de turnos:** registro, consulta, edición, búsqueda y cambio de estado.
- **Gestión de emergencias:** registro, consulta, edición, búsqueda y cambio de estado.
- **Consulta de información del personal:** datos personales y días u horarios de trabajo disponibles en el sistema.
- **Auditoría:** registro de altas y modificaciones realizadas por administradores en Supabase.

### 3.3. Panel del personal

El personal dispone de una interfaz orientada a la consulta de su información y sus actividades laborales.

- Consulta de sus datos personales.
- Visualización de la información laboral disponible.
- Consulta de turnos asignados, según los datos disponibles.
- Acceso restringido de acuerdo con los permisos de su cuenta.

El personal no dispone de los permisos administrativos para gestionar los registros generales del sistema.

### 3.4. Validaciones y seguridad

- Validación de campos obligatorios en los formularios.
- Control de acceso según los roles de administrador y personal.
- Autenticación mediante Supabase Auth.
- Protección de datos mediante políticas de seguridad de nivel de fila (RLS) en Supabase.
- Registro de auditoría de determinadas operaciones administrativas.

## 4. Tecnologías utilizadas

| Tecnología | Utilidad |
|---|---|
| Flutter | Desarrollo de la interfaz multiplataforma. |
| Dart | Lenguaje de programación de la aplicación. |
| Provider | Gestión del estado e inyección de dependencias. |
| Supabase Auth | Autenticación de usuarios. |
| Supabase / PostgreSQL | Almacenamiento y gestión de datos. |
| PostgREST | Acceso a los datos mediante la API de Supabase. |
| SharedPreferences | Almacenamiento de preferencias locales. |
| Android SDK, Gradle y Kotlin | Configuración y compilación de la aplicación Android. |
| Git y GitHub | Control de versiones y alojamiento del código fuente. |
| Render | Despliegue de la versión web, según la configuración del proyecto. |

## 5. Requisitos para instalar el proyecto en otra computadora

Antes de ejecutar el sistema, se deben instalar las herramientas necesarias.

### 5.1. Requisitos de software

- **Sistema operativo:** Windows 10 o superior, u otro sistema compatible con Flutter.
- **Git:** para descargar el repositorio desde GitHub.
- **Flutter SDK:** se recomienda utilizar Flutter 3.44.8 para mantener el entorno de desarrollo utilizado en el proyecto.
- **Dart:** se incluye con Flutter.
- **Google Chrome:** para ejecutar la versión web durante el desarrollo.
- **Android Studio y Android SDK:** necesarios para compilar o ejecutar la aplicación Android.
- **Java 17:** para la compilación Android, de acuerdo con la configuración del proyecto.
- **Conexión a Internet:** necesaria para descargar las dependencias y conectarse a Supabase.

Si únicamente se necesita ejecutar la versión web ya desplegada, no es necesario instalar Flutter ni Android Studio en la computadora del usuario final.

### 5.2. Comprobar la instalación de Flutter

Una vez instalado Flutter, abra PowerShell o una terminal y ejecute:

```powershell
flutter --version
flutter doctor
git --version
```

Si los comandos funcionan correctamente, continúe con la instalación del proyecto.

## 6. Instalación y ejecución del proyecto

### 6.1. Descargar el código fuente

Abra PowerShell y ejecute:

```powershell
git clone https://github.com/JoseCarlosVasquezproyect/proyecto-final-diplomado.git
cd proyecto-final-diplomado
```

Si el repositorio es privado, deberá contar con los permisos correspondientes para acceder.

También puede descargar el código como archivo ZIP desde GitHub, extraerlo y abrir una terminal dentro de la carpeta del proyecto.

### 6.2. Descargar las dependencias

Dentro de la carpeta raíz del proyecto, donde se encuentra el archivo `pubspec.yaml`, ejecute:

```powershell
flutter pub get
```

Este comando descarga las dependencias de Flutter declaradas en el proyecto.

Para comprobar que el entorno está preparado, puede ejecutar:

```powershell
flutter doctor
flutter analyze
```

La ejecución de `flutter analyze` es opcional y sirve para revisar el código fuente.

### 6.3. Ejecutar en modo demostración

Si se desea probar el sistema sin configurar una conexión propia a Supabase, utilice:

```powershell
flutter run --dart-define-from-file=config/demo.json
```

Este modo requiere que el archivo `config/demo.json` esté disponible en el proyecto. Los datos de demostración no deben confundirse con los registros persistentes de una base de datos real.

### 6.4. Configurar Supabase para trabajar con datos reales

Para utilizar el sistema con una base de datos propia, siga estos pasos:

1. Cree o utilice un proyecto en Supabase.
2. Abra el SQL Editor de Supabase.
3. Ejecute el script `supabase/01_schema_y_rls.sql` para crear la estructura y las políticas incluidas en ese archivo.
4. Compruebe si el proyecto requiere ejecutar migraciones adicionales o configurar funciones de Supabase para completar las funcionalidades utilizadas.
5. Cree el archivo local de configuración a partir del ejemplo disponible.

En PowerShell, ejecute:

```powershell
Copy-Item config/local.example.json config/local.json
```

Abra `config/local.json` y complete los valores de configuración correspondientes:

```json
{
  "DEMO_MODE": false,
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "TU_CLAVE_PUBLICA"
}
```

Sustituya los valores de ejemplo por la URL y la clave pública correspondientes al proyecto de Supabase.

**Importante:** el archivo `config/local.json` es una configuración local y no debe subirse al repositorio. Nunca incluya la clave `service_role`, contraseñas ni otras credenciales privadas en el código de la aplicación.

### 6.5. Configurar una cuenta de acceso

Para entrar en el sistema conectado a Supabase:

1. Configure la autenticación de Supabase.
2. Cree o habilite una cuenta de usuario.
3. Para acceder al panel administrativo, compruebe que la cuenta tenga el registro de administrador activo que exige el sistema.
4. Para acceder al panel del personal, configure el registro de personal y su relación con la cuenta de autenticación según el modelo de datos utilizado.

Cada computadora puede ejecutar la aplicación, pero los usuarios deben disponer de cuentas autorizadas y de acceso a la misma configuración de Supabase para consultar los mismos datos.

### 6.6. Ejecutar en la web

Con la configuración de Supabase preparada, ejecute:

```powershell
flutter run -d chrome --dart-define-from-file=config/local.json
```

Para el modo demostración:

```powershell
flutter run -d chrome --dart-define-from-file=config/demo.json
```

Flutter abrirá la aplicación en Google Chrome.

### 6.7. Ejecutar en Android

Conecte un dispositivo Android con la depuración USB habilitada o inicie un emulador desde Android Studio.

Compruebe los dispositivos disponibles:

```powershell
flutter devices
```

Ejecute la aplicación, sustituyendo `ID_DEL_DISPOSITIVO` por el identificador correspondiente:

```powershell
flutter run -d ID_DEL_DISPOSITIVO --dart-define-from-file=config/local.json
```

Para ejecutar en modo demostración, sustituya `config/local.json` por `config/demo.json`.

## 7. Ejecutar el sistema sin instalar Flutter

Si el objetivo es permitir que otras personas utilicen el sistema sin instalar herramientas de desarrollo, existen dos alternativas.

### 7.1. Acceso mediante la versión web

Si la versión web está desplegada y disponible públicamente, basta con compartir su URL.

Los usuarios podrán abrirla desde un navegador compatible sin descargar el código fuente ni instalar las dependencias de Flutter.

Para utilizar los datos reales, la versión desplegada debe estar configurada con el proyecto de Supabase correspondiente y contar con las políticas de acceso adecuadas.

**URL de la aplicación:** añadir aquí la dirección pública de Render cuando corresponda.

### 7.2. Instalación mediante APK en Android

También se puede compartir el archivo APK de la aplicación Android.

El usuario deberá instalarlo en un dispositivo compatible, autorizando la instalación de aplicaciones de esa procedencia cuando sea necesario.

El APK debe haberse compilado con la configuración adecuada para conectarse al proyecto de Supabase. No es necesario instalar Flutter en el teléfono.

## 8. Generación de la aplicación Android (APK)

Para generar el APK de producción desde la raíz del proyecto, ejecute:

```powershell
flutter build apk --release --dart-define-from-file=config/local.json
```

El archivo generado se encontrará en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

La compilación de producción requiere que la configuración de Supabase esté preparada. Si el proyecto exige firma de lanzamiento, también será necesario disponer de los archivos privados de firma Android configurados en Gradle.

No se deben compartir ni subir al repositorio las contraseñas, el keystore privado ni el archivo `android/key.properties`.

## 9. Estructura general del proyecto

| Ruta | Descripción |
|---|---|
| `lib/` | Código fuente principal de Flutter. |
| `lib/screens/` | Pantallas de acceso, paneles y módulos de gestión. |
| `lib/models/` | Modelos de datos. |
| `lib/controllers/` | Controladores de datos y preferencias. |
| `lib/repositories/` | Acceso a datos y repositorios de demostración. |
| `lib/services/` | Servicios de autenticación y preferencias locales. |
| `lib/config/` | Lectura de la configuración de la aplicación. |
| `supabase/` | Scripts SQL del esquema y las políticas de seguridad. |
| `config/` | Archivos de ejemplo y configuración para demostración. |
| `android/` | Configuración y código nativo Android. |
| `web/` | Archivos de soporte para la versión web. |
| `windows/` y `linux/` | Archivos de soporte para escritorio. |
| `test/` | Pruebas automatizadas. |
| `iconos/` | Recursos gráficos de la aplicación. |
| `scripts/` | Scripts de verificación y preparación. |
| `docs/` | Documentación complementaria. |
| `pubspec.yaml` | Metadatos y dependencias de Flutter. |

## 10. Limitaciones conocidas

- La disponibilidad de funciones depende de la configuración de Supabase, los permisos de la cuenta y los datos registrados.
- El esquema de datos contempla asignaciones de turnos y equipos de emergencia, pero no todas estas operaciones cuentan con pantallas de administración en la interfaz actual.
- Los módulos de gestión permiten cambiar el estado de los registros, pero no ofrecen eliminación física desde la interfaz.
- El modo demostración no sustituye la configuración de Supabase necesaria para trabajar con datos persistentes.
- La ejecución en una computadora diferente requiere instalar las herramientas de desarrollo y dependencias si se desea ejecutar desde el código fuente.

## 11. Versión del proyecto

**Versión:** 1.0.0+1

**Plataformas:** Web y Android.

**Backend:** Supabase y PostgreSQL.

## 12. Autor

**Jose Carlos Vásquez Yurquina**
