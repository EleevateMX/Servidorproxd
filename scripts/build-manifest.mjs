#!/usr/bin/env node
// Genera update-manifest.json: los archivos de texto de cada recurso pxd_* con su
// SHA-256. pxd_updater lo lee desde GitHub para saber qué ha cambiado.
// Uso: node scripts/build-manifest.mjs [--check]   (--check falla si está desactualizado)
import { readdirSync, readFileSync, writeFileSync, statSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const res = join(root, 'server-data/resources/[proxima]');
const TEXT = /\.(lua|html|css|js|json|svg)$/;

function walk(dir, out = []) {
  for (const name of readdirSync(dir).sort()) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out); else out.push(p);
  }
  return out;
}

export function buildManifest() {
  const files = [];
  for (const resource of readdirSync(res).sort()) {
    const dir = join(res, resource);
    if (!statSync(dir).isDirectory() || !resource.startsWith('pxd_')) continue;
    for (const p of walk(dir)) {
      const rel = relative(dir, p).split(sep).join('/');
      if (!TEXT.test(rel)) continue;                       // binarios (arte, audio) fuera
      if (rel.startsWith('data/') || rel.startsWith('html/assets/')) continue; // datos del servidor
      const buf = readFileSync(p);
      files.push({ resource, path: rel, size: buf.length, sha256: createHash('sha256').update(buf).digest('hex'),
        config: rel === 'config.lua' || undefined });
    }
  }
  return { format: 1, files };
}

const out = join(root, 'update-manifest.json');
if (import.meta.url === `file://${process.argv[1]}`) {
  const text = JSON.stringify(buildManifest(), null, 1) + '\n';
  if (process.argv.includes('--check')) {
    const cur = existsSync(out) ? readFileSync(out, 'utf8') : '';
    if (cur !== text) { console.error('update-manifest.json desactualizado: ejecuta node scripts/build-manifest.mjs'); process.exit(1); }
    console.log('update-manifest.json al día');
  } else {
    writeFileSync(out, text);
    console.log(`update-manifest.json: ${JSON.parse(text).files.length} archivos`);
  }
}
