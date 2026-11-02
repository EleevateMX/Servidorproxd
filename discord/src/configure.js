// Asistente para crear discord/.env haciendo preguntas (lo abre 1-configurar.bat).
import { createInterface } from 'node:readline/promises';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { stdin, stdout } from 'node:process';
import { ROOT } from './config.js';
import { buildEnv, parseEnv, isGuildId, looksLikeToken, isHttps, fivemAddress } from './envfile.js';

const envPath = join(ROOT, '.env');
const template = readFileSync(join(ROOT, '.env.example'), 'utf8');
const current = existsSync(envPath) ? parseEnv(readFileSync(envPath, 'utf8')) : parseEnv(template);
const rl = createInterface({ input: stdin, terminal: false });
const lines = rl[Symbol.asyncIterator]();

async function ask(question, { check, keep, optional = false, error }) {
  for (;;) {
    const hint = keep ? ' (Enter = dejar el que ya está)' : optional ? ' (Enter = saltar)' : '';
    stdout.write(`\n${question}${hint}\n> `);
    const next = await lines.next();
    if (next.done) {
      console.log('\nSe cerró sin terminar. No se ha guardado nada.');
      process.exit(1);
    }
    const answer = next.value.trim();
    if (!answer && keep) return keep;
    if (!answer && optional) return '';
    if (check(answer)) return answer;
    console.log(`  ✗ ${error}`);
  }
}

console.log('\n✦ PRÓXIMA RP — configurar el bot de Discord');
console.log('Contesta cada pregunta y pulsa Enter. Para pegar: clic derecho en esta ventana.');

const values = {};
values.DISCORD_TOKEN = await ask('1) Pega el TOKEN del bot (portal de Discord → Bot → Reset Token). Es secreto: no lo compartas.', {
  check: looksLikeToken, keep: current.DISCORD_TOKEN || '', error: 'Eso no parece un token. Copia el token completo (tres trozos separados por puntos).',
});
values.DISCORD_GUILD_ID = await ask('2) Pega el ID de tu servidor de Discord (clic derecho en el servidor → Copiar ID del servidor).', {
  check: isGuildId, keep: current.DISCORD_GUILD_ID || '', error: 'El ID son solo números (unos 18 o 19).',
});
const address = await ask('3) IP y puerto de tu servidor de FiveM, como en el panel del hosting (ej.: 123.45.67.89:30120).', {
  check: (v) => Boolean(fivemAddress(v)), optional: true, keep: current.FIVEM_CONNECT || '', error: 'Escríbelo como IP:PUERTO, por ejemplo 123.45.67.89:30120.',
});
if (address) Object.assign(values, fivemAddress(address));
values.FIVEM_JOIN_URL = await ask('4) Enlace para entrar con un clic (empieza por https://cfx.re/join/).', {
  check: isHttps, optional: true, keep: current.FIVEM_JOIN_URL || '', error: 'Tiene que empezar por https://',
});
values.LINK_STORE = await ask('5) Enlace de tu tienda (Tebex), si ya la tienes.', {
  check: isHttps, optional: true, keep: current.LINK_STORE || '', error: 'Tiene que empezar por https://',
});
rl.close();

writeFileSync(envPath, buildEnv(existsSync(envPath) ? readFileSync(envPath, 'utf8') : template, values));
console.log('\n✓ Guardado. Ahora abre «2-montar-servidor».');
