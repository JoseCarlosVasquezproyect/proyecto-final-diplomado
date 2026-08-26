#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
if [ ! -f config/local.json ]; then
  echo 'Falta config/local.json. Copia config/local.example.json y completa tus datos.'
  exit 1
fi
flutter pub get
flutter run --dart-define-from-file=config/local.json
