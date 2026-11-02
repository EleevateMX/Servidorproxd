// Contadores del servidor: jugadores en la ciudad y miembros del Discord. Puro.

// /dynamic.json de FXServer (citizenfx/fivem, InfoHttpHandler.cpp): `clients` es un
// número y `sv_maxclients` llega como texto.
export function parseDynamic(json) {
  if (!json || typeof json !== 'object') return { online: false };
  const clients = Number(json.clients);
  const max = Number.parseInt(json.sv_maxclients, 10);
  if (!Number.isFinite(clients) || clients < 0) return { online: false };
  return { online: true, clients, max: Number.isFinite(max) && max > 0 ? max : null };
}

export function statNames({ server, members }) {
  const players = server?.online
    ? `🟢 En la ciudad: ${server.clients}${server.max ? `/${server.max}` : ''}`
    : '🔴 Ciudad cerrada';
  const people = Number.isFinite(members) ? `👥 Ciudadanos: ${members.toLocaleString('es-MX')}` : '👥 Ciudadanos: —';
  return { stat_players: players, stat_members: people };
}

// Discord limita los cambios de nombre de un canal a 2 cada 10 minutos.
export const MIN_INTERVAL_MIN = 10;
export function statsInterval(value) {
  const n = Number.parseInt(value, 10);
  return Math.max(MIN_INTERVAL_MIN, Number.isFinite(n) ? n : MIN_INTERVAL_MIN) * 60_000;
}

// URL base del servidor de FiveM (http://IP:30120). Devuelve null si no es válida.
export function dynamicUrl(base) {
  if (!base) return null;
  try {
    const u = new URL(base);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
    u.pathname = '/dynamic.json';
    u.search = '';
    return u.toString();
  } catch {
    return null;
  }
}
