// Genera el fondo de pantalla del teléfono (SVG determinista) y lo pasa a JPG con Chromium.
// Uso: node scripts/generar-fondo-telefono.mjs <salida.svg> <salida.jpg>
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const [svgOut, pngOut] = process.argv.slice(2);
const W = 1080, H = 2340;
let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
const stars = Array.from({ length: 220 }, () => {
  const x = rnd() * W, y = rnd() * H * 0.72, r = rnd() < 0.12 ? 2.2 : 1 + rnd() * 0.8, o = 0.25 + rnd() * 0.7;
  return `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r.toFixed(2)}" fill="#fff" opacity="${o.toFixed(2)}"/>`;
}).join('');
// Silueta de ciudad con ventanas encendidas
let x = 0, city = '', windows = '';
while (x < W) {
  const w = 50 + rnd() * 110, h = 180 + rnd() * 520, top = H - h;
  city += `<rect x="${x.toFixed(1)}" y="${top.toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}"/>`;
  for (let wy = top + 24; wy < H - 30; wy += 34) for (let wx = x + 12; wx < x + w - 14; wx += 22)
    if (rnd() < 0.16) windows += `<rect x="${wx.toFixed(1)}" y="${wy.toFixed(1)}" width="8" height="12" rx="1.5" fill="${rnd() < 0.6 ? '#5ce1ff' : (rnd() < 0.5 ? '#ff4fd8' : '#ffc857')}" opacity="${(0.35 + rnd() * 0.5).toFixed(2)}"/>`;
  x += w + 4 + rnd() * 10;
}
const STAR = 'M80 12 C85 62 98 75 148 80 C98 85 85 98 80 148 C75 98 62 85 12 80 C62 75 75 62 80 12Z';
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">
<defs>
  <radialGradient id="sky" cx="72%" cy="22%" r="95%"><stop offset="0" stop-color="#2a2f6e"/><stop offset=".35" stop-color="#121845"/><stop offset=".7" stop-color="#070a1c"/><stop offset="1" stop-color="#05070f"/></radialGradient>
  <radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#5ce1ff" stop-opacity=".55"/><stop offset=".45" stop-color="#5ce1ff" stop-opacity=".12"/><stop offset="1" stop-color="#ff4fd8" stop-opacity="0"/></radialGradient>
  <linearGradient id="haze" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff4fd8" stop-opacity="0"/><stop offset="1" stop-color="#ff4fd8" stop-opacity=".22"/></linearGradient>
  <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05070f" stop-opacity="0"/><stop offset="1" stop-color="#05070f" stop-opacity=".9"/></linearGradient>
</defs>
<rect width="${W}" height="${H}" fill="url(#sky)"/>
${stars}
<rect x="0" y="${H * 0.55}" width="${W}" height="${H * 0.45}" fill="url(#haze)"/>
<circle cx="${W * 0.72}" cy="${H * 0.2}" r="330" fill="url(#glow)"/>
<g transform="translate(${W * 0.72 - 96} ${H * 0.2 - 96}) scale(1.2)"><path d="${STAR}" fill="#ffffff"/></g>
<g fill="#070914">${city}</g>
${windows}
<rect x="0" y="${H - 420}" width="${W}" height="420" fill="url(#fade)"/>
</svg>`;
writeFileSync(svgOut, svg);
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: W / 2, height: H / 2 }, deviceScaleFactor: 2 });
await p.setContent(`<style>html,body{margin:0}</style>${svg.replace(`width="${W}" height="${H}"`, `width="${W / 2}" height="${H / 2}"`)}`);
await p.screenshot({ path: pngOut, type: 'jpeg', quality: 86 });
await b.close();
console.log('ok');
