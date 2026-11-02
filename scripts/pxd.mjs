#!/usr/bin/env node
// pxd — inyecta diseños en el servidor de Próxima RP a través de la API de pxd_props.
//
//   node scripts/pxd.mjs anchors                     anclas guardadas con /ancla en el juego
//   node scripts/pxd.mjs list                        layouts del servidor
//   node scripts/pxd.mjs get <id>                    JSON completo de un layout
//   node scripts/pxd.mjs compile <blueprint.json>    compila sin tocar el servidor (necesita las anclas)
//   node scripts/pxd.mjs apply <blueprint.json> [--overwrite] [--dry-run]
//   node scripts/pxd.mjs activate <id> [on|off]      visible para todos o no
//   node scripts/pxd.mjs remove <id>
//
// Configuración (variables de entorno o archivo .env en la raíz del repo):
//   PXD_URL    por defecto http://127.0.0.1:30120/pxd_props
//   PXD_TOKEN  el mismo valor que pxd_props_webToken en secrets.cfg
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { compile } from '../tools/blueprint.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

function loadEnv() {
  const file = join(root, '.env');
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
loadEnv();

const BASE = (process.env.PXD_URL || 'http://127.0.0.1:30120/pxd_props').replace(/\/+$/, '');
const TOKEN = process.env.PXD_TOKEN || '';

async function api(method, path, body) {
  if (!TOKEN) throw new Error('Falta PXD_TOKEN (el valor de pxd_props_webToken). Ponlo en .env o en el entorno.');
  let res;
  try {
    res = await fetch(`${BASE}/${path}`, {
      method,
      headers: { Authorization: `Bearer ${TOKEN}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    throw new Error(`No se pudo conectar con ${BASE} (${e.cause?.code || e.message}). ¿Está el servidor encendido y pxd_props iniciado?`);
  }
  const data = await res.json().catch(() => ({ ok: false, error: `HTTP ${res.status}` }));
  if (!data.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data.result;
}

const readJson = (file) => {
  try { return JSON.parse(readFileSync(file, 'utf8')); } catch (e) { throw new Error(`No se pudo leer ${file}: ${e.message}`); }
};

function summary(stats) {
  const models = Object.entries(stats.models).map(([m, n]) => `${n}× ${m}`).join(', ');
  return `${stats.props} props${models ? ` (${models})` : ''}, ${stats.points} puntos`;
}

async function main() {
  const [cmd, arg, ...rest] = process.argv.slice(2);
  const flags = new Set(rest.concat(arg && arg.startsWith('--') ? [arg] : []));
  switch (cmd) {
    case 'anchors': {
      const anchors = await api('GET', 'api/anchors');
      const names = Object.keys(anchors).sort();
      if (!names.length) return console.log('No hay anclas. En el juego: /ancla <nombre>');
      for (const n of names) {
        const a = anchors[n];
        console.log(`${n.padEnd(20)} x ${a.x}  y ${a.y}  z ${a.z}  rumbo ${a.h}°`);
      }
      return;
    }
    case 'list': {
      for (const l of await api('GET', 'api/layouts')) {
        console.log(`${l.active ? '●' : '○'} ${l.id.padEnd(24)} ${String(l.props).padStart(4)} props ${String(l.points).padStart(3)} puntos  ${l.name}`);
      }
      return;
    }
    case 'get':
      if (!arg) throw new Error('Uso: pxd get <id>');
      return console.log(JSON.stringify(await api('GET', `api/layouts/${encodeURIComponent(arg)}`), null, 2));
    case 'compile':
    case 'apply': {
      if (!arg || arg.startsWith('--')) throw new Error(`Uso: pxd ${cmd} <blueprint.json>`);
      const bp = readJson(arg);
      const anchors = typeof bp.anchor === 'string' ? await api('GET', 'api/anchors') : {};
      const { layout, stats } = compile(bp, anchors);
      console.log(`Blueprint «${layout.name}» → ${summary(stats)}`);
      if (cmd === 'compile' || flags.has('--dry-run')) {
        if (cmd === 'compile') console.log(JSON.stringify(layout, null, 2));
        return;
      }
      const result = await api('POST', 'api/op', { op: 'importLayout', payload: { data: layout, overwrite: flags.has('--overwrite') } });
      console.log(`Inyectado en el servidor: ${result.id} (${result.props.length} props, ${result.points.length} puntos).`);
      if (!layout.active) console.log(`Está oculto. Para que lo vean todos: node scripts/pxd.mjs activate ${result.id}`);
      return;
    }
    case 'activate': {
      if (!arg) throw new Error('Uso: pxd activate <id> [on|off]');
      const on = rest[0] !== 'off';
      await api('POST', 'api/op', { op: 'setActive', payload: { id: arg, active: on } });
      return console.log(`${arg}: ${on ? 'visible para todos' : 'oculto'}`);
    }
    case 'remove': {
      if (!arg) throw new Error('Uso: pxd remove <id>');
      await api('POST', 'api/op', { op: 'deleteLayout', payload: { id: arg } });
      return console.log(`${arg}: borrado`);
    }
    default:
      console.log(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(1, 16).map((l) => l.replace(/^\/\/ ?/, '')).join('\n'));
  }
}

main().catch((e) => {
  console.error(`✖ ${e.message}`);
  process.exit(1);
});
