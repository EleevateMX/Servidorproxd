// Monta el servidor de Discord de Próxima RP a partir de la plantilla.
//   npm run setup                  → muestra lo que haría (no cambia nada)
//   npm run setup -- --aplicar     → crea roles, canales y mensajes fijos que falten
//   --permisos   vuelve a poner los permisos de la plantilla en canales que ya existían
//   --paneles    vuelve a escribir los mensajes fijos (normas, cómo jugar…)
//   --icono      pone el icono de brand/portal como icono del servidor
// Nunca borra roles, canales ni mensajes.
import { join } from 'node:path';
import { Client, Events, GatewayIntentBits, GuildFeature } from 'discord.js';
import { env, requireEnv, ART_DIR, STATE_FILE } from './config.js';
import { loadState, saveState } from './state.js';
import { planSetup, describePlan } from './plan.js';
import { buildPanels } from './panels.js';
import { CHANNEL_TYPE, kindOf, permissionBits, resolveOverwrites, panelPayload } from './discord-glue.js';

const args = new Set(process.argv.slice(2));
const apply = args.has('--aplicar');

requireEnv('DISCORD_TOKEN', 'DISCORD_GUILD_ID');

const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const ready = new Promise((resolve) => client.once(Events.ClientReady, resolve));
await client.login(env.DISCORD_TOKEN);
await ready;

try {
  const guild = await client.guilds.fetch(env.DISCORD_GUILD_ID);
  const me = await guild.members.fetchMe();
  if (!me.permissions.has('Administrator')) {
    throw new Error('El bot necesita el permiso Administrador para crear roles con permisos (ver docs/11-discord.md).');
  }
  await guild.roles.fetch();
  const channels = await guild.channels.fetch();
  const community = guild.features.includes(GuildFeature.Community);
  const state = loadState(STATE_FILE);

  const snapshot = {
    community,
    roles: guild.roles.cache.filter((r) => r.id !== guild.id && !r.managed).map((r) => ({ id: r.id, name: r.name })),
    channels: channels.filter(Boolean).map((c) => ({ id: c.id, name: c.name, type: kindOf(c), parentId: c.parentId ?? null })),
  };
  const actions = planSetup(snapshot, state, { syncPerms: args.has('--permisos') });

  console.log(`Servidor: ${guild.name}  ·  Comunidad: ${community ? 'activada' : 'NO activada (anuncios y foros se crean como texto)'}`);
  console.log(describePlan(actions));
  if (!apply) {
    console.log('\nNo se ha cambiado nada. Para aplicarlo: npm run setup -- --aplicar');
  } else {
    for (const a of actions) {
      if (a.op === 'adoptRole') state.roles[a.key] = a.id;
      if (a.op === 'adoptChannel') state.channels[a.key] = a.id;
      if (a.op === 'createRole') {
        const role = await guild.roles.create({
          name: a.spec.name,
          colors: { primaryColor: a.spec.color },
          hoist: Boolean(a.spec.hoist),
          mentionable: Boolean(a.spec.mentionable),
          permissions: permissionBits(a.spec.perms),
          reason: 'Plantilla de Próxima RP',
        });
        state.roles[a.key] = role.id;
        console.log(`✓ rol ${role.name}`);
      }
      if (a.op === 'createChannel') {
        const created = await guild.channels.create({
          name: a.name,
          type: CHANNEL_TYPE[a.type],
          ...(a.parentKey ? { parent: state.channels[a.parentKey] } : {}),
          ...(a.topic && a.type !== 'voice' ? { topic: a.topic } : {}),
          permissionOverwrites: resolveOverwrites(a.overwrites, guild, state.roles),
          reason: 'Plantilla de Próxima RP',
        });
        state.channels[a.key] = created.id;
        console.log(`✓ ${a.type} ${created.name}`);
      }
      if (a.op === 'convertToAnnouncement') {
        await guild.channels.cache.get(a.id).edit({ type: CHANNEL_TYPE.announcement, reason: 'Plantilla de Próxima RP' });
        console.log(`✓ ${a.key} ahora es canal de anuncios`);
      }
      if (a.op === 'setOverwrites') {
        await guild.channels.cache.get(state.channels[a.key])
          .permissionOverwrites.set(resolveOverwrites(a.overwrites, guild, state.roles), 'Plantilla de Próxima RP');
        console.log(`✓ permisos de ${a.key}`);
      }
      saveState(STATE_FILE, state);
    }

    // Mensajes fijos: se publican si faltan; con --paneles se reescriben.
    const panels = buildPanels(env, state.channels);
    for (const [key, panel] of Object.entries(panels)) {
      const channel = await guild.channels.fetch(state.channels[key]).catch(() => null);
      if (!channel?.isTextBased()) continue;
      const old = state.panels[key] && await channel.messages.fetch(state.panels[key]).catch(() => null);
      if (old && !args.has('--paneles')) continue;
      const msg = old ? await old.edit(panelPayload(panel, { edit: true })) : await channel.send(panelPayload(panel));
      state.panels[key] = msg.id;
      saveState(STATE_FILE, state);
      console.log(`✓ mensaje fijo en ${channel.name}`);
    }

    if (args.has('--icono')) {
      await guild.setIcon(join(ART_DIR, 'server-icon.png'), 'Icono de Próxima RP');
      console.log('✓ icono del servidor');
    }
    console.log('\nListo. Arranca el bot con: npm start');
  }
} catch (err) {
  console.error(`✗ ${err.message}`);
  process.exitCode = 1;
} finally {
  await client.destroy();
}
