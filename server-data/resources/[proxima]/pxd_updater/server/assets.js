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

const crypto = require('crypto');
const SAFE_NAME = /^pxd_[a-z0-9_]+$/;
const SAFE_FILE = /^[A-Za-z0-9_\-./]+$/;

/** Ruta relativa segura: sin «..», sin absoluta, sin caracteres raros. */
function safeRel(p) {
  return typeof p === 'string' && SAFE_FILE.test(p) && !p.startsWith('/') && !p.split('/').some((s) => s === '..' || s === '');
}

/**
 * Escribe recursos nuevos completos en `root` (la carpeta [proxima]). Cada archivo
 * se comprueba otra vez con SHA-256 antes de escribir; un recurso se escribe en una
 * carpeta temporal y se renombra al final, para no dejarlo a medias.
 */
function installResources(packages, root) {
  const results = [];
  for (const pkg of Array.isArray(packages) ? packages : []) {
    const name = pkg && pkg.name;
    try {
      if (!SAFE_NAME.test(String(name))) throw new Error('nombre no permitido');
      const files = Array.isArray(pkg.files) ? pkg.files : [];
      if (files.length === 0) throw new Error('sin archivos');
      const final = path.join(root, name);
      if (fs.existsSync(final)) throw new Error('la carpeta ya existe');
      const tmp = path.join(root, `.${name}.part`);
      fs.rmSync(tmp, { recursive: true, force: true });
      for (const f of files) {
        if (!safeRel(f.path)) throw new Error(`ruta no permitida: ${f.path}`);
        const buf = Buffer.from(String(f.body), 'utf8');
        const sha = crypto.createHash('sha256').update(buf).digest('hex');
        if (sha !== f.sha256) throw new Error(`huella incorrecta en ${f.path}`);
        const dest = path.join(tmp, f.path);
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        fs.writeFileSync(dest, buf);
      }
      fs.renameSync(tmp, final);
      results.push({ name, ok: true });
    } catch (e) {
      try { fs.rmSync(path.join(root, `.${name}.part`), { recursive: true, force: true }); } catch (_) { /* nada */ }
      results.push({ name: String(name), ok: false, message: e.message });
    }
  }
  return results;
}

const zlib = require('zlib');
const MAX_ZIP_BYTES = 80 * 1024 * 1024;

/**
 * Descomprime un .zip (método 0 «stored» u 8 «deflate») en `dest`, quitando la
 * carpeta raíz que pone GitHub («repo-main/»). Rechaza rutas peligrosas.
 */
function unzipTo(buf, dest) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= Math.max(0, buf.length - 65557); i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('zip no válido');
  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  let written = 0;
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) throw new Error('zip dañado');
    const method = buf.readUInt16LE(p + 10);
    const csize = buf.readUInt32LE(p + 20);
    const usize = buf.readUInt32LE(p + 24);
    const nlen = buf.readUInt16LE(p + 28);
    const elen = buf.readUInt16LE(p + 30);
    const clen = buf.readUInt16LE(p + 32);
    const local = buf.readUInt32LE(p + 42);
    const name = buf.toString('utf8', p + 46, p + 46 + nlen);
    p += 46 + nlen + elen + clen;
    const rel = name.split('/').slice(1).join('/');          // sin «repo-main/»
    if (!rel || name.endsWith('/')) continue;                 // carpetas
    if (!safeRel(rel)) throw new Error(`ruta no permitida en el zip: ${rel}`);
    if (buf.readUInt32LE(local) !== 0x04034b50) throw new Error('zip dañado');
    const start = local + 30 + buf.readUInt16LE(local + 26) + buf.readUInt16LE(local + 28);
    const raw = buf.subarray(start, start + csize);
    const data = method === 0 ? raw : method === 8 ? zlib.inflateRawSync(raw) : null;
    if (!data) throw new Error(`compresión no soportada en ${rel}`);
    if (data.length !== usize) throw new Error(`tamaño incorrecto en ${rel}`);
    written += data.length;
    if (written > MAX_ZIP_BYTES) throw new Error('el zip es demasiado grande');
    const out = path.join(dest, rel);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, data);
  }
}

const SAFE_EXT_NAME = /^[A-Za-z0-9_-]+$/;
const SAFE_CATEGORY = /^\[[A-Za-z0-9_-]+\]$/;
const SAFE_REPO = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const SAFE_REF = /^[A-Za-z0-9_.-]+$/;

/**
 * Instala recursos de terceros desde GitHub (zip de una rama) en
 * resources/<categoría>/<nombre>. No toca los que ya existan.
 */
async function installExternal(list, resourcesRoot, opts = {}) {
  const results = [];
  for (const e of Array.isArray(list) ? list : []) {
    const name = e && e.name;
    try {
      if (!SAFE_EXT_NAME.test(String(name)) || !SAFE_CATEGORY.test(String(e.category))
        || !SAFE_REPO.test(String(e.repo)) || !SAFE_REF.test(String(e.ref))) throw new Error('datos no permitidos');
      const dir = path.join(resourcesRoot, e.category);
      const final = path.join(dir, name);
      if (fs.existsSync(final)) throw new Error('la carpeta ya existe');
      const url = opts.urlFor ? opts.urlFor(e) : `https://codeload.github.com/${e.repo}/zip/refs/heads/${e.ref}`;
      const buf = await fetchBuffer(url, Boolean(opts.allowHttp));
      const tmp = path.join(dir, `.${name}.part`);
      fs.rmSync(tmp, { recursive: true, force: true });
      fs.mkdirSync(tmp, { recursive: true });
      try {
        unzipTo(buf, tmp);
        if (!fs.existsSync(path.join(tmp, 'fxmanifest.lua'))) throw new Error('no trae fxmanifest.lua');
        fs.renameSync(tmp, final);
      } catch (err) {
        fs.rmSync(tmp, { recursive: true, force: true });
        throw err;
      }
      results.push({ name, ok: true });
    } catch (err) {
      results.push({ name: String(name), ok: false, message: err.message });
    }
  }
  return results;
}

if (typeof on === 'function') {
  on('pxd_updater:installExternal', (list, src) => {
    const resourcesRoot = path.dirname(path.dirname(GetResourcePath(GetCurrentResourceName())));
    installExternal(list, resourcesRoot).then((results) => {
      setImmediate(() => emit('pxd_updater:externalDone', src, results));
    });
  });

  on('pxd_updater:installResources', (packages, src) => {
    const root = path.dirname(GetResourcePath(GetCurrentResourceName()));
    const results = installResources(packages, root);
    setImmediate(() => emit('pxd_updater:installDone', src, results));
  });

  // Evento local (no de red): solo lo puede disparar el propio servidor.
  on('pxd_updater:downloadAssets', (list, src) => {
    const items = prepare(list, (res) => GetResourcePath(res));
    downloadAll(items).then((messages) => {
      setImmediate(() => { for (const m of messages) emit('pxd_updater:assetLog', src, m); });
    });
  });
}

if (typeof module !== 'undefined') module.exports = { fetchBuffer, downloadAll, prepare, installResources, safeRel, unzipTo, installExternal };
