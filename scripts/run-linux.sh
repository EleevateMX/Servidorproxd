#!/usr/bin/env bash
# Arranca el servidor de pruebas de Próxima RP (Linux).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/server/run.sh" ] || { echo "Falta server/run.sh. Ejecuta scripts/setup-linux.sh"; exit 1; }
[ -f "$ROOT/server-data/secrets.cfg" ] || { echo "Falta server-data/secrets.cfg. Ejecuta scripts/setup-linux.sh"; exit 1; }
cd "$ROOT/server-data" && exec bash "$ROOT/server/run.sh" +exec server.cfg
