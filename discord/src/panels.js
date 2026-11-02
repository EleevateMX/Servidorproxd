// Mensajes fijos de los canales de información (normas, cómo jugar, verificación…).
// Puro: devuelve embeds y botones como datos; src/discord-glue.js los convierte.
import { BRAND, RULES, ROLES, SELF_ROLES, allChannels } from './template.js';
import { isHttpsUrl } from './announce.js';

export const IDS = {
  verify: 'pxd:verify',
  ticketOpen: 'pxd:ticket:open',
  ticketClose: 'pxd:ticket:close',
  rolePrefix: 'pxd:role:',
};

const footer = { text: `✦ ${BRAND.tagline}` };

// Mención clicable a un canal de la plantilla (<#id>) o su nombre si aún no existe.
export function channelRef(channels, key) {
  const id = channels?.[key];
  if (id) return `<#${id}>`;
  const spec = allChannels().find((c) => c.key === key);
  return spec ? `#${spec.name}` : `#${key}`;
}

// Enlaces opcionales; solo se muestran los que son https de verdad.
export function linksFrom(env) {
  const all = [
    ['🌐', 'Web', env.LINK_WEB],
    ['🛒', 'Tienda', env.LINK_STORE],
    ['📸', 'Instagram', env.LINK_INSTAGRAM],
    ['🎵', 'TikTok', env.LINK_TIKTOK],
    ['▶️', 'YouTube', env.LINK_YOUTUBE],
    ['🔗', 'Invitación al Discord', env.LINK_DISCORD],
  ];
  return all.filter(([, , url]) => url && isHttpsUrl(url)).map(([emoji, label, url]) => ({ emoji, label, url }));
}

/**
 * env: variables de entorno (FIVEM_CONNECT, FIVEM_JOIN_URL, LINK_*).
 * channels: { claveDeCanal: id } para que las menciones sean clicables.
 * Devuelve { claveDeCanal: mensaje }.
 */
export function buildPanels(env = {}, channels = {}) {
  const ref = (key) => channelRef(channels, key);
  const join = isHttpsUrl(env.FIVEM_JOIN_URL) ? env.FIVEM_JOIN_URL : null;
  const connect = env.FIVEM_CONNECT?.trim();
  const links = linksFrom(env);

  return {
    verify: {
      embeds: [{
        color: BRAND.colors.star,
        title: '✅ Entra a Próxima RP',
        description: [
          `Antes de seguir, lee las normas en ${ref('rules')}.`,
          '',
          'Pulsa el botón para aceptarlas. Recibirás el rol **✦ Ciudadano** y verás el resto del servidor.',
        ].join('\n'),
        footer,
      }],
      buttons: [{ customId: IDS.verify, label: 'Acepto las normas', emoji: '✦', style: 'success' }],
    },

    rules: {
      embeds: [{
        color: BRAND.colors.gold,
        title: '📜 Normas de Próxima RP',
        description: RULES.map((r, i) => `**${i + 1}.** ${r}`).join('\n\n'),
        footer: { text: 'Al entrar al juego aceptas también estas normas. ✦ Tu próxima vida empieza aquí.' },
      }],
    },

    howto: {
      embeds: [{
        color: BRAND.colors.star,
        title: '🎮 Cómo entrar a la ciudad',
        description: [
          '**1.** Ten GTA V original y descarga FiveM desde https://fivem.net.',
          `**2.** Verifícate en ${ref('verify')}.`,
          connect
            ? `**3.** Abre FiveM, pulsa **F8** y escribe \`connect ${connect}\`${join ? ' o usa el botón de abajo' : ''}.`
            : `**3.** Abre FiveM y busca **Próxima RP** en la lista de servidores${join ? ' o usa el botón de abajo' : ''}.`,
          '**4.** Acepta las normas al conectar y disfruta.',
          '',
          '**Ya dentro**',
          '• **F7** o `/modos`: modos de juego (todos contra todos, deathmatch por equipos, rey de la colina y carreras).',
          '• `/salirmodo`: salir de una partida.',
          '• `/bienvenida`: volver a la pantalla de bienvenida.',
          '',
          `¿Algún problema? Abre un ticket en ${ref('support')}.`,
        ].join('\n'),
        footer,
      }],
      buttons: join ? [{ label: 'Entrar a la ciudad', emoji: '🚀', style: 'link', url: join }] : [],
    },

    about: {
      embeds: [{
        color: BRAND.colors.nova,
        title: '⭐ Qué es Próxima RP',
        description: [
          `**${BRAND.tagline}**`,
          '',
          'Servidor de rol en español para toda Latinoamérica. Vive tu historia en Los Santos o compite en modos de juego: todos contra todos, deathmatch por equipos, rey de la colina y carreras.',
          '',
          'Próxima Centauri es la estrella más cercana al Sol. Aquí empieza tu próxima vida.',
        ].join('\n'),
        thumbnail: { url: BRAND.icon },
        footer,
      }],
    },

    links: {
      embeds: [{
        color: BRAND.colors.star,
        title: '🔗 Enlaces oficiales',
        description: links.length
          ? links.map((l) => `${l.emoji} **${l.label}:** ${l.url}`).join('\n')
          : 'Pronto añadiremos aquí la web, la tienda y las redes oficiales.',
        footer: { text: 'Solo estos enlaces son oficiales. ✦ Tu próxima vida empieza aquí.' },
      }],
      buttons: links.slice(0, 5).map((l) => ({ label: l.label, emoji: l.emoji, style: 'link', url: l.url })),
    },

    roles: {
      embeds: [{
        color: BRAND.colors.nova,
        title: '🎭 Elige tus avisos',
        description: 'Pulsa un botón para recibir (o dejar de recibir) menciones de ese tipo. Púlsalo otra vez para quitártelo.',
        footer,
      }],
      buttons: SELF_ROLES.map((key) => {
        const role = ROLES.find((r) => r.key === key);
        const [emoji, ...rest] = role.name.split(' ');
        return { customId: IDS.rolePrefix + key, label: rest.join(' '), emoji, style: 'secondary' };
      }),
    },

    support: {
      embeds: [{
        color: BRAND.colors.blue,
        title: '🎫 Soporte de Próxima RP',
        description: [
          'Pulsa el botón y se abrirá un **hilo privado** entre tú y el staff.',
          '',
          'Cuéntanos: qué pasó, cuándo y, si puedes, una captura o clip.',
          'Para reportar a un jugador, indica su nombre en el juego y la hora.',
        ].join('\n'),
        footer,
      }],
      buttons: [{ customId: IDS.ticketOpen, label: 'Abrir ticket', emoji: '🎫', style: 'primary' }],
    },
  };
}

// Mensaje de bienvenida en #bienvenida.
export function welcomeMessage({ userId, memberCount, channels = {} }) {
  return {
    content: `<@${userId}>`,
    allowedMentions: { users: [userId] },
    embeds: [{
      color: BRAND.colors.star,
      title: '👋 ¡Bienvenido a Próxima RP!',
      description: [
        `**${BRAND.tagline}**`,
        '',
        `Verifícate en ${channelRef(channels, 'verify')} y lee ${channelRef(channels, 'howto')} para entrar a la ciudad.`,
      ].join('\n'),
      thumbnail: { url: BRAND.icon },
      footer: { text: Number.isFinite(memberCount) ? `Eres el ciudadano n.º ${memberCount}` : footer.text },
    }],
  };
}
