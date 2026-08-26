@echo off
where flutter >nul 2>nul || (echo ERROR: Flutter no esta en PATH & exit /b 1)
flutter --version
flutter doctor
flutter devices
flutter pub get
