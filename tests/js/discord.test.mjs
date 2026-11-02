// Bot de Discord: plantilla, plan de montaje, permisos, anuncios, contadores y paneles.
// Solo módulos puros (no necesitan discord.js instalado).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { ROLES, CATEGORIES, STAFF_ROLES, SELF_ROLES, RULES, allChannels } from '../../discord/src/template.js';
import { planSetup, overwritesFor, normalizeName, resolveType, describePlan } from '../../discord/src/plan.js';
import { canAnnounce, canCloseTicket, canSelfAssign, isStaff, openTicketOf, ticketName } from '../../discord/src/access.js';
import { buildAnnouncement, KINDS } from '../../discord/src/announce.js';
import { parseDynamic, statNames, statsInterval, dynamicUrl } from '../../discord/src/stats.js';
import { buildPanels, linksFrom, welcomeMessage, IDS } from '../../discord/src/panels.js';

const root = new URL('../../', import.meta.url).pathname;

// PermissionFlagsBits de discord.js 14.28.0 (comprobado en tiempo de ejecución).
const PERMS = new Set(('CreateInstantInvite,KickMembers,BanMembers,Administrator,ManageChannels,ManageGuild,AddReactions,' +
  'ViewAuditLog,PrioritySpeaker,Stream,ViewChannel,SendMessages,SendTTSMessages,ManageMessages,EmbedLinks,AttachFiles,' +
  'ReadMessageHistory,MentionEveryone,UseExternalEmojis,ViewGuildInsights,Connect,Speak,MuteMembers,DeafenMembers,' +
  'MoveMembers,UseVAD,ChangeNickname,ManageNicknames,ManageRoles,ManageWebhooks,ManageEmojisAndStickers,' +
  'ManageGuildExpressions,UseApplicationCommands,RequestToSpeak,ManageEvents,ManageThreads,CreatePublicThreads,' +
  'CreatePrivateThreads,UseExternalStickers,SendMessagesInThreads,UseEmbeddedActivities,ModerateMembers,' +
  'ViewCreatorMonetizationAnalytics,UseSoundboard,CreateGuildExpressions,CreateEvents,UseExternalSounds,' +
  'SendVoiceMessages,SetVoiceChannelStatus,SendPolls,UseExternalApps,PinMessages,BypassSlowmode').split(','));

const empty = { community: true, roles: [], channels: [] };

test('plantilla: claves únicas, permisos que existen y nombres dentro de los límites', () => {
  // Roles y canales se guardan por separado (state.roles / state.channels).
  for (const keys of [ROLES.map((r) => r.key), [...CATEGORIES.map((c) => c.key), ...allChannels().map((c) => c.key)]]) {
    assert.equal(new Set(keys).size, keys.length, 'claves repetidas');
  }
  for (const r of ROLES) {
    for (const p of r.perms) assert.ok(PERMS.has(p), `${r.key}: permiso ${p}`);
    assert.ok(r.name.length <= 100);
    assert.ok(Number.isInteger(r.color) && r.color >= 0 && r.color <= 0xffffff);
  }
  for (const c of allChannels()) {
    assert.ok(c.name.length <= 100, c.name);
    assert.ok(!c.topic || c.topic.length <= 1024);
    for (const o of overwritesFor(c)) for (const p of [...o.allow, ...o.deny]) assert.ok(PERMS.has(p), p);
  }
  // Canales que usa el bot.
  for (const key of ['welcome', 'verify', 'rules', 'howto', 'roles', 'support', 'logs', 'news', 'updates', 'events', 'stat_players', 'stat_members']) {
    assert.ok(allChannels().some((c) => c.key === key), `falta ${key}`);
  }
  for (const k of Object.values(KINDS)) assert.ok(allChannels().some((c) => c.key === k.channel));
  assert.ok(SELF_ROLES.length > 0 && STAFF_ROLES.includes('founder'));
});

test('identidad propia: nada de GTAHUB ni Rockstar en lo que publica el bot', () => {
  const text = JSON.stringify({ ROLES, CATEGORIES, RULES, panels: buildPanels({}) }).toLowerCase();
  for (const word of ['gtahub', 'hub |', 'rockstar']) assert.ok(!text.includes(word), word);
});

test('normas: incluyen las mismas que se aceptan al entrar al juego (pxd_login)', () => {
  const lua = readFileSync(`${root}server-data/resources/[proxima]/pxd_login/config.lua`, 'utf8');
  const block = lua.match(/Config\.rules = \{([\s\S]*?)\n\}/)[1];
  const loginRules = [...block.matchAll(/'([^']+)'/g)].map((m) => m[1]);
  assert.ok(loginRules.length >= 3);
  for (const r of loginRules) assert.ok(RULES.includes(r), `falta en Discord: ${r}`);
});

test('permisos: público, solo verificados, solo staff, solo lectura y contadores', () => {
  const pub = overwritesFor({ access: 'public', mode: 'readonly' });
  const everyone = pub.find((o) => o.who === '@everyone');
  assert.ok(everyone.allow.includes('ViewChannel') && everyone.deny.includes('SendMessages'));
  assert.ok(pub.find((o) => o.who === 'admin').allow.includes('SendMessages'));

  const cit = overwritesFor({ access: 'citizens', mode: 'chat' });
  assert.ok(cit.find((o) => o.who === '@everyone').deny.includes('ViewChannel'));
  assert.ok(cit.find((o) => o.who === 'citizen').allow.includes('ViewChannel'));
  assert.ok(cit.find((o) => o.who === 'support').allow.includes('ViewChannel'));

  const staff = overwritesFor({ access: 'staff', mode: 'chat' });
  assert.ok(!staff.some((o) => o.who === 'citizen'));
  assert.ok(!staff.some((o) => o.who === 'creator' || o.who === 'vip'));

  const stat = overwritesFor({ access: 'public', mode: 'stat' });
  assert.ok(stat.find((o) => o.who === '@everyone').deny.includes('Connect'));

  // Los canales del staff no los ve nadie más.
  for (const c of allChannels().filter((ch) => ch.category === 'cat_staff')) assert.equal(c.access, 'staff');
});

test('plan: en un servidor vacío lo crea todo, roles de abajo arriba', () => {
  const actions = planSetup(empty, {});
  const roles = actions.filter((a) => a.op === 'createRole').map((a) => a.key);
  assert.deepEqual(roles, ROLES.map((r) => r.key).reverse());
  const created = actions.filter((a) => a.op === 'createChannel');
  assert.equal(created.length, CATEGORIES.length + allChannels().length);
  // Cada canal va después de su categoría.
  const seen = new Set();
  for (const a of created) {
    if (a.parentKey) assert.ok(seen.has(a.parentKey), `${a.key} antes que ${a.parentKey}`);
    seen.add(a.key);
  }
  assert.ok(!actions.some((a) => /delete|remove/i.test(a.op)), 'nunca borra');
  assert.match(describePlan(actions), /Total: 12 roles/);
});

test('plan: sin Comunidad, anuncios y foros se crean como texto', () => {
  const actions = planSetup({ ...empty, community: false }, {});
  const news = actions.find((a) => a.key === 'news');
  assert.equal(news.type, 'text');
  assert.equal(news.wanted, 'announcement');
  assert.equal(actions.find((a) => a.key === 'questions').type, 'text');
  assert.equal(resolveType('voice', false), 'voice');
});

test('plan: reutiliza lo que ya existe (por id guardado o por nombre) y no duplica', () => {
  const snapshot = {
    community: true,
    roles: [{ id: 'r1', name: '✦ Ciudadano' }, { id: 'r2', name: 'Otro rol' }],
    channels: [
      { id: 'c1', name: '✦ BIENVENIDA', type: 'category', parentId: null },
      { id: 'c2', name: '📜│normas', type: 'text', parentId: 'c1' },
      { id: 'c3', name: '✦ ANUNCIOS', type: 'category', parentId: null },
      { id: 'c4', name: '📣│noticias', type: 'text', parentId: 'c3' },
      { id: 'c5', name: '✦ LA CIUDAD', type: 'category', parentId: null },
      { id: 'c6', name: '🔴 Ciudad cerrada', type: 'voice', parentId: 'c5' },
      { id: 'c7', name: '👋│bienvenida', type: 'text', parentId: null }, // fuera de su categoría
    ],
  };
  const actions = planSetup(snapshot, { roles: { founder: 'gone' }, channels: { stat_members: 'c99' } });
  const adopted = Object.fromEntries(actions.filter((a) => a.op.startsWith('adopt')).map((a) => [a.key, a.id]));
  assert.equal(adopted.citizen, 'r1');
  assert.equal(adopted.rules, 'c2');
  assert.equal(adopted.stat_players, 'c6', 'el contador se reconoce aunque haya cambiado de nombre');
  assert.ok(actions.some((a) => a.op === 'createRole' && a.key === 'founder'), 'id guardado que ya no existe → se crea');
  assert.ok(actions.some((a) => a.op === 'createChannel' && a.key === 'welcome'));
  assert.ok(actions.some((a) => a.op === 'convertToAnnouncement' && a.id === 'c4'));
  assert.ok(!actions.some((a) => a.op === 'setOverwrites'), 'sin --permisos no toca lo existente');
  const synced = planSetup(snapshot, {}, { syncPerms: true });
  assert.ok(synced.some((a) => a.op === 'setOverwrites' && a.key === 'rules'));
  assert.equal(normalizeName('Mi Canal  Nuevo', 'text'), 'mi-canal-nuevo');
});

test('acceso: anuncios, tickets y roles de avisos', () => {
  assert.ok(canAnnounce(['admin'], 'news'));
  assert.ok(canAnnounce([], 'maintenance', true));
  assert.ok(canAnnounce(['events'], 'events'));
  assert.ok(!canAnnounce(['events'], 'news'));
  assert.ok(!canAnnounce(['citizen', 'vip'], 'events'));
  assert.ok(isStaff(['support']) && !isStaff(['creator']));
  assert.ok(canCloseTicket({ roleKeys: [], userId: 'u1', ownerId: 'u1' }));
  assert.ok(!canCloseTicket({ roleKeys: ['citizen'], userId: 'u2', ownerId: 'u1' }));
  assert.ok(canCloseTicket({ roleKeys: ['mod'], userId: 'u2', ownerId: 'u1' }));
  assert.ok(!canCloseTicket({ roleKeys: [], userId: 'u2', ownerId: undefined }));
  assert.ok(canSelfAssign('ping_events') && !canSelfAssign('admin') && !canSelfAssign('citizen'));
  assert.equal(openTicketOf({ t1: { ownerId: 'u1', closed: true }, t2: { ownerId: 'u1' } }, 'u1'), 't2');
  assert.equal(openTicketOf({}, 'u1'), null);
  assert.equal(ticketName('Pepe_Ñ!😀', 7), '🎫 ticket-0007-pepe_');
  assert.equal(ticketName('😀', 1), '🎫 ticket-0001-ciudadano');
});

test('anuncios: estilo, menciones seguras y validación', () => {
  const now = Date.UTC(2026, 10, 2, 18, 0);
  const ok = buildAnnouncement({ kind: 'events', title: 'Carrera nocturna', body: 'Este sábado en el puerto.', now });
  const e = ok.message.embeds[0];
  assert.equal(e.color, 0xff4fd8);
  assert.equal(e.title, '🎉 Carrera nocturna');
  assert.match(e.author.name, /PRÓXIMA RP — EVENTO/);
  assert.equal(e.timestamp, '2026-11-02T18:00:00.000Z');
  assert.deepEqual(ok.message.allowedMentions, { parse: [] });
  assert.equal(ok.message.content, '');

  const all = buildAnnouncement({ kind: 'news', title: 'a', body: 'b', mention: 'everyone' });
  assert.deepEqual(all.message.allowedMentions, { parse: ['everyone'] });
  const role = buildAnnouncement({ kind: 'news', title: 'a', body: 'b', mention: '123456789012345678' });
  assert.equal(role.message.content, '<@&123456789012345678>');
  assert.deepEqual(role.message.allowedMentions, { roles: ['123456789012345678'] });
  const junk = buildAnnouncement({ kind: 'news', title: 'a', body: 'b', mention: '@here' });
  assert.deepEqual(junk.message.allowedMentions, { parse: [] });

  assert.ok(buildAnnouncement({ kind: 'nope', title: 'a', body: 'b' }).errors);
  assert.ok(buildAnnouncement({ kind: 'news', title: ' ', body: 'b' }).errors);
  assert.ok(buildAnnouncement({ kind: 'news', title: 'x'.repeat(257), body: 'b' }).errors);
  assert.ok(buildAnnouncement({ kind: 'news', title: 'a', body: 'b', image: 'http://inseguro/x.png' }).errors);
  assert.ok(buildAnnouncement({ kind: 'news', title: 'a', body: 'b', image: 'javascript:alert(1)' }).errors);
  assert.equal(buildAnnouncement({ kind: 'news', title: 'a', body: 'b', image: 'https://x.io/a.png' }).message.embeds[0].image.url, 'https://x.io/a.png');
});

test('contadores: /dynamic.json de FXServer y límites de Discord', () => {
  assert.deepEqual(parseDynamic({ clients: 12, sv_maxclients: '48', hostname: 'x' }), { online: true, clients: 12, max: 48 });
  assert.deepEqual(parseDynamic({ clients: 0, sv_maxclients: 'abc' }), { online: true, clients: 0, max: null });
  assert.deepEqual(parseDynamic(null), { online: false });
  assert.deepEqual(parseDynamic({ clients: 'x' }), { online: false });
  const names = statNames({ server: { online: true, clients: 12, max: 48 }, members: 1361 });
  assert.equal(names.stat_players, '🟢 En la ciudad: 12/48');
  assert.equal(names.stat_members, '👥 Ciudadanos: 1,361');
  assert.equal(statNames({ server: { online: false } }).stat_players, '🔴 Ciudad cerrada');
  // Los nombres nuevos siguen encajando con el patrón con el que el plan los reconoce.
  const match = allChannels().find((c) => c.key === 'stat_players').match;
  assert.match('🔴 Ciudad cerrada', new RegExp(`^(${match})`, 'u'));
  assert.equal(statsInterval('3'), 600_000);
  assert.equal(statsInterval('15'), 900_000);
  assert.equal(statsInterval(undefined), 600_000);
  assert.equal(dynamicUrl('http://1.2.3.4:30120'), 'http://1.2.3.4:30120/dynamic.json');
  assert.equal(dynamicUrl('ftp://x'), null);
  assert.equal(dynamicUrl(''), null);
});

test('paneles: botones válidos, enlaces solo https y menciones clicables', () => {
  const panels = buildPanels(
    { FIVEM_JOIN_URL: 'https://cfx.re/join/abc123', FIVEM_CONNECT: '1.2.3.4:30120', LINK_STORE: 'https://tienda.example', LINK_WEB: 'http://inseguro.example' },
    { rules: '111111111111111111', support: '222222222222222222' },
  );
  assert.match(panels.verify.embeds[0].description, /<#111111111111111111>/);
  assert.match(panels.howto.embeds[0].description, /connect 1\.2\.3\.4:30120/);
  assert.match(panels.howto.embeds[0].description, /<#222222222222222222>/);
  assert.equal(panels.howto.buttons[0].url, 'https://cfx.re/join/abc123');
  assert.deepEqual(linksFrom({ LINK_STORE: 'https://tienda.example', LINK_WEB: 'http://inseguro.example' }).map((l) => l.label), ['Tienda']);
  assert.equal(panels.verify.buttons[0].customId, IDS.verify);
  assert.equal(panels.roles.buttons.length, SELF_ROLES.length);
  for (const p of Object.values(panels)) {
    for (const e of p.embeds) {
      assert.ok(e.title.length <= 256 && e.description.length <= 4096);
    }
    for (const b of p.buttons ?? []) {
      assert.ok(b.label.length <= 80);
      if (b.style === 'link') assert.match(b.url, /^https:\/\//);
      else assert.ok(b.customId.length <= 100);
    }
  }
  // Sin configuración no hay botones rotos ni direcciones inventadas.
  const bare = buildPanels({});
  assert.deepEqual(bare.howto.buttons, []);
  assert.doesNotMatch(bare.howto.embeds[0].description, /connect /);
  assert.match(bare.verify.embeds[0].description, /#📜│normas/);
  const w = welcomeMessage({ userId: '333333333333333333', memberCount: 50 });
  assert.deepEqual(w.allowedMentions, { users: ['333333333333333333'] });
  assert.match(w.embeds[0].footer.text, /n\.º 50/);
});
