// Abre las interfaces en modo demo con Chromium, falla si hay errores de consola
// y guarda capturas. Uso: node tests/web/screens.mjs [carpeta-salida]
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join } from 'node:path';

const out = resolve(process.argv[2] || 'tests/web/out');
mkdirSync(out, { recursive: true });
const res_dir = resolve('server-data/resources/[proxima]');
const pages = [
  { name: 'props-web', file: 'pxd_props/html/index.html', query: '?demo=1', size: [1440, 900] },
  { name: 'props-web-movil', file: 'pxd_props/html/index.html', query: '?demo=1', size: [390, 844] },
  { name: 'modos-menu', file: 'pxd_gamemodes/html/index.html', query: '?demo=1', size: [1280, 720] },
  { name: 'modos-hud', file: 'pxd_gamemodes/html/index.html', query: '?demo=1&hud=1', size: [1280, 720] },
  { name: 'loadscreen', file: 'pxd_loadscreen/html/index.html', query: '?demo=1', size: [1920, 1080] },
  { name: 'loadscreen-transicion', file: 'pxd_loadscreen/html/index.html', query: '?demo=1&transition=1', size: [1920, 1080] },
  { name: 'login', file: 'pxd_login/html/index.html', query: '?demo=1', size: [1280, 720] },
];

// Servidor estático mínimo (fetch no funciona con file://).
const TYPES = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.mp4': 'video/mp4', '.mp3': 'audio/mpeg' };
const server = createServer(async (req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const file = join(res_dir, path);
  if (!file.startsWith(res_dir)) { res.writeHead(403); return res.end(); }
  try { const body = await readFile(file); res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream' }); res.end(body); }
  catch { res.writeHead(404); res.end(); }
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const origin = `http://127.0.0.1:${server.address().port}`;

const browser = await chromium.launch();
let failed = 0;
for (const p of pages) {
  const page = await browser.newPage({ viewport: { width: p.size[0], height: p.size[1] } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' && !/ERR_FILE_NOT_FOUND|net::|status of 404/.test(m.text())) errors.push(m.text()); });
  const url = `${origin}/${p.file}${p.query}`;
  try {
    await page.goto(url);
    await page.waitForTimeout(900);
    await page.screenshot({ path: `${out}/${p.name}.png` });
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
    if (overflow) errors.push('desbordamiento horizontal');
  } catch (e) { errors.push(e.message); }
  console.log(`${errors.length ? '✖' : '✔'} ${p.name}${errors.length ? ' — ' + errors.join(' | ') : ''}`);
  if (errors.length) failed++;
  await page.close();
}
await browser.close();
server.close();
process.exit(failed ? 1 : 0);
