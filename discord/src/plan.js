// Calcula qué hay que crear en el servidor de Discord a partir de la plantilla.
// Puro: recibe una foto del servidor y devuelve acciones. Nunca borra nada.
import { ROLES, CATEGORIES, STAFF_ROLES, allChannels } from './template.js';

const READONLY_DENY = ['SendMessages', 'CreatePublicThreads', 'CreatePrivateThreads', 'SendMessagesInThreads'];

// Permisos de un canal o categoría como lista de { who: '@everyone' | clave de rol, allow, deny }.
// Las categorías solo marcan quién ve; cada canal lleva sus permisos completos.
export function overwritesFor({ access, mode = 'chat' }) {
  const list = [];
  const everyone = { who: '@everyone', allow: [], deny: [] };
  list.push(everyone);
  const staffAllow = [];

  if (access === 'public') everyone.allow.push('ViewChannel');
  else {
    everyone.deny.push('ViewChannel');
    staffAllow.push('ViewChannel');
    if (access === 'citizens') list.push({ who: 'citizen', allow: ['ViewChannel'], deny: [] });
  }

  if (mode === 'readonly') {
    everyone.deny.push(...READONLY_DENY);
    staffAllow.push('SendMessages', 'SendMessagesInThreads');
  }
  if (mode === 'stat') {
    // Contadores: se ven, pero nadie entra.
    everyone.deny.push('Connect');
  }
  if (staffAllow.length) {
    for (const key of STAFF_ROLES) list.push({ who: key, allow: [...staffAllow], deny: [] });
  }
  return list;
}

// Discord guarda los canales de texto en minúsculas y con guiones en vez de espacios.
export function normalizeName(name, type) {
  const n = name.trim();
  if (type === 'voice' || type === 'category') return n.toLowerCase();
  return n.toLowerCase().replace(/\s+/g, '-');
}

// Tipo real según si el servidor tiene la Comunidad activada.
export function resolveType(type, community) {
  if (type === 'announcement' || type === 'forum') return community ? type : 'text';
  return type;
}

const KIND_OF = { text: 'text', announcement: 'announcement', forum: 'forum', voice: 'voice', category: 'category' };

function findChannel(snapshot, state, spec, parentId) {
  const known = state.channels?.[spec.key];
  if (known) {
    const hit = snapshot.channels.find((c) => c.id === known);
    if (hit) return hit;
  }
  if (spec.match) {
    const re = new RegExp(`^(${spec.match})`, 'u');
    return snapshot.channels.find((c) => c.type === 'voice' && c.parentId === parentId && re.test(c.name));
  }
  const want = normalizeName(spec.name, spec.type === 'voice' ? 'voice' : spec.type === 'category' ? 'category' : 'text');
  return snapshot.channels.find((c) => {
    if (spec.type === 'category' ? c.type !== 'category' : c.type === 'category') return false;
    if (spec.type !== 'category' && (c.parentId ?? null) !== (parentId ?? null)) return false;
    return normalizeName(c.name, c.type) === want;
  });
}

/**
 * snapshot: { community: bool, roles: [{ id, name }], channels: [{ id, name, type, parentId }] }
 *   (type: 'text' | 'announcement' | 'forum' | 'voice' | 'category' | 'other')
 * state:    { roles: { clave: id }, channels: { clave: id } } (lo que creó el bot otras veces)
 * options:  { syncPerms: bool } vuelve a poner los permisos de la plantilla en lo que ya existe.
 *
 * Devuelve acciones en orden. Las de creación de canales se refieren a su categoría por
 * clave (parentKey), porque la categoría puede crearse en la misma pasada.
 */
export function planSetup(snapshot, state = {}, options = {}) {
  const actions = [];

  // Roles: se crean de abajo arriba, porque Discord coloca cada rol nuevo encima de @everyone.
  for (const role of [...ROLES].reverse()) {
    const known = state.roles?.[role.key];
    const hit = (known && snapshot.roles.find((r) => r.id === known))
      || snapshot.roles.find((r) => r.name.trim().toLowerCase() === role.name.toLowerCase());
    if (hit) actions.push({ op: 'adoptRole', key: role.key, id: hit.id });
    else actions.push({ op: 'createRole', key: role.key, spec: role });
  }

  for (const cat of CATEGORIES) {
    const catSpec = { key: cat.key, name: cat.name, type: 'category' };
    const catOw = overwritesFor({ access: cat.access, type: 'category' });
    const catHit = findChannel(snapshot, state, catSpec, null);
    if (catHit) {
      actions.push({ op: 'adoptChannel', key: cat.key, id: catHit.id });
      if (options.syncPerms) actions.push({ op: 'setOverwrites', key: cat.key, overwrites: catOw });
    } else {
      actions.push({ op: 'createChannel', key: cat.key, type: 'category', name: cat.name, overwrites: catOw });
    }

    for (const ch of allChannels([cat])) {
      const type = resolveType(ch.type, snapshot.community);
      const ow = overwritesFor(ch);
      const hit = catHit ? findChannel(snapshot, state, ch, catHit.id) : null;
      if (!hit) {
        actions.push({
          op: 'createChannel', key: ch.key, type, name: ch.name, parentKey: cat.key, topic: ch.topic, overwrites: ow,
          ...(type !== ch.type ? { wanted: ch.type } : {}),
        });
        continue;
      }
      actions.push({ op: 'adoptChannel', key: ch.key, id: hit.id });
      if (ch.type === 'announcement' && type === 'announcement' && KIND_OF[hit.type] === 'text') {
        actions.push({ op: 'convertToAnnouncement', key: ch.key, id: hit.id });
      }
      if (options.syncPerms) actions.push({ op: 'setOverwrites', key: ch.key, overwrites: ow });
    }
  }
  return actions;
}

// Resumen legible del plan (para la consola).
export function describePlan(actions) {
  const count = (op) => actions.filter((a) => a.op === op).length;
  const lines = [];
  for (const a of actions) {
    if (a.op === 'createRole') lines.push(`+ rol      ${a.spec.name}`);
    if (a.op === 'createChannel') {
      const note = a.wanted ? `  (como texto: ${a.wanted === 'announcement' ? 'anuncios' : 'foro'} necesita la Comunidad activada)` : '';
      lines.push(`+ ${a.type.padEnd(12)} ${a.name}${note}`);
    }
    if (a.op === 'convertToAnnouncement') lines.push(`~ anuncios  ${a.key} (texto → canal de anuncios)`);
    if (a.op === 'setOverwrites') lines.push(`~ permisos  ${a.key}`);
  }
  lines.push(`Total: ${count('createRole')} roles y ${count('createChannel')} canales nuevos, ` +
    `${count('adoptRole') + count('adoptChannel')} ya existían.`);
  return lines.join('\n');
}
