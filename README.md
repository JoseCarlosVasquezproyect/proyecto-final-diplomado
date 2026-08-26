# Proyecto Final 360 · Base de Sesión 1

Base académica genérica para construir el Trabajo Final del Diplomado.

## 1. Levantar YA sin backend
```bash
flutter pub get
flutter run --dart-define-from-file=config/demo.json
```

## 2. Conectar Supabase
```bash
cp config/local.example.json config/local.json
# editar local.json
flutter run --dart-define-from-file=config/local.json
```

Antes, ejecutar `supabase/01_schema_y_rls.sql` en Supabase.

## Qué demuestra esta versión
- navegación;
- estado global simple con Provider;
- persistencia local con SharedPreferences;
- autenticación email/password;
- CRUD remoto con Supabase/PostgreSQL;
- RLS: cada usuario ve sus propios registros;
- validación de formularios;
- manejo de carga/error/reintento;
- base lista para adaptar al dominio individual.

## Regla
`RegistroDemo` no debe sobrevivir al Trabajo Final. Debe convertirse en una entidad real de tu problema.
