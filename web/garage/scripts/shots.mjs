// Capturas de la interfaz compilada con datos simulados (?demo=1). Uso: node scripts/shots.mjs [carpeta].
// Usa el Chromium preinstalado (require('playwright')).
import { createServer } from 'node:http';
import { readFileSync, mkdirSync } from 'node:fs';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const web = fileURLToPath(new URL('../../../server-data/resources/[proxima]/pxd_garage/html/', import.meta.url));
const out = process.argv[2] || fileURLToPath(new URL('../shots/', import.meta.url));
mkdirSync(out, { recursive: true });

const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };
const server = createServer((req, res) => {
  const path = decodeURIComponent(req.url.split('?')[0]);
  try {
    const p = join(web, path === '/' ? 'index.html' : path);
    res.writeHead(200, { 'Content-Type': types[extname(p)] || 'application/octet-stream' });
    res.end(readFileSync(p));
  } catch { res.writeHead(404).end(); }
}).listen(0);
const base = `http://127.0.0.1:${server.address().port}/`;

const SIZES = [[1280, 720], [1920, 1080], [2560, 1080]];
const VIEWS = ['self', 'self-cart', 'self-paint', 'self-wheels', 'self-lights', 'mechanic'];
const browser = await chromium.launch();
let problems = 0;
for (const [w, h] of SIZES) {
  for (const view of VIEWS) {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    page.on('pageerror', (e) => { problems++; console.error(`[${view} ${w}x${h}]`, e.message); });
    await page.goto(`${base}index.html?demo=1&view=${view}`);
    await page.waitForTimeout(1100);
    // Nada puede salirse de la pantalla ni desbordar su panel en horizontal.
    const bad = await page.evaluate(() => {
      const out = [];
      for (const el of document.querySelectorAll('.panel, .card, .entry, .views')) {
        const r = el.getBoundingClientRect();
        // Las entradas viven en una lista con desplazamiento propio: solo se mira su ancho.
        const scrolled = el.classList.contains('entry');
        if (!scrolled && (r.left < -1 || r.right > window.innerWidth + 1 || r.top < -1 || r.bottom > window.innerHeight + 1)) out.push(`${el.className}: fuera de pantalla`);
        if (el.scrollWidth > el.clientWidth + 1) out.push(`${el.className}: desborde horizontal`);
      }
      return out;
    });
    if (bad.length) { problems += bad.length; console.error(`[${view} ${w}x${h}]`, bad.join('; ')); }
    await page.screenshot({ path: join(out, `taller-${view}-${w}x${h}.png`) });
    await page.close();
  }
}
await browser.close();
server.close();
console.log(problems ? `${problems} problema(s)` : `Capturas en ${out} sin errores de página ni desbordes`);
process.exit(problems ? 1 : 0);
