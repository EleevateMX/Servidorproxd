import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, existsSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// FXServer lo carga como script CommonJS; aquí el repo es ESM, así que se copia como .cjs.
const require = createRequire(import.meta.url);
const cjs = join(mkdtempSync(join(tmpdir(), 'pxd-assets-')), 'assets.cjs');
copyFileSync(new URL('../../server-data/resources/[proxima]/pxd_updater/server/assets.js', import.meta.url), cjs);
const { downloadAll, prepare } = require(cjs);

test('descarga binarios con bytes nulos sin cortarlos (y sigue redirecciones)', async () => {
  const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d]), Buffer.alloc(5000, 7)]);
  const srv = createServer((req, res) => {
    if (req.url === '/redir') { res.writeHead(302, { Location: '/img.png' }); return res.end(); }
    if (req.url === '/img.png') { res.writeHead(200); return res.end(png); }
    if (req.url === '/tiny.png') { res.writeHead(200); return res.end('x'); }
    res.writeHead(404); res.end();
  });
  await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
  const base = `http://127.0.0.1:${srv.address().port}`;
  const dir = mkdtempSync(join(tmpdir(), 'pxd-'));
  const msgs = await downloadAll([
    { path: 'html/assets/a.png', url: `${base}/redir`, dest: join(dir, 'html/assets/a.png') },
    { path: 'html/assets/b.png', url: `${base}/tiny.png`, dest: join(dir, 'html/assets/b.png') },
    { path: 'html/assets/c.png', url: `${base}/nope.png`, dest: join(dir, 'html/assets/c.png') },
  ], true);
  srv.close();
  assert.deepEqual(readFileSync(join(dir, 'html/assets/a.png')), png);
  assert.ok(!existsSync(join(dir, 'html/assets/b.png')), 'descarta archivos demasiado pequeños');
  assert.match(msgs.join('\n'), /b\.png: archivo demasiado pequeño/);
  assert.match(msgs.join('\n'), /c\.png: HTTP 404/);
  assert.match(msgs.at(-1), /Arte descargado: 1 de 3/);
});

test('solo acepta https, recursos pxd_* y rutas dentro de html/assets', () => {
  const root = () => '/srv/res';
  const items = prepare([
    { resource: 'pxd_loadscreen', path: 'html/assets/ok.png', url: 'https://cdn/ok.png' },
    { resource: 'pxd_loadscreen', path: 'html/assets/../../server.lua', url: 'https://cdn/x' },
    { resource: 'pxd_loadscreen', path: 'server/main.lua', url: 'https://cdn/x' },
    { resource: 'qbx_core', path: 'html/assets/x.png', url: 'https://cdn/x' },
    { resource: 'pxd_loadscreen', path: 'html/assets/y.png', url: 'http://cdn/y' },
  ], root);
  assert.equal(items.length, 1);
  assert.equal(items[0].dest, '/srv/res/html/assets/ok.png');
});

test('instala recursos nuevos: comprueba huellas, rutas y no pisa carpetas', async () => {
  const { installResources } = require(cjs);
  const { createHash } = await import('node:crypto');
  const sha = (t) => createHash('sha256').update(Buffer.from(t, 'utf8')).digest('hex');
  const root = mkdtempSync(join(tmpdir(), 'pxd-res-'));
  const body = 'print("hola ñ")';
  const res = installResources([
    { name: 'pxd_nuevo', files: [{ path: 'server/main.lua', sha256: sha(body), body }] },
    { name: 'pxd_malo', files: [{ path: '../fuera.lua', sha256: sha('x'), body: 'x' }] },
    { name: 'pxd_huella', files: [{ path: 'a.lua', sha256: 'f'.repeat(64), body: 'x' }] },
    { name: 'qbx_core', files: [{ path: 'a.lua', sha256: sha('x'), body: 'x' }] },
  ], root);
  assert.equal(readFileSync(join(root, 'pxd_nuevo/server/main.lua'), 'utf8'), body);
  assert.deepEqual(res.map((r) => r.ok), [true, false, false, false]);
  assert.ok(!existsSync(join(root, 'pxd_malo')) && !existsSync(join(root, '.pxd_huella.part')));
  const again = installResources([{ name: 'pxd_nuevo', files: [{ path: 'b.lua', sha256: sha('y'), body: 'y' }] }], root);
  assert.equal(again[0].ok, false, 'no pisa un recurso que ya existe');
});
