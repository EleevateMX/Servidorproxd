// Anuncios con el estilo de Próxima RP. Puro: devuelve los datos del mensaje.
import { BRAND } from './template.js';

export const KINDS = {
  news: { label: 'NOTICIAS', channel: 'news', color: BRAND.colors.star, emoji: '📣', name: 'Noticia' },
  updates: { label: 'ACTUALIZACIÓN', channel: 'updates', color: BRAND.colors.gold, emoji: '🛠️', name: 'Actualización' },
  events: { label: 'EVENTO', channel: 'events', color: BRAND.colors.nova, emoji: '🎉', name: 'Evento' },
  maintenance: { label: 'MANTENIMIENTO', channel: 'news', color: BRAND.colors.red, emoji: '🔧', name: 'Mantenimiento' },
};

// Límites de Discord para embeds: título 256, descripción 4096.
export const LIMITS = { title: 256, body: 4000 };

export function isHttpsUrl(value) {
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Devuelve { errors: [...] } o { message } listo para channel.send().
 * mention: 'none' | 'everyone' | id de un rol de avisos.
 */
export function buildAnnouncement({ kind, title, body, image = '', mention = 'none', now = Date.now() }) {
  const errors = [];
  const k = KINDS[kind];
  if (!k) errors.push('Tipo de anuncio desconocido.');
  const t = String(title ?? '').trim();
  const b = String(body ?? '').trim();
  const img = String(image ?? '').trim();
  if (!t) errors.push('Falta el titular.');
  if (t.length > LIMITS.title) errors.push(`El titular pasa de ${LIMITS.title} caracteres.`);
  if (!b) errors.push('Falta el texto.');
  if (b.length > LIMITS.body) errors.push(`El texto pasa de ${LIMITS.body} caracteres.`);
  if (img && !isHttpsUrl(img)) errors.push('La imagen tiene que ser un enlace https.');
  if (errors.length) return { errors };

  let content = '';
  let allowedMentions = { parse: [] };
  if (mention === 'everyone') {
    content = '@everyone';
    allowedMentions = { parse: ['everyone'] };
  } else if (/^\d{17,20}$/.test(mention)) {
    content = `<@&${mention}>`;
    allowedMentions = { roles: [mention] };
  }

  const embed = {
    color: k.color,
    author: { name: `${BRAND.name} — ${k.label}`, icon_url: BRAND.icon },
    title: `${k.emoji} ${t}`.slice(0, LIMITS.title),
    description: b,
    footer: { text: `✦ ${BRAND.tagline}` },
    timestamp: new Date(now).toISOString(),
    ...(img ? { image: { url: img } } : {}),
  };
  return { message: { content, embeds: [embed], allowedMentions } };
}
