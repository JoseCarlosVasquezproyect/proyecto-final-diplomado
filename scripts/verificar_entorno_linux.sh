#!/usr/bin/env bash
set -e
printf '\n=== PROYECTO FINAL 360 · VERIFICACION ===\n'
command -v flutter >/dev/null || { echo 'ERROR: Flutter no esta en PATH'; exit 1; }
flutter --version
flutter doctor
flutter devices
flutter pub get
echo 'OK: entorno base verificado.'
