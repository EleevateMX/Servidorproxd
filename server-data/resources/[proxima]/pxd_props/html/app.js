// Editor de props de Próxima RP. Una sola app con dos transportes:
//  · NUI (dentro del juego): habla con client/main.lua mediante callbacks.
//  · Web (http://IP:30120/pxd_props/): habla con la API HTTP del servidor con token.
// Todo texto de usuario se pinta con textContent.
(() => {
  'use strict';

  const params = new URLSearchParams(location.search);
  const inGame = typeof window.GetParentResourceName === 'function';
  const demo = !inGame && params.has('demo');
  const mode = inGame ? 'nui' : 'web';
  document.body.classList.add(`mode-${mode}`);

  const $ = (id) => document.getElementById(id);
  const el = (tag, cls, text) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined) n.textContent = text;
    return n;
  };
  const round = (v, d = 3) => Math.round(v * 10 ** d) / 10 ** d;
  const normAngle = (a) => { a = ((a % 360) + 360) % 360; return round(a > 180 ? a - 360 : a, 2); };

  const POINT_LABEL = { spawn: 'Spawn', team1: 'Equipo azul', team2: 'Equipo rojo', grid: 'Parrilla', checkpoint: 'Checkpoint', zone: 'Zona' };
  const POINT_COLOR = { spawn: '#ffffff', team1: '#50a0ff', team2: '#ff5a5a', grid: '#ffc857', checkpoint: '#5ce1ff', zone: '#ff4fd8' };

  const state = {
    layouts: {},          // id -> layout completo (o resumen en web hasta cargarlo)
    current: null,        // id del layout abierto
    selected: null,       // { kind: 'prop'|'point', id }
    catalog: { categories: [] },
    category: null,
    available: {},        // modelo -> bool (solo en juego)
    gridSizes: [0.05, 0.1, 0.25, 0.5, 1, 2],
    rotationSteps: [1, 5, 15, 45, 90],
    history: [], future: [],
    token: null,
  };

  // ── Transportes ─────────────────────────────────────────────────────────
  const resource = inGame ? window.GetParentResourceName() : 'pxd_props';
  async function nuiPost(name, data = {}) {
    const r = await fetch(`https://${resource}/${name}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
    });
    return r.ok ? r.json() : { ok: false, error: `NUI ${r.status}` };
  }

  const apiBase = (() => {
    const p = location.pathname;
    if (/\.html?$/.test(p)) return p.replace(/[^/]*$/, '');
    return p.endsWith('/') ? p : `${p}/`;
  })();

  async function web(method, path, body) {
    const r = await fetch(apiBase + path, {
      method,
      headers: { Authorization: `Bearer ${state.token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    let data = null;
    try { data = await r.json(); } catch { data = { ok: false, error: `HTTP ${r.status}` }; }
    if (r.status === 401 || r.status === 503 || r.status === 429) showGate(data.error);
    return data;
  }

  // Transporte de demostración (vista previa sin servidor: ?demo=1)
  const demoStore = { layouts: {} };
  function demoOp(op, p) {
    const L = demoStore.layouts;
    const nextId = (l) => (l.nextId = (l.nextId || 1) + 1) - 1;
    switch (op) {
      case 'createLayout': if (L[p.id]) return { ok: false, error: 'ya existe' }; L[p.id] = { id: p.id, name: p.name || p.id, active: false, props: [], points: [], nextId: 1 }; return { ok: true, result: L[p.id] };
      case 'renameLayout': L[p.id].name = p.name; return { ok: true, result: L[p.id] };
      case 'setActive': L[p.id].active = !!p.active; return { ok: true, result: L[p.id] };
      case 'deleteLayout': delete L[p.id]; return { ok: true, result: true };
      case 'addProp': { const pr = { frozen: true, collision: true, rx: 0, ry: 0, rz: 0, ...p.prop, id: nextId(L[p.layout]) }; L[p.layout].props.push(pr); return { ok: true, result: pr }; }
      case 'updateProp': { const l = L[p.layout]; const i = l.props.findIndex((x) => x.id === p.id); l.props[i] = { ...l.props[i], ...p.patch, id: p.id }; return { ok: true, result: l.props[i] }; }
      case 'removeProp': { const l = L[p.layout]; const i = l.props.findIndex((x) => x.id === p.id); return { ok: true, result: l.props.splice(i, 1)[0] }; }
      case 'addPoint': {
        const l = L[p.layout];
        const pt = { h: 0, ...p.point, id: nextId(l) };
        if (pt.kind === 'zone') l.points = l.points.filter((x) => x.kind !== 'zone');
        if (pt.kind === 'checkpoint' && pt.order === undefined) pt.order = l.points.filter((x) => x.kind === 'checkpoint').reduce((m, x) => Math.max(m, x.order || 0), 0) + 1;
        l.points.push(pt);
        return { ok: true, result: pt };
      }
      case 'updatePoint': { const l = L[p.layout]; const i = l.points.findIndex((x) => x.id === p.id); l.points[i] = { ...l.points[i], ...p.patch, id: p.id }; return { ok: true, result: l.points[i] }; }
      case 'removePoint': { const l = L[p.layout]; const i = l.points.findIndex((x) => x.id === p.id); return { ok: true, result: l.points.splice(i, 1)[0] }; }
      case 'importLayout': { const id = p.data.id; if (L[id] && !p.overwrite) return { ok: false, error: 'ya existe' }; L[id] = JSON.parse(JSON.stringify(p.data)); return { ok: true, result: L[id] }; }
      default: return { ok: false, error: 'op desconocida' };
    }
  }

  async function op(name, payload) {
    let res;
    if (inGame) res = await nuiPost('op', { op: name, payload });
    else if (demo) res = demoOp(name, structuredClone(payload));
    else res = await web('POST', 'api/op', { op: name, payload });
    if (!res || !res.ok) {
      toast(res?.error || 'Error desconocido', 'error');
      return null;
    }
    // En juego llegan los cambios por el evento 'layout'; en web/demo se recarga.
    if (!inGame) await refreshLayout(payload.layout || payload.id || res.result?.id);
    return res.result;
  }

  async function refreshList() {
    if (demo) { state.layouts = structuredClone(demoStore.layouts); return renderAll(); }
    const r = await web('GET', 'api/layouts');
    if (!r?.ok) return;
    const next = {};
    for (const s of r.result) next[s.id] = state.layouts[s.id]?.props ? state.layouts[s.id] : { ...s, props: null, points: null };
    state.layouts = next;
    renderAll();
  }

  async function refreshLayout(id) {
    if (!id) return;
    if (demo) { state.layouts = structuredClone(demoStore.layouts); return renderAll(); }
    const r = await web('GET', `api/layouts/${encodeURIComponent(id)}`);
    if (r?.ok) state.layouts[id] = r.result;
    else if (r && !r.ok) delete state.layouts[id];
    renderAll();
  }

  // ── Historial (deshacer / rehacer) ─────────────────────────────────────
  function record(entry) {
    state.history.push(entry);
    if (state.history.length > 100) state.history.shift();
    state.future = [];
    renderHistory();
  }
  async function undo() {
    const e = state.history.pop();
    if (!e) return;
    await e.undo();
    state.future.push(e);
    renderHistory();
  }
  async function redo() {
    const e = state.future.pop();
    if (!e) return;
    await e.redo();
    state.history.push(e);
    renderHistory();
  }
  function renderHistory() {
    $('undo').disabled = state.history.length === 0;
    $('redo').disabled = state.future.length === 0;
  }

  const current = () => state.layouts[state.current];
  const findProp = (id) => current()?.props?.find((p) => p.id === id);
  const findPoint = (id) => current()?.points?.find((p) => p.id === id);
  const propData = (p) => ({ model: p.model, x: p.x, y: p.y, z: p.z, rx: p.rx, ry: p.ry, rz: p.rz, frozen: p.frozen, collision: p.collision });
  const pointData = (p) => { const { id, ...rest } = p; return rest; };

  // Acciones con historial ------------------------------------------------
  async function addProp(prop) {
    const layout = state.current;
    const created = await op('addProp', { layout, prop });
    if (!created) return null;
    const entry = { id: created.id };
    record({
      undo: () => op('removeProp', { layout, id: entry.id }),
      redo: async () => { const r = await op('addProp', { layout, prop }); if (r) entry.id = r.id; },
    });
    select('prop', created.id);
    return created;
  }

  async function updateProp(id, patch) {
    const layout = state.current;
    const before = findProp(id);
    if (!before) return;
    const prev = propData(before);
    const r = await op('updateProp', { layout, id, patch });
    if (r) record({ undo: () => op('updateProp', { layout, id, patch: prev }), redo: () => op('updateProp', { layout, id, patch }) });
  }

  async function removeProp(id) {
    const layout = state.current;
    const before = findProp(id);
    if (!before) return;
    const data = propData(before);
    const entry = { id };
    if (await op('removeProp', { layout, id })) {
      if (state.selected?.id === id) select(null);
      record({
        undo: async () => { const r = await op('addProp', { layout, prop: data }); if (r) entry.id = r.id; },
        redo: () => op('removeProp', { layout, id: entry.id }),
      });
    }
  }

  async function addPoint(point) {
    const layout = state.current;
    const created = await op('addPoint', { layout, point });
    if (!created) return;
    const entry = { id: created.id };
    record({
      undo: () => op('removePoint', { layout, id: entry.id }),
      redo: async () => { const r = await op('addPoint', { layout, point }); if (r) entry.id = r.id; },
    });
  }

  async function updatePoint(id, patch) {
    const layout = state.current;
    const before = findPoint(id);
    if (!before) return;
    const prev = pointData(before);
    if (await op('updatePoint', { layout, id, patch })) {
      record({ undo: () => op('updatePoint', { layout, id, patch: prev }), redo: () => op('updatePoint', { layout, id, patch }) });
    }
  }

  async function removePoint(id) {
    const layout = state.current;
    const before = findPoint(id);
    if (!before) return;
    const data = pointData(before);
    const entry = { id };
    if (await op('removePoint', { layout, id })) {
      if (state.selected?.id === id) select(null);
      record({
        undo: async () => { const r = await op('addPoint', { layout, point: data }); if (r) entry.id = r.id; },
        redo: () => op('removePoint', { layout, id: entry.id }),
      });
    }
  }

  // ── Selección y pestañas ────────────────────────────────────────────────
  function select(kind, id) {
    state.selected = kind ? { kind, id } : null;
    if (inGame) nuiPost('select', kind ? { layout: state.current, id, kind } : {});
    if (kind === 'prop' && mode === 'nui') setTab('edit');
    renderEdit();
    renderLists();
    drawMap();
  }

  function setTab(tab) {
    for (const b of document.querySelectorAll('.tabs button')) b.setAttribute('aria-selected', String(b.dataset.tab === tab));
    for (const r of document.querySelectorAll('.region')) r.classList.toggle('is-active', r.dataset.region === tab);
    if (tab === 'map') requestAnimationFrame(() => { resizeMap(); drawMap(); });
  }

  async function openLayout(id) {
    state.current = id;
    state.selected = null;
    state.history = []; state.future = [];
    renderHistory();
    if (inGame) nuiPost('focusLayout', { id });
    else if (!state.layouts[id]?.props) await refreshLayout(id);
    fitMap();
    renderAll();
  }

  // ── Render ──────────────────────────────────────────────────────────────
  function renderAll() {
    if (state.current && !state.layouts[state.current]) state.current = null;
    renderLayouts();
    renderLists();
    renderEdit();
    drawMap();
  }

  function renderLayouts() {
    const list = $('layout-list');
    list.replaceChildren();
    const items = Object.values(state.layouts).sort((a, b) => a.name.localeCompare(b.name));
    for (const l of items) {
      const li = el('li');
      li.setAttribute('aria-selected', String(l.id === state.current));
      const left = el('span');
      left.append(el('span', `dot${l.active ? ' dot--on' : ''}`), document.createTextNode(l.name));
      const nProps = Array.isArray(l.props) ? l.props.length : l.props ?? 0;
      const nPoints = Array.isArray(l.points) ? l.points.length : l.points ?? 0;
      li.append(left, el('small', '', `${nProps} props · ${nPoints} puntos`));
      li.addEventListener('click', () => openLayout(l.id));
      list.append(li);
    }
    if (!items.length) list.append(el('li', 'muted', 'Aún no hay layouts.'));
    const l = current();
    $('layout-actions').classList.toggle('hidden', !l);
    if (l) {
      if (document.activeElement !== $('layout-name')) $('layout-name').value = l.name;
      $('layout-active').checked = !!l.active;
    }
  }

  function renderLists() {
    const l = current();
    const props = $('prop-list');
    props.replaceChildren();
    for (const p of l?.props ?? []) {
      const li = el('li');
      li.setAttribute('aria-selected', String(state.selected?.kind === 'prop' && state.selected.id === p.id));
      li.append(el('span', 'mono', `#${p.id} ${p.model}`), el('small', 'mono', `${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}`));
      li.addEventListener('click', () => select('prop', p.id));
      props.append(li);
    }
    const points = $('point-list');
    points.replaceChildren();
    const sorted = [...(l?.points ?? [])].sort((a, b) => (a.kind === b.kind ? (a.order ?? a.id) - (b.order ?? b.id) : a.kind.localeCompare(b.kind)));
    for (const p of sorted) {
      const li = el('li');
      li.setAttribute('aria-selected', String(state.selected?.kind === 'point' && state.selected.id === p.id));
      const label = el('span');
      const dot = el('span', 'dot');
      dot.style.background = POINT_COLOR[p.kind];
      label.append(dot, document.createTextNode(`${POINT_LABEL[p.kind]}${p.kind === 'checkpoint' ? ` ${p.order}` : ''}${p.kind === 'zone' ? ` · r ${p.radius} m` : ''}`));
      const del = el('button', 'icon-btn', '✕');
      del.title = 'Borrar punto';
      del.setAttribute('aria-label', 'Borrar punto');
      del.addEventListener('click', (e) => { e.stopPropagation(); removePoint(p.id); });
      li.append(label, del);
      li.addEventListener('click', () => select('point', p.id));
      points.append(li);
    }
  }

  function renderEdit() {
    const p = state.selected?.kind === 'prop' ? findProp(state.selected.id) : null;
    $('edit-empty').classList.toggle('hidden', !!p);
    $('edit-form').classList.toggle('hidden', !p);
    if (!p) return;
    $('edit-model').textContent = `#${p.id} · ${p.model}`;
    for (const input of document.querySelectorAll('#edit-form [data-field]')) {
      if (document.activeElement === input) continue;
      const f = input.dataset.field;
      if (input.type === 'checkbox') input.checked = p[f] !== false;
      else input.value = p[f];
    }
  }

  function renderCatalog() {
    const cats = $('catalog-cats');
    cats.replaceChildren();
    for (const c of state.catalog.categories) {
      const chip = el('button', 'chip', c.label);
      chip.type = 'button';
      chip.setAttribute('aria-pressed', String(state.category === c.id));
      chip.addEventListener('click', () => { state.category = state.category === c.id ? null : c.id; renderCatalog(); });
      cats.append(chip);
    }
    const q = $('catalog-search').value.trim().toLowerCase();
    const list = $('catalog-list');
    list.replaceChildren();
    for (const c of state.catalog.categories) {
      if (state.category && state.category !== c.id) continue;
      for (const m of c.models) {
        if (q && !m.includes(q)) continue;
        const li = el('li', state.available[m] === false ? 'unavailable' : '');
        li.append(el('span', 'mono', m), el('small', '', c.label));
        li.title = state.available[m] === false ? 'No existe en esta build del juego' : 'Colocar';
        li.addEventListener('click', () => startPlacing(m));
        list.append(li);
      }
    }
  }

  // ── Colocación ──────────────────────────────────────────────────────────
  function placeOptions() {
    return {
      grid: Number($('grid-size').value) || 0,
      rotStep: Number($('rot-step').value) || 15,
      ground: $('opt-ground').checked,
      continuous: $('opt-continuous').checked,
    };
  }

  async function startPlacing(model) {
    if (!state.current) return toast('Primero crea o abre un layout.', 'error');
    if (inGame) return nuiPost('place', { layout: state.current, model, ...placeOptions() });
    // En navegador: centro del mapa, altura del elemento más cercano.
    const l = current();
    const all = [...(l.props || []), ...(l.points || [])];
    let z = 0, best = Infinity;
    for (const it of all) {
      const d = (it.x - view.cx) ** 2 + (it.y - view.cy) ** 2;
      if (d < best) { best = d; z = it.z; }
    }
    const g = placeOptions().grid;
    const snap = (v) => (g ? Math.round(v / g) * g : v);
    await addProp({ model, x: round(snap(view.cx)), y: round(snap(view.cy)), z: round(z), rx: 0, ry: 0, rz: 0 });
  }

  // ── Mapa 2D ─────────────────────────────────────────────────────────────
  const canvas = $('map');
  const ctx = canvas.getContext('2d');
  const view = { cx: 0, cy: 0, scale: 8 }; // px por metro
  let drag = null;

  function resizeMap() {
    const r = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.round(r.width * dpr));
    canvas.height = Math.max(1, Math.round(r.height * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  const W = () => canvas.width / (window.devicePixelRatio || 1);
  const H = () => canvas.height / (window.devicePixelRatio || 1);
  const toScreen = (x, y) => [W() / 2 + (x - view.cx) * view.scale, H() / 2 - (y - view.cy) * view.scale];
  const toWorld = (sx, sy) => [view.cx + (sx - W() / 2) / view.scale, view.cy - (sy - H() / 2) / view.scale];

  function fitMap() {
    const l = current();
    const items = [...(l?.props || []), ...(l?.points || [])];
    if (!items.length) return;
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    for (const it of items) {
      const r = it.kind === 'zone' ? it.radius : 0;
      minX = Math.min(minX, it.x - r); maxX = Math.max(maxX, it.x + r);
      minY = Math.min(minY, it.y - r); maxY = Math.max(maxY, it.y + r);
    }
    view.cx = (minX + maxX) / 2;
    view.cy = (minY + maxY) / 2;
    const span = Math.max(maxX - minX, maxY - minY, 10);
    view.scale = Math.min(60, Math.max(0.2, (Math.min(W(), H()) - 60) / span));
  }

  function drawMap() {
    if (!canvas.width) resizeMap();
    const w = W(), h = H();
    ctx.clearRect(0, 0, w, h);
    // Rejilla adaptativa
    const steps = [0.5, 1, 2, 5, 10, 25, 50, 100, 250, 500];
    const step = steps.find((s) => s * view.scale >= 28) || 1000;
    ctx.lineWidth = 1;
    const [x0, y1] = toWorld(0, 0), [x1, y0] = toWorld(w, h);
    for (let x = Math.floor(x0 / step) * step; x <= x1; x += step) {
      const [sx] = toScreen(x, 0);
      ctx.strokeStyle = Math.round(x / step) % 5 === 0 ? 'rgba(140,170,255,.16)' : 'rgba(140,170,255,.06)';
      ctx.beginPath(); ctx.moveTo(sx, 0); ctx.lineTo(sx, h); ctx.stroke();
    }
    for (let y = Math.floor(y0 / step) * step; y <= y1; y += step) {
      const [, sy] = toScreen(0, y);
      ctx.strokeStyle = Math.round(y / step) % 5 === 0 ? 'rgba(140,170,255,.16)' : 'rgba(140,170,255,.06)';
      ctx.beginPath(); ctx.moveTo(0, sy); ctx.lineTo(w, sy); ctx.stroke();
    }
    ctx.fillStyle = 'rgba(154,166,199,.8)';
    ctx.font = '11px ui-monospace, Consolas, monospace';
    ctx.fillText(`rejilla ${step} m · N ↑`, 10, h - 10);

    const l = current();
    if (!l || !l.props) return;
    // Recorrido de checkpoints
    const cps = (l.points || []).filter((p) => p.kind === 'checkpoint').sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
    if (cps.length > 1) {
      ctx.strokeStyle = 'rgba(92,225,255,.5)';
      ctx.setLineDash([6, 6]);
      ctx.beginPath();
      cps.forEach((p, i) => { const [sx, sy] = toScreen(p.x, p.y); i ? ctx.lineTo(sx, sy) : ctx.moveTo(sx, sy); });
      ctx.stroke();
      ctx.setLineDash([]);
    }
    for (const p of l.points || []) {
      const [sx, sy] = toScreen(p.x, p.y);
      const sel = state.selected?.kind === 'point' && state.selected.id === p.id;
      ctx.strokeStyle = POINT_COLOR[p.kind];
      ctx.fillStyle = POINT_COLOR[p.kind];
      if (p.kind === 'zone') {
        ctx.globalAlpha = 0.15;
        ctx.beginPath(); ctx.arc(sx, sy, p.radius * view.scale, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 1;
        ctx.beginPath(); ctx.arc(sx, sy, p.radius * view.scale, 0, Math.PI * 2); ctx.stroke();
      }
      ctx.beginPath(); ctx.arc(sx, sy, sel ? 8 : 6, 0, Math.PI * 2); ctx.fill();
      if (sel) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 1; }
      if (p.kind === 'checkpoint') { ctx.fillStyle = '#031018'; ctx.fillText(String(p.order), sx - 3, sy + 4); }
    }
    for (const p of l.props) {
      const [sx, sy] = toScreen(p.x, p.y);
      const sel = state.selected?.kind === 'prop' && state.selected.id === p.id;
      const size = Math.max(6, Math.min(26, view.scale * 1.2));
      ctx.save();
      ctx.translate(sx, sy);
      ctx.rotate(-(p.rz || 0) * Math.PI / 180);
      ctx.fillStyle = sel ? 'rgba(255,79,216,.9)' : 'rgba(238,242,255,.85)';
      ctx.fillRect(-size / 2, -size / 2, size, size);
      ctx.strokeStyle = sel ? '#fff' : 'rgba(5,7,15,.9)';
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -size); ctx.stroke(); // rumbo
      ctx.restore();
    }
  }

  function hitTest(sx, sy) {
    const l = current();
    if (!l?.props) return null;
    const near = (x, y, r) => { const [px, py] = toScreen(x, y); return (px - sx) ** 2 + (py - sy) ** 2 <= r * r; };
    for (let i = l.props.length - 1; i >= 0; i--) {
      if (near(l.props[i].x, l.props[i].y, Math.max(8, view.scale * 0.8))) return { kind: 'prop', item: l.props[i] };
    }
    for (const p of l.points || []) if (near(p.x, p.y, 9)) return { kind: 'point', item: p };
    return null;
  }

  canvas.addEventListener('pointerdown', (e) => {
    const r = canvas.getBoundingClientRect();
    const sx = e.clientX - r.left, sy = e.clientY - r.top;
    const hit = hitTest(sx, sy);
    canvas.setPointerCapture(e.pointerId);
    canvas.classList.add('dragging');
    if (hit) {
      select(hit.kind, hit.item.id);
      drag = { kind: hit.kind, id: hit.item.id, startX: hit.item.x, startY: hit.item.y, sx, sy, moved: false };
    } else {
      drag = { kind: 'pan', cx: view.cx, cy: view.cy, sx, sy };
    }
  });

  canvas.addEventListener('pointermove', (e) => {
    const r = canvas.getBoundingClientRect();
    const sx = e.clientX - r.left, sy = e.clientY - r.top;
    const [wx, wy] = toWorld(sx, sy);
    $('map-cursor').textContent = `x ${wx.toFixed(2)} · y ${wy.toFixed(2)}`;
    if (!drag) return;
    const dx = (sx - drag.sx) / view.scale, dy = -(sy - drag.sy) / view.scale;
    if (drag.kind === 'pan') {
      view.cx = drag.cx - dx; view.cy = drag.cy - dy;
    } else {
      const item = drag.kind === 'prop' ? findProp(drag.id) : findPoint(drag.id);
      if (!item) return;
      const g = Number($('grid-size').value) || 0;
      const snap = (v) => (g ? Math.round(v / g) * g : v);
      item.x = round(snap(drag.startX + dx)); item.y = round(snap(drag.startY + dy));
      drag.moved = true;
    }
    drawMap();
  });

  canvas.addEventListener('pointerup', async () => {
    canvas.classList.remove('dragging');
    const d = drag;
    drag = null;
    if (!d || d.kind === 'pan' || !d.moved) return;
    const item = d.kind === 'prop' ? findProp(d.id) : findPoint(d.id);
    if (!item) return;
    const patch = { x: item.x, y: item.y };
    // Restaura el original para que el historial guarde el estado previo correcto.
    item.x = d.startX; item.y = d.startY;
    if (d.kind === 'prop') await updateProp(d.id, patch); else await updatePoint(d.id, patch);
  });

  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    const r = canvas.getBoundingClientRect();
    const sx = e.clientX - r.left, sy = e.clientY - r.top;
    const [wx, wy] = toWorld(sx, sy);
    view.scale = Math.min(120, Math.max(0.05, view.scale * (e.deltaY < 0 ? 1.15 : 1 / 1.15)));
    const [nx, ny] = toWorld(sx, sy);
    view.cx += wx - nx; view.cy += wy - ny;
    drawMap();
  }, { passive: false });

  window.addEventListener('resize', () => { resizeMap(); drawMap(); });

  // ── Teclado ─────────────────────────────────────────────────────────────
  document.addEventListener('keydown', (e) => {
    const typing = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName);
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); return undo(); }
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') { e.preventDefault(); return redo(); }
    if (inGame && (e.key === 'Escape' || e.key === 'F6') && !typing) return nuiPost('close');
    if (typing || !state.selected) return;
    const sel = state.selected;
    const item = sel.kind === 'prop' ? findProp(sel.id) : findPoint(sel.id);
    if (!item) return;
    const step = (Number($('grid-size').value) || 0.1) * (e.shiftKey ? 10 : 1);
    const rot = Number($('rot-step').value) || 15;
    let patch = null;
    if (e.key === 'ArrowUp') patch = { y: round(item.y + step) };
    if (e.key === 'ArrowDown') patch = { y: round(item.y - step) };
    if (e.key === 'ArrowLeft') patch = { x: round(item.x - step) };
    if (e.key === 'ArrowRight') patch = { x: round(item.x + step) };
    if (e.key === 'PageUp') patch = { z: round(item.z + step) };
    if (e.key === 'PageDown') patch = { z: round(item.z - step) };
    if (sel.kind === 'prop' && e.key.toLowerCase() === 'q') patch = { rz: normAngle((item.rz || 0) + rot) };
    if (sel.kind === 'prop' && e.key.toLowerCase() === 'e') patch = { rz: normAngle((item.rz || 0) - rot) };
    if (e.key === 'Delete') { e.preventDefault(); return sel.kind === 'prop' ? removeProp(sel.id) : removePoint(sel.id); }
    if (patch) {
      e.preventDefault();
      if (sel.kind === 'prop') updateProp(sel.id, patch); else updatePoint(sel.id, patch);
    }
  });

  // ── Controles de la interfaz ────────────────────────────────────────────
  for (const b of document.querySelectorAll('.tabs button')) b.addEventListener('click', () => setTab(b.dataset.tab));
  $('undo').addEventListener('click', undo);
  $('redo').addEventListener('click', redo);
  $('close').addEventListener('click', () => nuiPost('close'));
  $('map-fit').addEventListener('click', () => { fitMap(); drawMap(); });

  $('new-layout').addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = $('new-layout-id').value.trim();
    const r = await op('createLayout', { id, name: id });
    if (r) { $('new-layout-id').value = ''; openLayout(r.id); }
  });
  $('layout-name').addEventListener('change', () => op('renameLayout', { id: state.current, name: $('layout-name').value }));
  $('layout-active').addEventListener('change', () => op('setActive', { id: state.current, active: $('layout-active').checked }));
  $('layout-delete').addEventListener('click', async () => {
    const l = current();
    if (!l || !confirm(`¿Borrar el layout «${l.name}» y sus ${l.props?.length ?? 0} props? No se puede deshacer.`)) return;
    if (await op('deleteLayout', { id: l.id })) { state.current = null; renderAll(); }
  });

  const showJson = (text) => {
    $('json-box').value = text;
    $('json-box').classList.remove('hidden');
    $('json-actions').classList.remove('hidden');
  };
  $('layout-export').addEventListener('click', () => {
    const l = current();
    if (l) showJson(JSON.stringify({ id: l.id, name: l.name, props: l.props, points: l.points }, null, 2));
  });
  $('layout-import').addEventListener('click', () => showJson(''));
  $('json-cancel').addEventListener('click', () => { $('json-box').classList.add('hidden'); $('json-actions').classList.add('hidden'); });
  $('json-apply').addEventListener('click', async () => {
    let data;
    try { data = JSON.parse($('json-box').value); } catch { return toast('El JSON no es válido.', 'error'); }
    const exists = data?.id && state.layouts[data.id];
    if (exists && !confirm(`Ya existe «${data.id}». ¿Sobrescribirlo?`)) return;
    const r = await op('importLayout', { data, overwrite: !!exists });
    if (r) { toast(`Layout «${r.name}» importado.`, 'ok'); openLayout(r.id); }
  });

  $('catalog-search').addEventListener('input', renderCatalog);
  $('custom-model').addEventListener('submit', (e) => { e.preventDefault(); startPlacing($('custom-model-name').value.trim()); });
  $('pick').addEventListener('click', () => nuiPost('pick'));

  for (const input of document.querySelectorAll('#edit-form [data-field]')) {
    input.addEventListener('change', () => {
      const p = state.selected?.kind === 'prop' && findProp(state.selected.id);
      if (!p) return;
      const f = input.dataset.field;
      const v = input.type === 'checkbox' ? input.checked : Number(input.value);
      if (input.type !== 'checkbox' && !Number.isFinite(v)) return renderEdit();
      updateProp(p.id, { [f]: f.startsWith('r') ? normAngle(v) : v });
    });
  }
  for (const b of document.querySelectorAll('[data-nudge]')) {
    b.addEventListener('click', () => {
      const p = state.selected?.kind === 'prop' && findProp(state.selected.id);
      if (!p) return;
      const [axis, dir] = b.dataset.nudge.split(',');
      updateProp(p.id, { [axis]: round(p[axis] + Number(dir) * Number($('nudge-step').value)) });
    });
  }
  $('edit-dup').addEventListener('click', () => {
    const p = state.selected?.kind === 'prop' && findProp(state.selected.id);
    if (p) addProp({ ...propData(p), x: round(p.x + 1), y: round(p.y + 1) });
  });
  $('edit-level').addEventListener('click', () => {
    const p = state.selected?.kind === 'prop' && findProp(state.selected.id);
    if (p) updateProp(p.id, { rx: 0, ry: 0 });
  });
  $('edit-delete').addEventListener('click', () => { if (state.selected?.kind === 'prop') removeProp(state.selected.id); });
  $('edit-tp').addEventListener('click', () => {
    const p = state.selected?.kind === 'prop' && findProp(state.selected.id);
    if (p) nuiPost('teleport', p);
  });
  $('edit-move').addEventListener('click', () => {
    const p = state.selected?.kind === 'prop' && findProp(state.selected.id);
    if (p) nuiPost('place', { layout: state.current, model: p.model, moveId: p.id, rz: p.rz, ...placeOptions(), continuous: false });
  });

  $('point-add').addEventListener('click', async () => {
    if (!state.current) return toast('Primero crea o abre un layout.', 'error');
    const kind = $('point-kind').value;
    const point = { kind };
    if (kind === 'zone') point.radius = Number($('point-radius').value) || 20;
    if (inGame) {
      const here = await nuiPost('here');
      Object.assign(point, { x: round(here.x), y: round(here.y), z: round(here.z), h: round(here.h, 1) });
    } else {
      const l = current();
      const ref = [...(l.props || []), ...(l.points || [])][0];
      Object.assign(point, { x: round(view.cx), y: round(view.cy), z: ref ? ref.z : 0, h: 0 });
    }
    addPoint(point);
  });

  // ── Toasts y mensajes del juego ────────────────────────────────────────
  function toast(message, kind = 'info') {
    const t = el('div', `toast toast--${kind}`, message);
    $('toasts').append(t);
    setTimeout(() => t.remove(), 4500);
  }

  function fillSelect(sel, values, fmt, preferred) {
    sel.replaceChildren();
    for (const v of values) {
      const o = el('option', '', fmt(v));
      o.value = String(v);
      if (v === preferred) o.selected = true;
      sel.append(o);
    }
  }
  function fillSteps() {
    fillSelect($('grid-size'), [0, ...state.gridSizes], (v) => (v ? `${v} m` : 'libre'), 0.25);
    fillSelect($('rot-step'), state.rotationSteps, (v) => `${v}°`, 15);
  }

  async function loadCatalog() {
    try {
      const r = await fetch(inGame ? 'catalog.json' : `${apiBase}catalog.json`);
      state.catalog = await r.json();
    } catch { state.catalog = { categories: [] }; }
    if (inGame) {
      const models = state.catalog.categories.flatMap((c) => c.models);
      state.available = await nuiPost('checkModels', { models });
    }
    renderCatalog();
  }

  const handlers = {
    open: (d) => {
      state.layouts = d.layouts || {};
      if (d.gridSizes) state.gridSizes = d.gridSizes;
      if (d.rotationSteps) state.rotationSteps = d.rotationSteps;
      fillSteps();
      $('app').classList.remove('hidden');
      setTab(state.current ? 'edit' : 'layouts');
      renderAll();
      loadCatalog();
    },
    close: () => $('app').classList.add('hidden'),
    layouts: (d) => { state.layouts = d || {}; renderAll(); },
    layout: (d) => {
      if (d.layout) state.layouts[d.id] = d.layout; else delete state.layouts[d.id];
      renderAll();
    },
    placing: (d) => {
      const box = $('placing');
      box.classList.toggle('hidden', !d.active);
      $('app').style.opacity = d.active ? '0.35' : '';
      box.textContent = d.picking ? 'Apunta a un prop y haz clic para seleccionarlo' : (d.active ? `Colocando ${d.model}` : '');
    },
    opDone: (d) => {
      const r = d.response;
      if (!r?.ok) return toast(r?.error || 'Error', 'error');
      if (d.op === 'addProp') {
        const layout = state.current, prop = propData(r.result), entry = { id: r.result.id };
        record({
          undo: () => op('removeProp', { layout, id: entry.id }),
          redo: async () => { const x = await op('addProp', { layout, prop }); if (x) entry.id = x.id; },
        });
        select('prop', r.result.id);
      }
    },
    picked: (d) => { if (d.layout !== state.current) openLayout(d.layout); select('prop', d.id); },
    toast: (d) => toast(d.message, d.kind),
  };
  window.addEventListener('message', (e) => {
    const m = e.data;
    if (m && handlers[m.type]) handlers[m.type](m.data || {});
  });

  // ── Arranque en navegador ───────────────────────────────────────────────
  function showGate(error) {
    $('app').classList.add('hidden');
    $('gate').classList.remove('hidden');
    $('gate-error').textContent = error || '';
  }

  async function startWeb() {
    fillSteps();
    $('app').classList.remove('hidden');
    $('gate').classList.add('hidden');
    resizeMap();
    await refreshList();
    loadCatalog();
    const first = Object.keys(state.layouts)[0];
    if (first && !state.current) await openLayout(first);
    // Sondeo ligero para ver cambios hechos desde el juego.
    setInterval(() => { if (!document.hidden) { refreshList(); if (state.current && !drag) refreshLayout(state.current); } }, 5000);
  }

  if (!inGame) {
    $('gate-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      state.token = $('gate-token').value;
      try { sessionStorage.setItem('pxd_props_token', state.token); } catch { /* sin almacenamiento */ }
      const r = await web('GET', 'api/layouts');
      if (r?.ok) startWeb();
    });
    if (demo) {
      demoOp('createLayout', { id: 'circuito_puerto', name: 'Circuito del puerto' });
      demoOp('setActive', { id: 'circuito_puerto', active: true });
      const models = ['prop_mp_cone_02', 'prop_barrier_work05', 'prop_tyre_wall_01', 'prop_mp_ramp_01'];
      for (let i = 0; i < 14; i++) {
        const a = (i / 14) * Math.PI * 2;
        demoOp('addProp', { layout: 'circuito_puerto', prop: { model: models[i % 4], x: round(-120 + Math.cos(a) * 30), y: round(-2640 + Math.sin(a) * 18), z: 6, rz: normAngle((a * 180) / Math.PI + 90) } });
      }
      [[-90, -2640], [-120, -2622], [-150, -2640], [-120, -2658]].forEach(([x, y]) => demoOp('addPoint', { layout: 'circuito_puerto', point: { kind: 'checkpoint', x, y, z: 6 } }));
      demoOp('addPoint', { layout: 'circuito_puerto', point: { kind: 'grid', x: -95, y: -2650, z: 6, h: 0 } });
      demoOp('addPoint', { layout: 'circuito_puerto', point: { kind: 'zone', x: -120, y: -2640, z: 6, radius: 12 } });
      demoOp('createLayout', { id: 'plaza_eventos', name: 'Plaza de eventos' });
      startWeb();
    } else {
      let saved = null;
      try { saved = sessionStorage.getItem('pxd_props_token'); } catch { /* sin almacenamiento */ }
      if (saved) { state.token = saved; web('GET', 'api/layouts').then((r) => (r?.ok ? startWeb() : showGate())); }
      else showGate();
    }
  }
  renderHistory();
})();
