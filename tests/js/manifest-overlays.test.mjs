import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { buildManifest } from '../../scripts/build-manifest.mjs';

const res = fileURLToPath(new URL('../../server-data/resources/[proxima]/', import.meta.url));

test('overlays: la interfaz propia sustituye la web de ox_inventory 2.48.1 (huella y versión)', () => {
  const { overlays: all, plan } = buildManifest();
  const overlays = all.filter((o) => o.from.resource === 'pxd_inventory');
  assert.deepEqual(overlays.map((o) => o.path).sort(), ['web/build/assets/pxd-inventory.css', 'web/build/assets/pxd-inventory.js', 'web/build/index.html']);
  for (const o of overlays) {
    assert.equal(o.resource, 'ox_inventory');
    assert.equal(o.requiresVersion, '2.48.1');
    assert.equal(o.from.path, o.path.replace(/^web\/build\//, 'web/'));
    const buf = readFileSync(join(res, o.from.resource, o.from.path));
    assert.equal(o.sha256, createHash('sha256').update(buf).digest('hex'));
    assert.equal(o.size, buf.length);
  }
  // Ningún parche puede tocar el index.html que se sustituye (el antiguo añadía pxd.css/pxd.js en </head>).
  assert.ok(!plan.patches.some((p) => p.resource === 'ox_inventory' && p.path === 'web/build/index.html'));
  assert.ok(plan.autostart.includes('pxd_inventory'));
});
