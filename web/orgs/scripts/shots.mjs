#!/usr/bin/env node
// Capturas de la interfaz compilada con datos simulados (?demo=1&view=…) en 720p, 1080p y 21:9.
// Uso: node scripts/shots.mjs <carpeta de salida>
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const { chromium } = createRequire(import.meta.url)('playwright');
const html = fileURLToPath(new URL('../../../server-data/resources/[proxima]/pxd_orgs/html', import.meta.url));
const out = process.argv[2];
if (!out) { console.error('Uso: node scripts/shots.mjs <carpeta>'); process.exit(1); }
mkdirSync(out, { recursive: true });

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };
const server = createServer((req, res) => {
  const file = join(html, decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/^\/+/, '') || 'index.html');
  if (!file.startsWith(html) || !existsSync(file)) { res.writeHead(404).end(); return; }
  res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' }).end(readFileSync(file));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}/index.html?demo=1`;

const SIZES = [[1280, 720], [1920, 1080], [2560, 1080]];
// [nombre, parámetros, acción previa a la captura]
const VIEWS = [
  ['inicio', '&view=home'],
  ['crear', '&view=create-form', async (page) => {
    await page.fill('input[placeholder="Los Reyes del Sur"]', 'Barrio Bajo');
    await page.fill('input[placeholder="Una frase que os defina"]', 'Desde abajo');
    await page.click('.swatch >> nth=5');
    await page.click('.fontcard >> nth=3');
    await page.click('.pick >> nth=0');
  }],
  ['fundacion-en-curso', '&view=draft'],
  ['solicitud-pendiente', '&view=pending'],
  ['organizacion-miembros', '&view=org'],
  ['organizacion-fondos', '&view=org-funds'],
  ['organizacion-identidad', '&view=org-identity'],
  ['organizacion-invitar', '&view=org-invites'],
  ['organizacion-expulsar', '&view=org&modal=kick'],
  ['organizacion-disolver', '&view=org-settings&modal=dissolve'],
  ['miembro-sin-permisos', '&view=member'],
  ['staff-solicitudes', '&view=staff'],
  ['staff-rechazar', '&view=staff&modal=reject'],
];

const browser = await chromium.launch();
const problems = [];
for (const [w, h] of SIZES) {
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  page.on('pageerror', (e) => problems.push(`${w}x${h}: ${e.message}`));
  for (const [name, query, prepare] of VIEWS) {
    await page.goto(base + query);
    await page.waitForSelector('.window');
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(350);
    if (prepare) { await prepare(page); await page.waitForTimeout(150); }
    // Nada debe salirse de la ventana ni necesitar desplazamiento horizontal.
    const overflow = await page.evaluate(() => {
      const win = document.querySelector('.window').getBoundingClientRect();
      const bad = [];
      for (const el of document.querySelectorAll('.window *')) {
        const r = el.getBoundingClientRect();
        if (r.width && (r.right > win.right + 1 || r.left < win.left - 1)) bad.push(el.className || el.tagName);
        if (el.scrollWidth > el.clientWidth + 1 && getComputedStyle(el).overflowX === 'visible' && el.clientWidth > 0 && !['OPTION', 'SELECT'].includes(el.tagName)) bad.push('desborda:' + (el.className || el.tagName));
      }
      return [...new Set(bad)].slice(0, 5);
    });
    if (overflow.length) problems.push(`${name} ${w}x${h}: ${overflow.join(', ')}`);
    await page.screenshot({ path: join(out, `${name}-${w}x${h}.png`) });
  }
  await page.close();
}
await browser.close();
server.close();
console.log(`${VIEWS.length * SIZES.length} capturas en ${out}`);
if (problems.length) { console.error('Problemas:\n' + problems.join('\n')); process.exit(1); }
