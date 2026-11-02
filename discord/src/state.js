// Lo que el bot recuerda entre reinicios: ids de roles, canales, mensajes fijos y tickets.
import { readFileSync, writeFileSync, mkdirSync, renameSync } from 'node:fs';
import { dirname } from 'node:path';

const EMPTY = () => ({ roles: {}, channels: {}, panels: {}, tickets: {}, ticketCounter: 0 });

export function loadState(file) {
  try {
    return { ...EMPTY(), ...JSON.parse(readFileSync(file, 'utf8')) };
  } catch {
    return EMPTY();
  }
}

// Escribe en un temporal y lo renombra: si se corta a medias no se pierde el archivo.
export function saveState(file, state) {
  mkdirSync(dirname(file), { recursive: true });
  const tmp = `${file}.tmp`;
  writeFileSync(tmp, JSON.stringify(state, null, 2));
  renameSync(tmp, file);
}
