#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
if [ -e config/local.json ]; then
  echo 'config/local.json ya existe; no se sobrescribe.'
else
  cp config/local.example.json config/local.json
  echo 'Creado config/local.json. Editalo con URL y publishable/anon key.'
fi
