// Comprueba que lo que se despliega es coherente: cada `ensure` tiene recurso,
// cada recurso propio tiene fxmanifest y los archivos que declara existen,
// y la receta de txAdmin apunta a rutas reales del repo.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../../', import.meta.url).pathname;
const res = join(root, 'server-data/resources/[proxima]');
const own = readdirSync(res).filter((d) => statSync(join(res, d)).isDirectory());

// Recursos externos: chat viene con FXServer (citizenfx/fivem ext/system-resources);
// el resto, de citizenfx/cfx-server-data.
const EXTERNAL = new Set(['chat', 'mapmanager', 'spawnmanager', 'basic-gamemode', 'baseevents', 'fivem-map-hipster']);

// Lo que trae la receta de Qbox (categorías y recursos que descarga).
const QBOX_ONLY = new Set(['pxd_multichar', 'pxd_hud', 'pxd_panel', 'pxd_jobs', 'pxd_interact', 'pxd_voice', 'pxd_admin', 'pxd_inventory', 'pxd_compat', 'pxd_justice', 'pxd_phone', 'pxd_theme', 'pxd_blips', 'pxd_audit']);
const QBOX = new Set(['ox_lib', 'qbx_core', 'ox_target', '[ox]', '[qbx]', '[standalone]', '[voice]', '[assets]', '[npwd-apps]', 'qbx_npwd', 'npwd']);

for (const cfg of ['server-data/server.cfg', 'server-data/server.hosting.cfg', 'server-data/server.qbox.cfg']) {
  test(`${cfg}: cada ensure apunta a un recurso existente`, () => {
    const text = readFileSync(join(root, cfg), 'utf8');
    const ensures = [...text.matchAll(/^ensure (\S+)/gm)].map((m) => m[1]);
    assert.ok(ensures.length > 0);
    for (const name of ensures) {
      const qboxOk = cfg.endsWith('qbox.cfg') && QBOX.has(name);
      assert.ok(EXTERNAL.has(name) || own.includes(name) || qboxOk, `${cfg}: «ensure ${name}» no existe`);
    }
    // Los recursos que solo funcionan con Qbox van únicamente en server.qbox.cfg.
    for (const name of own) {
      if (QBOX_ONLY.has(name) && !cfg.endsWith('qbox.cfg')) continue;
      assert.ok(ensures.includes(name), `${cfg}: falta «ensure ${name}»`);
    }
    assert.match(text, /^set onesync on$/m, 'los modos de juego necesitan OneSync');
    assert.doesNotMatch(text, /^setr .*(token|accessCode)/im, 'los secretos nunca con setr');
  });
}

for (const cfg of ['server-data/server.hosting.cfg', 'server-data/server.qbox.cfg']) {
  test(`${cfg}: solo variables que rellena txAdmin y nada obsoleto`, () => {
    const text = readFileSync(join(root, cfg), 'utf8');
    const known = new Set(['serverEndpoints', 'svLicense', 'maxClients', 'serverName', 'addPrincipalsMaster', 'dbConnectionString']);
    for (const [, v] of text.matchAll(/\{\{(\w+)\}\}/g)) assert.ok(known.has(v), `variable desconocida {{${v}}}`);
    // Cfx.re: se configuran en el portal (docs server-commands: «deprecated»).
    assert.doesNotMatch(text, /^(sv_hostname|sets sv_projectName|sets sv_projectDesc)/m);
    assert.ok(!cfg.endsWith('qbox.cfg') || text.includes('{{dbConnectionString}}'), 'Qbox necesita la base de datos');
  });
}

for (const name of own) {
  test(`${name}: fxmanifest válido y archivos declarados presentes`, () => {
    const dir = join(res, name);
    const manifest = join(dir, 'fxmanifest.lua');
    assert.ok(existsSync(manifest), `${name} no tiene fxmanifest.lua`);
    const text = readFileSync(manifest, 'utf8');
    assert.match(text, /fx_version 'cerulean'/);
    assert.match(text, /game 'gta5'/);
    if (/ui_page|RegisterNUICallback/.test(text)) assert.match(text, /nui_callback_strict_mode 'true'/);
    // Rutas literales (sin comodines) entre comillas que parezcan archivos.
    for (const [, p] of text.matchAll(/'([\w./-]+\.(?:lua|html|css|js|json|svg))'/g)) {
      if (p.includes('*')) continue;
      assert.ok(existsSync(join(dir, p)), `${name}: declara «${p}» pero no existe`);
    }
  });
}

for (const recipe of ['recipe.yaml', 'recipe-qbox.yaml']) test(`${recipe}: rutas del repo y acciones conocidas de txAdmin`, () => {
  const text = readFileSync(join(root, recipe), 'utf8');
  assert.match(text, /^\$engine: 3$/m);
  assert.match(text, /^\$onesync: on$/m);
  const actions = [...text.matchAll(/- action: (\w+)/g)].map((m) => m[1]);
  const allowed = new Set(['download_github', 'download_file', 'move_path', 'remove_path', 'replace_string', 'copy_path', 'ensure_dir', 'unzip', 'write_file', 'connect_database', 'query_database', 'waste_time']);
  assert.match(text, /src: https:\/\/github.com\/EleevateMX\/Servidorproxd/);
  for (const slide of ['policia', 'emergencias', 'taller', 'barrio']) assert.match(text, new RegExp(`assets/slide-${slide}.png`));
  for (const a of actions) assert.ok(allowed.has(a), `acción desconocida ${a}`);
  for (const [, src] of text.matchAll(/src: \.\/tmp\/proxima\/(.+)$/gm)) {
    assert.ok(existsSync(join(root, src)), `la receta mueve «${src}», que no existe en el repo`);
  }
});

test('proxima.cfg: cada ajuste coincide con server.qbox.cfg (misma fuente)', () => {
  const extra = readFileSync(join(root, 'server-data/proxima.cfg'), 'utf8');
  const qbox = readFileSync(join(root, 'server-data/server.qbox.cfg'), 'utf8');
  const lines = extra.split('\n').map((l) => l.trim()).filter((l) => /^(set|setr) /.test(l) && !l.includes('pxd_updater_ref') && !l.includes('qbx:motd'));
  assert.ok(lines.length >= 9);
  for (const l of lines) assert.ok(qbox.includes(l), `server.qbox.cfg no tiene: ${l}`);
});
