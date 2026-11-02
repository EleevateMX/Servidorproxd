import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { mkdtempSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// FXServer lo carga como script CommonJS; aquí el repo es ESM, así que se copia como .cjs.
const require = createRequire(import.meta.url);
const cjs = join(mkdtempSync(join(tmpdir(), 'pxd-assets-')), 'assets.cjs');
copyFileSync(new URL('../../server-data/resources/[proxima]/pxd_updater/server/assets.js', import.meta.url), cjs);
const { downloadAll, prepare } = require(cjs);

test('descarga binarios con bytes nulos sin cortarlos y los entrega en base64', async () => {
  const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d]), Buffer.alloc(5000, 7)]);
  const srv = createServer((req, res) => {
    if (req.url === '/redir') { res.writeHead(302, { Location: '/img.png' }); return res.end(); }
    if (req.url === '/img.png') { res.writeHead(200); return res.end(png); }
    if (req.url === '/tiny.png') { res.writeHead(200); return res.end('x'); }
    res.writeHead(404); res.end();
  });
  await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
  const base = `http://127.0.0.1:${srv.address().port}`;
  const got = [];
  const { messages, ok } = await downloadAll([
    { path: 'html/assets/a.png', url: `${base}/redir` },
    { path: 'html/assets/b.png', url: `${base}/tiny.png` },
    { path: 'html/assets/c.png', url: `${base}/nope.png` },
  ], (it, b64) => got.push([it.path, b64]), true);
  srv.close();
  assert.equal(ok, 1);
  assert.deepEqual(Buffer.from(got[0][1], 'base64'), png);
  assert.match(messages.join('\n'), /b\.png: archivo demasiado pequeño/);
  assert.match(messages.join('\n'), /c\.png: HTTP 404/);
  assert.match(messages.at(-1), /Arte descargado: 1 de 3/);
});

test('solo acepta https, recursos pxd_* y rutas dentro de html/assets', () => {
  const items = prepare([
    { resource: 'pxd_loadscreen', path: 'html/assets/ok.png', url: 'https://cdn/ok.png' },
    { resource: 'pxd_loadscreen', path: 'html/assets/../../server.lua', url: 'https://cdn/x' },
    { resource: 'pxd_loadscreen', path: 'server/main.lua', url: 'https://cdn/x' },
    { resource: 'qbx_core', path: 'html/assets/x.png', url: 'https://cdn/x' },
    { resource: 'pxd_loadscreen', path: 'html/assets/y.png', url: 'http://cdn/y' },
  ]);
  assert.deepEqual(items.map((i) => i.path), ['html/assets/ok.png']);
});
