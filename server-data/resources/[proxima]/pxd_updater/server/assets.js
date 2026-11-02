// Descarga del arte (PNG/MP4) para pxd_updater. Va en JavaScript porque el runtime de
// Node.js del servidor maneja binarios; PerformHttpRequest de Lua corta el contenido
// en el primer byte nulo. Regla de FiveM: las natives solo en el hilo principal, así
// que las rutas se calculan al recibir el evento y los avisos se emiten con setImmediate.
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

const SAFE_PATH = /^html\/assets\/[\w.-]+$/;
const MIN_BYTES = 1024;

function fetchBuffer(url, allowHttp, redirects = 5) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https://') ? https : (allowHttp && url.startsWith('http://') ? http : null);
    if (!client) return reject(new Error('URL no permitida'));
    const req = client.get(url, { timeout: 60000 }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location && redirects > 0) {
        res.resume();
        return resolve(fetchBuffer(new URL(res.headers.location, url).toString(), allowHttp, redirects - 1));
      }
      if (res.statusCode !== 200) { res.resume(); return reject(new Error(`HTTP ${res.statusCode}`)); }
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    });
    req.on('timeout', () => req.destroy(new Error('tiempo agotado')));
    req.on('error', reject);
  });
}

/** items: [{ path, url, dest }] → mensajes para el log. */
async function downloadAll(items, allowHttp = false) {
  const messages = [];
  let ok = 0;
  for (const it of items) {
    try {
      const buf = await fetchBuffer(it.url, allowHttp);
      if (buf.length < MIN_BYTES) throw new Error(`archivo demasiado pequeño (${buf.length} bytes)`);
      fs.mkdirSync(path.dirname(it.dest), { recursive: true });
      const tmp = `${it.dest}.part`;
      fs.writeFileSync(tmp, buf);
      fs.renameSync(tmp, it.dest);
      ok += 1;
    } catch (e) {
      messages.push(`No se pudo descargar ${it.path}: ${e.message}`);
    }
  }
  messages.push(`Arte descargado: ${ok} de ${items.length}. Se verá al reconectar.`);
  return messages;
}

/** Valida la lista que manda el Lua y calcula los destinos (en el hilo principal). */
function prepare(list, getRoot) {
  const items = [];
  for (const a of Array.isArray(list) ? list : []) {
    if (!a || typeof a.resource !== 'string' || !a.resource.startsWith('pxd_')) continue;
    if (typeof a.path !== 'string' || !SAFE_PATH.test(a.path)) continue;
    if (typeof a.url !== 'string' || !a.url.startsWith('https://')) continue;
    const root = getRoot(a.resource);
    if (!root) continue;
    items.push({ path: a.path, url: a.url, dest: path.join(root, a.path) });
  }
  return items;
}

if (typeof on === 'function') {
  // Evento local (no de red): solo lo puede disparar el propio servidor.
  on('pxd_updater:downloadAssets', (list, src) => {
    const items = prepare(list, (res) => GetResourcePath(res));
    downloadAll(items).then((messages) => {
      setImmediate(() => { for (const m of messages) emit('pxd_updater:assetLog', src, m); });
    });
  });
}

if (typeof module !== 'undefined') module.exports = { fetchBuffer, downloadAll, prepare };
