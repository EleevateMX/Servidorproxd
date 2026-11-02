#!/usr/bin/env node
// Descarga el arte de la marca (fondo y vídeo de la pantalla de carga) a pxd_loadscreen.
// Uso: node scripts/fetch-brand-assets.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dest = join(root, 'server-data/resources/[proxima]/pxd_loadscreen/html/assets');
const { files } = JSON.parse(readFileSync(join(root, 'scripts/brand-assets.json'), 'utf8'));
mkdirSync(dest, { recursive: true });

let failed = 0;
for (const f of files) {
  try {
    const res = await fetch(f.url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    writeFileSync(join(dest, f.dest), buf);
    console.log(`✔ ${f.dest} (${(buf.length / 1024 / 1024).toFixed(1)} MB) — ${f.source}`);
  } catch (e) {
    failed++;
    console.error(`✖ ${f.dest}: ${e.message}`);
  }
}
if (failed) {
  console.error('Algunos archivos no se descargaron. La pantalla de carga funciona igual con el fondo animado por CSS.');
  process.exit(1);
}
