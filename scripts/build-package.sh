#!/usr/bin/env bash
# Genera el paquete de instalación para un servidor ya montado (docs/07):
#   resources/[proxima]/pxd_*   (recursos propios, sin datos)
#   resources/[qbx]/...         (trabajos y casas de Qbox: bloque «fase 2» de recipe-qbox.yaml)
#   arte de la pantalla de carga (scripts/brand-assets.json)
# Uso: scripts/build-package.sh [--sin-configs] [salida.zip]
#   --sin-configs  no incluye los archivos editables (config.lua de cada recurso y los de
#                  EDITABLE en scripts/build-manifest.mjs: reglamento, catálogo de props…).
#                  Úsalo para ACTUALIZAR un servidor que ya funciona sin pisar su
#                  configuración: al descomprimir solo se añaden/actualizan los demás archivos.
#                  Para una instalación NUEVA no lo uses (faltarían las configs).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
sinConfigs=0
if [ "${1:-}" = "--sin-configs" ]; then sinConfigs=1; shift; fi
out="${1:-$root/proxima-paquete-instalacion.zip}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/resources/[qbx]"
git -C "$root" archive HEAD "server-data/resources/[proxima]" | tar -x -C "$tmp/resources" --strip-components=2 -f -
if [ "$sinConfigs" = 1 ]; then
  node --input-type=module -e '
import { readdirSync, statSync, rmSync } from "node:fs";
import { join } from "node:path";
const [root, dir] = process.argv.slice(1);
const { isEditable } = await import(`file://${root}/scripts/build-manifest.mjs`);
const walk = (d, base = "") => readdirSync(d).flatMap((n) => {
  const p = join(d, n), rel = base ? `${base}/${n}` : n;
  return statSync(p).isDirectory() ? walk(p, rel) : [rel];
});
let n = 0;
for (const res of readdirSync(dir)) {
  for (const rel of walk(join(dir, res))) {
    if (isEditable(res, rel)) { rmSync(join(dir, res, rel)); n++; }
  }
}
console.log(`--sin-configs: ${n} archivos editables fuera del paquete`);
' "$root" "$tmp/resources/[proxima]"
fi
node -e '
const m = require(process.argv[1] + "/update-manifest.json");
for (const e of m.plan.external) console.log(`${e.name} ${e.repo} ${e.ref}`);
' "$root" | while read -r name repo ref; do
  git clone -q --depth 1 --branch "$ref" "https://github.com/$repo.git" "$tmp/resources/[qbx]/$name"
  rm -rf "$tmp/resources/[qbx]/$name/.git" "$tmp/resources/[qbx]/$name/.github"
done
node -e '
const fs = require("fs"); const { execFileSync } = require("child_process");
const [root, dir] = process.argv.slice(1);
for (const f of require(root + "/scripts/brand-assets.json").files) {
  if (f.resource && f.resource !== "pxd_loadscreen") continue; // ya viene en el repo (git archive)
  const dest = `${dir}/${f.dest}`;
  if (f.url.includes("raw.githubusercontent.com/EleevateMX/Servidorproxd/")) fs.copyFileSync(`${root}/brand/media/${f.dest}`, dest);
  else execFileSync("curl", ["-sSfL", "-o", dest, f.url]);
}
' "$root" "$tmp/resources/[proxima]/pxd_loadscreen/html/assets"
rm -f "$out"; (cd "$tmp" && zip -qr -9 "$out" resources)
echo "Paquete: $out"
