@echo off
cd /d %~dp0\..
echo === PREFLIGHT DOCENTE - PROYECTO FINAL 360 ===
flutter --version || exit /b 1
flutter doctor
flutter devices
flutter pub get || exit /b 1
flutter analyze || exit /b 1
flutter test || exit /b 1
echo OK: pub get + analyze + test completados.
echo Siguiente: scripts\run_demo_windows.bat
