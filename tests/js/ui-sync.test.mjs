import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildFiles, TARGETS } from '../../scripts/sync-ui.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));
const files = buildFiles();

for (const t of TARGETS) {
  test(`${t}: UI común sincronizada y declarada en el fxmanifest`, () => {
    const dir = join(root, 'server-data/resources/[proxima]', t);
    for (const [name, text] of Object.entries(files)) {
      assert.equal(readFileSync(join(dir, 'html/ui', name), 'utf8'), text, `${t}/html/ui/${name} desactualizado: node scripts/sync-ui.mjs`);
    }
    assert.match(readFileSync(join(dir, 'fxmanifest.lua'), 'utf8'), /'html\/ui\/\*\.css'/);
  });
}

test('la UI común no usa backdrop-filter (deja rectángulos oscuros en el juego)', () => {
  assert.doesNotMatch(files['proxima-ui.css'].replace(/\/\*[\s\S]*?\*\//g, ''), /backdrop-filter/);
});
