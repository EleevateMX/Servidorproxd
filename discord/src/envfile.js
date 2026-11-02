// Arma discord/.env a partir de .env.example y de lo que contesta el asistente. Puro.

export const isGuildId = (v) => /^\d{17,20}$/.test(String(v ?? '').trim());
// Los tokens de bot de Discord son tres trozos separados por puntos.
export const looksLikeToken = (v) => /^[\w-]{20,}\.[\w-]{4,}\.[\w-]{20,}$/.test(String(v ?? '').trim());
export const isHttps = (v) => /^https:\/\/\S+$/.test(String(v ?? '').trim());

// «123.45.67.89:30120» → valores de FIVEM_URL y FIVEM_CONNECT. null si no tiene esa forma.
export function fivemAddress(input) {
  const v = String(input ?? '').trim().replace(/^connect\s+/i, '').replace(/^https?:\/\//, '').replace(/\/+$/, '');
  const m = v.match(/^([a-z0-9.-]+)(?::(\d{2,5}))?$/i);
  if (!m) return null;
  const host = `${m[1]}:${m[2] ?? '30120'}`;
  return { FIVEM_CONNECT: host, FIVEM_URL: `http://${host}` };
}

// Leer KEY=valor de un texto .env.
export function parseEnv(text) {
  const out = {};
  for (const line of String(text ?? '').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) out[m[1]] = m[2];
  }
  return out;
}

// Rellena la plantilla (con sus comentarios) con los valores dados; las claves que no
// están en la plantilla se añaden al final.
export function buildEnv(template, values) {
  const used = new Set();
  const lines = String(template).split(/\r?\n/).map((line) => {
    const m = line.match(/^([A-Z0-9_]+)=/);
    if (!m || !(m[1] in values)) return line;
    used.add(m[1]);
    return `${m[1]}=${values[m[1]] ?? ''}`;
  });
  for (const [k, v] of Object.entries(values)) if (!used.has(k)) lines.push(`${k}=${v ?? ''}`);
  return lines.join('\n');
}
