@echo off
cd /d %~dp0\..
if not exist config\local.json (echo Falta config\local.json & exit /b 1)
flutter pub get
flutter run --dart-define-from-file=config/local.json
