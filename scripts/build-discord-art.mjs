// Genera las imágenes del bot y del servidor de Discord en brand/discord/.
// Usa el arte de marca ya existente (key art de Kling) y lo compone con el logo en Chromium.
//   node scripts/fetch-brand-assets.mjs   (descarga los fondos, una vez)
//   node scripts/build-discord-art.mjs
import { createRequire } from 'node:module';
import { existsSync, mkdirSync, readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const assets = join(root, 'server-data/resources/[proxima]/pxd_loadscreen/html/assets');
const out = join(root, 'brand/discord');
const logo = readFileSync(join(root, 'brand/logo.svg'), 'utf8');
const { chromium } = createRequire(import.meta.url)('playwright');

const STAR = 'M72 18 C76 62 90 76 134 80 C90 84 76 98 72 142 C68 98 54 84 10 80 C54 76 68 62 72 18Z';
const bg = (file) => {
  const path = join(assets, file);
  if (!existsSync(path)) throw new Error(`Falta ${file}: ejecuta antes node scripts/fetch-brand-assets.mjs`);
  return pathToFileURL(path).href;
};

const BASE_CSS = `
  * { box-sizing: border-box; margin: 0; }
  html, body { width: 100%; height: 100%; overflow: hidden; background: #05070f; }
  body { font-family: 'Inter Display', Inter, 'Segoe UI', sans-serif; color: #eef2ff; position: relative; }
  .photo { position: absolute; inset: 0; background-size: cover; }
  .shade { position: absolute; inset: 0; }
  .grain { position: absolute; inset: 0; opacity: .5;
    background-image: radial-gradient(rgba(255,255,255,.05) 1px, transparent 1px); background-size: 3px 3px; }
`;

// Cabeceras de los mensajes fijos: texto a la izquierda, foto a la derecha.
function header({ photo, pos = 'right center', eyebrow = '✦ PRÓXIMA RP', title, sub }) {
  return `<style>${BASE_CSS}
    .photo { background-image: url('${bg(photo)}'); background-position: ${pos}; }
    .shade { background:
      linear-gradient(90deg, rgba(5,7,15,.96) 0%, rgba(5,7,15,.86) 34%, rgba(5,7,15,.25) 68%, rgba(5,7,15,.05) 100%),
      linear-gradient(0deg, rgba(5,7,15,.75) 0%, rgba(5,7,15,0) 45%); }
    .text { position: absolute; left: 96px; top: 50%; transform: translateY(-50%); max-width: 900px; }
    .eyebrow { display: flex; align-items: center; gap: 14px; font-size: 26px; font-weight: 700;
      letter-spacing: .32em; color: #5ce1ff; }
    .eyebrow svg { width: 34px; height: 34px; filter: drop-shadow(0 0 10px rgba(92,225,255,.9)); }
    h1 { margin-top: 18px; font-size: 104px; line-height: .95; font-weight: 900; letter-spacing: -.01em;
      text-transform: uppercase; text-wrap: balance; text-shadow: 0 6px 40px rgba(0,0,0,.6); }
    p { margin-top: 22px; font-size: 34px; font-weight: 500; color: #c9d6ff; }
    .bar { position: absolute; left: 0; bottom: 0; height: 8px; width: 100%;
      background: linear-gradient(90deg, #5ce1ff 0%, #ff4fd8 55%, rgba(255,79,216,0) 100%); }
  </style>
  <div class="photo"></div><div class="shade"></div><div class="grain"></div>
  <div class="text">
    <div class="eyebrow"><svg viewBox="10 18 124 124"><path d="${STAR}" fill="#fff"/></svg>${eyebrow.replace('✦ ', '')}</div>
    <h1>${title}</h1>
    <p>${sub}</p>
  </div>
  <div class="bar"></div>`;
}

// Estrella sobre cielo nocturno; con órbita para el avatar del bot.
function emblem({ orbit }) {
  return `<style>${BASE_CSS}
    body { background: radial-gradient(circle at 50% 50%, #1b2a55 0%, #0d1430 42%, #05070f 78%); }
    svg { position: absolute; inset: 0; width: 100%; height: 100%; }
  </style>
  <svg viewBox="0 0 1024 1024">
    <defs>
      <radialGradient id="g" cx="50%" cy="50%" r="50%">
        <stop offset="0" stop-color="#ffffff"/><stop offset=".3" stop-color="#5ce1ff"/>
        <stop offset="1" stop-color="#5ce1ff" stop-opacity="0"/>
      </radialGradient>
      <linearGradient id="o" x1="0" x2="1" y1="0" y2="1">
        <stop offset="0" stop-color="#5ce1ff"/><stop offset="1" stop-color="#ff4fd8"/>
      </linearGradient>
    </defs>
    <circle cx="512" cy="512" r="300" fill="url(#g)" opacity=".5"/>
    ${orbit ? `
    <ellipse cx="512" cy="512" rx="370" ry="150" fill="none" stroke="url(#o)" stroke-width="14" opacity=".9"
      transform="rotate(-24 512 512)"/>
    <circle cx="845" cy="370" r="30" fill="#ff4fd8"/>
    <circle cx="845" cy="370" r="54" fill="#ff4fd8" opacity=".25"/>` : ''}
    <g transform="translate(512 512) scale(${orbit ? 4.6 : 5.2}) translate(-72 -80)">
      <path d="${STAR}" fill="#fff"/>
      <circle cx="72" cy="80" r="7" fill="#5ce1ff"/>
    </g>
  </svg>`;
}

// Foto con el logo completo (banner del bot, banner del servidor, fondo de invitación).
function logoScene({ photo, pos = 'center', logoWidth, align = 'center', tagline = '', shade }) {
  const place = {
    center: 'left: 50%; top: 50%; transform: translate(-50%, -50%); text-align: center; align-items: center;',
    topleft: 'left: 6%; top: 8%; align-items: flex-start;',
    bottomleft: 'left: 6%; bottom: 10%; align-items: flex-start;',
  }[align];
  return `<style>${BASE_CSS}
    .photo { background-image: url('${bg(photo)}'); background-position: ${pos}; }
    .shade { background: ${shade}; }
    .brand { position: absolute; display: flex; flex-direction: column; gap: 0.6em; ${place} }
    .brand svg { width: ${logoWidth}px; height: auto; filter: drop-shadow(0 8px 30px rgba(0,0,0,.7)); }
    .tag { font-size: ${Math.round(logoWidth / 17)}px; font-weight: 600; color: #c9d6ff; letter-spacing: .04em;
      text-shadow: 0 2px 16px rgba(0,0,0,.8); }
  </style>
  <div class="photo"></div><div class="shade"></div>
  <div class="brand">${logo.replace(/<title[^>]*>.*?<\/title>/, '')}${tagline ? `<div class="tag">${tagline}</div>` : ''}</div>`;
}

const TAGLINE = 'Tu próxima vida empieza aquí.';
const vignette = 'radial-gradient(ellipse at center, rgba(5,7,15,.15) 0%, rgba(5,7,15,.75) 100%)';

// [archivo, ancho, alto, html, formato]
const JOBS = [
  // Portal de desarrolladores de Discord
  ['bot-avatar.png', 1024, 1024, emblem({ orbit: true }), 'png'],
  ['bot-banner.jpg', 680, 240, logoScene({ photo: 'keyart.png', pos: 'center 60%', logoWidth: 440, shade: vignette }), 'jpeg'],
  // Servidor
  ['server-icon.png', 1024, 1024, emblem({ orbit: false }), 'png'],
  ['server-banner.jpg', 960, 540, logoScene({ photo: 'keyart.png', pos: 'center', logoWidth: 600, tagline: TAGLINE, shade: vignette }), 'jpeg'],
  ['invite-splash.jpg', 1920, 1080, logoScene({
    photo: 'ciudad-3.png', pos: 'center', logoWidth: 520, align: 'topleft',
    shade: 'linear-gradient(180deg, rgba(5,7,15,.7) 0%, rgba(5,7,15,0) 40%)',
  }), 'jpeg'],
  // Cabeceras de los mensajes fijos (las adjunta el bot)
  ['header-bienvenida.jpg', 1600, 500, header({ photo: 'keyart.png', pos: 'right 60%', title: 'Bienvenido a la ciudad', sub: TAGLINE }), 'jpeg'],
  ['header-verificacion.jpg', 1600, 500, header({ photo: 'ciudad-3.png', pos: 'right 55%', title: 'Verificación', sub: 'Acepta las normas y entra a Próxima RP' }), 'jpeg'],
  ['header-normas.jpg', 1600, 500, header({ photo: 'slide-policia.png', pos: 'right 55%', title: 'Normas de la ciudad', sub: 'Rol ante todo. Respeto siempre.' }), 'jpeg'],
  ['header-como-jugar.jpg', 1600, 500, header({ photo: 'ciudad-1.png', pos: 'right 70%', title: 'Cómo jugar', sub: 'De FiveM a las calles de Los Santos' }), 'jpeg'],
  ['header-sobre.jpg', 1600, 500, header({ photo: 'keyart-alt.png', pos: 'right 60%', title: 'Sobre Próxima', sub: 'Rol en español para toda Latinoamérica' }), 'jpeg'],
  ['header-enlaces.jpg', 1600, 500, header({ photo: 'ciudad-4.png', pos: 'right 60%', title: 'Enlaces oficiales', sub: 'Solo estos enlaces son oficiales' }), 'jpeg'],
  ['header-roles.jpg', 1600, 500, header({ photo: 'slide-taller.png', pos: 'right 60%', title: 'Elige tus avisos', sub: 'Eventos, reinicios y directos' }), 'jpeg'],
  ['header-soporte.jpg', 1600, 500, header({ photo: 'slide-emergencias.png', pos: 'right 50%', title: 'Soporte', sub: 'Abre un ticket y habla en privado con el staff' }), 'jpeg'],
];

mkdirSync(out, { recursive: true });
const tmp = mkdtempSync(join(tmpdir(), 'pxd-art-'));
const browser = await chromium.launch();
try {
  for (const [name, width, height, html, type] of JOBS) {
    const page = await browser.newPage({ viewport: { width, height } });
    const file = join(tmp, `${name}.html`);
    writeFileSync(file, `<!doctype html><meta charset="utf-8">${html}`);
    await page.goto(pathToFileURL(file).href, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    const target = join(out, name);
    await page.screenshot({ path: target, type, ...(type === 'jpeg' ? { quality: 88 } : {}) });
    await page.close();
    console.log(`✔ brand/discord/${name} (${width}×${height})`);
  }
} finally {
  await browser.close();
  rmSync(tmp, { recursive: true, force: true });
}
