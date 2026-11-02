// NUI de pxd_gamemodes. Todo el texto de jugadores se pinta con textContent (nunca innerHTML).
(() => {
  'use strict';
  const inGame = typeof window.GetParentResourceName === 'function';
  const resource = inGame ? window.GetParentResourceName() : 'pxd_gamemodes';
  const $ = (id) => document.getElementById(id);

  const state = { lobby: null, selectedMode: null, joined: null, snap: null, me: null };

  const KIND_LABEL = { combat: 'Combate', zone: 'Zona', race: 'Carrera' };
  const STATE_LABEL = { lobby: 'En sala', countdown: 'Empezando', running: 'En curso', ended: 'Terminada' };

  async function post(name, data = {}) {
    if (!inGame) { console.info('[demo] post', name, data); return { ok: true }; }
    const res = await fetch(`https://${resource}/${name}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
    });
    return res.ok ? res.json() : { ok: false };
  }

  const el = (tag, cls, text) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined) n.textContent = text;
    return n;
  };

  const fmtTime = (s) => {
    s = Math.max(0, Math.floor(s || 0));
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  };

  // ── Menú ────────────────────────────────────────────────
  function renderModes() {
    const box = $('modes');
    box.replaceChildren();
    for (const m of state.lobby?.modes ?? []) {
      const b = el('button', 'mode');
      b.type = 'button';
      b.setAttribute('role', 'listitem');
      b.setAttribute('aria-pressed', String(state.selectedMode === m.id));
      b.append(el('strong', '', m.label), el('span', '', m.description || ''));
      const meta = [KIND_LABEL[m.kind], m.teams ? `${m.teams} equipos` : 'Individual', `${m.minPlayers}-${m.maxPlayers} jug.`];
      b.append(el('em', '', meta.join(' · ')));
      b.addEventListener('click', () => { state.selectedMode = m.id; renderModes(); renderArenas(); });
      box.append(b);
    }
    $('create').disabled = !state.selectedMode;
  }

  function renderArenas() {
    const sel = $('arena');
    sel.replaceChildren();
    const def = state.lobby?.defaultArena?.[state.selectedMode];
    for (const a of state.lobby?.arenas ?? []) {
      const o = el('option', '', a.label);
      o.value = a.id;
      if (a.id === def) o.selected = true;
      sel.append(o);
    }
  }

  function renderMatches() {
    const list = $('matches');
    list.replaceChildren();
    const matches = state.lobby?.matches ?? [];
    $('no-matches').classList.toggle('hidden', matches.length > 0);
    for (const m of matches) {
      const li = el('li', 'match');
      const info = el('div');
      info.append(el('strong', '', `#${m.id} ${m.modeLabel}`), el('small', '', `${m.arenaLabel} · ${m.players}/${m.maxPlayers}`));
      const right = el('div', 'row');
      right.style.marginTop = '0';
      right.append(el('span', `badge badge--${m.state}`, STATE_LABEL[m.state] || m.state));
      const mine = state.joined && state.joined.id === m.id;
      if (!mine && m.state !== 'ended') {
        const join = el('button', 'btn btn--ghost', 'Unirse');
        join.addEventListener('click', () => post('join', { id: m.id }));
        right.append(join);
      }
      li.append(info, right);
      list.append(li);
    }
    renderCurrent();
  }

  function renderCurrent() {
    const box = $('current');
    const j = state.joined;
    box.classList.toggle('hidden', !j);
    if (!j) return;
    const s = state.snap;
    $('current-title').textContent = `Estás en: ${j.label} · ${j.arena.label}`;
    const isHost = s && s.host === state.me;
    $('current-state').textContent = s ? `${STATE_LABEL[s.state] || s.state} · ${s.players} jugador(es)${isHost ? ' · eres el anfitrión' : ''}` : '';
    $('start').classList.toggle('hidden', !(s && s.state === 'lobby' && isHost));
  }

  // ── HUD ─────────────────────────────────────────────────
  function renderHud() {
    const s = state.snap;
    const show = !!(state.joined && s && s.state !== 'lobby');
    $('hud').classList.toggle('hidden', !show);
    if (!show) return;
    $('hud-mode').textContent = s.modeLabel;
    $('hud-clock').textContent = s.state === 'countdown' ? fmtTime(s.countdown) : fmtTime(s.timeLeft ?? 0);

    const score = $('hud-score');
    score.replaceChildren();
    if (s.teams >= 2) {
      score.append(el('span', 't1', String(Math.floor(s.teamScores[0] ?? s.teamScores['1'] ?? 0))));
      score.append(el('span', '', '—'));
      score.append(el('span', 't2', String(Math.floor(s.teamScores[1] ?? s.teamScores['2'] ?? 0))));
    } else if (s.kind === 'race') {
      const me = (s.playersList || []).find((p) => p.id === state.me);
      if (me) score.append(el('span', '', `Vuelta ${Math.min(me.lap, s.laps)}/${s.laps} · CP ${me.checkpoint}/${s.checkpoints}`));
    } else if (s.scoreLimit) {
      score.append(el('span', '', `Meta ${s.scoreLimit}`));
    }

    const board = $('hud-board');
    board.replaceChildren();
    for (const p of (s.playersList || []).slice(0, 8)) {
      const li = el('li', p.id === state.me ? 'me' : '');
      const right = s.kind === 'race'
        ? (p.finished ? fmtTime(p.finishTime) : `V${p.lap} · CP${p.checkpoint}`)
        : `${p.score} pts · ${p.kills}/${p.deaths}`;
      li.append(el('span', '', p.name));
      li.append(el('span', 'pts', right));
      if (p.team) li.style.borderLeft = `3px solid var(--team${p.team})`, li.style.paddingLeft = '6px';
      board.append(li);
    }

    const center = $('hud-center');
    center.replaceChildren();
    if (s.state === 'countdown') {
      center.append(document.createTextNode(String(s.countdown)), el('small', '', 'Prepárate'));
    }
  }

  function showResults(s) {
    const w = s.winner;
    let title = 'Sin ganador';
    if (w?.type === 'team') title = `Gana el equipo ${w.team === 1 ? 'Azul' : 'Rojo'}`;
    else if (w?.type === 'player') title = `Gana ${w.name}`;
    else if (w?.type === 'draw') title = 'Empate';
    $('results-title').textContent = title;
    const list = $('results-list');
    list.replaceChildren();
    for (const p of (s.playersList || []).slice(0, 5)) {
      const detail = s.kind === 'race' ? (p.finished ? fmtTime(p.finishTime) : 'DNF') : `${p.score} pts`;
      list.append(el('li', '', `${p.name} — ${detail}`));
    }
    $('results').classList.remove('hidden');
  }

  function toast(message, kind = 'info') {
    const t = el('div', `toast toast--${kind}`, message);
    $('toasts').append(t);
    setTimeout(() => t.remove(), 5000);
  }

  function feed(f) {
    let text = `☠ ${f.victim}`;
    if (f.kind === 'kill') text = `${f.killer} ⟶ ${f.victim}`;
    if (f.kind === 'teamkill') text = `${f.killer} ⟶ ${f.victim} (fuego amigo)`;
    const li = el('li', '', text);
    $('hud-feed').prepend(li);
    setTimeout(() => li.remove(), 6000);
  }

  // ── Mensajes desde Lua ──────────────────────────────────
  const handlers = {
    menu: (d) => $('menu').classList.toggle('hidden', !d.open),
    lobby: (d) => { state.lobby = d; if (!state.selectedMode && d.modes?.[0]) state.selectedMode = d.modes[0].id; renderModes(); renderArenas(); renderMatches(); },
    joined: (d) => { state.joined = d; state.me = d.me ?? state.me; $('results').classList.add('hidden'); renderMatches(); },
    match: (d) => { state.snap = d; renderHud(); renderCurrent(); },
    ended: (d) => { state.snap = d; renderHud(); showResults(d); },
    left: () => { state.joined = null; state.snap = null; $('results').classList.add('hidden'); renderHud(); renderMatches(); },
    toast: (d) => toast(d.message, d.kind),
    feed,
    respawn: (d) => toast(`Reapareces en ${d.seconds} s`),
  };

  window.addEventListener('message', (e) => {
    const msg = e.data;
    if (msg && handlers[msg.type]) handlers[msg.type](msg.data || {});
  });

  // ── Controles ───────────────────────────────────────────
  document.querySelector('[data-action="close"]').addEventListener('click', () => post('close'));
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' || e.key === 'F7') post('close'); });
  $('create').addEventListener('click', () => post('create', { mode: state.selectedMode, arena: $('arena').value }));
  $('start').addEventListener('click', () => post('start'));
  $('leave').addEventListener('click', () => post('leave'));

  // Vista previa en navegador: abre html/index.html?demo=1
  if (!inGame && new URLSearchParams(location.search).has('demo')) {
    document.body.style.background = '#1b2238';
    const send = (type, data) => window.postMessage({ type, data }, '*');
    send('menu', { open: true });
    send('lobby', {
      modes: [
        { id: 'ffa', label: 'Todos contra todos', description: 'Cada baja suma.', kind: 'combat', teams: 0, minPlayers: 2, maxPlayers: 16 },
        { id: 'tdm', label: 'Deathmatch por equipos', description: 'Dos equipos.', kind: 'combat', teams: 2, minPlayers: 2, maxPlayers: 20 },
        { id: 'koth', label: 'Rey de la colina', description: 'Controla la zona.', kind: 'zone', teams: 2, minPlayers: 2, maxPlayers: 20 },
        { id: 'race', label: 'Carrera', description: 'Checkpoints en orden.', kind: 'race', teams: 0, minPlayers: 1, maxPlayers: 12 },
      ],
      arenas: [{ id: 'prueba', label: 'Arena de prueba (Forum Dr)' }, { id: 'colinas', label: 'Colinas de Vinewood' }],
      defaultArena: { ffa: 'prueba' },
      matches: [{ id: 3, modeLabel: 'Deathmatch por equipos', arenaLabel: 'Arena de prueba', state: 'running', players: 6, maxPlayers: 20 }],
    });
    if (new URLSearchParams(location.search).has('hud')) {
      send('menu', { open: false });
      send('joined', { id: 3, label: 'Deathmatch por equipos', me: 1, arena: { label: 'Arena de prueba' } });
      send('match', {
        id: 3, modeLabel: 'Deathmatch por equipos', state: 'running', kind: 'combat', teams: 2, timeLeft: 431,
        teamScores: [12, 9], host: 1, players: 4,
        playersList: [
          { id: 1, name: 'Nova', team: 1, score: 7, kills: 7, deaths: 2 },
          { id: 2, name: 'Centauri', team: 2, score: 5, kills: 5, deaths: 4 },
          { id: 4, name: 'Orbit', team: 1, score: 5, kills: 5, deaths: 3 },
          { id: 5, name: 'Lumen', team: 2, score: 4, kills: 4, deaths: 6 },
        ],
      });
      send('feed', { kind: 'kill', killer: 'Nova', victim: 'Lumen' });
    }
  }
})();
