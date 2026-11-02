// pxd_admin — soporte (todos) y panel de staff. Todo el texto con textContent.
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const params = new URLSearchParams(location.search);
  const DEMO = params.has('demo');
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pxd_admin';

  const post = (name, data = {}) => {
    if (DEMO) { demoPost(name, data); return Promise.resolve(); }
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).catch(() => {});
  };

  const el = (tag, cls, text) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined && text !== null) n.textContent = String(text);
    return n;
  };
  const money = (n) => (Number.isFinite(n) ? `$${Math.round(n).toLocaleString('en-US')}` : '—');
  const duration = (s) => {
    if (!Number.isFinite(s)) return '—';
    const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
    if (d) return `${d} d ${h} h`;
    if (h) return `${h} h ${m} min`;
    return `${m} min`;
  };
  const ago = (t) => {
    if (!t) return '';
    const s = Math.max(0, Math.floor(Date.now() / 1000 - t));
    if (s < 60) return 'ahora';
    if (s < 3600) return `hace ${Math.floor(s / 60)} min`;
    if (s < 86400) return `hace ${Math.floor(s / 3600)} h`;
    return new Date(t * 1000).toLocaleDateString('es-MX', { day: 'numeric', month: 'short' });
  };
  const STATE = { open: 'Nuevo', claimed: 'En curso', closed: 'Cerrado' };
  const stateChip = (s) => el('span', `state state--${s}`, STATE[s] || s);

  // ── Avisos ────────────────────────────────────────────
  function toast(title, text, kind = 'info') {
    const t = el('div', `toast toast--${kind}`);
    t.append(el('b', '', title || 'Próxima RP'), el('span', '', text || ''));
    $('toasts').prepend(t);
    setTimeout(() => t.remove(), 7000);
    while ($('toasts').children.length > 4) $('toasts').lastChild.remove();
  }
  function beep() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      [660, 880].forEach((f, i) => {
        const o = ctx.createOscillator(), g = ctx.createGain();
        o.frequency.value = f; o.type = 'sine';
        g.gain.setValueAtTime(0.0001, ctx.currentTime + i * 0.14);
        g.gain.exponentialRampToValueAtTime(0.18, ctx.currentTime + i * 0.14 + 0.02);
        g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + i * 0.14 + 0.18);
        o.connect(g).connect(ctx.destination);
        o.start(ctx.currentTime + i * 0.14); o.stop(ctx.currentTime + i * 0.14 + 0.2);
      });
    } catch (_) { /* sin audio */ }
  }

  // ── Cerrar ────────────────────────────────────────────
  function close() {
    $('support').classList.add('hidden');
    $('staff').classList.add('hidden');
    $('wounds').classList.add('hidden');
    post('close');
  }
  document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('wounds').classList.contains('hidden')) return $('wounds').classList.add('hidden');
    if (!$('support').classList.contains('hidden') || !$('staff').classList.contains('hidden')) close();
  });

  // ══ Soporte ═══════════════════════════════════════════
  const sup = { data: null, tab: 'help', category: null, openId: null };

  function renderSupport() {
    const d = sup.data || {};
    $('open-staff').classList.toggle('hidden', !d.isStaff);
    const mine = d.reports || [];
    $('mine-count').textContent = mine.filter((r) => r.state !== 'closed').length || '';
    document.querySelectorAll('[data-stab]').forEach((b) => b.classList.toggle('is-on', b.dataset.stab === sup.tab));
    const isForm = sup.tab !== 'mine';
    $('report-form').classList.toggle('hidden', !isForm);
    $('mine').classList.toggle('hidden', isForm);
    if (isForm) {
      const kind = sup.tab;
      $('form-hint').textContent = kind === 'player'
        ? 'Si alguien rompe las normas, cuéntanoslo. Necesitamos su ID (lo ves sobre su cabeza o en el panel) o su PROX-ID.'
        : 'Si estás atascado/a, encontraste un fallo o tienes una duda, escríbenos y alguien del staff te atenderá.';
      $('target-field').classList.toggle('hidden', kind !== 'player');
      const box = $('categories');
      box.replaceChildren();
      const cats = (d.categories || []).filter((c) => c.kind === kind);
      if (!cats.some((c) => c.id === sup.category)) sup.category = cats[0] ? cats[0].id : null;
      cats.forEach((c) => {
        const b = el('button', `chip${c.id === sup.category ? ' is-on' : ''}`, c.label);
        b.type = 'button';
        b.addEventListener('click', () => { sup.category = c.id; renderSupport(); });
        box.append(b);
      });
    } else {
      renderMine(mine);
    }
  }

  function thread(r, staffView) {
    const box = el('div', 'thread__msgs');
    const first = el('div', 'msg');
    first.append(el('small', '', staffView ? `${r.reporter ? (r.reporter.charName || r.reporter.name) : 'Jugador'} · ${ago(r.createdAt)}` : `Tú · ${ago(r.createdAt)}`), document.createTextNode(r.text));
    box.append(first);
    (r.messages || []).forEach((m) => {
      const n = el('div', `msg${m.staff ? ' msg--staff' : ''}`);
      n.append(el('small', '', `${m.staff ? `Staff · ${m.author}` : (staffView ? m.author : 'Tú')} · ${ago(m.at)}`), document.createTextNode(m.text));
      box.append(n);
    });
    if (r.state === 'closed') box.append(el('div', 'msg msg--note', `Cerrado${r.staff ? ` por ${r.staff}` : ''}${r.note ? ` · ${r.note}` : ''}`));
    return box;
  }

  function renderMine(list) {
    const ul = $('mine-list');
    ul.replaceChildren();
    if (!list.length) ul.append(el('p', 'empty', 'Aún no has enviado reportes.'));
    list.forEach((r) => {
      const li = el('li', `item${r.id === sup.openId ? ' is-on' : ''}`);
      const main = el('div', 'item__main');
      main.append(el('b', '', `${r.categoryLabel}${r.targetRef ? ` · ${r.targetRef}` : ''}`), el('small', '', r.text.slice(0, 90)));
      const side = el('div', 'item__side');
      side.append(stateChip(r.state), el('small', '', ago(r.updatedAt)));
      li.append(el('span', 'item__id', `#${r.id}`), main, side);
      li.addEventListener('click', () => { sup.openId = r.id; renderSupport(); });
      ul.append(li);
    });
    const r = list.find((x) => x.id === sup.openId);
    const art = $('mine-thread');
    art.classList.toggle('hidden', !r);
    art.replaceChildren();
    if (!r) return;
    art.append(thread(r, false));
    if (r.state !== 'closed') {
      const row = el('div', 'reply');
      const input = el('input');
      input.maxLength = 600; input.placeholder = 'Añadir un mensaje…';
      const send = el('button', 'btn btn--primary', 'Enviar');
      send.type = 'button';
      const go = () => { if (input.value.trim()) { post('playerReply', { id: r.id, text: input.value }); input.value = ''; } };
      send.addEventListener('click', go);
      input.addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
      row.append(input, send);
      art.append(row);
    }
  }

  document.querySelectorAll('[data-stab]').forEach((b) => b.addEventListener('click', () => { sup.tab = b.dataset.stab; renderSupport(); }));
  $('text').addEventListener('input', () => { $('text-count').textContent = $('text').value.length; });
  $('report-form').addEventListener('submit', (e) => {
    e.preventDefault();
    post('createReport', { kind: sup.tab, category: sup.category, target: $('target').value, text: $('text').value });
    $('text').value = ''; $('target').value = ''; $('text-count').textContent = '0';
    sup.tab = 'mine';
  });
  $('open-staff').addEventListener('click', () => { $('support').classList.add('hidden'); post('openStaff'); });

  // ══ Staff ═════════════════════════════════════════════
  const st = { data: null, view: 'players', query: '', selected: null, report: null, filter: 'active' };

  function setView(v) {
    st.view = v;
    document.querySelectorAll('[data-view]').forEach((b) => b.classList.toggle('is-on', b.dataset.view === v));
    document.querySelectorAll('[data-pane]').forEach((p) => p.classList.toggle('hidden', p.dataset.pane !== v));
  }
  document.querySelectorAll('[data-view]').forEach((b) => b.addEventListener('click', () => setView(b.dataset.view)));
  $('refresh').addEventListener('click', () => post('refreshStaff'));
  $('player-search').addEventListener('input', (e) => { st.query = e.target.value; renderPlayers(); });

  function matches(p, q) {
    q = q.trim().toLowerCase();
    if (!q) return true;
    if (String(p.id) === q) return true;
    return [p.name, p.charName, p.citizenid, p.proxId, p.job].some((v) => v && String(v).toLowerCase().includes(q));
  }

  function renderStaff() {
    const d = st.data || {};
    const players = d.players || [];
    const reports = d.reports || [];
    $('players-count').textContent = players.length;
    const open = reports.filter((r) => r.state === 'open').length;
    $('reports-open').textContent = open;
    $('reports-open').classList.toggle('is-zero', open === 0);
    $('duty').classList.toggle('is-on', !!d.onDuty);
    $('duty-label').textContent = d.onDuty ? 'De servicio' : 'Fuera de servicio';
    renderPlayers(); renderReports(); renderLog(); renderCommands();
  }

  function renderPlayers() {
    const list = ((st.data && st.data.players) || []).filter((p) => matches(p, st.query));
    const ul = $('player-list');
    ul.replaceChildren();
    if (!list.length) ul.append(el('p', 'empty', 'Nadie coincide con la búsqueda.'));
    list.forEach((p) => {
      const li = el('li', `item${p.id === st.selected ? ' is-on' : ''}`);
      const main = el('div', 'item__main');
      main.append(el('b', '', p.charName || p.name), el('small', '', [p.charName ? p.name : null, p.job, p.proxId].filter(Boolean).join(' · ')));
      const side = el('div', 'item__side', `${p.ping ?? '—'} ms`);
      li.append(el('span', 'item__id', p.id), main, side);
      li.addEventListener('click', () => { st.selected = p.id; renderPlayers(); });
      ul.append(li);
    });
    renderPlayerDetail();
  }

  const act = (action, target, payload) => post('action', { action, target, payload });

  function actionBtn(label, action, target, cls = '') {
    const b = el('button', `btn ${cls}`.trim(), label);
    b.type = 'button';
    b.addEventListener('click', () => act(action, target));
    return b;
  }

  function renderPlayerDetail() {
    const box = $('player-detail');
    box.replaceChildren();
    const p = ((st.data && st.data.players) || []).find((x) => x.id === st.selected);
    if (!p) { box.append(el('p', 'empty', 'Elige un jugador para ver su ficha.')); return; }
    const head = el('div', 'card-head');
    const left = el('div');
    left.append(el('h2', '', p.charName || p.name), el('p', '', `${p.name} · ID ${p.id}${p.bucket ? ` · mundo ${p.bucket}` : ''}`));
    const right = el('div');
    if (p.proxId) right.append(el('span', 'tag', p.proxId));
    head.append(left, right);

    const stats = el('div', 'stats');
    const stat = (label, value, cls) => { const s = el('div', 'stat'); s.append(el('small', '', label), el('b', cls || '', value)); return s; };
    stats.append(
      stat('Trabajo', p.job ? `${p.job}${p.grade ? ` · ${p.grade}` : ''}` : '—', p.onduty ? 'onduty' : ''),
      stat('Efectivo', money(p.cash), 'cash'),
      stat('Banco', money(p.bank)),
      stat('Nivel', p.level ?? '—'),
      stat('Tiempo jugado', duration(p.playtime)),
      stat('Hoy', duration(p.playtimeToday)),
      stat('Ping', p.ping != null ? `${p.ping} ms` : '—'),
      stat('Estado', p.frozen ? 'Congelado' : 'Normal'),
    );

    const ids = el('div', 'ids');
    [['Citizen ID', p.citizenid], ['Licencia', p.license], ['Discord', p.discord]].forEach(([k, v]) => {
      if (!v) return;
      const row = el('div');
      row.append(document.createTextNode(`${k}: `), el('code', '', v));
      ids.append(row);
    });

    const actions = el('div', 'actions');
    actions.append(
      actionBtn('Ir', 'goto', p.id), actionBtn('Traer', 'bring', p.id), actionBtn('Devolver', 'back', p.id),
      actionBtn(p.frozen ? 'Descongelar' : 'Congelar', 'freeze', p.id), actionBtn('Reanimar', 'revive', p.id),
      actionBtn('Vida', 'heal', p.id), actionBtn('Necesidades', 'needs', p.id), actionBtn('Heridas', 'wounds', p.id),
      actionBtn('Espectar', 'spectate', p.id),
    );

    const msgRow = el('div', 'reply');
    const msg = el('input');
    msg.maxLength = 300; msg.placeholder = 'Mensaje privado para este jugador';
    const msgBtn = el('button', 'btn btn--primary', 'Enviar');
    msgBtn.type = 'button';
    msgBtn.addEventListener('click', () => { if (msg.value.trim()) { act('message', p.id, { text: msg.value }); msg.value = ''; } });
    msgRow.append(msg, msgBtn);

    box.append(head, stats, ids, el('p', 'section-title', 'Acciones'), actions, el('p', 'section-title', 'Mensaje'), msgRow);
    if (st.data.canKick) {
      const kickRow = el('div', 'reply');
      const reason = el('input');
      reason.maxLength = 200; reason.placeholder = 'Motivo de la expulsión';
      const kick = el('button', 'btn btn--danger', 'Expulsar');
      kick.type = 'button';
      kick.addEventListener('click', () => { if (reason.value.trim().length >= 3) act('kick', p.id, { reason: reason.value }); });
      kickRow.append(reason, kick);
      box.append(el('p', 'section-title', 'Moderación'), kickRow);
    }
    box.append(el('p', 'note', `${st.data.txAdminHint || ''} Casi todas las acciones piden estar de servicio.`));
  }

  // Reportes
  document.querySelectorAll('[data-filter]').forEach((b) => b.addEventListener('click', () => {
    st.filter = b.dataset.filter;
    document.querySelectorAll('[data-filter]').forEach((x) => x.classList.toggle('is-on', x === b));
    renderReports();
  }));

  function renderReports() {
    const all = (st.data && st.data.reports) || [];
    const list = all.filter((r) => (st.filter === 'active' ? r.state !== 'closed' : r.state === st.filter));
    const ul = $('report-list');
    ul.replaceChildren();
    if (!list.length) ul.append(el('p', 'empty', 'No hay reportes aquí.'));
    list.forEach((r) => {
      const li = el('li', `item${r.id === st.report ? ' is-on' : ''}`);
      const main = el('div', 'item__main');
      const who = r.reporter ? (r.reporter.charName || r.reporter.name) : '—';
      main.append(el('b', '', `${r.categoryLabel}`), el('small', '', `${who}${r.target ? ` → ${r.target.charName || r.target.name}` : ''} · ${ago(r.createdAt)}`));
      const side = el('div', 'item__side');
      side.append(stateChip(r.state));
      li.append(el('span', 'item__id', `#${r.id}`), main, side);
      li.addEventListener('click', () => { st.report = r.id; renderReports(); });
      ul.append(li);
    });
    renderReportDetail(all.find((r) => r.id === st.report));
  }

  function renderReportDetail(r) {
    const box = $('report-detail');
    box.replaceChildren();
    if (!r) { box.append(el('p', 'empty', 'Elige un reporte.')); return; }
    const head = el('div', 'card-head');
    const left = el('div');
    left.append(el('h2', '', `#${r.id} · ${r.categoryLabel}`), el('p', '', r.kind === 'player' ? 'Reporte a un jugador' : 'Petición de ayuda'));
    head.append(left, stateChip(r.state));
    const meta = el('div', 'meta');
    const m = (k, v) => { const s = el('span'); s.append(document.createTextNode(`${k} `), el('b', '', v)); return s; };
    meta.append(m('Reporta:', r.reporter ? `${r.reporter.charName || r.reporter.name}${r.reporter.online ? ` (ID ${r.reporter.online})` : ' (desconectado)'}` : '—'));
    if (r.target) meta.append(m('Reportado:', `${r.target.charName || r.target.name} (ID ${r.target.id}${r.target.proxId ? ` · ${r.target.proxId}` : ''})`));
    if (r.staff) meta.append(m('Atiende:', r.staff));
    meta.append(m('Creado:', ago(r.createdAt)));

    const actions = el('div', 'actions');
    const rbtn = (label, action, cls, payload) => {
      const b = el('button', `btn ${cls || ''}`.trim(), label);
      b.type = 'button';
      b.disabled = r.state === 'closed' && action !== 'goto';
      b.addEventListener('click', () => post('reportAction', { action, id: r.id, text: payload ? payload() : undefined }));
      return b;
    };
    actions.append(rbtn('Reclamar', 'claim'), rbtn('Ir con quien reporta', 'goto'));
    if (r.target) {
      const b = el('button', 'btn', 'Ir al reportado');
      b.type = 'button';
      b.addEventListener('click', () => act('goto', r.target.id));
      actions.append(b);
    }

    const reply = el('div', 'reply');
    const input = el('input');
    input.maxLength = 600; input.placeholder = 'Responder al jugador…';
    const send = el('button', 'btn btn--primary', 'Responder');
    send.type = 'button';
    send.disabled = r.state === 'closed';
    send.addEventListener('click', () => { if (input.value.trim()) { post('reportAction', { action: 'reply', id: r.id, text: input.value }); input.value = ''; } });
    reply.append(input, send);

    const closeRow = el('div', 'reply');
    const note = el('input');
    note.maxLength = 300; note.placeholder = 'Nota de cierre (qué se hizo)';
    const closeBtn = el('button', 'btn btn--danger', 'Cerrar');
    closeBtn.type = 'button';
    closeBtn.disabled = r.state === 'closed';
    closeBtn.addEventListener('click', () => post('reportAction', { action: 'close', id: r.id, text: note.value }));
    closeRow.append(note, closeBtn);

    const t = el('div', 'thread');
    t.append(thread(r, true));
    box.append(head, meta, actions, t, el('p', 'section-title', 'Responder'), reply, el('p', 'section-title', 'Cerrar'), closeRow);
  }

  function renderLog() {
    const body = $('log-body');
    body.replaceChildren();
    ((st.data && st.data.log) || []).forEach((l) => {
      const tr = el('tr');
      [new Date(l.at * 1000).toLocaleString('es-MX', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }), l.staff, l.action, l.target || '—', l.detail || ''].forEach((v) => tr.append(el('td', '', v)));
      body.append(tr);
    });
  }

  function renderCommands() {
    const body = $('commands-body');
    body.replaceChildren();
    const NO_DUTY = new Set(['duty', 'message', 'kick']);
    ((st.data && st.data.commands) || []).forEach((c) => {
      const tr = el('tr');
      const cmd = el('td');
      cmd.append(el('code', '', `/${c.name}${c.args ? ` ${c.args}` : ''}`));
      tr.append(cmd, el('td', '', c.desc), el('td', NO_DUTY.has(c.action) ? '' : 'yes', NO_DUTY.has(c.action) ? 'No' : 'Sí'));
      body.append(tr);
    });
  }

  // Herramientas propias
  document.querySelectorAll('[data-tool]').forEach((b) => b.addEventListener('click', () => {
    const t = b.dataset.tool;
    const me = st.data ? st.data.me : 0;
    if (t === 'car') return act('car', me, { model: $('car-model').value });
    if (t === 'announce') { const v = $('announce-text').value; $('announce-text').value = ''; return act('announce', me, { text: v }); }
    act(t, me);
  }));
  $('duty').addEventListener('click', () => act('duty', st.data ? st.data.me : 0));

  function showWounds(w) {
    const m = $('wounds');
    m.replaceChildren();
    const card = el('div', 'modal__card');
    const r = w.report || { parts: [] };
    card.append(el('h2', '', `Heridas · ${w.name || ''}`), el('p', '', `${r.state} · sangrado ${r.bleed || 0}`));
    if (!r.parts.length) card.append(el('p', '', 'Sin heridas registradas.'));
    r.parts.forEach((p) => {
      const row = el('div', 'wound');
      row.append(el('span', '', p.part), el('b', `sev-${Math.min(p.severity, 4)}`, p.label));
      card.append(row);
    });
    const ok = el('button', 'btn btn--primary', 'Entendido');
    ok.type = 'button';
    ok.style.marginTop = '16px';
    ok.addEventListener('click', () => m.classList.add('hidden'));
    card.append(ok);
    m.append(card);
    m.classList.remove('hidden');
  }

  let announceTimer = null;
  function announce(text) {
    $('announce-text-view').textContent = text;
    $('announce').classList.remove('hidden');
    clearTimeout(announceTimer);
    announceTimer = setTimeout(() => $('announce').classList.add('hidden'), 12000);
  }

  // ── Mensajes del juego ────────────────────────────────
  window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
      case 'support':
        sup.data = m.data; $('staff').classList.add('hidden'); $('support').classList.remove('hidden'); renderSupport(); break;
      case 'staff':
        st.data = m.data; $('support').classList.add('hidden'); $('staff').classList.remove('hidden'); renderStaff(); break;
      case 'reports':
        if (st.data) { st.data.reports = m.reports; renderStaff(); } break;
      case 'duty':
        if (st.data) { st.data.onDuty = m.on; renderStaff(); } break;
      case 'hide':
        $('support').classList.add('hidden'); $('staff').classList.add('hidden'); break;
      case 'toast':
        toast(m.title, m.text, m.kind); break;
      case 'alert': {
        const r = m.report || {};
        beep();
        toast(`Nuevo reporte #${r.id}`, `${r.categoryLabel} · ${r.reporter || ''}`, 'alert');
        break;
      }
      case 'spectate':
        $('spectate').textContent = m.on ? `Espectando a ${m.name} · pulsa la tecla del panel de staff para salir` : '';
        $('spectate').classList.toggle('hidden', !m.on); break;
      case 'wounds': showWounds(m.data || {}); break;
      case 'announce': announce(m.text || ''); break;
      default: break;
    }
  });

  // ── Demo ──────────────────────────────────────────────
  function demoPost(name, data) {
    if (name === 'action') toast('Staff', `Acción «${data.action}» (demo)`, 'success');
    if (name === 'createReport') toast('Soporte', 'Reporte #13 enviado. El staff te responderá aquí.', 'success');
  }
  if (DEMO) {
    document.body.style.background = '#2a3140';
    const now = Math.floor(Date.now() / 1000);
    const categories = [
      { id: 'pg', kind: 'player', label: 'Powergaming / antirol' }, { id: 'dm', kind: 'player', label: 'Ataque sin rol (DM/VDM)' },
      { id: 'mg', kind: 'player', label: 'Metagaming' }, { id: 'trato', kind: 'player', label: 'Insultos o acoso' },
      { id: 'atascado', kind: 'help', label: 'Estoy atascado/a' }, { id: 'bug', kind: 'help', label: 'Encontré un fallo' }, { id: 'duda', kind: 'help', label: 'Tengo una duda' },
    ];
    const reports = [
      { id: 12, kind: 'player', categoryLabel: 'Ataque sin rol (DM/VDM)', text: 'Me atropelló dos veces en la plaza sin mediar palabra.', state: 'open', createdAt: now - 240, updatedAt: now - 240,
        targetRef: '7', reporter: { name: 'Edy', charName: 'Valeria Ríos', online: 3 }, target: { id: 7, name: 'Zeta', charName: 'Bruno Salgado', proxId: 'PROX-7KQ2' }, messages: [] },
      { id: 11, kind: 'help', categoryLabel: 'Estoy atascado/a', text: 'Me quedé dentro de una pared en el hospital.', state: 'claimed', staff: 'IsyConta', createdAt: now - 1900, updatedAt: now - 600,
        reporter: { name: 'Lumen', charName: 'Ana Torres', online: 5 }, messages: [{ author: 'IsyConta', text: 'Voy para allá, no te muevas.', at: now - 600, staff: true }] },
      { id: 9, kind: 'help', categoryLabel: 'Tengo una duda', text: '¿Dónde se saca la licencia de conducir?', state: 'closed', staff: 'IsyConta', note: 'Explicado: Ayuntamiento.', createdAt: now - 86000, updatedAt: now - 80000,
        reporter: { name: 'Nova', charName: 'Iker Méndez' }, messages: [] },
    ];
    const players = [
      { id: 3, name: 'Edy', charName: 'Valeria Ríos', citizenid: 'LWWI414K', proxId: 'PROX-3MHA', job: 'Servicios Médicos', grade: 'Paramédica', onduty: true, cash: 12850, bank: 248300, level: 7, playtime: 2563200, playtimeToday: 8040, ping: 48, license: 'license:3f2a…c91', discord: 'discord:4410…', bucket: 0 },
      { id: 5, name: 'Lumen', charName: 'Ana Torres', citizenid: 'QX81PA2D', proxId: 'PROX-9TRV', job: 'Taxi', grade: 'Conductora', cash: 500, bank: 5000, level: 2, playtime: 7300, playtimeToday: 3100, ping: 71, license: 'license:aa11…', bucket: 0 },
      { id: 7, name: 'Zeta', charName: 'Bruno Salgado', citizenid: 'MM20KD8E', proxId: 'PROX-7KQ2', job: 'Mecánico', grade: 'Aprendiz', cash: 2200, bank: 14000, level: 4, playtime: 50400, playtimeToday: 1200, ping: 95, license: 'license:bb22…', bucket: 0, frozen: true },
    ];
    const commands = [
      { name: 'duty', action: 'duty', args: '', desc: 'Entrar o salir de servicio: atuendo STAFF, etiqueta e invencible.' },
      { name: 'revivir', action: 'revive', args: '[id]', desc: 'Reanima a un jugador (o a ti).' },
      { name: 'vida', action: 'heal', args: '[id]', desc: 'Salud y armadura al máximo y quita heridas.' },
      { name: 'llenarnecesidades', action: 'needs', args: '[id]', desc: 'Hambre y sed al 100 y estrés a 0.' },
      { name: 'wounds', action: 'wounds', args: '[id]', desc: 'Muestra heridas por zona, sangrado y estado.' },
      { name: 'tp', action: 'goto', args: '<id>', desc: 'Ir con un jugador.' },
      { name: 'noclip', action: 'noclip', args: '', desc: 'Volar atravesando paredes.' },
      { name: 'coche', action: 'car', args: '<modelo>', desc: 'Sacar un vehículo (p. ej. /coche sultan).' },
    ];
    if (params.has('staff')) {
      st.data = { players, reports, log: [
        { at: now - 300, staff: 'IsyConta', action: 'goto', target: 'Ana Torres (#5)' },
        { at: now - 900, staff: 'IsyConta', action: 'report:claim', target: '#11' },
        { at: now - 4000, staff: 'IsyConta', action: 'kick', target: 'Troll (#9)', detail: 'DM reiterado' },
      ], me: 1, canKick: true, onDuty: true, commands, txAdminHint: 'Para banear, usa txAdmin → Players → busca al jugador → Ban.' };
      st.selected = 3; st.report = 12;
      $('staff').classList.remove('hidden');
      renderStaff();
      const v = params.get('view');
      if (v) setView(v);
      if (params.has('wounds')) showWounds({ name: 'Valeria Ríos', report: { state: 'Herido/a en el suelo', bleed: 2, parts: [{ part: 'Pierna izq.', severity: 3, label: 'Grave' }, { part: 'Torso', severity: 1, label: 'Leve' }] } });
      if (params.has('alert')) toast('Nuevo reporte #12', 'Ataque sin rol (DM/VDM) · Valeria Ríos', 'alert');
    } else {
      sup.data = { categories, reports: [{ ...reports[1], reporter: undefined }, { ...reports[2], reporter: undefined }], isStaff: true };
      sup.tab = params.get('tab') || 'player';
      if (sup.tab === 'mine') sup.openId = 11;
      $('support').classList.remove('hidden');
      renderSupport();
    }
    if (params.has('announce')) announce('Evento esta noche a las 21:00 en la playa de Vespucci. ¡Os esperamos!');
  }
})();
