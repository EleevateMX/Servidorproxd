// Descarga del arte (PNG/MP4) para pxd_updater.
// - Va en JavaScript porque PerformHttpRequest de Lua corta el contenido binario en el
//   primer byte nulo.
// - No escribe en disco: FXServer no deja a un recurso escribir en otro desde Node.
//   Pasa el archivo en base64 a server/main.lua, que lo guarda con SaveResourceFile
//   (con el permiso add_filesystem_permission del server.cfg).
// - Las natives solo en el hilo principal: los avisos se emiten con setImmediate.
const https = require('https');
const http = require('http');

const SAFE_PATH = /^html\/assets\/[\w.-]+$/;
const SAFE_RES = /^pxd_[a-z0-9_]+$/;
const MIN_BYTES = 1024;
const MAX_BYTES = 40 * 1024 * 1024;

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
      let size = 0;
      res.on('data', (c) => {
        size += c.length;
        if (size > MAX_BYTES) { req.destroy(new Error('archivo demasiado grande')); return; }
        chunks.push(c);
      });
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    });
    req.on('timeout', () => req.destroy(new Error('tiempo agotado')));
    req.on('error', reject);
  });
}

/** Solo recursos pxd_*, rutas dentro de html/assets y https. */
function prepare(list) {
  return (Array.isArray(list) ? list : []).filter((a) => a && SAFE_RES.test(String(a.resource))
    && SAFE_PATH.test(String(a.path)) && typeof a.url === 'string' && a.url.startsWith('https://'));
}

/**
 * Descarga cada archivo y llama a `deliver(item, base64, index, total)` con los que
 * estén bien. Devuelve los mensajes de error para el log.
 */
async function downloadAll(items, deliver, allowHttp = false) {
  const messages = [];
  let ok = 0;
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    try {
      const buf = await fetchBuffer(it.url, allowHttp);
      if (buf.length < MIN_BYTES) throw new Error('archivo demasiado pequeño');
      ok += 1;
      deliver(it, buf.toString('base64'), ok);
    } catch (e) {
      messages.push(`No se pudo descargar ${it.path}: ${e.message}`);
    }
  }
  messages.push(`Arte descargado: ${ok} de ${items.length}.`);
  return { messages, ok };
}

if (typeof on === 'function') {
  on('pxd_updater:downloadAssets', (list, src) => {
    const items = prepare(list);
    const pending = [];
    downloadAll(items, (it, b64, n) => pending.push([it, b64, n])).then(({ messages, ok }) => {
      setImmediate(() => {
        for (const m of messages) emit('pxd_updater:assetLog', src, m);
        for (const [it, b64, n] of pending) emit('pxd_updater:writeAsset', src, it.resource, it.path, b64, ok, n);
      });
    });
  });
}

if (typeof module !== 'undefined') module.exports = { fetchBuffer, downloadAll, prepare };
