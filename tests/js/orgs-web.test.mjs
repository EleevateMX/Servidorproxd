// Interfaz de organizaciones (web/orgs → pxd_orgs/html). docs/42-organizaciones.md
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sourceHash } from '../../web/orgs/scripts/source-hash.mjs';
import { buildFiles } from '../../scripts/sync-ui.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const res = join(root, 'server-data/resources/[proxima]/pxd_orgs');
const config = readFileSync(join(res, 'config.lua'), 'utf8');

test('organizaciones: el build versionado corresponde a las fuentes (npm --prefix web/orgs run build)', () => {
  const stamp = JSON.parse(readFileSync(join(root, 'web/orgs/build-stamp.json'), 'utf8'));
  assert.equal(stamp.sources, sourceHash());
});

test('organizaciones: nombres fijos, rutas relativas y sin recursos externos', () => {
  assert.deepEqual(readdirSync(join(res, 'html')).sort(), ['assets', 'index.html', 'ui']);
  assert.deepEqual(readdirSync(join(res, 'html/assets')).sort(), ['app.css', 'app.js']);
  assert.deepEqual(readdirSync(join(res, 'html/ui')).sort(), ['orgs-fonts.css', 'proxima-fonts.css']);
  const html = readFileSync(join(res, 'html/index.html'), 'utf8');
  assert.match(html, /src="\.\/assets\/app\.js"/);
  assert.match(html, /href="\.\/assets\/app\.css"/);
  assert.doesNotMatch(html, /https?:\/\//);
  for (const f of ['html/assets/app.css', 'html/ui/orgs-fonts.css']) {
    assert.doesNotMatch(readFileSync(join(res, f), 'utf8'), /url\(\s*['"]?https?:/, `${f}: sin fuentes externas`);
  }
});

test('organizaciones: cada tipografía de Config.fonts está incluida en el recurso', () => {
  const families = [...config.matchAll(/id = '(\w+)',\s+label = '[^']+',\s+family = '([^']+)'/g)].map((m) => ({ id: m[1], family: m[2] }));
  assert.ok(families.length >= 5, 'lista de tipografías');
  const own = readFileSync(join(res, 'html/ui/orgs-fonts.css'), 'utf8');
  const base = readFileSync(join(res, 'html/ui/proxima-fonts.css'), 'utf8');
  for (const f of families) {
    const css = f.family === 'Sora' ? base : own;
    assert.ok(css.includes(`font-family: '${f.family}'`), `falta la fuente «${f.family}» (${f.id})`);
  }
  assert.equal(base, buildFiles()['proxima-fonts.css'], 'proxima-fonts.css desactualizado: npm --prefix web/orgs run fonts');
  const licenses = readFileSync(join(res, 'LICENSES.md'), 'utf8');
  for (const f of families) if (f.family !== 'Sora') assert.ok(licenses.includes(f.family.replace('PXO ', '')), `licencia de ${f.family}`);
});

test('organizaciones: paleta de colores válida y sin repetidos', () => {
  const block = config.slice(config.indexOf('Config.colors = {'), config.indexOf('}', config.indexOf('Config.colors = {')));
  const colors = [...block.matchAll(/'(#[0-9a-f]{6})'/g)].map((m) => m[1]);
  assert.ok(colors.length >= 8);
  assert.equal(new Set(colors).size, colors.length);
  assert.equal([...block.matchAll(/'([^']+)'/g)].length, colors.length, 'solo colores #rrggbb en minúsculas');
});
