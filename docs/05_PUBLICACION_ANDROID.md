# Generar APK de produccion

## 1. Crear y resguardar la clave de firma

Desde la raiz del proyecto, cree una carpeta local para la clave y ejecute:

```powershell
New-Item -ItemType Directory -Force keystore
keytool -genkeypair -v -keystore keystore/gestion-hospitalaria-release.jks -alias gestion_hospitalaria -keyalg RSA -keysize 2048 -validity 10000
```

Guarde la clave y sus contrasenas en un gestor seguro. Perderlas impide publicar actualizaciones de la misma aplicacion en Google Play.

## 2. Configurar la firma

Copie `android/key.properties.example` como `android/key.properties` y reemplace los valores de ejemplo. Ambos archivos sensibles estan excluidos de Git.

## 3. Compilar

Para la configuracion demo:

```powershell
flutter build apk --release --dart-define-from-file=config/demo.json
```

Para produccion con Supabase, cree `config/local.json` a partir de `config/local.example.json`, complete la URL y la clave publicable, y ejecute:

```powershell
flutter build apk --release --dart-define-from-file=config/local.json
```

El APK se genera en `build/app/outputs/flutter-apk/app-release.apk`. Verifique primero que la cuenta de Supabase usada para la publicacion tenga RLS correctamente aplicado; una clave `service_role` nunca debe incluirse en la app.
