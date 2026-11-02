// Capa visual de Próxima sobre ox_lib 3.42.0 y ox_target 1.18.1 (pxd_theme; docs/24).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildManifest } from '../../scripts/build-manifest.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));
const plan = JSON.parse(readFileSync(join(root, 'scripts/update-plan.json'), 'utf8'));
const recipe = readFileSync(join(root, 'recipe-qbox.yaml'), 'utf8');
const ORIGINAL_THEME = 'colorScheme:"dark",fontFamily:"Roboto",shadows:{sm:"1px 1px 3px rgba(0, 0, 0, 0.5)"},components:{Button:{styles:{root:{border:"none"}}}}';

test('ox_lib: el parche sustituye el objeto de tema original por uno válido', () => {
  const p = plan.patches.find((x) => x.resource === 'ox_lib' && x.path.endsWith('.js'));
  assert.ok(p, 'falta el parche del bundle');
  assert.equal(p.path, 'web/build/assets/index-Dqr00JhT.js');
  assert.equal(p.find, ORIGINAL_THEME);
  assert.equal(p.requires, 'pxd_theme');
  assert.ok(!p.replace.includes(p.find), 'el reemplazo no puede contener el original');
  const theme = new Function(`return {${p.replace}}`)();
  assert.equal(theme.colorScheme, 'dark');
  for (const name of ['dark', 'cyan', 'blue', 'pink', 'yellow', 'red', 'teal']) {
    assert.equal(theme.colors[name].length, 10, `${name} necesita 10 tonos`);
    for (const c of theme.colors[name]) assert.match(c, /^#[0-9a-f]{6}$/);
  }
  assert.equal(theme.colors.cyan[4], '#5ce1ff');
  assert.equal(theme.colors.pink[5], '#ff4fd8');
  assert.equal(theme.colors.dark[9], '#05070f');
  assert.equal(typeof theme.components.Button.styles, 'function');
  const filled = theme.components.Button.styles({}, { variant: 'filled' }).root;
  assert.equal(filled.color, '#031018');
});

test('ox_lib y ox_target: capas con versión fija, huella y parches de index.html', () => {
  const { overlays } = buildManifest();
  const mine = overlays.filter((o) => o.from.resource === 'pxd_theme');
  assert.deepEqual(mine.map((o) => `${o.resource}:${o.requiresVersion}:${o.path}`).sort(),
    ['ox_lib:3.42.0:web/build/assets/pxd.css', 'ox_target:1.18.1:web/style.css']);
  const head = plan.patches.find((x) => x.resource === 'ox_lib' && x.path === 'web/build/index.html');
  assert.equal(head.find, '</head>');
  assert.match(head.replace, /href="\.\/assets\/pxd\.css"/);
  const eye = plan.patches.find((x) => x.resource === 'ox_target');
  assert.match(eye.find, /^<svg id="eyeSvg"/);
  assert.match(eye.replace, /^<svg id="eyeSvg"/, 'conserva el id que usa su JS');
  assert.ok(plan.autostart.includes('pxd_theme'));
});

test('receta: versiones fijas y mismos cambios que el actualizador', () => {
  assert.match(recipe, /ox_lib\/releases\/download\/v3\.42\.0\/ox_lib\.zip/);
  assert.match(recipe, /ox_target\/releases\/download\/v1\.18\.1\/ox_target\.zip/);
  assert.doesNotMatch(recipe, /ox_lib\/releases\/latest/);
  assert.ok(recipe.includes("file: ./resources/[ox]/ox_lib/web/build/assets/index-Dqr00JhT.js"));
  assert.ok(recipe.includes('pxd_theme/overlay/ox_target/style.css'));
});

test('ox_target: el estilo conserva las clases que usa su JS', () => {
  const css = readFileSync(join(root, 'server-data/resources/[proxima]/pxd_theme/overlay/ox_target/style.css'), 'utf8');
  for (const sel of ['#eye', '#eyeSvg', '.eye-hover', '#options-wrapper', '.option-container', '.option-icon', '.option-label', 'body {'])
    assert.ok(css.includes(sel), `falta ${sel}`);
  assert.match(css, /visibility: hidden/, 'el body debe empezar oculto (lo muestra el JS)');
  assert.doesNotMatch(css, /@import|https?:\/\//, 'sin recursos externos');
});
