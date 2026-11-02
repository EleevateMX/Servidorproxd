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

// Trabajos y demás recursos de terceros de la fase 2: se leen de la receta Qbox
// (bloque «download_github» a resources/[categoría]/nombre con ref), así hay una sola fuente.
function externalFromRecipe() {
  const text = readFileSync(join(root, 'recipe-qbox.yaml'), 'utf8');
  const start = text.indexOf('# fase 2 (recursos de terceros)');
  if (start < 0) return [];
  const end = text.indexOf('# fin fase 2', start);
  const block = text.slice(start, end < 0 ? undefined : end);
  const re = /dest: \.\/resources\/(\[[\w-]+\])\/([\w-]+)\n\s+ref: ([\w.-]+)\n\s+src: https:\/\/github\.com\/([\w.-]+\/[\w.-]+)/g;
  return [...block.matchAll(re)].map((m) => ({ name: m[2], category: m[1], repo: m[4], ref: m[3] }));
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
  // Arte (binario, en Higgsfield): se descarga solo si falta en el servidor.
  const brand = JSON.parse(readFileSync(join(root, 'scripts/brand-assets.json'), 'utf8'));
  const assets = brand.files.map((f) => ({ resource: f.resource || 'pxd_loadscreen', path: `html/assets/${f.dest}`, url: f.url }));
  // Plan: arranque automático, sustituciones y ajustes, solo de recursos que existen.
  const raw = JSON.parse(readFileSync(join(root, 'scripts/update-plan.json'), 'utf8'));
  const exists = (r) => existsSync(join(res, r));
  const plan = {
    autostart: raw.autostart.filter(exists),
    replaces: Object.fromEntries(Object.entries(raw.replaces).filter(([r]) => exists(r))),
    patches: raw.patches.filter((p) => exists(p.requires)),
    external: externalFromRecipe(),
  };
  return { format: 1, files, assets, plan };
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
