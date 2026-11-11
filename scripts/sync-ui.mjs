#!/usr/bin/env node
// Copia el sistema de diseño común (design/ui) a html/ui/ de cada recurso con NUI.
// - proxima-ui.css: tokens y componentes (copia exacta).
// - proxima-fonts.css: las fuentes (OFL) incrustadas en base64. Así son archivos de
//   texto y pxd_updater las puede actualizar como el resto (no maneja binarios).
// Uso: node scripts/sync-ui.mjs [--check]
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const src = join(root, 'design/ui');
const res = join(root, 'server-data/resources/[proxima]');

export const TARGETS = ['pxd_panel', 'pxd_hud', 'pxd_ui', 'pxd_multichar', 'pxd_restart', 'pxd_loadscreen', 'pxd_login', 'pxd_gamemodes', 'pxd_chat', 'pxd_garage'];

const FONTS = [
  { family: 'Inter', file: 'inter-latin-var.woff2', weight: '100 900' },
  { family: 'Sora', file: 'sora-latin-600.woff2', weight: '600' },
  { family: 'Sora', file: 'sora-latin-700.woff2', weight: '700' },
  { family: 'Sora', file: 'sora-latin-800.woff2', weight: '800' },
];

export function buildFiles() {
  const fonts = [
    '/* Generado por scripts/sync-ui.mjs — no editar. Inter y Sora: SIL Open Font License 1.1 (design/ui/fonts). */',
    ...FONTS.map((f) => `@font-face { font-family: '${f.family}'; font-style: normal; font-weight: ${f.weight}; font-display: block; src: url(data:font/woff2;base64,${readFileSync(join(src, 'fonts', f.file)).toString('base64')}) format('woff2'); }`),
    '',
  ].join('\n');
  return { 'proxima-ui.css': readFileSync(join(src, 'proxima-ui.css'), 'utf8'), 'proxima-fonts.css': fonts };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const files = buildFiles();
  const check = process.argv.includes('--check');
  let stale = [];
  for (const t of TARGETS) {
    const dir = join(res, t, 'html/ui');
    for (const [name, text] of Object.entries(files)) {
      const p = join(dir, name);
      if (check) { if (!existsSync(p) || readFileSync(p, 'utf8') !== text) stale.push(`${t}/html/ui/${name}`); continue; }
      mkdirSync(dir, { recursive: true });
      writeFileSync(p, text);
    }
  }
  if (check) {
    if (stale.length) { console.error('UI desincronizada (node scripts/sync-ui.mjs):\n' + stale.join('\n')); process.exit(1); }
    console.log('UI común al día');
  } else console.log(`UI común copiada a ${TARGETS.length} recursos`);
}
