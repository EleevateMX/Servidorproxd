import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { buildManifest } from '../../scripts/build-manifest.mjs';

const res = fileURLToPath(new URL('../../server-data/resources/[proxima]/', import.meta.url));

test('overlays: huella de la copia de pxd_inventory y versión de ox_inventory', () => {
  const { overlays, plan } = buildManifest();
  assert.ok(overlays.length >= 2);
  for (const o of overlays) {
    assert.equal(o.resource, 'ox_inventory');
    assert.match(o.path, /^web\/build\/assets\/pxd\.(css|js)$/);
    assert.equal(o.requiresVersion, '2.48.1');
    const buf = readFileSync(join(res, o.from.resource, o.from.path));
    assert.equal(o.sha256, createHash('sha256').update(buf).digest('hex'));
    assert.equal(o.size, buf.length);
  }
  const patch = plan.patches.find((p) => p.resource === 'ox_inventory');
  assert.ok(patch && patch.find === '</head>' && patch.replace.includes('./assets/pxd.css') && patch.replace.includes('./assets/pxd.js'));
  assert.ok(plan.autostart.includes('pxd_inventory'));
});

test('pxd.js no usa innerHTML (texto siempre con textContent)', () => {
  const js = readFileSync(join(res, 'pxd_inventory/overlay/ox_inventory/pxd.js'), 'utf8');
  assert.doesNotMatch(js, /innerHTML|insertAdjacentHTML|document\.write/);
});
