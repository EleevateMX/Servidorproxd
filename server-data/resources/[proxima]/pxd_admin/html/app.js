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
    $('dialog').classList.add('hidden');
    post('close');
  }
  document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('warning').classList.contains('hidden')) return;
    if (!$('dialog').classList.contains('hidden')) return $('dialog').classList.add('hidden');
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

  // ══ Centro de administración ══════════════════════════
  // La interfaz solo muestra u oculta según los permisos que manda el servidor; el
  // servidor vuelve a comprobar cada acción (permiso, objetivo y motivo).
  const st = { data: null, view: 'players', query: '', selected: null, report: null, filter: 'active', detailTab: 'ficha', history: null, hours: 24 };
  const can = (perm) => !!(st.data && st.data.perms && String(perm).split('|').some((p) => st.data.perms[p]));
  const fmtDate = (t) => (t ? new Date(t * 1000).toLocaleString('es-MX', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—');
  const ACTION_LABEL = {
    duty: 'Servicio', goto: 'Ir a', bring: 'Traer', back: 'Devolver', freeze: 'Congelar', revive: 'Reanimar', heal: 'Curar',
    needs: 'Necesidades', wounds: 'Heridas', spectate: 'Espectar', message: 'Mensaje', kick: 'Expulsar', warn: 'Advertencia',
    ban: 'Baneo', unban: 'Levantar baneo', noclip: 'Noclip', invisible: 'Invisible', tpm: 'Ir al marcador', car: 'Vehículo de prueba',
    repair: 'Reparar', clean: 'Limpiar', dv: 'Borrar vehículo', vehinfo: 'Info vehículo', vehowner: 'Titularidad', coords: 'Coordenadas',
    devtools: 'Herramientas dev', props: 'Editor de props', qbxmenu: 'Menú Qbox', announce: 'Anuncio', money: 'Corrección de dinero',
    'report:claim': 'Reporte: reclamar', 'report:reply': 'Reporte: responder', 'report:close': 'Reporte: cerrar', 'report:goto': 'Reporte: ir',
  };

  function setView(v) {
    st.view = v;
    document.querySelectorAll('[data-view]').forEach((b) => b.classList.toggle('is-on', b.dataset.view === v));
    document.querySelectorAll('[data-pane]').forEach((p) => p.classList.toggle('hidden', p.dataset.pane !== v));
    if (v === 'moderation') post('query', { kind: 'bans' });
    if (v === 'economy') post('query', { kind: 'economy', args: { hours: st.hours } });
    if (v === 'log') post('query', { kind: 'audit' });
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

  const act = (action, target, payload) => post('action', { action, target, payload });

  // ── Diálogo de motivo ────────────────────────────────
  let dialogSubmit = null;
  function ask({ title, text, extra, onOk }) {
    $('dialog-title').textContent = title;
    $('dialog-text').textContent = text || '';
    $('dialog-extra').replaceChildren(...(extra ? [extra.node] : []));
    $('dialog-reason').value = '';
    $('dialog').classList.remove('hidden');
    dialogSubmit = () => {
      const reason = $('dialog-reason').value.trim();
      if (reason.length < 3) { toast('Administración', 'Escribe el motivo (mínimo 3 caracteres).', 'error'); return; }
      const more = extra && extra.read ? extra.read() : {};
      if (more === null) return;
      onOk({ reason, ...more });
      $('dialog').classList.add('hidden');
    };
    setTimeout(() => $('dialog-reason').focus(), 30);
  }
  $('dialog-form').addEventListener('submit', (e) => { e.preventDefault(); if (dialogSubmit) dialogSubmit(); });
  $('dialog-cancel').addEventListener('click', () => $('dialog').classList.add('hidden'));

  const selectField = (label, options) => {
    const wrap = el('label', 'field');
    const sel = el('select');
    options.forEach(([v, t]) => { const o = el('option', '', t); o.value = v; sel.append(o); });
    wrap.append(el('span', '', label), sel);
    return { wrap, sel };
  };
  const inputField = (label, attrs) => {
    const wrap = el('label', 'field');
    const inp = el('input');
    Object.assign(inp, attrs || {});
    wrap.append(el('span', '', label), inp);
    return { wrap, inp };
  };

  function askAction(action, p, title, text) {
    ask({ title, text, onOk: (payload) => act(action, p.id, payload) });
  }

  function askBan(p) {
    const f = selectField('Duración', [['24', '1 día'], ['72', '3 días'], ['168', '7 días'], ['720', '30 días'], ['0', 'Permanente']]);
    ask({ title: `Banear a ${p.charName || p.name}`, text: (st.data && st.data.banHint) || '', extra: { node: f.wrap, read: () => ({ hours: Number(f.sel.value) }) },
      onOk: (payload) => act('ban', p.id, payload) });
  }

  function askMoney(p) {
    const box = el('div', 'form-row');
    const acc = selectField('Cuenta', [['cash', 'Efectivo'], ['bank', 'Banco']]);
    const amt = inputField('Importe (negativo para retirar)', { type: 'number', step: '1', placeholder: 'p. ej. 500 o -500' });
    box.append(acc.wrap, amt.wrap);
    const max = (st.data && st.data.limits && st.data.limits.maxMoney) || 1000000;
    ask({ title: `Corregir dinero de ${p.charName || p.name}`, text: `Máximo ${money(max)} por corrección. El saldo nunca queda en negativo.`,
      extra: { node: box, read: () => {
        const n = Number(amt.inp.value);
        if (!Number.isInteger(n) || n === 0 || Math.abs(n) > max) { toast('Administración', 'Importe no válido.', 'error'); return null; }
        return { account: acc.sel.value, amount: n };
      } },
      onOk: (payload) => act('money', p.id, payload) });
  }

  // ── Render general ──────────────────────────────────
  function renderStaff() {
    const d = st.data || {};
    const players = d.players || [];
    const reports = d.reports || [];
    $('my-role').textContent = d.role || 'Staff';
    $('players-count').textContent = players.length;
    const open = reports.filter((r) => r.state === 'open').length;
    $('reports-open').textContent = open;
    $('reports-open').classList.toggle('is-zero', open === 0);
    $('duty').classList.toggle('is-on', !!d.onDuty);
    $('duty-label').textContent = d.onDuty ? 'De servicio' : 'Fuera de servicio';
    $('noclip-badge').classList.toggle('is-on', !!d.noclip);
    $('spec-badge').classList.toggle('is-on', !!d.spectating);
    $('ban-hint').textContent = d.banHint || '';
    document.querySelectorAll('[data-perm]').forEach((n) => n.classList.toggle('hidden', !can(n.dataset.perm)));
    $('qbx-menu').disabled = !d.qbxMenu;
    if (document.querySelector(`[data-view="${st.view}"]`).classList.contains('hidden')) setView('players');
    renderPlayers(); renderReports(); renderLog(d.log || []); renderCommands();
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
      const side = el('div', 'item__side');
      if (p.frozen) side.append(el('span', 'mini mini--bad', 'congelado'));
      if (p.staff) side.append(el('span', 'mini', 'staff'));
      side.append(el('small', '', `${p.ping ?? '—'} ms`));
      li.append(el('span', 'item__id', p.id), main, side);
      li.addEventListener('click', () => { st.selected = p.id; st.history = null; st.detailTab = 'ficha'; renderPlayers(); });
      ul.append(li);
    });
    renderPlayerDetail();
  }

  function btn(label, onClick, cls = '', perm) {
    const b = el('button', `btn ${cls}`.trim(), label);
    b.type = 'button';
    if (perm && !can(perm)) b.classList.add('hidden');
    b.addEventListener('click', onClick);
    return b;
  }

  function group(title, buttons) {
    const visible = buttons.filter((b) => !b.classList.contains('hidden'));
    if (!visible.length) return null;
    const g = el('div', 'group');
    const actions = el('div', 'actions');
    actions.append(...visible);
    g.append(el('p', 'section-title', title), actions);
    return g;
  }

  function renderPlayerDetail() {
    const box = $('player-detail');
    box.replaceChildren();
    const p = ((st.data && st.data.players) || []).find((x) => x.id === st.selected);
    if (!p) { box.append(el('p', 'empty', 'Elige un jugador para ver su ficha.')); return; }
    const head = el('div', 'card-head');
    const left = el('div');
    left.append(el('h2', '', p.charName || p.name), el('p', '', `${p.name} · ID ${p.id}${p.bucket ? ` · bucket ${p.bucket}` : ''}`));
    const right = el('div', 'tags');
    if (p.proxId) right.append(el('span', 'tag', p.proxId));
    if (p.frozen) right.append(el('span', 'tag tag--bad', 'Congelado'));
    head.append(left, right);

    const tabs = el('nav', 'tabs tabs--inner');
    [['ficha', 'Ficha'], ['historial', 'Historial']].forEach(([id, label]) => {
      const t = el('button', `tab${st.detailTab === id ? ' is-on' : ''}`, label);
      t.type = 'button';
      t.addEventListener('click', () => {
        st.detailTab = id;
        if (id === 'historial') post('query', { kind: 'history', args: { target: p.id } });
        renderPlayerDetail();
      });
      tabs.append(t);
    });
    box.append(head, tabs);
    if (st.detailTab === 'historial') return renderHistory(box, p);

    const stats = el('div', 'stats');
    const stat = (label, value, cls) => { const s = el('div', 'stat'); s.append(el('small', '', label), el('b', cls || '', value)); return s; };
    stats.append(stat('Trabajo', p.job ? `${p.job}${p.grade ? ` · ${p.grade}` : ''}` : '—', p.onduty ? 'onduty' : ''), stat('Ping', p.ping != null ? `${p.ping} ms` : '—'));
    if (can('players.identity')) {
      stats.append(stat('Efectivo', money(p.cash), 'cash'), stat('Banco', money(p.bank)), stat('Nivel', p.level ?? '—'),
        stat('Tiempo jugado', duration(p.playtime)), stat('Hoy', duration(p.playtimeToday)));
    }
    stats.append(stat('Estado', p.frozen ? 'Congelado' : 'Normal'));
    box.append(stats);

    if (can('players.identity')) {
      const ids = el('div', 'ids');
      [['Citizen ID', p.citizenid], ['Licencia', p.license], ['Discord', p.discord], ['FiveM', p.fivem], ['IP', p.ip]].forEach(([k, v]) => {
        if (!v) return;
        const row = el('div');
        const code = el('code', '', v);
        const copy = el('button', 'link', 'copiar');
        copy.type = 'button';
        copy.addEventListener('click', () => copyText(v));
        row.append(document.createTextNode(`${k}: `), code, copy);
        ids.append(row);
      });
      box.append(ids);
    }

    const name = p.charName || p.name;
    [
      group('Movimiento', [
        btn('Ir', () => act('goto', p.id), '', 'players.goto'), btn('Traer', () => act('bring', p.id), '', 'players.bring'),
        btn('Devolver', () => act('back', p.id), '', 'players.goto'),
        btn('Espectar…', () => askAction('spectate', p, `Espectar a ${name}`, 'Queda registrado. Pulsa F10 para salir.'), '', 'players.spectate'),
      ]),
      group('Salud', [
        btn('Reanimar', () => act('revive', p.id), '', 'players.heal'), btn('Curar', () => act('heal', p.id), '', 'players.heal'),
        btn('Necesidades', () => act('needs', p.id), '', 'players.heal'), btn('Heridas', () => act('wounds', p.id), '', 'players.heal'),
      ]),
      group('Moderación', [
        btn(p.frozen ? 'Descongelar' : 'Congelar', () => act('freeze', p.id), '', 'players.freeze'),
        btn('Advertir…', () => askAction('warn', p, `Advertir a ${name}`, 'Se le muestra en pantalla y queda en su historial.'), '', 'players.warn'),
        btn('Expulsar…', () => askAction('kick', p, `Expulsar a ${name}`, 'Se desconecta con el motivo.'), 'btn--danger', 'players.kick'),
        btn('Banear…', () => askBan(p), 'btn--danger', 'players.ban'),
      ]),
      group('Economía', [
        btn('Multas', () => { $('eco-cid').value = p.citizenid || ''; setView('economy'); post('query', { kind: 'fines', args: { target: p.id } }); }, '', 'economy.view'),
        btn('Facturas', () => { $('eco-cid').value = p.citizenid || ''; setView('economy'); post('query', { kind: 'invoices', args: { target: p.id } }); }, '', 'economy.view'),
        btn('Corregir dinero…', () => askMoney(p), 'btn--danger', 'economy.correct'),
      ]),
    ].forEach((g) => { if (g) box.append(g); });

    if (can('players.message')) {
      const msgRow = el('div', 'reply');
      const msg = el('input');
      msg.maxLength = 300; msg.placeholder = 'Mensaje privado para este jugador';
      const send = btn('Enviar', () => { if (msg.value.trim()) { act('message', p.id, { text: msg.value }); msg.value = ''; } }, 'btn--primary');
      msg.addEventListener('keydown', (e) => { if (e.key === 'Enter') send.click(); });
      msgRow.append(msg, send);
      box.append(el('p', 'section-title', 'Mensaje'), msgRow);
    }
  }

  function miniTable(headers, rows) {
    const t = el('table', 'table');
    const thead = el('thead');
    const tr = el('tr');
    headers.forEach((h) => tr.append(el('th', '', h)));
    thead.append(tr);
    const tbody = el('tbody');
    rows.forEach((r) => { const row = el('tr'); r.forEach((v) => row.append(el('td', '', v ?? '—'))); tbody.append(row); });
    t.append(thead, tbody);
    return t;
  }

  function renderHistory(box, p) {
    const h = st.history && st.history.target === p.id ? st.history : null;
    if (!h) { box.append(el('p', 'empty', 'Cargando historial…')); return; }
    const sec = (title, node) => box.append(el('p', 'section-title', title), node);
    if (h.warnings) sec(`Advertencias (${h.warnings.length})`, h.warnings.length ? miniTable(['Cuándo', 'Staff', 'Motivo'], h.warnings.map((w) => [fmtDate(w.at), w.staff, w.reason])) : el('p', 'muted', 'Sin advertencias.'));
    if (h.bans) sec('Baneos', h.bans.length ? miniTable(['#', 'Motivo', 'Hasta', 'Por'], h.bans.map((b) => [b.id, b.reason, banUntil(b.expire), b.bannedby])) : el('p', 'muted', 'Sin baneos.'));
    if (h.reported) sec('Reportes contra este jugador', h.reported.length ? miniTable(['#', 'Categoría', 'Estado', 'Cuándo'], h.reported.map((r) => [r.id, r.categoryLabel, STATE[r.state], fmtDate(r.createdAt)])) : el('p', 'muted', 'Ninguno.'));
    if (h.reports) sec('Reportes que ha enviado', h.reports.length ? miniTable(['#', 'Categoría', 'Estado', 'Cuándo'], h.reports.map((r) => [r.id, r.categoryLabel, STATE[r.state], fmtDate(r.createdAt)])) : el('p', 'muted', 'Ninguno.'));
    if (h.actions) sec('Acciones del staff sobre este jugador', h.actions.length ? miniTable(['Cuándo', 'Staff', 'Acción', 'Motivo'], h.actions.map((a) => [fmtDate(a.at), a.staff, ACTION_LABEL[a.action] || a.action, a.reason || a.detail])) : el('p', 'muted', 'Ninguna.'));
  }

  const banUntil = (exp) => (Number(exp) >= 2147483647 ? 'Permanente' : fmtDate(Number(exp)));

  // ── Reportes ─────────────────────────────────────────
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
    const rbtn = (label, action, cls) => {
      const b = btn(label, () => post('reportAction', { action, id: r.id }), cls);
      b.disabled = r.state === 'closed' && action !== 'goto';
      return b;
    };
    actions.append(rbtn('Reclamar', 'claim'), rbtn('Ir con quien reporta', 'goto'));
    if (r.target) actions.append(btn('Ir al reportado', () => act('goto', r.target.id), '', 'players.goto'),
      btn('Ficha del reportado', () => { st.selected = r.target.id; setView('players'); renderPlayers(); }));

    const reply = el('div', 'reply');
    const input = el('input');
    input.maxLength = 600; input.placeholder = 'Responder al jugador…';
    const send = btn('Responder', () => { if (input.value.trim()) { post('reportAction', { action: 'reply', id: r.id, text: input.value }); input.value = ''; } }, 'btn--primary');
    send.disabled = r.state === 'closed';
    reply.append(input, send);

    const closeRow = el('div', 'reply');
    const note = el('input');
    note.maxLength = 300; note.placeholder = 'Nota de cierre (qué se hizo)';
    const closeBtn = btn('Cerrar', () => post('reportAction', { action: 'close', id: r.id, text: note.value }), 'btn--danger');
    closeBtn.disabled = r.state === 'closed';
    closeRow.append(note, closeBtn);

    const t = el('div', 'thread');
    t.append(thread(r, true));
    box.append(head, meta, actions, t, el('p', 'section-title', 'Responder'), reply, el('p', 'section-title', 'Cerrar'), closeRow);
  }

  // ── Moderación: baneos ──────────────────────────────
  $('bans-refresh').addEventListener('click', () => post('query', { kind: 'bans' }));
  function renderBans(data) {
    const body = $('bans-body');
    body.replaceChildren();
    const rows = (data && data.rows) || [];
    if (!rows.length) { const tr = el('tr'); const td = el('td', 'muted', 'No hay baneos activos.'); td.colSpan = 6; tr.append(td); body.append(tr); return; }
    rows.forEach((b) => {
      const tr = el('tr');
      [`#${b.id}`, b.name || b.license, b.reason, banUntil(b.expire), b.bannedby].forEach((v) => tr.append(el('td', '', v)));
      const td = el('td');
      td.append(btn('Levantar…', () => ask({ title: `Levantar el baneo #${b.id}`, text: `${b.name || ''} · ${b.reason || ''}`,
        onOk: (payload) => { act('unban', 0, { ...payload, banId: b.id }); setTimeout(() => post('query', { kind: 'bans' }), 400); } }), 'btn--small'));
      tr.append(td);
      body.append(tr);
    });
  }

  // ── Vehículos ───────────────────────────────────────
  ['sultan', 'police', 'ambulance', 'adder', 'bati', 'flatbed'].forEach((m) => {
    const c = el('button', 'chip', m);
    c.type = 'button';
    c.addEventListener('click', () => { $('car-model').value = m; });
    $('car-quick').append(c);
  });
  $('car-spawn').addEventListener('click', () => act('car', 0, { model: $('car-model').value }));
  $('car-model').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('car-spawn').click(); });
  document.querySelectorAll('[data-act]').forEach((b) => b.addEventListener('click', () => act(b.dataset.act, st.data ? st.data.me : 0)));
  $('plate-go').addEventListener('click', () => post('query', { kind: 'vehicle', args: { plate: $('plate-search').value } }));
  $('own-go').addEventListener('click', () => {
    const plate = $('own-plate').value.trim(), citizenid = $('own-cid').value.trim();
    if (!plate || !citizenid) return toast('Administración', 'Escribe matrícula y Citizen ID.', 'error');
    ask({ title: `Cambiar el titular de ${plate.toUpperCase()}`, text: `Nuevo titular: ${citizenid.toUpperCase()}`,
      onOk: (payload) => act('vehowner', 0, { ...payload, plate, citizenid }) });
  });

  function kv(box, pairs) {
    box.replaceChildren();
    pairs.forEach(([k, v]) => { if (v === undefined || v === null || v === '') return; box.append(el('dt', '', k), el('dd', '', v)); });
  }
  const ownerText = (o) => (o ? (o.citizenid ? `${o.citizenid}${o.garage ? ` · garaje ${o.garage}` : ''}` : `Registrado (#${o.id})`) : 'Sin dueño (no está en player_vehicles)');

  // ── Mundo ───────────────────────────────────────────
  $('coords-read').addEventListener('click', () => post('localTool', { tool: 'coords' }));
  $('buckets-go').addEventListener('click', () => post('query', { kind: 'buckets' }));
  $('announce-go').addEventListener('click', () => { const v = $('announce-text').value; $('announce-text').value = ''; act('announce', 0, { text: v }); });

  function copyText(t) {
    const ta = el('textarea');
    ta.value = t;
    ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.append(ta);
    ta.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch (_) { ok = false; }
    ta.remove();
    toast('Copiado', ok ? t : 'No se pudo copiar: selecciónalo a mano.', ok ? 'success' : 'error');
  }

  function renderCoords(c) {
    const f = (n) => Number(n).toFixed(2);
    kv($('coords-info'), [['X', f(c.x)], ['Y', f(c.y)], ['Z', f(c.z)], ['Rumbo', f(c.h)], ['Calle', c.street], ['Interior', c.interior ? String(c.interior) : 'no']]);
    const box = $('coords-copy');
    box.replaceChildren(
      btn('vec3', () => copyText(`vec3(${f(c.x)}, ${f(c.y)}, ${f(c.z)})`)),
      btn('vec4', () => copyText(`vec4(${f(c.x)}, ${f(c.y)}, ${f(c.z)}, ${f(c.h)})`)),
      btn('rumbo', () => copyText(f(c.h))),
      btn('JSON', () => copyText(JSON.stringify({ x: +f(c.x), y: +f(c.y), z: +f(c.z), h: +f(c.h) }))),
    );
  }

  function renderBuckets(list) {
    const box = $('buckets');
    box.replaceChildren(miniTable(['Bucket', 'Jugadores'], (list || []).map((b) => [b.bucket === 0 ? '0 (ciudad)' : String(b.bucket), b.players.map((p) => `${p.name} (#${p.id})`).join(', ')])));
  }

  // ── Economía ────────────────────────────────────────
  document.querySelectorAll('[data-hours]').forEach((b) => b.addEventListener('click', () => {
    st.hours = Number(b.dataset.hours);
    document.querySelectorAll('[data-hours]').forEach((x) => x.classList.toggle('is-on', x === b));
    post('query', { kind: 'economy', args: { hours: st.hours } });
  }));
  $('eco-fines').addEventListener('click', () => post('query', { kind: 'fines', args: { citizenid: $('eco-cid').value } }));
  $('eco-inv').addEventListener('click', () => post('query', { kind: 'invoices', args: { citizenid: $('eco-cid').value } }));
  const INV_STATE = { pending: 'Pendiente', partial: 'Parcial', paid: 'Pagada', cancelled: 'Cancelada' };

  function fillBody(id, rows, cols, empty) {
    const body = $(id);
    body.replaceChildren();
    if (!rows.length) { const tr = el('tr'); const td = el('td', 'muted', empty); td.colSpan = cols; tr.append(td); body.append(tr); return; }
    rows.forEach((r) => { const tr = el('tr'); r.forEach((v) => tr.append(el('td', '', v ?? '—'))); body.append(tr); });
  }

  function renderEconomy(d) {
    const s = d.summary;
    const stats = $('eco-stats');
    stats.replaceChildren();
    const stat = (label, value, cls) => { const x = el('div', 'stat'); x.append(el('small', '', label), el('b', cls || '', value)); return x; };
    if (!s) {
      stats.append(stat('Economía', 'pxd_economy no responde'));
    } else {
      stats.append(stat('Entra', money(s.totalIn), 'cash'), stat('Sale', money(s.totalOut)),
        stat('Neto (creado − retirado)', `${s.net >= 0 ? '+' : '−'}${money(Math.abs(s.net))}`, s.net >= 0 ? 'cash' : 'bad'));
      if (s.circulation) stats.append(stat('En circulación', money(s.circulation.cash + s.circulation.bank)));
    }
    fillBody('eco-cats', ((s && s.categories) || []).map((c) => [c.label, money(c.in), money(c.out), String(c.count)]), 4, 'Sin movimientos en este periodo.');
    fillBody('eco-large', ((s && s.large) || []).map((l) => [`${l.direction === 'in' ? '+' : '−'}${money(l.amount)} ${l.money_type}`, l.reason || 'sin motivo', l.citizenid]), 3, 'Ninguno.');
    fillBody('eco-invoices', (d.invoices || []).map((i) => [`#${i.id}`, i.job_label, i.client_name, i.concept, `${money(i.paid)} / ${money(i.amount)}`, INV_STATE[i.status] || i.status]), 6, 'Sin facturas.');
  }

  function renderPerson(kind, d) {
    if (kind === 'fines') {
      const f = d.fines || {};
      const rows = [...(f.open || []), ...(f.closed || [])].map((x) => [`Multa #${x.id}`, x.reason, `${money(x.paid)} / ${money(x.amount)}`, x.statusLabel || x.status]);
      fillBody('eco-person', rows, 4, `Sin multas para ${d.citizenid}.`);
    } else {
      fillBody('eco-person', (d.invoices || []).map((i) => [`Factura #${i.id}`, `${i.job_label || ''} · ${i.concept}`, `${money(i.paid)} / ${money(i.amount)}`, INV_STATE[i.status] || i.status]), 4, `Sin facturas para ${d.citizenid}.`);
    }
  }

  // ── Registro y comandos ─────────────────────────────
  $('log-refresh').addEventListener('click', () => post('query', { kind: 'audit' }));
  function renderLog(list) {
    fillBody('log-body', (list || []).map((l) => [fmtDate(l.at), l.staff, ACTION_LABEL[l.action] || l.action, l.target, l.reason ? `Motivo: ${l.reason}${l.detail ? ` · ${l.detail}` : ''}` : (l.detail || '')]), 5, 'Sin acciones registradas.');
  }

  function renderCommands() {
    fillBody('commands-body', ((st.data && st.data.commands) || []).filter((c) => can((ACTIONS_PERM[c.action]) || 'panel'))
      .map((c) => [`/${c.name}${c.args ? ` ${c.args}` : ''}`, c.desc]), 2, '');
  }
  const ACTIONS_PERM = { noclip: 'noclip', invisible: 'noclip', tpm: 'noclip', revive: 'players.heal', heal: 'players.heal', needs: 'players.heal',
    wounds: 'players.heal', goto: 'players.goto', back: 'players.goto', bring: 'players.bring', freeze: 'players.freeze', car: 'vehicles.spawn',
    dv: 'vehicles.manage', repair: 'vehicles.manage', announce: 'announce', spectate: 'players.spectate', duty: 'panel' };

  $('duty').addEventListener('click', () => act('duty', st.data ? st.data.me : 0));

  // ── Resultados de consultas ─────────────────────────
  function onResult(kind, data) {
    switch (kind) {
      case 'history': st.history = data; renderPlayerDetail(); break;
      case 'bans': renderBans(data); break;
      case 'audit': renderLog(data); break;
      case 'economy': renderEconomy(data || {}); break;
      case 'fines': case 'invoices': renderPerson(kind, data || {}); break;
      case 'buckets': renderBuckets(data); break;
      case 'coords': renderCoords(data); break;
      case 'vehicleLocal': kv($('veh-info'), [['Modelo', data.name], ['Motor', String(data.engine)], ['Carrocería', String(data.body)], ['Suciedad', String(data.dirt)]]); break;
      case 'vehicle':
        if (data.netId !== undefined) {
          const box = $('veh-info');
          box.append(el('dt', '', 'Matrícula'), el('dd', '', data.plate), el('dt', '', 'Dueño'), el('dd', '', ownerText(data.owner)));
          if (data.canOwner) $('own-plate').value = data.plate;
        } else {
          kv($('plate-info'), [['Matrícula', data.plate], ['Dueño', ownerText(data.owner)]]);
        }
        break;
      default: break;
    }
  }

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

  function showWarning(reason, by) {
    $('warning-text').textContent = reason || '';
    $('warning-by').textContent = by ? `De: ${by}. Queda en tu historial.` : 'Queda en tu historial.';
    $('warning').classList.remove('hidden');
  }
  $('warning-ok').addEventListener('click', () => { $('warning').classList.add('hidden'); post('close'); });

  function noclipHud(m) {
    const h = $('noclip-hud');
    h.classList.toggle('hidden', !m.on);
    if (m.on) h.textContent = `Noclip · velocidad ${m.speed ?? ''}${m.invisible ? ' · invisible' : ''} · rueda: velocidad · Espacio/X: subir/bajar`;
    if (st.data) { st.data.noclip = !!m.on; $('noclip-badge').classList.toggle('is-on', !!m.on); }
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
        $('support').classList.add('hidden'); $('staff').classList.add('hidden'); $('dialog').classList.add('hidden'); break;
      case 'toast':
        toast(m.title, m.text, m.kind); break;
      case 'alert': {
        const r = m.report || {};
        beep();
        toast(`Nuevo reporte #${r.id}`, `${r.categoryLabel} · ${r.reporter || ''}`, 'alert');
        break;
      }
      case 'spectate':
        $('spectate').textContent = m.on ? `Espectando a ${m.name} · pulsa F10 para salir` : '';
        $('spectate').classList.toggle('hidden', !m.on); break;
      case 'wounds': showWounds(m.data || {}); break;
      case 'announce': announce(m.text || ''); break;
      case 'result': onResult(m.kind, m.data); break;
      case 'warning': showWarning(m.reason, m.by); break;
      case 'noclip': noclipHud(m); break;
      default: break;
    }
  });

  // ── Demo (vista previa en navegador: ?demo&staff&view=…) ─
  function demoPost(name, data) {
    if (name === 'action') toast('Administración', `Acción «${ACTION_LABEL[data.action] || data.action}» (demo)`, 'success');
    if (name === 'createReport') toast('Soporte', 'Reporte #13 enviado. El staff te responderá aquí.', 'success');
    if (name === 'query') {
      const now = Math.floor(Date.now() / 1000);
      const R = {
        bans: { rows: [{ id: 4, name: 'Troll', license: 'license:9f…', reason: 'DM reiterado tras dos advertencias', expire: now + 86400 * 6, bannedby: 'IsyConta' },
          { id: 2, name: 'Cheater', license: 'license:1a…', reason: 'Menú de trucos', expire: 2147483647, bannedby: 'IsyConta' }] },
        audit: [
          { at: now - 120, staff: 'IsyConta', action: 'warn', target: 'Bruno Salgado (#7)', reason: 'VDM en la plaza' },
          { at: now - 600, staff: 'IsyConta', action: 'money', target: 'Ana Torres (#5)', reason: 'Reembolso por fallo del concesionario', detail: 'bank +2500 (5000 → 7500)' },
          { at: now - 900, staff: 'Lía', action: 'noclip', detail: 'activado' },
          { at: now - 4000, staff: 'IsyConta', action: 'kick', target: 'Troll (#9)', reason: 'DM reiterado' },
        ],
        economy: { summary: { totalIn: 184300, totalOut: 121950, net: 62350, circulation: { cash: 412000, bank: 3820000 },
          categories: [{ label: 'Nóminas', in: 96000, out: 0, count: 64 }, { label: 'Efectivo del inventario (tiendas, entregas…)', in: 51200, out: 70450, count: 211 },
            { label: 'Facturas', in: 0, out: 18300, count: 9 }, { label: 'Multas', in: 0, out: 9200, count: 6 }],
          large: [{ direction: 'in', amount: 40000, money_type: 'bank', reason: 'pxd-admin: Reembolso', citizenid: 'QX81PA2D' }] },
          invoices: [{ id: 31, job_label: 'Taller', client_name: 'Ana Torres', concept: 'Reparación de motor', amount: 1800, paid: 900, status: 'partial' },
            { id: 30, job_label: 'Taxi', client_name: 'Bruno Salgado', concept: 'Viaje al aeropuerto', amount: 250, paid: 250, status: 'paid' }] },
        buckets: [{ bucket: 0, players: [{ id: 3, name: 'Edy' }, { id: 5, name: 'Lumen' }] }, { bucket: 60001, players: [{ id: 7, name: 'Zeta' }] }],
        history: { target: data.args && data.args.target, warnings: [{ at: now - 7200, staff: 'IsyConta', reason: 'VDM en la plaza' }], bans: [],
          reported: [{ id: 12, categoryLabel: 'Ataque sin rol (DM/VDM)', state: 'open', createdAt: now - 240 }], reports: [],
          actions: [{ at: now - 7200, staff: 'IsyConta', action: 'warn', reason: 'VDM en la plaza' }, { at: now - 9000, staff: 'IsyConta', action: 'freeze', detail: 'congelar' }] },
      };
      if (R[data.kind]) setTimeout(() => onResult(data.kind, R[data.kind]), 50);
    }
    if (name === 'localTool') setTimeout(() => onResult('coords', { x: 215.76, y: -810.12, z: 30.73, h: 157.5, street: 'Alta St / Las Lagunas Blvd', interior: 0 }), 50);
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
      { id: 3, name: 'Edy', charName: 'Valeria Ríos', citizenid: 'LWWI414K', proxId: 'PROX-3MHA', job: 'Servicios Médicos', grade: 'Paramédica', onduty: true, cash: 12850, bank: 248300, level: 7, playtime: 2563200, playtimeToday: 8040, ping: 48, license: 'license:3f2ac91d0e', discord: 'discord:441098', fivem: 'fivem:1290', bucket: 0, staff: true },
      { id: 5, name: 'Lumen', charName: 'Ana Torres', citizenid: 'QX81PA2D', proxId: 'PROX-9TRV', job: 'Taxi', grade: 'Conductora', cash: 500, bank: 5000, level: 2, playtime: 7300, playtimeToday: 3100, ping: 71, license: 'license:aa11', bucket: 0 },
      { id: 7, name: 'Zeta', charName: 'Bruno Salgado', citizenid: 'MM20KD8E', proxId: 'PROX-7KQ2', job: 'Mecánico', grade: 'Aprendiz', cash: 2200, bank: 14000, level: 4, playtime: 50400, playtimeToday: 1200, ping: 95, license: 'license:bb22', bucket: 60001, frozen: true },
    ];
    const allPerms = {};
    ['panel', 'reports', 'players.goto', 'players.bring', 'players.heal', 'players.message', 'players.spectate', 'players.freeze', 'players.identity',
      'players.kick', 'players.warn', 'players.ban', 'noclip', 'announce', 'audit', 'vehicles.spawn', 'vehicles.manage', 'world', 'props', 'qbxmenu',
      'economy.view', 'players.ip', 'vehicles.owner', 'economy.correct'].forEach((p) => { allPerms[p] = true; });
    const role = params.get('role');
    const SUPPORT = ['panel', 'reports', 'players.goto', 'players.bring', 'players.heal', 'players.message'];
    const perms = role === 'soporte' ? Object.fromEntries(SUPPORT.map((p) => [p, true])) : allPerms;
    if (params.has('staff')) {
      st.data = { players, reports, log: [], me: 1, perms, role: role === 'soporte' ? 'Soporte' : 'Superadministrador', onDuty: true, noclip: params.has('noclip'),
        qbxMenu: true, economy: true, limits: { maxMoney: 1000000, maxBanHours: 87600 },
        banHint: 'Los baneos usan la lista de Qbox (tabla bans). Los de txAdmin se gestionan en su web.',
        commands: [
          { name: 'admin', action: 'duty', args: '', desc: 'Abrir este panel (también F10).' },
          { name: 'noclip', action: 'noclip', args: '', desc: 'Vuelo libre (W/A/S/D, Espacio sube, X baja, Shift rápido, rueda: velocidad).' },
          { name: 'duty', action: 'duty', args: '', desc: 'Entrar o salir de servicio: atuendo STAFF, etiqueta e invencible.' },
          { name: 'ir', action: 'goto', args: '<id>', desc: 'Ir con un jugador.' },
          { name: 'traer', action: 'bring', args: '<id>', desc: 'Traer a un jugador contigo.' },
          { name: 'coche', action: 'car', args: '<modelo>', desc: 'Sacar un vehículo de prueba.' },
        ] };
      st.selected = 7; st.report = 12;
      $('staff').classList.remove('hidden');
      renderStaff();
      const v = params.get('view');
      if (v) setView(v);
      if (params.get('tab') === 'historial') { st.detailTab = 'historial'; post('query', { kind: 'history', args: { target: 7 } }); renderPlayerDetail(); }
      if (v === 'world') post('localTool', { tool: 'coords' });
      if (v === 'vehicles') { onResult('vehicleLocal', { name: 'SULTAN', engine: 870, body: 912, dirt: 3 }); onResult('vehicle', { netId: 1, plate: 'PXD 042', owner: { id: 18, citizenid: 'QX81PA2D', garage: 'legion' }, canOwner: true }); }
      if (params.has('ban')) askBan(players[2]);
      if (params.has('money')) askMoney(players[1]);
      if (params.has('noclip')) noclipHud({ on: true, speed: 1, invisible: true });
    } else if (params.has('warning')) {
      showWarning('Conducción temeraria en la plaza: atropellaste a dos personas sin rol.', 'IsyConta');
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
