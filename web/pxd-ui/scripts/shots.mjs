// Capturas de la interfaz compilada con datos simulados (Chromium de Playwright).
// Uso: node scripts/shots.mjs <carpeta de salida>
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, extname, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const res = fileURLToPath(new URL('../../../server-data/resources/[proxima]/', import.meta.url));
const out = process.argv[2] || fileURLToPath(new URL('../shots/', import.meta.url));
mkdirSync(out, { recursive: true });

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml' };
const server = createServer((req, rsp) => {
  const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^([/\\])+/, '');
  const file = join(res, path);
  if (!file.startsWith(res) || !existsSync(file)) { rsp.writeHead(404); rsp.end(); return; }
  rsp.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream' });
  rsp.end(readFileSync(file));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;

const SIZES = [[1280, 720], [1920, 1080], [2560, 1080]];
const VIEWS = [
  ['hud-a-pie', 'pxd_hud/html/index.html?demo=foot'],
  ['hud-vehiculo', 'pxd_hud/html/index.html?demo=vehicle'],
  ['hud-ajustes', 'pxd_hud/html/index.html?demo=settings'],
  ['ui-avisos', 'pxd_ui/html/index.html?demo=notify'],
  ['ui-indicacion', 'pxd_ui/html/index.html?demo=text'],
  ['ui-progreso', 'pxd_ui/html/index.html?demo=progress'],
  ['ui-progreso-circulo', 'pxd_ui/html/index.html?demo=circle'],
  ['ui-dialogo', 'pxd_ui/html/index.html?demo=alert'],
];

const browser = await chromium.launch();
let errors = 0;
for (const [w, h] of SIZES) {
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  page.on('pageerror', (e) => { errors += 1; console.log('ERROR de página:', e.message); });
  for (const [name, url] of VIEWS) {
    await page.goto(`${base}/${url}`);
    await page.waitForTimeout(name.includes('progreso') ? 5200 : 900);
    await page.screenshot({ path: join(out, `${name}-${w}x${h}.png`) });
  }
  // Desbordes: nada del HUD ni del kit puede salirse de la pantalla.
  for (const url of ['pxd_hud/html/index.html?demo=vehicle', 'pxd_ui/html/index.html?demo=all']) {
    await page.goto(`${base}/${url}`);
    await page.waitForTimeout(700);
    const bad = await page.evaluate(() => {
      const out = [];
      for (const el of document.querySelectorAll('.vitals, .side, .north, .east, .car, .map-frame, .notice, .hint, .bar, .dialog')) {
        const r = el.getBoundingClientRect();
        if (r.width === 0) continue;
        if (r.left < -1 || r.top < -1 || r.right > innerWidth + 1 || r.bottom > innerHeight + 1) out.push(el.className);
      }
      return out;
    });
    if (bad.length) { errors += 1; console.log(`Fuera de pantalla en ${w}x${h} (${url}):`, bad.join(', ')); }
  }
  await page.close();
}
await browser.close();
server.close();
console.log(errors ? `Capturas con ${errors} problema(s)` : `Capturas correctas en ${out}`);
process.exit(errors ? 1 : 0);
