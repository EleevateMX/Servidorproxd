// Interfaz propia del inventario (web/pxd-inventory → pxd_inventory/web). docs/36-inventario.md
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sourceHash } from '../../web/pxd-inventory/scripts/source-hash.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const web = join(root, 'server-data/resources/[proxima]/pxd_inventory/web');

test('inventario: el build versionado corresponde a las fuentes (npm run build en web/pxd-inventory)', () => {
  const stamp = JSON.parse(readFileSync(join(root, 'web/pxd-inventory/build-stamp.json'), 'utf8'));
  assert.equal(stamp.sources, sourceHash());
});

test('inventario: solo index.html y assets/pxd-inventory.{js,css}, enlazados con rutas relativas', () => {
  assert.deepEqual(readdirSync(web).sort(), ['assets', 'index.html']);
  assert.deepEqual(readdirSync(join(web, 'assets')).sort(), ['pxd-inventory.css', 'pxd-inventory.js']);
  const html = readFileSync(join(web, 'index.html'), 'utf8');
  assert.match(html, /src="\.\/assets\/pxd-inventory\.js"/);
  assert.match(html, /href="\.\/assets\/pxd-inventory\.css"/);
  assert.doesNotMatch(html, /https?:\/\//, 'sin recursos externos (fuentes incluidas en el CSS)');
});

test('inventario: el bundle avisa uiLoaded y no anula fetch', () => {
  const js = readFileSync(join(web, 'assets/pxd-inventory.js'), 'utf8');
  assert.match(js, /uiLoaded/);
  assert.match(js, /pxd_inventory/);
  assert.doesNotMatch(js, /window\.fetch\s*=/);
});
