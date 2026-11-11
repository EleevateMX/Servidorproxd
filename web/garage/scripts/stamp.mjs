// Tras vite build: comprueba los nombres fijos y guarda la huella de las fuentes (build-stamp.json).
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sourceHash } from './source-hash.mjs';

const out = fileURLToPath(new URL('../../../server-data/resources/[proxima]/pxd_garage/html/', import.meta.url));
for (const f of ['index.html', 'assets/app.js', 'assets/app.css']) {
  if (!existsSync(join(out, f))) { console.error('Falta en el build:', f); process.exit(1); }
}
let html = readFileSync(join(out, 'index.html'), 'utf8').replace(/\s+crossorigin/g, '');
if (!html.includes('./assets/app.js') || !html.includes('./assets/app.css')) { console.error('index.html no enlaza assets/app.{js,css}'); process.exit(1); }
writeFileSync(join(out, 'index.html'), html);
writeFileSync(fileURLToPath(new URL('../build-stamp.json', import.meta.url)), JSON.stringify({ sources: sourceHash() }, null, 2) + '\n');
console.log('pxd_garage/html actualizado');
