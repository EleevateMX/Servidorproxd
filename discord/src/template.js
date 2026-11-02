// Plantilla del servidor de Discord de Próxima RP. Puro: sin discord.js.
// Los permisos se escriben con los nombres de PermissionFlagsBits de discord.js
// y los convierte src/discord-glue.js.

export const BRAND = {
  name: 'PRÓXIMA RP',
  tagline: 'Tu próxima vida empieza aquí.',
  // docs/05-login-carga-y-marca.md
  colors: {
    night: 0x05070f,
    star: 0x5ce1ff,
    nova: 0xff4fd8,
    gold: 0xffc857,
    blue: 0x50a0ff,
    red: 0xff5a5a,
  },
  icon: 'https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/brand/portal/proxima-rp-icono-512.png',
};

const MOD = ['KickMembers', 'ModerateMembers', 'ManageMessages', 'ManageThreads', 'ManageNicknames',
  'ViewAuditLog', 'MuteMembers', 'DeafenMembers', 'MoveMembers'];

// De arriba abajo, tal y como se ven en la lista de miembros.
export const ROLES = [
  { key: 'founder', name: '👑 Fundador', color: 0xffc857, hoist: true, staff: true, perms: ['Administrator'] },
  {
    key: 'admin', name: '🛡️ Administración', color: 0xff4fd8, hoist: true, staff: true,
    perms: [...MOD, 'ManageGuild', 'ManageChannels', 'ManageRoles', 'BanMembers', 'MentionEveryone',
      'ManageEvents', 'ManageWebhooks', 'ManageGuildExpressions', 'PinMessages'],
  },
  { key: 'mod', name: '⚔️ Moderación', color: 0xff5a5a, hoist: true, staff: true, perms: MOD },
  { key: 'dev', name: '💻 Programación', color: 0x5ce1ff, hoist: true, staff: true, perms: ['ManageThreads'] },
  { key: 'support', name: '🎟️ Soporte', color: 0x50a0ff, hoist: true, staff: true, mentionable: true,
    perms: ['ManageThreads', 'ModerateMembers', 'MoveMembers'] },
  { key: 'events', name: '🎉 Eventos', color: 0xb98cff, hoist: true, staff: true, perms: ['ManageEvents', 'MoveMembers'] },
  { key: 'creator', name: '🎥 Creador de contenido', color: 0xff8fb1, hoist: true, perms: [] },
  // Recompensa cosmética de Tebex: sin ventajas en el juego (docs/09-hoja-de-ruta.md, fase 4).
  { key: 'vip', name: '💎 VIP Próxima', color: 0xffe3a3, hoist: true, perms: [] },
  { key: 'citizen', name: '✦ Ciudadano', color: 0xc9d6ff, perms: [] },
  // Roles de avisos que cada uno se pone o quita en #roles.
  { key: 'ping_events', name: '🔔 Avisos de eventos', color: 0, mentionable: true, selfAssign: true, perms: [] },
  { key: 'ping_restarts', name: '🔔 Avisos de reinicios', color: 0, mentionable: true, selfAssign: true, perms: [] },
  { key: 'ping_streams', name: '🔔 Avisos de directos', color: 0, mentionable: true, selfAssign: true, perms: [] },
];

export const STAFF_ROLES = ROLES.filter((r) => r.staff).map((r) => r.key);
export const SELF_ROLES = ROLES.filter((r) => r.selfAssign).map((r) => r.key);

// access: 'public' (todos), 'citizens' (verificados y staff), 'staff'.
// mode: 'chat', 'readonly' (solo escribe el staff), 'stat' (canal de voz que hace de contador).
// type: 'text' | 'announcement' | 'forum' | 'voice'. Anuncios y foros necesitan la
// Comunidad activada en Discord; sin ella se crean como texto (y se convierten luego).
export const CATEGORIES = [
  {
    key: 'cat_welcome', name: '✦ BIENVENIDA', access: 'public',
    channels: [
      { key: 'welcome', name: '👋│bienvenida', type: 'text', mode: 'readonly', topic: 'Cada nuevo ciudadano que llega a Próxima RP.' },
      { key: 'verify', name: '✅│verificación', type: 'text', mode: 'readonly', topic: 'Acepta las normas para ver todo el servidor.' },
      { key: 'rules', name: '📜│normas', type: 'text', mode: 'readonly', topic: 'Las normas de la ciudad y del Discord.' },
      { key: 'howto', name: '🎮│cómo-jugar', type: 'text', mode: 'readonly', topic: 'Cómo entrar a Próxima RP paso a paso.' },
      { key: 'about', name: '⭐│sobre-próxima', type: 'text', mode: 'readonly', topic: 'Qué es Próxima RP.' },
      { key: 'links', name: '🔗│enlaces', type: 'text', mode: 'readonly', topic: 'Enlaces oficiales.' },
      { key: 'roles', name: '🎭│roles', type: 'text', mode: 'readonly', access: 'citizens', topic: 'Elige qué avisos quieres recibir.' },
    ],
  },
  {
    key: 'cat_news', name: '✦ ANUNCIOS', access: 'citizens',
    channels: [
      { key: 'news', name: '📣│noticias', type: 'announcement', mode: 'readonly', topic: 'Todas las noticias de Próxima RP.' },
      { key: 'updates', name: '🛠️│actualizaciones', type: 'announcement', mode: 'readonly', topic: 'Novedades y cambios del servidor.' },
      { key: 'changelog', name: '📋│changelog', type: 'text', mode: 'readonly', topic: 'Registro técnico de cambios.' },
      { key: 'events', name: '🎉│eventos', type: 'announcement', mode: 'readonly', topic: 'Eventos de la comunidad y de los modos de juego.' },
    ],
  },
  {
    key: 'cat_city', name: '✦ LA CIUDAD', access: 'citizens',
    channels: [
      { key: 'stat_players', name: '🟢 En la ciudad: —', type: 'voice', mode: 'stat', access: 'public', match: '🟢|🔴' },
      { key: 'stat_members', name: '👥 Ciudadanos: —', type: 'voice', mode: 'stat', access: 'public', match: '👥' },
      { key: 'ic_news', name: '📰│noticias-ic', type: 'text', mode: 'readonly', topic: 'Noticias dentro del rol (IC).' },
      { key: 'government', name: '🏛️│gobierno', type: 'text', mode: 'readonly', topic: 'Comunicados del gobierno de la ciudad (IC).' },
      { key: 'city_chat', name: '💬│chat-ciudad', type: 'text', mode: 'chat', topic: 'Habla de la ciudad. Fuera de rol (OOC).' },
    ],
  },
  {
    key: 'cat_support', name: '✦ SOPORTE', access: 'citizens',
    channels: [
      { key: 'support', name: '🎫│soporte', type: 'text', mode: 'readonly', topic: 'Abre un ticket privado con el staff.' },
      { key: 'questions', name: '❓│preguntas', type: 'forum', mode: 'chat', topic: 'Pregunta lo que quieras sobre Próxima RP.' },
      { key: 'bugs', name: '🐞│reportar-bugs', type: 'forum', mode: 'chat', topic: 'Describe el fallo, cómo repetirlo y adjunta captura o clip.' },
      { key: 'ideas', name: '💡│sugerencias', type: 'forum', mode: 'chat', topic: 'Ideas para mejorar la ciudad.' },
    ],
  },
  {
    key: 'cat_community', name: '✦ COMUNIDAD', access: 'citizens',
    channels: [
      { key: 'general', name: '💬│general', type: 'text', mode: 'chat', topic: 'Charla general de la comunidad.' },
      // pxd_loadscreen/config.lua: «Comparte tus fotos en #media de nuestro Discord».
      { key: 'media', name: '📸│media', type: 'text', mode: 'chat', topic: 'Tus mejores capturas de la ciudad.' },
      { key: 'clips', name: '🎬│clips', type: 'text', mode: 'chat', topic: 'Clips y momentos del rol.' },
      { key: 'streams', name: '🔴│directos', type: 'text', mode: 'chat', topic: 'Avisa cuando estés en directo.' },
      { key: 'contests', name: '🏆│concursos', type: 'text', mode: 'readonly', topic: 'Concursos y actividades.' },
    ],
  },
  {
    key: 'cat_extras', name: '✦ EXTRAS', access: 'citizens',
    channels: [
      { key: 'offtopic', name: '🗨️│off-topic', type: 'text', mode: 'chat', topic: 'De todo un poco.' },
      { key: 'games', name: '🕹️│juegos', type: 'text', mode: 'chat', topic: 'Otros juegos.' },
      { key: 'memes', name: '😂│memes', type: 'text', mode: 'chat', topic: 'Memes (sin pasarse).' },
      { key: 'music', name: '🎵│música', type: 'text', mode: 'chat', topic: 'Comparte música.' },
    ],
  },
  {
    key: 'cat_voice', name: '✦ VOZ', access: 'citizens',
    channels: [
      { key: 'voice_lobby', name: '🔊 Sala general', type: 'voice', mode: 'chat' },
      { key: 'voice_waiting', name: '⏳ Esperando rol', type: 'voice', mode: 'chat' },
      { key: 'voice_events', name: '🎉 Eventos', type: 'voice', mode: 'chat' },
      { key: 'voice_support', name: '🎟️ Soporte por voz', type: 'voice', mode: 'chat' },
    ],
  },
  {
    key: 'cat_staff', name: '✦ STAFF', access: 'staff',
    channels: [
      { key: 'staff_notes', name: '📌│staff-avisos', type: 'text', mode: 'chat', topic: 'Avisos internos del staff.' },
      { key: 'staff_chat', name: '💬│staff-chat', type: 'text', mode: 'chat' },
      { key: 'logs', name: '📝│registros', type: 'text', mode: 'readonly', topic: 'Registro automático del bot: verificaciones, tickets y anuncios.' },
      { key: 'voice_staff', name: '🔒 Reunión staff', type: 'voice', mode: 'chat' },
    ],
  },
];

// Todos los canales con su categoría, en orden.
export function allChannels(categories = CATEGORIES) {
  return categories.flatMap((cat) => cat.channels.map((ch) => ({ ...ch, category: cat.key, access: ch.access ?? cat.access })));
}

// Normas: las cinco primeras son las mismas que se aceptan al entrar al juego
// (pxd_login/config.lua, lo comprueba tests/js/discord.test.mjs).
export const RULES = [
  'Rol ante todo: actúa como lo haría tu personaje.',
  'Nada de metagaming: lo que sabes fuera del personaje no lo sabe tu personaje.',
  'Nada de powergaming: da opciones de reacción a los demás.',
  'Prohibido usar trampas, mods de ventaja o fallos del juego.',
  'Respeto a la comunidad y al staff, dentro y fuera del rol.',
  'En Discord: nada de spam, publicidad de otros servidores ni contenido NSFW.',
  'Usa cada canal para lo que es: las dudas, en preguntas; los problemas, con un ticket en soporte.',
  'Las decisiones del staff se pueden apelar con respeto abriendo un ticket.',
];
