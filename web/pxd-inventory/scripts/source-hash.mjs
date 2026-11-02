// Huella de las fuentes de la interfaz: si cambia alguna sin recompilar, la prueba del repo falla
// (tests/js/inventory-web.test.mjs). Mismo cálculo en el build y en la prueba.
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const design = fileURLToPath(new URL('../../../design/ui/fonts', import.meta.url));

export function sourceHash() {
  const files = [];
  const walk = (d) => {
    for (const n of readdirSync(d).sort()) {
      const p = join(d, n);
      if (statSync(p).isDirectory()) walk(p);
      else files.push(p);
    }
  };
  walk(join(root, 'src'));
  for (const f of ['index.html', 'vite.config.ts', 'package-lock.json', 'tsconfig.json']) files.push(join(root, f));
  for (const f of ['inter-latin-var.woff2', 'sora-latin-700.woff2', 'sora-latin-800.woff2']) files.push(join(design, f));
  const h = createHash('sha256');
  for (const f of files) {
    h.update(relative(root, f).replaceAll('\\', '/'));
    // Texto con saltos de línea normalizados (Windows/Linux dan la misma huella).
    const buf = readFileSync(f);
    h.update(/\.(woff2)$/.test(f) ? buf : Buffer.from(buf.toString('utf8').replace(/\r\n/g, '\n')));
  }
  return h.digest('hex');
}
