#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
flutter pub get
flutter run --dart-define-from-file=config/demo.json
