// Tras compilar: guarda la huella de las fuentes (la comprueba tests/js/pxd-ui-web.test.mjs).
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { sourceHash } from './source-hash.mjs';

writeFileSync(fileURLToPath(new URL('../build-stamp.json', import.meta.url)), JSON.stringify({ sources: sourceHash() }, null, 1) + '\n');
