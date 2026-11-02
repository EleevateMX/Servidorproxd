// Panel de la ciudad — Próxima RP. Todo el texto se pinta con textContent.
(() => {
  'use strict';
  const params = new URLSearchParams(location.search);
  const DEMO = params.has('demo');
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pxd_panel';

  // ── Utilidades ─────────────────────────────────────
  const $ = (id) => document.getElementById(id);
  const SVGNS = 'http://www.w3.org/2000/svg';
  function h(tag, cls, text) {
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text !== undefined && text !== null) el.textContent = String(text);
    return el;
  }
  const ICONS = {
    profile: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21c1.5-4 4.5-6 8-6s6.5 2 8 6',
    gift: 'M4 11h16v9H4zM3 7h18v4H3zM12 7v13M12 7c-2-4-6-4-6-1.5S10 7 12 7zm0 0c2-4 6-4 6-1.5S14 7 12 7',
    trophy: 'M7 4h10v5a5 5 0 0 1-10 0zM7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4M12 14v4M8 21h8M9 18h6',
    calendar: 'M4 6h16v14H4zM4 10h16M8 3v5M16 3v5',
    building: 'M4 21V7l8-4 8 4v14M9 21v-5h6v5M8 10h1M12 10h1M16 10h1M8 13h1M12 13h1M16 13h1',
    help: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6M12 17h.01',
    news: 'M4 5h13v14H6a2 2 0 0 1-2-2zM17 9h3v8a2 2 0 0 1-2 2M8 9h5M8 13h5',
    gear: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-2.7-1.1l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0-1.1-2.7H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.1-2.7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 2.7-1.1V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0 1.1 2.7H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1.3z',
    swap: 'M7 7h13l-3-3M17 17H4l3 3',
    cash: 'M3 7h18v10H3zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6 10v4M18 10v4',
    card: 'M3 6h18v12H3zM3 10h18M7 15h4',
    clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
    sun: 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
    users: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21c1-4 3.8-6 7-6s6 2 7 6M16 3.5a4 4 0 0 1 0 7.5M18 15c2 .6 3.4 2.6 4 6',
    check: 'M5 12l5 5 9-10',
    lock: 'M6 11h12v10H6zM8 11V8a4 4 0 0 1 8 0v3',
    x: 'M6 6l12 12M18 6L6 18',
    search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM21 21l-5-5',
    chevL: 'M15 6l-6 6 6 6', chevR: 'M9 6l6 6-6 6',
    shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
    car: 'M5 16l1.5-5h11L19 16M4 16h16v3H4zM7 19v2M17 19v2',
    money: 'M12 3v18M16 7c0-2-2-3-4-3s-4 1-4 3 2 3 4 3.5 4 1.5 4 3.5-2 3-4 3-4-1-4-3',
    star: 'M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z',
    shirt: 'M8 4l-5 3 2 4 3-1v10h8V10l3 1 2-4-5-3c-1 2-2.5 3-4 3S9 6 8 4z',
    box: 'M3 7l9-4 9 4v10l-9 4-9-4zM3 7l9 4 9-4M12 11v10',
    sparkle: 'M12 2c.8 6 2 7.2 8 8-6 .8-7.2 2-8 8-.8-6-2-7.2-8-8 6-.8 7.2-2 8-8z',
  };
  function icon(name, cls) {
    const svg = document.createElementNS(SVGNS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');
    if (cls) svg.setAttribute('class', cls);
    const p = document.createElementNS(SVGNS, 'path');
    p.setAttribute('d', ICONS[name] || ICONS.gift);
    svg.appendChild(p);
    return svg;
  }
  const fmtMoney = (n) => '$' + Math.floor(Number(n) || 0).toLocaleString('es-MX');
  function fmtDuration(sec) {
    sec = Math.max(0, Math.floor(Number(sec) || 0));
    const d = Math.floor(sec / 86400), hh = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
    if (d > 0) return `${d} d ${hh} h`;
    if (hh > 0) return `${hh} h ${m} min`;
    return `${m} min`;
  }
  // Normaliza carácter a carácter (misma longitud) para buscar sin tildes y poder resaltar.
  const ACC = { á: 'a', é: 'e', í: 'i', ó: 'o', ú: 'u', ü: 'u', ñ: 'n' };
  const norm = (s) => Array.from(String(s || '').toLowerCase(), (c) => (ACC[c] || c)).join('');

  async function post(name, data) {
    if (DEMO) return demoAction(name, data);
    try {
      const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) });
      return await r.json();
    } catch (_) { return null; }
  }
  function openUrl(url) {
    if (!/^https:\/\//.test(String(url || ''))) return;
    if (typeof window.invokeNative === 'function') window.invokeNative('openUrl', url);
    else window.open(url, '_blank', 'noopener');
  }

  // ── Sonidos (WebAudio, sin archivos) ───────────────
  let audio;
  function beep(freq = 660, dur = 0.06, vol = 0.04) {
    if (!S.settings.sounds) return;
    try {
      audio = audio || new AudioContext();
      const o = audio.createOscillator(), g = audio.createGain();
      o.type = 'sine'; o.frequency.value = freq;
      g.gain.value = vol; g.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + dur);
      o.connect(g).connect(audio.destination); o.start(); o.stop(audio.currentTime + dur);
    } catch (_) { /* sin audio */ }
  }

  // ── Estado ─────────────────────────────────────────
  const S = {
    open: false, static: null, dyn: null, offset: 0,
    settings: { textScale: 3, sounds: true, reduceMotion: false },
    view: 'perfil', orgTab: 'government', helpTab: 'reglas', achId: null, query: '', settingsQuery: '',
    fineQuery: '', fineSearch: null,
  };
  const serverNow = () => Math.floor((Date.now() + S.offset) / 1000);

  const NAV = [
    { id: 'perfil', label: 'Perfil', icon: 'profile' },
    { id: 'recompensas', label: 'Recompensas', icon: 'gift', needs: 'progress' },
    { id: 'logros', label: 'Logros', icon: 'trophy', needs: 'progress' },
    { id: 'eventos', label: 'Eventos', icon: 'calendar' },
    { id: 'multas', label: 'Multas', icon: 'shield', needs: 'fines' },
    { id: 'organizaciones', label: 'Organizaciones', icon: 'building', needs: 'orgs',
      sub: [['government', 'Gubernamentales'], ['companies', 'Empresas'], ['groups', 'Grupos']], key: 'orgTab' },
    { id: 'ayuda', label: 'Ayuda', icon: 'help', sub: [['soporte', 'Soporte'], ['reglas', 'Reglamento']], key: 'helpTab' },
    { id: 'novedades', label: 'Novedades', icon: 'news' },
    { id: 'ajustes', label: 'Configuración', icon: 'gear' },
  ];
  const TITLES = {
    perfil: ['Tu personaje', 'Perfil'], recompensas: ['Cada día cuenta', 'Recompensas'], logros: ['Tu historia en la ciudad', 'Logros'],
    eventos: ['Comunidad', 'Eventos'], multas: ['Tus cuentas con la ciudad', 'Multas'], organizaciones: ['La ciudad', 'Organizaciones'], ayuda: ['Estamos para ayudarte', 'Ayuda'],
    novedades: ['Lo último', 'Novedades'], ajustes: ['Solo para ti', 'Configuración'],
  };

  function available(item) {
    if (!item.needs) return true;
    if (item.needs === 'progress') return !!(S.dyn && S.dyn.progress);
    if (item.needs === 'orgs') return !!(S.dyn && S.dyn.orgs);
    if (item.needs === 'fines') return !!(S.dyn && S.dyn.fines);
    return true;
  }

  // ── Barra lateral ──────────────────────────────────
  function renderNav() {
    const nav = $('nav');
    nav.replaceChildren();
    for (const item of NAV) {
      if (!available(item)) continue;
      const b = h('button', 'nav__item' + (S.view === item.id ? ' is-active' : ''));
      b.type = 'button';
      b.appendChild(icon(item.icon));
      b.appendChild(h('span', '', item.label));
      if (item.id === 'recompensas' && S.dyn && S.dyn.daily && S.dyn.daily.canClaim) b.appendChild(h('i', 'nav__badge', '1'));
      if (item.id === 'multas' && S.dyn.fines && S.dyn.fines.pending && S.dyn.fines.pending.length) b.appendChild(h('i', 'nav__badge', S.dyn.fines.pending.length));
      if (item.id === 'logros') {
        const n = claimableAchievements();
        if (n > 0) b.appendChild(h('i', 'nav__badge', n));
      }
      b.addEventListener('click', () => go(item.id));
      nav.appendChild(b);
      if (item.sub && S.view === item.id) {
        const sub = h('div', 'nav__sub');
        for (const [key, label] of item.sub) {
          const sb = h('button', S[item.key] === key ? 'is-active' : '', label);
          sb.type = 'button';
          sb.addEventListener('click', () => { S[item.key] = key; beep(720); render(); });
          sub.appendChild(sb);
        }
        nav.appendChild(sub);
      }
    }
    const d = S.dyn || {};
    $('online').textContent = d.online != null ? d.online : '—';
    $('online-max').textContent = d.maxPlayers ? ` / ${d.maxPlayers}` : '';
    const st = S.static || {};
    $('store').classList.toggle('hidden', !st.storeUrl);
    $('discord').classList.toggle('hidden', !st.discord);
  }
  function claimableAchievements() {
    const list = (S.dyn && S.dyn.achievements) || [];
    let n = 0;
    for (const c of list) for (const it of c.items || []) if (it.done && !it.claimed) n++;
    return n;
  }
  function go(view) { S.view = view; S.query = ''; beep(620); render(); $('view').scrollTop = 0; }

  // ── Vistas ─────────────────────────────────────────
  function render() {
    renderNav();
    const [eyebrow, title] = TITLES[S.view] || ['', ''];
    $('eyebrow').textContent = eyebrow;
    $('title').textContent = title;
    const v = $('view');
    v.replaceChildren();
    if (!S.dyn) { v.appendChild(h('div', 'empty', 'Cargando…')); return; }
    const fn = { perfil: viewProfile, recompensas: viewRewards, logros: viewAchievements, eventos: viewEvents, multas: viewFines,
      organizaciones: viewOrgs, ayuda: viewHelp, novedades: viewNews, ajustes: viewSettings }[S.view] || viewProfile;
    fn(v);
  }

  function levelBadge(p) {
    const wrap = h('div', 'level');
    const svg = document.createElementNS(SVGNS, 'svg');
    svg.setAttribute('viewBox', '0 0 112 124');
    const defs = document.createElementNS(SVGNS, 'defs');
    const lg = document.createElementNS(SVGNS, 'linearGradient');
    lg.id = 'lvl-grad'; lg.setAttribute('x1', '0'); lg.setAttribute('y1', '0'); lg.setAttribute('x2', '1'); lg.setAttribute('y2', '1');
    for (const [off, col] of [['0', '#5ce1ff'], ['1', '#ff4fd8']]) {
      const s = document.createElementNS(SVGNS, 'stop'); s.setAttribute('offset', off); s.setAttribute('stop-color', col); lg.appendChild(s);
    }
    defs.appendChild(lg); svg.appendChild(defs);
    const pts = '56,6 104,34 104,90 56,118 8,90 8,34';
    const bg = document.createElementNS(SVGNS, 'polygon'); bg.setAttribute('points', pts); bg.setAttribute('class', 'hex-bg');
    const fg = document.createElementNS(SVGNS, 'polygon'); fg.setAttribute('points', pts); fg.setAttribute('class', 'hex-fill');
    const per = 6 * 56.6;
    const ratio = p.xpNext > 0 ? Math.min(1, Math.max(0, (p.xpLevel || 0) / p.xpNext)) : 0;
    fg.setAttribute('stroke-dasharray', String(per));
    fg.setAttribute('stroke-dashoffset', String(per * (1 - ratio)));
    svg.append(bg, fg);
    wrap.appendChild(svg);
    const inner = h('div');
    inner.appendChild(h('b', '', p.level != null ? p.level : '—'));
    inner.appendChild(h('small', '', 'Nivel'));
    if (p.xpNext) inner.appendChild(h('span', '', `${p.xpLevel || 0}/${p.xpNext} XP`));
    wrap.appendChild(inner);
    return wrap;
  }

  function stat(label, value, ico, cls) {
    const c = h('div', 'card stat');
    const left = h('div');
    left.appendChild(h('small', '', label));
    left.appendChild(h('b', cls || '', value));
    const i = h('div', 'ico'); i.appendChild(icon(ico));
    c.append(left, i);
    return c;
  }

  function viewProfile(v) {
    const p = S.dyn.profile || {};
    const hero = h('div', 'hero');
    const left = h('div');
    const name = h('div', 'hero__name');
    name.appendChild(h('h2', '', p.name || 'Sin personaje'));
    if (p.citizenid) name.appendChild(h('span', 'chip chip--star', '#' + p.citizenid));
    if (p.plus) name.appendChild(h('span', 'chip chip--gold', 'PLUS'));
    left.appendChild(name);
    const org = h('div', 'hero__org');
    org.appendChild(h('span', 'label', 'Organización'));
    if (p.job) {
      org.appendChild(h('span', 'hero__job', p.job.label + (p.job.grade ? ` · ${p.job.grade}` : '')));
      org.appendChild(h('span', 'chip ' + (p.job.onduty ? 'chip--ok' : ''), p.job.onduty ? 'De servicio' : 'Fuera de servicio'));
    } else {
      org.appendChild(h('span', 'muted', 'Sin trabajo — visita el Ayuntamiento'));
    }
    if (p.gang) org.appendChild(h('span', 'chip chip--nova', p.gang.label + (p.gang.grade ? ` · ${p.gang.grade}` : '')));
    left.appendChild(org);
    hero.appendChild(left);
    if (S.dyn.progress) hero.appendChild(levelBadge(p));
    v.appendChild(hero);

    const actions = h('div', 'actions');
    if (S.dyn.progress) {
      const daily = S.dyn.daily || {};
      actions.appendChild(featureBtn('gift', 'Recompensas', daily.canClaim ? '¡Tienes una recompensa lista!' : 'Misión del día', 'action--feature', () => go('recompensas')));
      const n = claimableAchievements();
      actions.appendChild(featureBtn('trophy', 'Logros', n ? `${n} por reclamar` : 'Tu progreso', 'action--feature action--feature2', () => go('logros')));
    }
    if (S.dyn.framework) actions.appendChild(simpleBtn('swap', 'Cambiar personaje', confirmLogout));
    actions.appendChild(simpleBtn('gear', 'Configuración', () => go('ajustes')));
    v.appendChild(actions);

    v.appendChild(h('div', 'section-title', 'Cuenta'));
    const g = h('div', 'grid grid--2');
    g.appendChild(stat('Efectivo', fmtMoney(p.cash), 'cash', 'money'));
    g.appendChild(stat('Banco', fmtMoney(p.bank), 'card'));
    if (p.playtime != null) g.appendChild(stat('Tiempo jugado', fmtDuration(p.playtime), 'clock'));
    if (p.playtimeToday != null) g.appendChild(stat('Tiempo jugado hoy', fmtDuration(p.playtimeToday), 'sun'));
    v.appendChild(g);
  }
  function featureBtn(ico, title, sub, cls, fn) {
    const b = h('button', 'action ' + cls); b.type = 'button';
    b.appendChild(icon(ico));
    const t = h('div', '', title); t.appendChild(h('small', '', sub)); b.appendChild(t);
    b.addEventListener('click', fn);
    return b;
  }
  function simpleBtn(ico, label, fn) {
    const b = h('button', 'action'); b.type = 'button';
    b.appendChild(icon(ico)); b.appendChild(h('span', '', label));
    b.addEventListener('click', fn);
    return b;
  }

  const REWARD_ICON = { money: 'money', cash: 'money', car: 'car', vehicle: 'car', xp: 'star', star: 'star', clothes: 'shirt', shirt: 'shirt', item: 'box', box: 'box', gift: 'gift', sparkle: 'sparkle' };
  function rewardCell(r, lane, state) {
    const c = h('div', `reward reward--${lane} is-${state}`);
    const st = h('div', 'reward__state');
    if (state === 'claimed') st.appendChild(icon('check'));
    else if (state === 'locked' || (lane === 'plus' && !S.dyn.daily.plus)) st.appendChild(icon('lock'));
    if (st.childNodes.length) c.appendChild(st);
    const i = h('div', 'reward__icon'); i.appendChild(icon(REWARD_ICON[(r && r.icon) || 'gift'] || 'gift')); c.appendChild(i);
    c.appendChild(h('span', '', (r && r.label) || '—'));
    return c;
  }

  function viewRewards(v) {
    const d = S.dyn.daily;
    if (!d) { v.appendChild(h('div', 'empty', 'No hay una temporada de recompensas activa ahora mismo.')); return; }
    const head = h('div', 'card season');
    const left = h('div');
    left.appendChild(h('small', 'muted', 'Temporada'));
    left.appendChild(h('h3', '', (d.season && d.season.name) || 'Recompensas diarias'));
    head.appendChild(left);
    if (d.season && d.season.endsAt) {
      const left2 = d.season.endsAt - serverNow();
      if (left2 > 0) head.appendChild(h('span', 'chip chip--nova', 'Termina en ' + fmtDuration(left2)));
    }
    v.appendChild(head);

    const m = d.mission;
    const mission = h('div', 'mission');
    const ml = h('div');
    ml.appendChild(h('span', 'chip chip--star', d.day ? `Día ${d.day}` : 'Misión del día'));
    ml.appendChild(h('h3', '', m ? m.label : 'Sin misión por ahora'));
    if (m && m.goal) {
      const bar = h('div', 'bar' + (m.done ? ' bar--ok' : ''));
      const fill = h('span'); fill.style.width = `${Math.min(100, (m.progress / m.goal) * 100)}%`; bar.appendChild(fill);
      ml.appendChild(bar);
      ml.appendChild(h('div', 'small muted', `${Math.min(m.progress, m.goal)} / ${m.goal}` + (m.done ? ' · completada' : '')));
    }
    mission.appendChild(ml);
    const claim = h('button', 'btn btn--primary', d.canClaim ? 'Reclamar' : 'Reclamado o pendiente');
    claim.type = 'button';
    claim.disabled = !d.canClaim;
    claim.addEventListener('click', () => { claim.disabled = true; beep(880, .1); post('claimDaily'); });
    mission.appendChild(claim);
    v.appendChild(mission);

    const track = h('div', 'track');
    const lanes = h('div', 'track__lanes');
    lanes.appendChild(h('div'));
    lanes.appendChild(h('div', 'track__lane track__lane--free', 'Gratis'));
    lanes.appendChild(h('div', 'track__lane track__lane--plus', 'Plus'));
    track.appendChild(lanes);
    const days = h('div', 'days');
    for (const day of d.days || []) {
      const col = h('div', 'day' + (day.n === d.day ? ' is-today' : ''));
      col.appendChild(h('div', 'day__n', `Día ${day.n}`));
      col.appendChild(rewardCell(day.free, 'free', day.state));
      const plusState = d.plus ? day.state : 'locked';
      col.appendChild(rewardCell(day.plus, 'plus', plusState));
      days.appendChild(col);
    }
    track.appendChild(days);
    v.appendChild(track);
    setTimeout(() => { const t = days.querySelector('.is-today'); if (t) days.scrollLeft = Math.max(0, t.offsetLeft - days.offsetLeft - 130); }, 0);

    const foot = h('div', 'card');
    foot.style.marginTop = '16px';
    foot.appendChild(h('p', 'small muted', d.note || 'Completa la misión del día para desbloquear su recompensa. Vuelve cada día para avanzar en la temporada.'));
    if (!d.plus && S.static && S.static.storeUrl) {
      const b = h('button', 'btn btn--gold', 'Ver Plus en la tienda'); b.type = 'button';
      b.style.marginTop = '10px';
      b.addEventListener('click', () => openUrl(S.static.storeUrl));
      foot.appendChild(b);
    }
    v.appendChild(foot);
  }

  function viewAchievements(v) {
    const list = S.dyn.achievements || [];
    if (!list.length) { v.appendChild(h('div', 'empty', 'Todavía no hay logros disponibles.')); return; }
    if (!list.some((c) => c.id === S.achId)) S.achId = list[0].id;
    const wrap = h('div', 'ach');
    const side = h('div', 'ach__list');
    for (const c of list) {
      const b = h('button', 'ach__cat' + (c.id === S.achId ? ' is-active' : '')); b.type = 'button';
      const t = h('b'); t.appendChild(icon(c.icon && ICONS[c.icon] ? c.icon : 'trophy')); t.appendChild(h('span', '', c.label)); b.appendChild(t);
      const bar = h('div', 'bar' + (c.done >= c.total ? ' bar--ok' : '')); const f = h('span'); f.style.width = `${c.total ? (c.done / c.total) * 100 : 0}%`; bar.appendChild(f); b.appendChild(bar);
      const meta = h('div', 'meta'); meta.appendChild(h('span', '', `${c.done}/${c.total}`));
      if (c.limited) meta.appendChild(h('span', '', 'Limitado'));
      b.appendChild(meta);
      b.addEventListener('click', () => { S.achId = c.id; beep(700); render(); });
      side.appendChild(b);
    }
    wrap.appendChild(side);
    const c = list.find((x) => x.id === S.achId);
    const det = h('div');
    const head = h('div'); head.style.display = 'flex'; head.style.gap = '8px'; head.style.alignItems = 'center'; head.style.marginBottom = '10px';
    head.appendChild(h('h3', '', c.label));
    if (c.limited) {
      const left = c.endsAt ? c.endsAt - serverNow() : 0;
      head.appendChild(h('span', 'chip chip--nova', left > 0 ? `Limitado · ${fmtDuration(left)}` : 'Limitado'));
    }
    det.appendChild(head);
    if (c.image && /^(https:\/\/|nui:\/\/|[\w./-]+$)/.test(c.image)) {
      const img = h('img', 'ach__banner'); img.alt = ''; img.src = c.image; img.onerror = () => img.remove(); det.appendChild(img);
    }
    if (c.description) det.appendChild(h('p', 'muted', c.description));
    const items = h('div', 'grid'); items.style.marginTop = '12px';
    for (const it of c.items || []) {
      const row = h('div', 'ach__item' + (it.done ? ' is-done' : ''));
      const l = h('div');
      l.appendChild(h('h4', '', it.label));
      if (it.description) l.appendChild(h('div', 'small muted', it.description));
      const bar = h('div', 'bar' + (it.done ? ' bar--ok' : '')); const f = h('span'); f.style.width = `${it.goal ? Math.min(100, (it.progress / it.goal) * 100) : 0}%`; bar.appendChild(f); l.appendChild(bar);
      l.appendChild(h('div', 'small muted', `${Math.min(it.progress || 0, it.goal || 0)} / ${it.goal || 0}` + (it.rewardXp ? ` · +${it.rewardXp} XP` : '')));
      row.appendChild(l);
      if (it.claimed) row.appendChild(h('span', 'chip chip--ok', 'Reclamado'));
      else if (it.done) {
        const b = h('button', 'btn btn--nova', 'Reclamar'); b.type = 'button';
        b.addEventListener('click', () => { b.disabled = true; beep(880, .1); post('claimAchievement', { id: it.id }); });
        row.appendChild(b);
      } else row.appendChild(h('span', 'chip', 'En curso'));
      items.appendChild(row);
    }
    det.appendChild(items);
    wrap.appendChild(det);
    v.appendChild(wrap);
  }

  // ── Multas (pxd_justice decide; aquí solo se muestra y se pide) ──
  const FINE_STATUS = { pending: ['Pendiente', 'chip--nova'], partial: ['Pago parcial', 'chip--gold'], paid: ['Pagada', 'chip--ok'], cancelled: ['Anulada', ''] };
  function fmtShortDate(epoch) {
    if (!epoch) return '';
    const tz = S.static && S.static.timeZone;
    const opts = { day: 'numeric', month: 'short', year: 'numeric' };
    try { return new Intl.DateTimeFormat('es-MX', tz ? { ...opts, timeZone: tz } : opts).format(new Date(epoch * 1000)); }
    catch (_) { return new Date(epoch * 1000).toLocaleDateString('es-MX'); }
  }
  function fineRow(f, payable, methods) {
    const row = h('div', 'fine' + (payable ? '' : ' is-closed'));
    const top = h('div', 'fine__top');
    const l = h('div');
    l.appendChild(h('h4', '', f.reason));
    const meta = [`Multa #${f.id}`, fmtShortDate(f.issuedAt)];
    if (f.officer) meta.push(`Agente: ${f.officer}`);
    l.appendChild(h('div', 'small muted', meta.filter(Boolean).join(' · ')));
    if (f.notes) l.appendChild(h('p', 'small fine__notes', f.notes));
    top.appendChild(l);
    const [label, cls] = FINE_STATUS[f.status] || [f.status, ''];
    top.appendChild(h('span', 'chip ' + cls, label));
    row.appendChild(top);
    const nums = h('div', 'fine__nums');
    for (const [k, v, c] of [['Importe', f.amount], ['Pagado', f.paid], ['Pendiente', f.outstanding, f.outstanding > 0 ? 'fine__due' : '']]) {
      const n = h('div'); n.appendChild(h('small', '', k)); n.appendChild(h('b', c || '', fmtMoney(v))); nums.appendChild(n);
    }
    row.appendChild(nums);
    if (payable && f.outstanding > 0) {
      const pay = h('div', 'fine__pay');
      const amount = h('input', 'fine__amount');
      amount.type = 'number'; amount.min = '1'; amount.max = String(f.outstanding); amount.step = '1';
      amount.value = String(f.outstanding);
      amount.setAttribute('aria-label', 'Importe a pagar');
      pay.appendChild(amount);
      const order = [['bank', 'Pagar con banco', 'card'], ['cash', 'Pagar en efectivo', 'cash']];
      for (const [m, text, ico] of order) {
        if (methods && methods[m] === false) continue;
        const b = h('button', m === 'bank' ? 'btn btn--primary' : 'btn btn--ghost'); b.type = 'button';
        b.appendChild(icon(ico)); b.appendChild(h('span', '', text));
        b.addEventListener('click', () => {
          const n = Math.floor(Number(amount.value));
          if (!(n >= 1)) { toast('No se pudo', 'Escribe un importe válido.', true); return; }
          for (const x of pay.querySelectorAll('button')) x.disabled = true;
          beep(880, .1);
          post('payFine', { id: f.id, amount: Math.min(n, f.outstanding), method: m });
        });
        pay.appendChild(b);
      }
      row.appendChild(pay);
    }
    return row;
  }
  function fineList(v, view, payable, methods) {
    const sum = h('div', 'grid grid--2');
    sum.appendChild(stat('Deuda pendiente', fmtMoney(view.outstanding), 'shield', view.outstanding > 0 ? 'fine__due' : 'money'));
    sum.appendChild(stat('Multas abiertas', String((view.pending || []).length), 'news'));
    v.appendChild(sum);
    v.appendChild(h('div', 'section-title', 'Pendientes'));
    if (!(view.pending || []).length) v.appendChild(h('div', 'empty', 'No hay multas pendientes.'));
    else { const g = h('div', 'grid'); for (const f of view.pending) g.appendChild(fineRow(f, payable, methods)); v.appendChild(g); }
    v.appendChild(h('div', 'section-title', 'Historial'));
    if (!(view.history || []).length) v.appendChild(h('div', 'empty', 'Sin multas pagadas ni anuladas.'));
    else { const g = h('div', 'grid'); for (const f of view.history) g.appendChild(fineRow(f, false)); v.appendChild(g); }
  }
  function viewFines(v) {
    const fines = S.dyn.fines || {};
    const intro = h('p', 'muted');
    intro.textContent = 'Las multas no se cobran solas: si no tienes fondos quedan como deuda. Puedes pagarlas completas o por partes, con banco o en efectivo.';
    v.appendChild(intro);
    fineList(v, fines, true, fines.methods);
    if (!fines.canSearch) return;
    v.appendChild(h('div', 'section-title', 'Consulta de autoridades'));
    const form = h('form', 'fine__search');
    const search = h('label', 'search');
    search.appendChild(icon('search'));
    const input = h('input'); input.placeholder = 'ID de servidor, PROX-XXXX o ID de ciudadano'; input.value = S.fineQuery; input.maxLength = 64;
    search.appendChild(input);
    const b = h('button', 'btn btn--ghost', 'Buscar'); b.type = 'submit';
    form.append(search, b);
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      S.fineQuery = input.value.trim();
      if (!S.fineQuery) return;
      S.fineSearch = { loading: true };
      beep(720); post('searchFines', { query: S.fineQuery }); render();
    });
    v.appendChild(form);
    const r = S.fineSearch;
    if (!r) return;
    if (r.loading) { v.appendChild(h('div', 'empty', 'Buscando…')); return; }
    if (!r.ok) { v.appendChild(h('div', 'empty', r.message || 'Sin resultados.')); return; }
    const res = r.result || {};
    const who = h('div', 'card fine__who');
    who.appendChild(h('b', '', res.name || 'Ciudadano'));
    if (res.citizenid) who.appendChild(h('span', 'chip chip--star', '#' + res.citizenid));
    v.appendChild(who);
    fineList(v, res, false);
  }

  function fmtDate(epoch) {
    const opts = { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' };
    const tz = S.static && S.static.timeZone;
    try { return new Intl.DateTimeFormat('es-MX', tz ? { ...opts, timeZone: tz, timeZoneName: 'short' } : opts).format(new Date(epoch * 1000)); }
    catch (_) { return new Date(epoch * 1000).toLocaleString('es-MX'); }
  }
  function viewEvents(v) {
    const intro = h('p', 'muted');
    intro.textContent = 'Fiestas, carreras, torneos y quedadas. Participa, conoce gente y llévate algo a casa.';
    v.appendChild(intro);
    const list = S.dyn.events || [];
    if (!list.length) { v.appendChild(h('div', 'empty', 'No hay eventos anunciados. ¡Atento a Discord!')); return; }
    const car = h('div', 'carousel');
    const track = h('div', 'carousel__track');
    for (const e of list) {
      const card = h('article', 'event');
      const img = h('div', 'event__img');
      if (e.image && /^https:\/\//.test(e.image)) img.style.backgroundImage = `linear-gradient(180deg, transparent 40%, rgba(5,7,15,.8)), url("${encodeURI(e.image)}")`;
      if (e.startsAt) {
        const left = e.startsAt - serverNow();
        const t = h('div', 'event__time' + (left <= 0 ? ' event__time--live' : ''));
        t.appendChild(icon('clock'));
        t.appendChild(h('span', '', left <= 0 ? 'En curso' : countdownText(left)));
        img.appendChild(t);
      }
      card.appendChild(img);
      const body = h('div', 'event__body');
      body.appendChild(h('h3', '', e.title));
      if (e.startsAt) body.appendChild(h('span', 'chip chip--star', fmtDate(e.startsAt)));
      if (e.description) body.appendChild(h('p', 'muted small', e.description));
      if (e.place) body.appendChild(h('div', 'small', '📍 ' + e.place));
      if (Array.isArray(e.steps) && e.steps.length) {
        const ol = h('ol', 'steps');
        for (const s of e.steps) ol.appendChild(h('li', '', s));
        body.appendChild(ol);
      }
      if (e.howTo) body.appendChild(h('p', 'small', e.howTo));
      card.appendChild(body);
      track.appendChild(card);
    }
    car.appendChild(track);
    if (list.length > 2) {
      for (const [dir, cls, ico] of [[-1, 'prev', 'chevL'], [1, 'next', 'chevR']]) {
        const b = h('button', `carousel__nav carousel__nav--${cls}`); b.type = 'button'; b.setAttribute('aria-label', dir < 0 ? 'Anterior' : 'Siguiente');
        b.appendChild(icon(ico));
        b.addEventListener('click', () => track.scrollBy({ left: dir * track.clientWidth * 0.5 }));
        car.appendChild(b);
      }
    }
    v.appendChild(car);
  }
  function countdownText(sec) {
    const d = Math.floor(sec / 86400), hh = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
    return d > 0 ? `${d}d ${hh}h ${m}m` : `${hh}h ${m}m`;
  }

  function viewOrgs(v) {
    const orgs = S.dyn.orgs;
    const tabs = h('div', 'tabs');
    const names = { government: 'Gubernamentales', companies: 'Empresas', groups: 'Grupos' };
    for (const k of Object.keys(names)) {
      const b = h('button', S.orgTab === k ? 'is-active' : '', names[k]); b.type = 'button';
      b.addEventListener('click', () => { S.orgTab = k; beep(720); render(); });
      tabs.appendChild(b);
    }
    v.appendChild(tabs);
    const desc = { government: 'Servicios públicos de la ciudad. Postúlate en el Ayuntamiento o con sus responsables.',
      companies: 'Trabajos y negocios de la ciudad.', groups: 'Bandas y grupos reconocidos por la ciudad.' };
    const p = h('p', 'muted small', desc[S.orgTab]); v.appendChild(p);
    const list = (orgs && orgs[S.orgTab]) || [];
    if (!list.length) { v.appendChild(h('div', 'empty', 'No hay organizaciones en esta categoría.')); return; }
    const g = h('div', 'grid');
    for (const o of list) {
      const row = h('div', 'org' + (o.member ? ' is-member' : ''));
      row.appendChild(h('div', 'org__mark', (o.label || '?').slice(0, 2).toUpperCase()));
      const mid = h('div');
      mid.appendChild(h('h4', '', o.label));
      const tags = h('div'); tags.style.display = 'flex'; tags.style.gap = '6px'; tags.style.flexWrap = 'wrap';
      if (o.member) tags.appendChild(h('span', 'chip chip--star', 'Miembro' + (o.grade ? ` · ${o.grade}` : '')));
      if (o.primary) tags.appendChild(h('span', 'chip ' + (o.onduty ? 'chip--ok' : ''), o.onduty ? 'De servicio' : 'Trabajo actual'));
      if (!tags.childNodes.length) tags.appendChild(h('span', 'small muted', 'No perteneces'));
      mid.appendChild(tags);
      row.appendChild(mid);
      if (S.orgTab !== 'groups') {
        const d = h('div', 'duty'); d.appendChild(h('b', '', o.dutyCount || 0)); d.appendChild(h('span', '', 'de servicio'));
        row.appendChild(d);
      } else row.appendChild(h('div'));
      g.appendChild(row);
    }
    v.appendChild(g);
  }

  function highlight(parent, text, words) {
    text = String(text || '');
    if (!words.length) { parent.textContent = text; return; }
    const n = norm(text);
    const marks = new Array(text.length).fill(false);
    for (const w of words) { let i = 0; while ((i = n.indexOf(w, i)) !== -1) { for (let j = i; j < i + w.length; j++) marks[j] = true; i += w.length; } }
    let buf = '', on = false;
    const flush = () => { if (!buf) return; parent.appendChild(on ? h('mark', '', buf) : document.createTextNode(buf)); buf = ''; };
    for (let i = 0; i < text.length; i++) { if (marks[i] !== on) { flush(); on = marks[i]; } buf += text[i]; }
    flush();
  }
  function viewHelp(v) {
    const st = S.static || {};
    if (S.helpTab === 'soporte') {
      const g = h('div', 'help');
      for (const s of st.support || []) {
        const c = h('div', 'card');
        c.appendChild(h('h4', '', s.title));
        c.appendChild(h('p', '', s.text));
        if (s.link && /^https:\/\//.test(s.link)) {
          const a = h('button', 'link', s.link.replace(/^https:\/\//, '')); a.type = 'button';
          a.addEventListener('click', () => openUrl(s.link)); c.appendChild(a);
        }
        g.appendChild(c);
      }
      v.appendChild(g);
      const more = h('button', 'btn btn--ghost', 'Ver el reglamento'); more.type = 'button'; more.style.marginTop = '14px';
      more.addEventListener('click', () => { S.helpTab = 'reglas'; render(); });
      v.appendChild(more);
      return;
    }
    const search = h('label', 'search');
    search.appendChild(icon('search'));
    const input = h('input'); input.placeholder = 'Buscar en el reglamento (p. ej. «metagaming», «rehenes»)…'; input.value = S.query;
    search.appendChild(input);
    v.appendChild(search);
    const results = h('div', 'grid'); results.style.marginTop = '14px';
    v.appendChild(results);
    const draw = () => {
      results.replaceChildren();
      const words = norm(S.query).split(/\s+/).filter(Boolean);
      if (!words.length && st.rulesIntro) results.appendChild(h('p', 'muted', st.rulesIntro));
      let shown = 0;
      (st.rules || []).forEach((r, idx) => {
        const hay = norm([r.title, r.body, ...(r.points || [])].join(' '));
        if (words.length && !words.every((w) => hay.includes(w))) return;
        shown++;
        const c = h('article', 'rule');
        const t = h('h3'); t.appendChild(h('span', 'rule__n', idx + 1)); const tt = h('span'); highlight(tt, r.title, words); t.appendChild(tt);
        c.appendChild(t);
        if (r.body) { const p = h('p'); highlight(p, r.body, words); c.appendChild(p); }
        if (r.points && r.points.length) {
          const ul = h('ul');
          for (const pt of r.points) { const li = h('li'); highlight(li, pt, words); ul.appendChild(li); }
          c.appendChild(ul);
        }
        results.appendChild(c);
      });
      if (!shown) results.appendChild(h('div', 'empty', 'Ninguna norma coincide con tu búsqueda.'));
    };
    input.addEventListener('input', () => { S.query = input.value; draw(); });
    draw();
    setTimeout(() => input.focus(), 0);
  }

  function viewNews(v) {
    const list = (S.static && S.static.news) || [];
    if (!list.length) { v.appendChild(h('div', 'empty', 'Sin novedades por ahora.')); return; }
    const wrap = h('div', 'news');
    for (const n of list) {
      const c = h('div', 'card news__item');
      c.appendChild(h('span', 'chip chip--star', n.date || ''));
      const t = h('h3', '', n.title); t.style.marginTop = '8px'; c.appendChild(t);
      const ul = h('ul');
      for (const it of n.items || []) ul.appendChild(h('li', '', it));
      c.appendChild(ul);
      wrap.appendChild(c);
    }
    v.appendChild(wrap);
  }

  function viewSettings(v) {
    const search = h('label', 'search');
    search.appendChild(icon('search'));
    const input = h('input'); input.placeholder = 'Buscar…'; input.value = S.settingsQuery;
    search.appendChild(input);
    v.appendChild(search);
    const list = h('div', 'grid'); list.style.marginTop = '14px';
    v.appendChild(list);
    const save = async (patch) => {
      const next = { ...S.settings, ...patch };
      applySettings(next);
      const r = await post('saveSettings', next);
      if (r && r.settings) applySettings(r.settings);
      draw();
    };
    const rows = [
      { title: 'Tamaño del texto', text: 'Escala del texto de este panel. Por defecto: 3.', control: () => {
        const box = h('div', 'scale');
        for (let i = 1; i <= 5; i++) {
          const b = h('button', S.settings.textScale === i ? 'is-active' : '', i); b.type = 'button';
          b.addEventListener('click', () => { beep(600 + i * 60); save({ textScale: i }); });
          box.appendChild(b);
        }
        return box;
      } },
      { title: 'Sonidos del panel', text: 'Pequeños sonidos al navegar y al recibir avisos.', control: () => toggle(S.settings.sounds, (on) => save({ sounds: on })) },
      { title: 'Reducir animaciones', text: 'Quita transiciones y efectos de movimiento del panel.', control: () => toggle(S.settings.reduceMotion, (on) => save({ reduceMotion: on })) },
      { title: 'Tecla del panel', text: 'Cámbiala en Ajustes de FiveM → Asignación de teclas → FiveM → «Abrir el panel de la ciudad». También puedes escribir /panel.', control: () => h('kbd', '', 'Ajustes de FiveM') },
    ];
    if (S.dyn.framework) rows.push({ title: 'Cambiar personaje', text: 'Guarda tu personaje actual y vuelve a la selección de personajes.', control: () => {
      const b = h('button', 'btn btn--ghost', 'Cambiar'); b.type = 'button'; b.addEventListener('click', confirmLogout); return b;
    } });
    const draw = () => {
      list.replaceChildren();
      const q = norm(S.settingsQuery).trim();
      let shown = 0;
      for (const r of rows) {
        if (q && !norm(r.title + ' ' + r.text).includes(q)) continue;
        shown++;
        const row = h('div', 'setting');
        const l = h('div'); l.appendChild(h('h4', '', r.title)); l.appendChild(h('p', '', r.text));
        const rr = h('div'); rr.appendChild(r.control());
        row.append(l, rr);
        list.appendChild(row);
      }
      if (!shown) list.appendChild(h('div', 'empty', 'Ninguna opción coincide.'));
    };
    input.addEventListener('input', () => { S.settingsQuery = input.value; draw(); });
    draw();
  }
  function toggle(on, fn) {
    const wrap = h('div'); wrap.style.display = 'flex'; wrap.style.alignItems = 'center';
    const b = h('button', 'toggle' + (on ? ' is-on' : '')); b.type = 'button'; b.setAttribute('role', 'switch'); b.setAttribute('aria-checked', on ? 'true' : 'false');
    b.addEventListener('click', () => fn(!on));
    wrap.append(b, h('span', 'toggle-label', on ? 'Sí' : 'No'));
    return wrap;
  }

  // ── Modal, avisos, ajustes ─────────────────────────
  let modalOk = null;
  function confirmLogout() {
    $('modal-title').textContent = '¿Cambiar de personaje?';
    $('modal-text').textContent = 'Tu personaje se guardará donde está y volverás a la selección de personajes.';
    modalOk = () => post('logout');
    $('modal').classList.remove('hidden');
  }
  $('modal-cancel').addEventListener('click', () => { $('modal').classList.add('hidden'); modalOk = null; });
  $('modal-ok').addEventListener('click', () => { $('modal').classList.add('hidden'); const f = modalOk; modalOk = null; if (f) f(); });

  function toast(title, text, error) {
    const t = h('div', 'toast' + (error ? ' is-error' : ''));
    const i = h('div', 'toast__ico'); i.appendChild(icon('sparkle')); t.appendChild(i);
    const body = h('div'); body.appendChild(h('b', '', title)); if (text) body.appendChild(h('span', '', text)); t.appendChild(body);
    $('toasts').appendChild(t);
    beep(error ? 300 : 980, .12, .05);
    setTimeout(() => t.remove(), 5000);
  }

  function applySettings(s) {
    S.settings = { ...S.settings, ...(s || {}) };
    const scales = { 1: .85, 2: .92, 3: 1, 4: 1.08, 5: 1.16 };
    document.documentElement.style.setProperty('--scale', String(scales[S.settings.textScale] || 1));
    document.body.classList.toggle('reduce-motion', !!S.settings.reduceMotion);
  }

  function setOpen(open, settings) {
    S.open = open;
    if (settings) applySettings(settings);
    $('shell').classList.toggle('hidden', !open);
    $('modal').classList.add('hidden');
    if (open) render();
  }
  function close() { if (!S.open) return; setOpen(false); post('close'); }

  $('close').addEventListener('click', close);
  $('store').addEventListener('click', () => S.static && openUrl(S.static.storeUrl));
  $('discord').addEventListener('click', () => S.static && openUrl(S.static.discord));
  document.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.key === 'Escape') { if (!$('modal').classList.contains('hidden')) $('modal').classList.add('hidden'); else close(); }
  });
  // Refresca las cuentas atrás cada 30 s sin pedir nada al servidor.
  setInterval(() => { if (S.open && ['eventos', 'recompensas', 'logros'].includes(S.view) && !document.activeElement.matches('input')) render(); }, 30000);

  window.addEventListener('message', (ev) => {
    const msg = ev.data || {};
    if (msg.type === 'open') setOpen(!!(msg.data && msg.data.open), msg.data && msg.data.settings);
    else if (msg.type === 'data') {
      const d = msg.data || {};
      if (d.static) S.static = d.static;
      S.dyn = d;
      S.offset = (Number(d.now) || 0) * 1000 - Date.now();
      if (S.open) render();
    } else if (msg.type === 'result') {
      const r = msg.data || {};
      if (r.message) toast(r.ok ? '¡Listo!' : 'No se pudo', r.message, !r.ok);
    } else if (msg.type === 'fineSearch') {
      S.fineSearch = msg.data || null;
      if (S.open && S.view === 'multas') render();
    } else if (msg.type === 'notify') {
      const n = msg.data || {};
      toast(n.title || 'Próxima RP', n.text || '');
    }
  });

  // ── Modo demo (navegador) ──────────────────────────
  function demoAction(name, data) {
    if (name === 'close') return {};
    if (name === 'saveSettings') return { settings: data };
    if (name === 'claimDaily') {
      const d = S.dyn.daily; const today = d.days.find((x) => x.n === d.day); if (today) today.state = 'claimed'; d.canClaim = false;
      window.postMessage({ type: 'result', data: { ok: true, message: 'Recibiste: ' + today.free.label } }, '*');
      window.postMessage({ type: 'data', data: S.dyn }, '*');
    }
    if (name === 'claimAchievement') {
      for (const c of S.dyn.achievements) for (const it of c.items) if (it.id === data.id) it.claimed = true;
      window.postMessage({ type: 'result', data: { ok: true, message: '+50 XP' } }, '*');
      window.postMessage({ type: 'data', data: S.dyn }, '*');
    }
    if (name === 'payFine') {
      const f = S.dyn.fines.pending.find((x) => x.id === data.id);
      if (f) {
        f.paid += data.amount; f.outstanding -= data.amount; f.status = f.outstanding > 0 ? 'partial' : 'paid';
        if (f.status === 'paid') { S.dyn.fines.pending = S.dyn.fines.pending.filter((x) => x !== f); S.dyn.fines.history.unshift(f); }
        S.dyn.fines.outstanding -= data.amount;
        window.postMessage({ type: 'result', data: { ok: true, message: `Pagaste ${fmtMoney(data.amount)} de la multa #${f.id}.` } }, '*');
        window.postMessage({ type: 'data', data: S.dyn }, '*');
      }
    }
    if (name === 'searchFines') {
      window.postMessage({ type: 'fineSearch', data: { ok: true, result: { name: 'Leo Martínez', citizenid: 'PXD1203', outstanding: 750,
        pending: [{ id: 41, reason: 'Conducción temeraria', notes: 'Persecución por Vinewood', amount: 750, paid: 0, outstanding: 750, status: 'pending', officer: 'Ana Ortega', issuedAt: Math.floor(Date.now() / 1000) - 7200 }],
        history: [] } } }, '*');
    }
    if (name === 'logout') toast('Demo', 'Aquí volverías a la selección de personaje.');
    return {};
  }
  if (DEMO) {
    document.body.classList.add('demo');
    const now = Math.floor(Date.now() / 1000);
    const day = (n, free, plus, state) => ({ n, free, plus, state });
    const demo = {
      now, online: 37, maxPlayers: 48, progress: true, framework: true,
      profile: { name: 'Valeria Ríos', citizenid: 'PXD4821', job: { label: 'Servicios Médicos', grade: 'Paramédica', onduty: true }, gang: null,
        cash: 12850, bank: 248300, level: 7, xp: 1840, xpLevel: 140, xpNext: 320, playtime: 2534400 + 8 * 3600, playtimeToday: 2 * 3600 + 14 * 60, plus: false },
      daily: { season: { id: 'otono', name: 'Temporada de otoño', endsAt: now + 3 * 86400 + 5 * 3600 }, day: 3, plus: false, canClaim: true,
        mission: { label: 'Juega 60 minutos en la ciudad', progress: 60, goal: 60, done: true },
        days: [day(1, { label: '$1,000', icon: 'money' }, { label: '$3,000', icon: 'money' }, 'claimed'), day(2, { label: '+100 XP', icon: 'xp' }, { label: 'Chaqueta nocturna', icon: 'clothes' }, 'missed'),
          day(3, { label: '$1,500', icon: 'money' }, { label: '+300 XP', icon: 'xp' }, 'available'), day(4, { label: 'Kit de reparación', icon: 'item' }, { label: '$5,000', icon: 'money' }, 'locked'),
          day(5, { label: '+150 XP', icon: 'xp' }, { label: 'Gorra estelar', icon: 'clothes' }, 'locked'), day(6, { label: '$2,000', icon: 'money' }, { label: 'Pintura neón', icon: 'car' }, 'locked'),
          day(7, { label: 'Caja sorpresa', icon: 'gift' }, { label: 'Caja premium', icon: 'sparkle' }, 'locked')] },
      achievements: [
        { id: 'bienvenida', label: 'Bienvenida', icon: 'star', description: 'Tus primeros pasos en Próxima RP.', done: 3, total: 4, items: [
          { id: 'first_hour', label: 'Primera hora', description: 'Juega 1 hora en la ciudad.', progress: 60, goal: 60, done: true, claimed: true, rewardXp: 50 },
          { id: 'first_job', label: 'Manos a la obra', description: 'Consigue tu primer trabajo.', progress: 1, goal: 1, done: true, claimed: false, rewardXp: 100 },
          { id: 'duty_10h', label: 'Vocación', description: 'Pasa 10 horas de servicio.', progress: 4, goal: 10, done: false, claimed: false, rewardXp: 250 },
          { id: 'gm_win', label: 'Campeón', description: 'Gana una partida de los modos de juego.', progress: 1, goal: 1, done: true, claimed: true, rewardXp: 75 }] },
        { id: 'otono', label: 'Noches de otoño', icon: 'sparkle', limited: true, endsAt: now + 9 * 86400, description: 'Logros de temporada: solo durante este evento.', done: 0, total: 2, items: [
          { id: 'otono_event', label: 'Presente', description: 'Asiste a un evento de la comunidad.', progress: 0, goal: 1, done: false, claimed: false, rewardXp: 120 },
          { id: 'otono_hours', label: 'Noctámbulo', description: 'Juega 5 horas durante la temporada.', progress: 2, goal: 5, done: false, claimed: false, rewardXp: 200 }] },
      ],
      events: [
        { id: 'carrera', title: 'Carrera nocturna del puerto', description: 'Circuito por el puerto con la policía cortando calles.', startsAt: now + 2 * 86400 + 4 * 3600, place: 'Puerto de Los Santos', howTo: 'Inscríbete en Discord, canal #eventos.' },
        { id: 'propio', title: 'Crea tu propio evento', description: 'Propón el tuyo y el staff te ayuda a montarlo.', place: 'Discord', steps: ['Abre un ticket en Discord', 'Cuéntanos nombre, fecha y descripción', 'Diseñamos el escenario contigo', 'El staff lo revisa y lo anuncia'] },
        { id: 'boxeo', title: 'Velada de boxeo', description: 'Combates amistosos en el gimnasio.', startsAt: now - 1800, place: 'Gimnasio de Vespucci' },
      ],
      fines: { outstanding: 1300, canSearch: true, methods: { cash: true, bank: true },
        pending: [{ id: 12, reason: 'Exceso de velocidad', amount: 800, paid: 0, outstanding: 800, status: 'pending', officer: 'Ana Ortega', issuedAt: now - 3 * 3600 },
          { id: 9, reason: 'Estacionar en zona prohibida', amount: 1000, paid: 500, outstanding: 500, status: 'partial', officer: 'Marco Díaz', issuedAt: now - 4 * 86400 }],
        history: [{ id: 3, reason: 'No respetar un semáforo', amount: 300, paid: 300, outstanding: 0, status: 'paid', officer: 'Ana Ortega', issuedAt: now - 20 * 86400 }] },
      orgs: {
        government: [{ name: 'ambulance', label: 'Servicios Médicos', member: true, grade: 'Paramédica', primary: true, onduty: true, dutyCount: 3 },
          { name: 'police', label: 'Policía de Los Santos', member: false, dutyCount: 5 }, { name: 'sheriff', label: 'Sheriff del condado', member: false, dutyCount: 1 }],
        companies: [{ name: 'mechanic', label: 'Taller mecánico', member: true, grade: 'Aprendiz', dutyCount: 2 }, { name: 'taxi', label: 'Taxi', member: false, dutyCount: 0 }],
        groups: [{ name: 'ballas', label: 'Ballas', member: false }],
      },
      static: {
        serverName: 'PRÓXIMA RP', storeUrl: 'https://example.tebex.io', discord: 'https://discord.gg/qUcD5gCf6v',
        support: [{ title: 'Soporte del staff', text: 'Abre un ticket en nuestro Discord, canal de soporte.', link: 'https://discord.gg/qUcD5gCf6v' },
          { title: 'Reportar a un jugador', text: 'Pulsa F9 → «Reportar a un jugador».' }, { title: 'Hablar fuera de personaje', text: 'Usa /b (o /ooc) con respeto.' }, { title: 'Acciones', text: 'Usa /me.' }],
        news: [{ date: '2026-11-02', title: 'Panel de la ciudad', items: ['Nuevo panel con perfil, recompensas, logros, eventos y reglamento.'] }],
        rulesIntro: 'Próxima RP es una ciudad de rol.',
        rules: [{ id: 'pg', title: 'PowerGaming (PG)', body: 'Hacer algo que tu personaje no podría hacer en la realidad.', points: ['No fuerces resultados.', 'Respeta tus heridas.'] },
          { id: 'mg', title: 'MetaGaming (MG)', body: 'Usar información que tu personaje no conoce.', points: ['Lo que ves en streams no lo sabe tu personaje.'] },
          { id: 'robos', title: 'Robos, atracos y secuestros', body: 'Los delitos grandes necesitan preparación.', points: ['Rehenes: deben ser reales y voluntarios en el rol.'] }],
      },
    };
    window.postMessage({ type: 'data', data: demo }, '*');
    const view = params.get('view');
    if (view) S.view = view;
    if (params.get('tab')) { S.orgTab = params.get('tab'); S.helpTab = params.get('tab'); }
    if (params.get('q')) S.query = params.get('q');
    setTimeout(() => {
      setOpen(true, { textScale: 3, sounds: false, reduceMotion: true });
      if (params.has('toast')) toast('¡Logro desbloqueado!', 'Manos a la obra · +100 XP');
    }, 50);
  }
})();
