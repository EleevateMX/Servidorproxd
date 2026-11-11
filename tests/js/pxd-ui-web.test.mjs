// Interfaz común (pxd_ui) y HUD 2.0 (pxd_hud): build versionado y adaptador de ox_lib. docs/43-interfaz-y-hud.md
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sourceHash } from '../../web/pxd-ui/scripts/source-hash.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const res = join(root, 'server-data/resources/[proxima]');
const adapter = JSON.parse(readFileSync(join(root, 'web/pxd-ui/adapter/ox_lib-3.42.0.json'), 'utf8'));

test('pxd_ui y pxd_hud: el build versionado corresponde a las fuentes (npm run build en web/pxd-ui)', () => {
  const stamp = JSON.parse(readFileSync(join(root, 'web/pxd-ui/build-stamp.json'), 'utf8'));
  assert.equal(stamp.sources, sourceHash());
});

for (const name of ['pxd_ui', 'pxd_hud']) {
  test(`${name}: index.html y assets/app.{js,css} con nombres fijos y rutas relativas`, () => {
    const html = join(res, name, 'html');
    assert.deepEqual(readdirSync(html).sort(), ['assets', 'index.html', 'ui']);
    assert.deepEqual(readdirSync(join(html, 'assets')).sort(), ['app.css', 'app.js']);
    const page = readFileSync(join(html, 'index.html'), 'utf8');
    assert.match(page, /src="\.\/assets\/app\.js"/);
    assert.match(page, /href="\.\/assets\/app\.css"/);
    assert.doesNotMatch(page, /https?:\/\//, 'sin recursos externos');
    const css = readFileSync(join(html, 'assets/app.css'), 'utf8');
    assert.doesNotMatch(css, /backdrop-filter/, 'backdrop-filter deja rectángulos negros sobre el juego');
  });
}

test('fuentes: el texto de terceros nunca se inserta como HTML', () => {
  const walk = (d) => readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(join(d, e.name)) : [join(d, e.name)]));
  for (const f of walk(join(root, 'web/pxd-ui/src')).filter((n) => /\.tsx?$/.test(n))) {
    const text = readFileSync(f, 'utf8').replace(/\/\/.*$/gm, '');
    assert.doesNotMatch(text, /dangerouslySetInnerHTML|\.innerHTML|insertAdjacentHTML|document\.write/, f);
  }
});

test('adaptador de ox_lib: cada parche delega en un export que existe en pxd_ui y conserva el original', () => {
  const client = readFileSync(join(res, 'pxd_ui/client/main.lua'), 'utf8');
  const exported = new Set([...client.matchAll(/exports\('(\w+)'/g)].map((m) => m[1]));
  assert.equal(adapter.patches.length, 9);
  const seen = new Set();
  for (const p of adapter.patches) {
    assert.equal(p.resource, 'ox_lib');
    assert.equal(p.requires, 'pxd_ui');
    assert.equal(p.requiresVersion, '3.42.0');
    assert.match(p.path, /^resource\/interface\/client\/(notify|textui|progress|alert)\.lua$/);
    assert.notEqual(p.find, p.replace);
    assert.ok(!seen.has(p.path + '\n' + p.find), 'búsquedas distintas en el mismo archivo');
    seen.add(p.path + '\n' + p.find);
    // El comportamiento original sigue en el archivo (se usa si pxd_ui no está arrancado o no lo atiende).
    for (const line of p.find.split('\n').map((l) => l.trim()).filter(Boolean)) {
      assert.ok(p.replace.includes(line), `el parche de ${p.path} conserva «${line}»`);
    }
    for (const [, name] of p.replace.matchAll(/exports\.pxd_ui:(\w+)\(/g)) {
      assert.ok(exported.has(name), `pxd_ui exporta ${name}`);
    }
    assert.ok(/pxd_ui/.test(p.replace));
    assert.doesNotMatch(p.replace, /\$[&1-9`']/, 'sin patrones de sustitución de JS (la receta usa String.replace)');
  }
  // Eventos locales con los que pxd_ui avisa a ox_lib.
  for (const ev of ['pxd_ui:oxProgressComplete', 'pxd_ui:oxAlertResult']) {
    assert.ok(client.includes(`TriggerEvent('${ev}'`), `pxd_ui lanza ${ev}`);
    assert.ok(adapter.patches.some((p) => p.replace.includes(`AddEventHandler('${ev}'`)), `ox_lib escucha ${ev}`);
  }
});

test('adaptador de ox_lib: los pasos de la receta salen del mismo JSON', () => {
  const yaml = readFileSync(join(root, 'web/pxd-ui/adapter/recipe-steps.yaml'), 'utf8');
  assert.equal([...yaml.matchAll(/- action: replace_string/g)].length, adapter.patches.length);
  for (const p of adapter.patches) assert.ok(yaml.includes(`./resources/[ox]/ox_lib/${p.path}`));
});

test('pxd_hud conserva los exports y eventos que usan otros recursos', () => {
  const client = readFileSync(join(res, 'pxd_hud/client/main.lua'), 'utf8');
  assert.match(client, /exports\('SetVisible'/);
  assert.match(client, /RegisterNetEvent\('pxd_hud:client:visible'/);
  const server = readFileSync(join(res, 'pxd_hud/server/main.lua'), 'utf8');
  for (const ev of ['hud:server:GainStress', 'hud:server:RelieveStress']) assert.ok(server.includes(ev));
  assert.match(server, /exports\('ChangeStress'/);
});
