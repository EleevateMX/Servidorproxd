// Bot de Próxima RP: bienvenida, verificación, roles de avisos, tickets, anuncios
// y contadores. Antes de arrancarlo, monta el servidor con `npm run setup -- --aplicar`.
import {
  ChannelType, Client, Events, GatewayIntentBits, LabelBuilder, MessageFlags, ModalBuilder,
  PermissionFlagsBits, SlashCommandBuilder, TextInputBuilder, TextInputStyle,
} from 'discord.js';
import { env, requireEnv, STATE_FILE } from './config.js';
import { loadState, saveState } from './state.js';
import { ROLES } from './template.js';
import { IDS, welcomeMessage } from './panels.js';
import { KINDS, buildAnnouncement, LIMITS } from './announce.js';
import { isStaff, canAnnounce, canSelfAssign, canCloseTicket, openTicketOf, ticketName } from './access.js';
import { parseDynamic, statNames, statsInterval, dynamicUrl } from './stats.js';
import { buttonRows, roleKeysOf, resolveFiles } from './discord-glue.js';

requireEnv('DISCORD_TOKEN', 'DISCORD_GUILD_ID');
const state = loadState(STATE_FILE);
if (!Object.keys(state.channels).length) {
  console.error('No hay canales registrados. Ejecuta antes: npm run setup -- --aplicar');
  process.exit(1);
}
const save = () => saveState(STATE_FILE, state);
const ephemeral = (content) => ({ content, flags: MessageFlags.Ephemeral });

// GuildMembers es un intent privilegiado: actívalo en el portal de desarrolladores (docs/11-discord.md).
const client = new Client({ intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMembers] });

async function channel(key) {
  const id = state.channels[key];
  return id ? client.channels.fetch(id).catch(() => null) : null;
}

async function log(text) {
  const ch = await channel('logs');
  await ch?.send({ content: text, allowedMentions: { parse: [] } }).catch(() => {});
}

const memberInfo = (interaction) => ({
  keys: roleKeysOf(interaction.member, state.roles),
  isAdmin: interaction.memberPermissions?.has(PermissionFlagsBits.Administrator) ?? false,
});

// ---- Comandos ----
const commands = [
  new SlashCommandBuilder()
    .setName('anuncio')
    .setDescription('Publica un anuncio con el estilo de Próxima RP')
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageEvents)
    .addStringOption((o) => o.setName('tipo').setDescription('Tipo de anuncio').setRequired(true)
      .addChoices(...Object.entries(KINDS).map(([value, k]) => ({ name: `${k.emoji} ${k.name}`, value }))))
    .addStringOption((o) => o.setName('mencion').setDescription('A quién avisar')
      .addChoices(
        { name: 'Nadie', value: 'none' },
        { name: '@everyone', value: 'everyone' },
        ...ROLES.filter((r) => r.selfAssign).map((r) => ({ name: r.name, value: r.key })),
      )),
  new SlashCommandBuilder()
    .setName('estado')
    .setDescription('¿Está abierta la ciudad? Jugadores conectados ahora mismo'),
];

function announceModal(kind, mention) {
  const input = (id, label, style, max, required = true) => new LabelBuilder().setLabel(label)
    .setTextInputComponent(new TextInputBuilder().setCustomId(id).setStyle(style).setMaxLength(max).setRequired(required));
  return new ModalBuilder()
    .setCustomId(`pxd:anuncio:${kind}:${mention}`)
    .setTitle(`${KINDS[kind].emoji} ${KINDS[kind].name}`)
    .addLabelComponents(
      input('title', 'Titular', TextInputStyle.Short, LIMITS.title),
      input('body', 'Texto (admite **negrita** y listas)', TextInputStyle.Paragraph, LIMITS.body),
      input('image', 'Imagen (enlace https, opcional)', TextInputStyle.Short, 500, false),
    );
}

async function fetchServer() {
  const url = dynamicUrl(env.FIVEM_URL);
  if (!url) return null;
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    return parseDynamic(res.ok ? await res.json() : null);
  } catch {
    return { online: false };
  }
}

// ---- Interacciones ----
async function onCommand(interaction) {
  if (interaction.commandName === 'anuncio') {
    const kind = interaction.options.getString('tipo', true);
    const mention = interaction.options.getString('mencion') ?? 'none';
    const { keys, isAdmin } = memberInfo(interaction);
    if (!KINDS[kind] || !canAnnounce(keys, kind, isAdmin)) {
      return interaction.reply(ephemeral('No tienes permiso para publicar este tipo de anuncio.'));
    }
    return interaction.showModal(announceModal(kind, mention));
  }
  if (interaction.commandName === 'estado') {
    const server = await fetchServer();
    if (!server) return interaction.reply(ephemeral('El bot no tiene configurada la dirección del servidor (FIVEM_URL).'));
    const text = statNames({ server }).stat_players;
    const join = /^https:\/\//.test(env.FIVEM_JOIN_URL ?? '') ? env.FIVEM_JOIN_URL : null;
    return interaction.reply({
      content: text,
      components: join && server.online ? buttonRows([{ label: 'Entrar a la ciudad', emoji: '🚀', style: 'link', url: join }]) : [],
      flags: MessageFlags.Ephemeral,
    });
  }
}

async function onAnnounceModal(interaction) {
  const [, , kind, mentionKey] = interaction.customId.split(':');
  const { keys, isAdmin } = memberInfo(interaction);
  // Se vuelve a comprobar: el modal llega como una petición nueva.
  if (!KINDS[kind] || !canAnnounce(keys, kind, isAdmin)) return interaction.reply(ephemeral('No tienes permiso.'));
  const everyoneOk = interaction.memberPermissions?.has(PermissionFlagsBits.MentionEveryone);
  if (mentionKey === 'everyone' && !everyoneOk) return interaction.reply(ephemeral('No tienes permiso para mencionar a @everyone.'));
  const mention = mentionKey === 'everyone' ? 'everyone' : (ROLES.find((r) => r.key === mentionKey && r.selfAssign) ? state.roles[mentionKey] ?? 'none' : 'none');

  const result = buildAnnouncement({
    kind,
    title: interaction.fields.getTextInputValue('title'),
    body: interaction.fields.getTextInputValue('body'),
    image: interaction.fields.getTextInputValue('image'),
    mention,
  });
  if (result.errors) return interaction.reply(ephemeral(result.errors.join('\n')));

  const target = await channel(KINDS[kind].channel);
  if (!target?.isTextBased()) return interaction.reply(ephemeral('No encuentro el canal de anuncios. Ejecuta el setup.'));
  await interaction.deferReply({ flags: MessageFlags.Ephemeral });
  const msg = await target.send(result.message);
  // En canales de anuncios se publica para los servidores que lo siguen («Seguir»).
  if (target.type === ChannelType.GuildAnnouncement) await msg.crosspost().catch(() => {});
  await log(`📣 ${interaction.user.tag} publicó «${KINDS[kind].name}» en ${target}: ${msg.url}`);
  return interaction.editReply(`Publicado: ${msg.url}`);
}

async function onVerify(interaction) {
  const roleId = state.roles.citizen;
  if (!roleId) return interaction.reply(ephemeral('Falta el rol de ciudadano. Avisa al staff.'));
  if (interaction.member.roles.cache.has(roleId)) return interaction.reply(ephemeral('Ya estás verificado. ¡Bienvenido de vuelta!'));
  await interaction.member.roles.add(roleId, 'Aceptó las normas');
  await log(`✅ ${interaction.user.tag} aceptó las normas.`);
  return interaction.reply(ephemeral('¡Listo! Ya eres **✦ Ciudadano**. Tu próxima vida empieza aquí.'));
}

async function onSelfRole(interaction) {
  const key = interaction.customId.slice(IDS.rolePrefix.length);
  const roleId = state.roles[key];
  if (!canSelfAssign(key) || !roleId) return interaction.reply(ephemeral('Ese rol no se puede elegir.'));
  const has = interaction.member.roles.cache.has(roleId);
  if (has) await interaction.member.roles.remove(roleId, 'Rol de avisos');
  else await interaction.member.roles.add(roleId, 'Rol de avisos');
  const name = ROLES.find((r) => r.key === key).name;
  return interaction.reply(ephemeral(has ? `Ya no tienes ${name}.` : `Ahora tienes ${name}.`));
}

async function onTicketOpen(interaction) {
  const existing = openTicketOf(state.tickets, interaction.user.id);
  if (existing) return interaction.reply(ephemeral(`Ya tienes un ticket abierto: <#${existing}>`));
  const support = await channel('support');
  if (support?.type !== ChannelType.GuildText) return interaction.reply(ephemeral('El canal de soporte no está listo.'));
  await interaction.deferReply({ flags: MessageFlags.Ephemeral });

  state.ticketCounter += 1;
  const thread = await support.threads.create({
    name: ticketName(interaction.user.username, state.ticketCounter),
    type: ChannelType.PrivateThread,
    invitable: false,
    reason: `Ticket de ${interaction.user.tag}`,
  });
  state.tickets[thread.id] = { ownerId: interaction.user.id, number: state.ticketCounter, openedAt: Date.now() };
  save();
  await thread.members.add(interaction.user.id);
  const supportRole = state.roles.support;
  await thread.send({
    content: `<@${interaction.user.id}>${supportRole ? ` <@&${supportRole}>` : ''}`,
    allowedMentions: { users: [interaction.user.id], roles: supportRole ? [supportRole] : [] },
    embeds: [{
      color: 0x50a0ff,
      title: `🎫 Ticket n.º ${state.ticketCounter}`,
      description: 'Cuéntanos qué pasa. Alguien del staff te responderá aquí.\nCuando esté resuelto, pulsa **Cerrar ticket**.',
    }],
    components: buttonRows([{ customId: IDS.ticketClose, label: 'Cerrar ticket', emoji: '🔒', style: 'danger' }]),
  });
  await log(`🎫 ${interaction.user.tag} abrió el ticket n.º ${state.ticketCounter}: ${thread}`);
  return interaction.editReply(`Tu ticket está aquí: ${thread}`);
}

async function onTicketClose(interaction) {
  const ticket = state.tickets[interaction.channelId];
  if (!ticket || !interaction.channel?.isThread()) return interaction.reply(ephemeral('Esto no es un ticket.'));
  const { keys, isAdmin } = memberInfo(interaction);
  if (!canCloseTicket({ roleKeys: keys, isAdmin, userId: interaction.user.id, ownerId: ticket.ownerId })) {
    return interaction.reply(ephemeral('Solo quien abrió el ticket o el staff pueden cerrarlo.'));
  }
  ticket.closed = true;
  ticket.closedAt = Date.now();
  save();
  await interaction.reply(`🔒 Ticket cerrado por ${interaction.user}.`);
  await interaction.channel.setLocked(true, 'Ticket cerrado');
  await interaction.channel.setArchived(true, 'Ticket cerrado');
  await log(`🔒 ${interaction.user.tag} cerró el ticket n.º ${ticket.number}.`);
}

client.on(Events.InteractionCreate, async (interaction) => {
  if (!interaction.inGuild() || interaction.guildId !== env.DISCORD_GUILD_ID) return;
  try {
    if (interaction.isChatInputCommand()) return await onCommand(interaction);
    if (interaction.isModalSubmit() && interaction.customId.startsWith('pxd:anuncio:')) return await onAnnounceModal(interaction);
    if (!interaction.isButton()) return;
    if (interaction.customId === IDS.verify) return await onVerify(interaction);
    if (interaction.customId === IDS.ticketOpen) return await onTicketOpen(interaction);
    if (interaction.customId === IDS.ticketClose) return await onTicketClose(interaction);
    if (interaction.customId.startsWith(IDS.rolePrefix)) return await onSelfRole(interaction);
  } catch (err) {
    console.error(err);
    const reply = ephemeral('Algo falló. Inténtalo de nuevo o avisa al staff.');
    if (interaction.deferred || interaction.replied) await interaction.editReply(reply).catch(() => {});
    else await interaction.reply(reply).catch(() => {});
  }
});

client.on(Events.GuildMemberAdd, async (member) => {
  if (member.guild.id !== env.DISCORD_GUILD_ID) return;
  const ch = await channel('welcome');
  const msg = welcomeMessage({ userId: member.id, memberCount: member.guild.memberCount, channels: state.channels });
  await ch?.send({ ...msg, files: resolveFiles(msg.files) }).catch(() => {});
});

// ---- Contadores ----
async function updateStats() {
  const guild = client.guilds.cache.get(env.DISCORD_GUILD_ID);
  if (!guild) return;
  const server = await fetchServer();
  const names = statNames({ server: server ?? { online: false }, members: guild.memberCount });
  if (!server) delete names.stat_players; // sin FIVEM_URL no se toca ese contador
  for (const [key, name] of Object.entries(names)) {
    const ch = await channel(key);
    if (ch && ch.name !== name) await ch.setName(name, 'Contador').catch((e) => console.warn(`Contador ${key}: ${e.message}`));
  }
}

client.once(Events.ClientReady, async () => {
  const guild = await client.guilds.fetch(env.DISCORD_GUILD_ID);
  await guild.commands.set(commands.map((c) => c.toJSON()));
  console.log(`✦ Próxima RP en línea como ${client.user.tag} en «${guild.name}».`);
  await updateStats();
  setInterval(updateStats, statsInterval(env.STATS_INTERVAL_MIN));
});

await client.login(env.DISCORD_TOKEN);
