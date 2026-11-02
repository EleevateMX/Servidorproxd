// Manifiesto del actualizador: archivos editables protegidos y versiones conocidas.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { buildManifest, isEditable, EDITABLE } from '../../scripts/build-manifest.mjs';

const sha = (buf) => createHash('sha256').update(buf).digest('hex');

test('isEditable: config.lua de cualquier recurso y la lista EDITABLE', () => {
  assert.equal(isEditable('pxd_login', 'config.lua'), true);
  assert.equal(isEditable('pxd_panel', 'shared/rules.lua'), true);
  assert.equal(isEditable('pxd_props', 'html/catalog.json'), true);
  assert.equal(isEditable('pxd_hud', 'npwd/config.json'), true);
  assert.equal(isEditable('pxd_login', 'server/main.lua'), false);
  assert.equal(isEditable('pxd_panel', 'config/rules.lua'), false);
  for (const p of EDITABLE) assert.match(p, /^pxd_[a-z_]+\//);
});

test('el manifiesto marca los editables y añade huellas de versiones anteriores (sin la actual)', () => {
  const m = buildManifest();
  const editables = m.files.filter((f) => f.config);
  assert.ok(editables.length >= 4);
  for (const f of m.files) assert.equal(Boolean(f.config), isEditable(f.resource, f.path), `${f.resource}/${f.path}`);
  for (const f of editables) {
    for (const h of f.known || []) {
      assert.match(h, /^[0-9a-f]{64}$/);
      assert.notEqual(h, f.sha256, 'la versión actual no va en known');
    }
  }
  // un archivo no editable nunca lleva known
  assert.ok(m.files.filter((f) => !f.config).every((f) => f.known === undefined));
  // la huella del manifiesto coincide con el archivo en disco
  const login = m.files.find((f) => f.resource === 'pxd_login' && f.path === 'config.lua');
  const buf = readFileSync(new URL('../../server-data/resources/[proxima]/pxd_login/config.lua', import.meta.url));
  assert.equal(login.sha256, sha(buf));
});
