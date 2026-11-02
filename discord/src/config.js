// Configuración por variables de entorno (discord/.env, ver .env.example).
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

try {
  process.loadEnvFile(join(ROOT, '.env'));
} catch {
  // Sin .env: se usan las variables del sistema (Docker, hosting).
}

export function requireEnv(...names) {
  const missing = names.filter((n) => !process.env[n]?.trim());
  if (missing.length) {
    console.error(`Faltan variables en discord/.env: ${missing.join(', ')} (copia .env.example).`);
    process.exit(1);
  }
}

export const env = process.env;
// Imágenes de brand/discord/ (en Docker se copian a /app/brand).
export const ART_DIR = join(ROOT, '..', 'brand', 'discord');
export const STATE_FILE = join(ROOT, 'data', 'state.json');
