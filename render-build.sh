#!/usr/bin/env bash
set -e

FLUTTER_VERSION="3.44.8"
FLUTTER_DIR="$HOME/flutter"

echo "==> Preparando Flutter $FLUTTER_VERSION..."

if [ -d "$FLUTTER_DIR/.git" ]; then
  CURRENT_VERSION=$("$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | head -n 1 || true)

  if [[ "$CURRENT_VERSION" != *"Flutter $FLUTTER_VERSION"* ]]; then
    echo "==> Version incorrecta en cache. Reinstalando Flutter $FLUTTER_VERSION..."
    rm -rf "$FLUTTER_DIR"
  else
    echo "==> Flutter $FLUTTER_VERSION encontrado en cache."
  fi
fi

if [ ! -d "$FLUTTER_DIR/.git" ]; then
  echo "==> Instalando Flutter $FLUTTER_VERSION..."
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git --depth 1 --branch "$FLUTTER_VERSION" "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "==> Version utilizada:"
flutter --version

echo "==> Instalando dependencias..."
flutter pub get

echo "==> Compilando Flutter Web..."
flutter build web --release \
  --dart-define=DEMO_MODE="$DEMO_MODE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"

echo "==> Build de Flutter Web completado."