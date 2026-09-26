#!/usr/bin/env bash
set -e

echo "==> Instalando Flutter 3.44.8..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch 3.44.8 "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

echo "==> Version de Flutter:"
flutter --version

echo "==> Instalando dependencias del proyecto..."
flutter pub get

echo "==> Compilando Flutter Web..."
flutter build web --release \
  --dart-define=DEMO_MODE="$DEMO_MODE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"

echo "==> Build de Flutter Web completado."
