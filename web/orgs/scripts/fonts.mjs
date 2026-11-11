#!/usr/bin/env node
// Genera las fuentes de pxd_orgs/html/ui como CSS con las fuentes incrustadas en base64
// (son archivos de texto: pxd_updater los actualiza como el resto; no maneja binarios).
// - proxima-fonts.css: Inter y Sora, las de toda la interfaz (misma salida que scripts/sync-ui.mjs).
// - orgs-fonts.css: tipografías de identidad de las organizaciones (Config.fonts de pxd_orgs).
//   La oleada 2 (grafitis, mapa de barrios) puede cargar este mismo archivo:
//   https://cfx-nui-pxd_orgs/html/ui/orgs-fonts.css
// Uso: node scripts/fonts.mjs [--check]
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildFiles } from '../../../scripts/sync-ui.mjs';

const here = fileURLToPath(new URL('..', import.meta.url));
const out = join(here, '../../server-data/resources/[proxima]/pxd_orgs/html/ui');

// family = Config.fonts[].family en pxd_orgs/config.lua (lo comprueba tests/js/orgs-web.test.mjs).
export const IDENTITY_FONTS = [
  { id: 'bebas', family: 'PXO Bebas Neue', pkg: 'bebas-neue', license: 'OFL-1.1' },
  { id: 'marker', family: 'PXO Permanent Marker', pkg: 'permanent-marker', license: 'Apache-2.0' },
  { id: 'bangers', family: 'PXO Bangers', pkg: 'bangers', license: 'OFL-1.1' },
  { id: 'russo', family: 'PXO Russo One', pkg: 'russo-one', license: 'OFL-1.1' },
  { id: 'pacifico', family: 'PXO Pacifico', pkg: 'pacifico', license: 'OFL-1.1' },
  { id: 'blackops', family: 'PXO Black Ops One', pkg: 'black-ops-one', license: 'OFL-1.1' },
];

export function buildOrgFonts() {
  const lines = ['/* Generado por web/orgs/scripts/fonts.mjs — no editar. Licencias: pxd_orgs/LICENSES.md. */'];
  for (const f of IDENTITY_FONTS) {
    const file = join(here, 'node_modules/@fontsource', f.pkg, 'files', `${f.pkg}-latin-400-normal.woff2`);
    lines.push(`@font-face { font-family: '${f.family}'; font-style: normal; font-weight: 400; font-display: block; src: url(data:font/woff2;base64,${readFileSync(file).toString('base64')}) format('woff2'); }`);
  }
  lines.push('');
  return lines.join('\n');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const files = { 'proxima-fonts.css': buildFiles()['proxima-fonts.css'], 'orgs-fonts.css': buildOrgFonts() };
  const check = process.argv.includes('--check');
  const stale = [];
  mkdirSync(out, { recursive: true });
  for (const [name, text] of Object.entries(files)) {
    const p = join(out, name);
    if (check) { if (!existsSync(p) || readFileSync(p, 'utf8') !== text) stale.push(name); continue; }
    writeFileSync(p, text);
  }
  if (check) {
    if (stale.length) { console.error('Fuentes de pxd_orgs desactualizadas (npm --prefix web/orgs run fonts): ' + stale.join(', ')); process.exit(1); }
    console.log('Fuentes de pxd_orgs al día');
  } else console.log('Fuentes de pxd_orgs generadas');
}
