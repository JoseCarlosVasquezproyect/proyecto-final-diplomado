@echo off
cd /d %~dp0\..
flutter pub get
flutter run --dart-define-from-file=config/demo.json
