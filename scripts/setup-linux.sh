#!/usr/bin/env bash
# Próxima RP — instalación del entorno de pruebas en Linux.
# Uso: bash scripts/setup-linux.sh "<enlace del build recomendado de Linux (fx.tar.xz)>"
# El enlace se copia de https://docs.fivem.net/docs/server-download/
# Nota oficial: el servidor de Linux es un "port de cortesía"; Windows recibe antes los arreglos.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$ROOT/server"; DATA="$ROOT/server-data"; CFX="$DATA/resources/[cfx]"
step() { printf '\n\033[36m» %s\033[0m\n' "$1"; }

step "Comprobando herramientas"
command -v git >/dev/null || { echo "Falta git"; exit 1; }
command -v xz >/dev/null || { echo "Falta xz (Debian/Ubuntu: apt install xz-utils)"; exit 1; }

step "Binarios de FXServer"
mkdir -p "$SERVER"
if [ -f "$SERVER/run.sh" ]; then
  echo "  Ya existen en $SERVER"
elif [ -n "${1:-}" ]; then
  curl -fL "$1" -o "$SERVER/fx.tar.xz"
  tar -xf "$SERVER/fx.tar.xz" -C "$SERVER" && rm "$SERVER/fx.tar.xz"
else
  echo "  Descarga el build RECOMENDADO de Linux desde https://docs.fivem.net/docs/server-download/"
  echo "  y vuelve a ejecutar: bash scripts/setup-linux.sh <enlace>"
fi

step "Recursos base (cfx-server-data)"
if [ -d "$CFX" ]; then echo "  Ya existen en $CFX"; else
  TMP="$(mktemp -d)"
  git clone --depth 1 https://github.com/citizenfx/cfx-server-data.git "$TMP/cfx"
  mkdir -p "$CFX" && cp -r "$TMP/cfx/resources/." "$CFX/" && rm -rf "$TMP"
fi

step "Secretos (secrets.cfg y .env)"
if [ ! -f "$DATA/secrets.cfg" ]; then
  TOKEN="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  sed "s/GENERA_UN_TOKEN_LARGO/$TOKEN/" "$DATA/secrets.cfg.example" > "$DATA/secrets.cfg"
  [ -f "$ROOT/.env" ] || sed "s/^PXD_TOKEN=$/PXD_TOKEN=$TOKEN/" "$ROOT/.env.example" > "$ROOT/.env"
  echo "  Creado secrets.cfg con un token nuevo (también en .env)."
else echo "  secrets.cfg ya existe; no se toca."; fi

if command -v node >/dev/null; then
  step "Arte de la marca"
  node "$ROOT/scripts/fetch-brand-assets.mjs" || true
fi

printf '\n\033[32mListo.\033[0m 1) Añade tu identificador en server-data/permissions.cfg  2) bash scripts/run-linux.sh  3) En FiveM: connect IP:30120\n'
