#!/usr/bin/env node
// Genera update-manifest.json: los archivos de texto de cada recurso pxd_* con su
// SHA-256. pxd_updater lo lee desde GitHub para saber qué ha cambiado.
// Uso: node scripts/build-manifest.mjs [--check]   (--check falla si está desactualizado)
import { readdirSync, readFileSync, writeFileSync, statSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const root = fileURLToPath(new URL('..', import.meta.url));
const res = join(root, 'server-data/resources/[proxima]');
const TEXT = /\.(lua|html|css|js|json|svg)$/;

// Archivos que el dueño del servidor puede editar: pxd_updater no los sobrescribe si
// difieren y no sabe qué versión se instaló (se respetan salvo «pxd_update force»).
export const EDITABLE = new Set([
  'pxd_panel/shared/rules.lua',      // reglamento del panel
  'pxd_props/html/catalog.json',     // catálogo de props del editor
  'pxd_hud/npwd/config.json',        // configuración propuesta del teléfono
]);
export const isEditable = (resource, rel) => rel === 'config.lua' || EDITABLE.has(`${resource}/${rel}`);

// Huellas de las versiones publicadas antes de un archivo editable (historial de git).
// Con ellas el actualizador sabe que un archivo sin editar se puede actualizar aunque
// no conste qué versión se instaló (instalación con el paquete o la receta).
function knownHashes(absPath, currentSha) {
  try {
    const rel = relative(root, absPath).split(sep).join('/');
    const commits = execFileSync('git', ['-C', root, 'log', '--format=%H', '--', rel], { encoding: 'utf8' }).split('\n').filter(Boolean);
    const out = new Set();
    for (const c of commits.slice(0, 60)) {
      try {
        const buf = execFileSync('git', ['-C', root, 'show', `${c}:${rel}`], { maxBuffer: 16 * 1024 * 1024 });
        out.add(createHash('sha256').update(buf).digest('hex'));
      } catch { /* el archivo no existía en ese commit */ }
    }
    out.delete(currentSha);
    return [...out].sort();
  } catch {
    return [];   // sin git (p. ej. dentro del paquete): sin historial
  }
}

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
      const sha256 = createHash('sha256').update(buf).digest('hex');
      const editable = isEditable(resource, rel);
      const known = editable ? knownHashes(p, sha256) : [];
      files.push({ resource, path: rel, size: buf.length, sha256,
        config: editable || undefined, known: known.length ? known : undefined });
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
  // Overlays: archivos de un recurso pxd_* que se copian a un recurso de terceros.
  const overlays = (raw.overlays || []).filter((o) => existsSync(join(res, o.from))).map((o) => {
    const buf = readFileSync(join(res, o.from));
    const [fromResource, ...rest] = o.from.split('/');
    return { resource: o.resource, path: o.path, requiresVersion: o.requiresVersion,
      from: { resource: fromResource, path: rest.join('/') }, size: buf.length, sha256: createHash('sha256').update(buf).digest('hex') };
  });
  return { format: 1, files, assets, plan, overlays };
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
