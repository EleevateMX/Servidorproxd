// Convierte los datos puros (plantilla, paneles, anuncios) en objetos de discord.js.
import {
  ActionRowBuilder, ButtonBuilder, ButtonStyle, ChannelType, PermissionFlagsBits,
} from 'discord.js';

export const CHANNEL_TYPE = {
  category: ChannelType.GuildCategory,
  text: ChannelType.GuildText,
  announcement: ChannelType.GuildAnnouncement,
  forum: ChannelType.GuildForum,
  voice: ChannelType.GuildVoice,
};

export function kindOf(channel) {
  const entry = Object.entries(CHANNEL_TYPE).find(([, t]) => t === channel.type);
  return entry ? entry[0] : 'other';
}

export function permissionBits(names) {
  return names.reduce((acc, name) => {
    const bit = PermissionFlagsBits[name];
    if (bit === undefined) throw new Error(`Permiso desconocido en la plantilla: ${name}`);
    return acc | bit;
  }, 0n);
}

// { who, allow, deny } → overwrite de discord.js. who: '@everyone' o clave de rol.
export function resolveOverwrites(list, guild, roleIds) {
  return list
    .map((o) => ({
      id: o.who === '@everyone' ? guild.roles.everyone.id : roleIds[o.who],
      allow: permissionBits(o.allow),
      deny: permissionBits(o.deny),
    }))
    .filter((o) => o.id);
}

const STYLE = {
  primary: ButtonStyle.Primary,
  secondary: ButtonStyle.Secondary,
  success: ButtonStyle.Success,
  danger: ButtonStyle.Danger,
  link: ButtonStyle.Link,
};

// Botones en filas de 5 (límite de Discord).
export function buttonRows(buttons = []) {
  const rows = [];
  for (let i = 0; i < buttons.length; i += 5) {
    rows.push(new ActionRowBuilder().addComponents(buttons.slice(i, i + 5).map((b) => {
      const btn = new ButtonBuilder().setLabel(b.label).setStyle(STYLE[b.style] ?? ButtonStyle.Secondary);
      if (b.emoji) btn.setEmoji(b.emoji);
      if (b.style === 'link') btn.setURL(b.url);
      else btn.setCustomId(b.customId);
      return btn;
    })));
  }
  return rows;
}

export function panelPayload(panel) {
  return { embeds: panel.embeds, components: buttonRows(panel.buttons), allowedMentions: { parse: [] } };
}

// Claves de rol (de la plantilla) que tiene un miembro.
export function roleKeysOf(member, roleIds) {
  const byId = Object.fromEntries(Object.entries(roleIds).map(([k, id]) => [id, k]));
  return [...member.roles.cache.keys()].map((id) => byId[id]).filter(Boolean);
}
