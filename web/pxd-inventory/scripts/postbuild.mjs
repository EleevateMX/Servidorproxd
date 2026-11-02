// Comprueba el resultado de vite build: nombres fijos, nada fuera de index.html + assets/pxd-inventory.{js,css}
// y cabecera de origen. Así pxd_updater puede copiarlo a ox_inventory/web/build sin crear carpetas.
import { readdirSync, readFileSync, writeFileSync, statSync } from 'node:fs';
import { sourceHash } from './source-hash.mjs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = fileURLToPath(new URL('../../../server-data/resources/[proxima]/pxd_inventory/web/', import.meta.url));
const want = ['assets/pxd-inventory.css', 'assets/pxd-inventory.js', 'index.html'];
const found = [];
const walk = (d, p = '') => {
  for (const n of readdirSync(join(d, p))) {
    const rel = p ? `${p}/${n}` : n;
    if (statSync(join(d, rel)).isDirectory()) walk(d, rel);
    else found.push(rel);
  }
};
walk(out);
found.sort();
if (JSON.stringify(found) !== JSON.stringify(want)) {
  console.error('Salida inesperada del build:', found);
  process.exit(1);
}
let html = readFileSync(join(out, 'index.html'), 'utf8');
// Rutas relativas y sin type="module" crossorigin innecesario para el esquema nui://.
html = html.replace(/\s+crossorigin/g, '');
if (!html.includes('./assets/pxd-inventory.js') || !html.includes('./assets/pxd-inventory.css')) {
  console.error('index.html no enlaza los archivos esperados');
  process.exit(1);
}
const banner = '<!-- Próxima RP · interfaz del inventario (web/pxd-inventory). Sustituye la web de ox_inventory 2.48.1; mismo contrato NUI (docs/36-inventario.md). -->\n';
if (!html.startsWith('<!-- Próxima')) html = banner + html;
writeFileSync(join(out, 'index.html'), html);
writeFileSync(fileURLToPath(new URL('../build-stamp.json', import.meta.url)), JSON.stringify({ sources: sourceHash() }, null, 1) + '\n');
for (const f of want) console.log(`${f}: ${(statSync(join(out, f)).size / 1024).toFixed(1)} KB`);
