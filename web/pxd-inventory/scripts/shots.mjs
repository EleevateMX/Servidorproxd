// Capturas de la interfaz compilada con datos simulados que imitan los mensajes de ox_inventory 2.48.1.
// Uso: node scripts/shots.mjs [carpeta de salida]. Usa el Chromium preinstalado (require('playwright')).
import { createServer } from 'node:http';
import { readFileSync, mkdirSync } from 'node:fs';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const web = fileURLToPath(new URL('../../../server-data/resources/[proxima]/pxd_inventory/web/', import.meta.url));
const out = process.argv[2] || fileURLToPath(new URL('../shots/', import.meta.url));
mkdirSync(out, { recursive: true });

const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };
const server = createServer((req, res) => {
  const p = join(web, decodeURIComponent(req.url.split('?')[0]) === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  try {
    res.writeHead(200, { 'Content-Type': types[extname(p)] || 'application/octet-stream' });
    res.end(readFileSync(p));
  } catch {
    res.writeHead(404).end();
  }
}).listen(0);
const base = `http://127.0.0.1:${server.address().port}/`;

const COLORS = { water: '#5ce1ff', burger: '#ffb547', phone: '#9b7bff', bandage: '#ff5472', weapon_pistol: '#c9d1ea', ammo: '#ffc857', lockpick: '#3fe08f', money: '#3fe08f', radio: '#5c8dff', id_card: '#ff4fd8', iron: '#9aa6c7', repairkit: '#ffb547' };
const icon = (name) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${COLORS[name] || '#9aa6c7'}"/><stop offset="1" stop-color="#1c2440"/></linearGradient></defs><rect x="12" y="10" width="40" height="44" rx="9" fill="url(#g)"/><rect x="20" y="18" width="24" height="6" rx="3" fill="rgba(255,255,255,.55)"/></svg>`;

const ITEMS = {
  water: { label: 'Agua', stack: true, count: 0, description: 'Botella de agua fría.' },
  burger: { label: 'Hamburguesa', stack: true, count: 0, description: 'Recién hecha.' },
  phone: { label: 'Teléfono', stack: false, count: 0 },
  bandage: { label: 'Venda', stack: true, count: 0, description: 'Detiene sangrados leves.' },
  weapon_pistol: { label: 'Pistola', stack: false, count: 0, ammoName: 'ammo' },
  ammo: { label: 'Munición 9 mm', stack: true, count: 0 },
  lockpick: { label: 'Ganzúa', stack: true, count: 0, buttons: [{ label: 'Inspeccionar' }] },
  money: { label: 'Dinero', stack: true, count: 0 },
  radio: { label: 'Radio', stack: false, count: 0 },
  id_card: { label: 'DNI', stack: false, count: 0 },
  iron: { label: 'Hierro', stack: true, count: 12 },
  repairkit: { label: 'Kit de reparación', stack: true, count: 0 },
};
const left = {
  id: 7, type: 'player', slots: 50, maxWeight: 85000, label: 'Lía Ríos', groups: { police: 2 },
  items: [
    { slot: 1, name: 'weapon_pistol', count: 1, weight: 1100, metadata: { durability: 86, ammo: 12, serial: 'PRX48213AZ', components: [] } },
    { slot: 2, name: 'phone', count: 1, weight: 190, metadata: {} },
    { slot: 3, name: 'water', count: 4, weight: 2000 },
    { slot: 4, name: 'bandage', count: 6, weight: 600 },
    { slot: 5, name: 'radio', count: 1, weight: 500 },
    { slot: 6, name: 'money', count: 2350, weight: 0 },
    { slot: 7, name: 'id_card', count: 1, weight: 10, metadata: { description: 'Lía Ríos · PROX-7KQ2', type: 'Documento' } },
    { slot: 8, name: 'burger', count: 2, weight: 440 },
    { slot: 9, name: 'lockpick', count: 3, weight: 150 },
    { slot: 12, name: 'ammo', count: 48, weight: 480 },
  ],
};
const trunk = {
  id: 'trunkPRX 123', type: 'trunk', slots: 30, maxWeight: 120000, label: 'Maletero',
  items: [
    { slot: 1, name: 'repairkit', count: 2, weight: 5000 },
    { slot: 2, name: 'water', count: 6, weight: 3000 },
    { slot: 4, name: 'iron', count: 12, weight: 6000 },
  ],
};
const shop = {
  id: 'shop', type: 'shop', slots: 12, label: '24/7 Supermercado', groups: undefined,
  items: [
    { slot: 1, name: 'water', count: 50, weight: 500, price: 15 },
    { slot: 2, name: 'burger', count: 30, weight: 220, price: 35 },
    { slot: 3, name: 'bandage', count: 0, weight: 100, price: 60 },
    { slot: 4, name: 'phone', count: 5, weight: 190, price: 900 },
  ],
};
const PXD = {
  contract: 2, name: 'Lía Ríos', id: 'PROX-7KQ2', cash: 2350, bank: 48210, canChange: true, preview: true,
  vitals: { health: 82, armour: 35, hunger: 64, thirst: 41, stress: 18 },
  clothing: [
    ['hat', 'Sombrero', 'left', false], ['mask', 'Máscara', 'left', false], ['top', 'Torso', 'left', true], ['pants', 'Pantalón', 'left', true], ['shoes', 'Zapatos', 'left', true],
    ['ears', 'Pendientes', 'right', true], ['glasses', 'Gafas', 'right', false], ['neck', 'Collar', 'right', true], ['watch', 'Reloj', 'right', true], ['bracelet', 'Pulsera', 'right', false],
    ['under', 'Camiseta interior', 'bottom', true], ['vest', 'Chaleco', 'bottom', false], ['bag', 'Mochila', 'bottom', true], ['decal', 'Insignia', 'bottom', false],
  ].map(([id, label, side, on]) => ({ id, label, icon: id, side, on })),
};

const browser = await chromium.launch();
const shots = [];
for (const [w, h, scene] of [[1920, 1080, 'maletero'], [1280, 720, 'maletero'], [2560, 1080, 'maletero'], [1920, 1080, 'tienda'], [1920, 1080, 'hotbar']]) {
  const page = await browser.newPage({ viewport: { width: w, height: h } });
  const calls = [];
  await page.route('https://ox_inventory/**', (r) => { calls.push(r.request().url().split('/').pop()); r.fulfill({ contentType: 'application/json', body: 'true' }); });
  await page.route('https://pxd_inventory/**', (r) => r.fulfill({ contentType: 'application/json', body: JSON.stringify(PXD) }));
  await page.route('https://img.mock/**', (r) => r.fulfill({ contentType: 'image/svg+xml', body: icon(r.request().url().split('/').pop().replace('.png', '')) }));
  await page.goto(base);
  // Fondo que imita el juego (en FiveM la página es transparente sobre la escena y el personaje).
  await page.addStyleTag({ content: 'body{background:radial-gradient(ellipse at 30% 60%,#3a4a6a 0,#1b2236 45%,#0b0f1c 100%)!important} body::before{content:"";position:fixed;left:calc(50vw - 55.5vh - 9vh);top:24vh;width:18vh;height:62vh;border-radius:9vh 9vh 3vh 3vh;background:linear-gradient(180deg,#56607a,#2b3248);opacity:.6}' });
  await page.evaluate(([items, leftInv]) => window.postMessage({ action: 'init', data: { locale: {}, items, imagepath: 'https://img.mock', leftInventory: leftInv } }, '*'), [ITEMS, left]);
  if (scene === 'hotbar') {
    await page.evaluate(() => window.postMessage({ action: 'toggleHotbar' }, '*'));
    await page.evaluate((it) => window.postMessage({ action: 'itemNotify', data: [it, 'ui_added', 2] }, '*'), left.items[2]);
  } else {
    await page.evaluate(([l, r]) => window.postMessage({ action: 'setupInventory', data: { leftInventory: l, rightInventory: r } }, '*'), [left, scene === 'tienda' ? shop : trunk]);
    await page.waitForTimeout(600);
    await page.click(scene === 'tienda' ? '.panel--right .slot[data-slot="2"]' : '.panel--left .slot[data-slot="1"]');
  }
  await page.waitForTimeout(700);
  const file = join(out, `inventario-${scene}-${w}x${h}.png`);
  await page.screenshot({ path: file });
  shots.push({ file, calls: [...new Set(calls)] });
  await page.close();
}
// Interacción real con el puntero: arrastrar Agua (bolsillo 3) al maletero (ranura 3), Usar la venda y
// Dividirla (3 de 6 a la primera ranura vacía: la 3, que acaba de quedar libre).
{
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  const bodies = [];
  await page.route('https://ox_inventory/**', (r) => {
    const name = r.request().url().split('/').pop();
    bodies.push([name, r.request().postData()]);
    r.fulfill({ contentType: 'application/json', body: 'true' });
  });
  await page.route('https://pxd_inventory/**', (r) => r.fulfill({ contentType: 'application/json', body: JSON.stringify(PXD) }));
  await page.route('https://img.mock/**', (r) => r.fulfill({ contentType: 'image/svg+xml', body: icon('water') }));
  await page.goto(base);
  await page.evaluate(([items, l, r]) => {
    window.postMessage({ action: 'init', data: { locale: {}, items, imagepath: 'https://img.mock', leftInventory: l } }, '*');
    window.postMessage({ action: 'setupInventory', data: { leftInventory: l, rightInventory: r } }, '*');
  }, [ITEMS, left, trunk]);
  await page.waitForTimeout(500);
  const a = await page.locator('.panel--left .slot[data-slot="3"]').boundingBox();
  const b = await page.locator('.panel--right .slot[data-slot="3"]').boundingBox();
  await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2);
  await page.mouse.down();
  await page.mouse.move(a.x + 40, a.y + 40, { steps: 4 });
  await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2, { steps: 8 });
  await page.mouse.up();
  await page.waitForTimeout(300);
  const moved = await page.locator('.panel--right .slot[data-slot="3"] .slot__label').textContent();
  await page.click('.panel--left .slot[data-slot="4"]');
  await page.click('.details .btn--primary');
  await page.click('.details >> text=Dividir');
  await page.click('.split .btn--primary');
  await page.waitForTimeout(300);
  const want = [
    ['swapItems', JSON.stringify({ fromSlot: 3, fromType: 'player', toSlot: 3, toType: 'trunk', count: 4 })],
    ['useItem', '4'],
    ['swapItems', JSON.stringify({ fromSlot: 4, fromType: 'player', toSlot: 3, toType: 'player', count: 3 })],
  ];
  const got = bodies.filter(([n]) => n !== 'uiLoaded' && n !== 'getItemData');
  const ok = moved === 'Agua' && JSON.stringify(got) === JSON.stringify(want);
  console.log(ok ? 'interacción OK' : 'interacción FALLA', JSON.stringify({ moved, got }));
  await page.screenshot({ path: join(out, 'inventario-tras-arrastrar-1920x1080.png') });
  await page.close();
  if (!ok) process.exitCode = 1;
}

await browser.close();
server.close();
for (const s of shots) console.log(s.file, '· callbacks:', s.calls.join(', '));
