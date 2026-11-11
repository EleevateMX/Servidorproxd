// Huella de las fuentes de la interfaz: si cambia alguna sin recompilar, la prueba del repo falla
// (tests/js/pxd-ui-web.test.mjs). Mismo cálculo en el build y en la prueba.
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

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
  for (const f of ['kit/index.html', 'hud/index.html', 'vite.kit.config.ts', 'vite.hud.config.ts', 'package-lock.json', 'tsconfig.json']) files.push(join(root, f));
  const h = createHash('sha256');
  for (const f of files) {
    h.update(relative(root, f).replaceAll('\\', '/'));
    h.update(Buffer.from(readFileSync(f).toString('utf8').replace(/\r\n/g, '\n')));
  }
  return h.digest('hex');
}
