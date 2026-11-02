(() => {
  'use strict';

  const params = new URLSearchParams(location.search);
  const DEMO = params.has('demo');
  const inGame = typeof window.GetParentResourceName === 'function';
  const resource = inGame ? window.GetParentResourceName() : 'pxd_multichar';
  const $ = (id) => document.getElementById(id);

  const ICONS = {
    character: 'M12 12a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9zm0 2c-4.4 0-8 2.2-8 5v1h16v-1c0-2.8-3.6-5-8-5z',
    free: 'M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6z',
    locked: 'M7 10V7a5 5 0 0 1 10 0v3h1a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1zm2 0h6V7a3 3 0 0 0-6 0z',
  };

  let data = null;
  let selected = 0;
  let gender = 0;
  let busy = false;

  // ── Utilidades ──────────────────────────────────────
  async function post(name, body) {
    if (!inGame) return demoPost(name, body);
    try {
      const res = await fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
      });
      return await res.json();
    } catch (e) {
      return { ok: false };
    }
  }

  const money = (n) => '$' + Math.floor(Number(n) || 0).toLocaleString('en-US');

  function playtime(seconds) {
    seconds = Math.floor(Number(seconds) || 0);
    if (seconds < 60) return 'Recién llegado';
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    if (days > 0) {
      const d = days === 1 ? '1 día' : `${days} días`;
      return hours === 0 ? d : `${d} y ${hours === 1 ? '1 hora' : hours + ' horas'}`;
    }
    return hours > 0 ? `${hours} h ${mins} min` : `${mins} min`;
  }

  function birth(str) {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str || '');
    return m ? `${m[3]}/${m[2]}/${m[1]}` : '';
  }

  function svg(path, cls, viewBox = '0 0 24 24') {
    const ns = 'http://www.w3.org/2000/svg';
    const el = document.createElementNS(ns, 'svg');
    el.setAttribute('viewBox', viewBox);
    el.setAttribute('aria-hidden', 'true');
    if (cls) el.setAttribute('class', cls);
    const p = document.createElementNS(ns, 'path');
    p.setAttribute('d', path);
    el.appendChild(p);
    return el;
  }

  function toast(text) {
    const t = $('toast');
    t.textContent = text;
    t.classList.remove('hidden');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.add('hidden'), 4000);
  }

  function setBusy(value) {
    busy = !!value;
    $('app').classList.toggle('is-busy', busy);
  }

  const cardById = (id) => (data.characters || []).find((c) => c.citizenid === id);

  // ── Ranuras ─────────────────────────────────────────
  function renderSlots() {
    const list = $('slots');
    list.replaceChildren();
    data.slots.forEach((slot, i) => {
      const li = document.createElement('li');
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `slot slot--${slot.kind === 'character' ? 'char' : slot.kind}`;
      if (i === selected) btn.classList.add('is-active');

      const icon = document.createElement('span');
      icon.className = 'slot__icon';
      icon.appendChild(svg(ICONS[slot.kind]));
      const text = document.createElement('span');
      text.className = 'slot__text';
      const name = document.createElement('span');
      name.className = 'slot__name';
      const meta = document.createElement('span');
      meta.className = 'slot__meta';

      if (slot.kind === 'character') {
        const c = cardById(slot.citizenid) || {};
        name.textContent = `${c.firstname || ''} ${c.lastname || ''}`.trim();
        meta.textContent = c.job ? `${c.job}${c.grade ? ' · ' + c.grade : ''}` : 'Sin trabajo';
      } else if (slot.kind === 'free') {
        name.textContent = 'Crear personaje';
        meta.textContent = 'Ranura libre';
      } else {
        name.textContent = data.lockedLabel || 'Ranura Plus';
        meta.textContent = 'Bloqueada';
      }
      text.append(name, meta);
      btn.append(icon, text);
      btn.addEventListener('click', () => select(i));
      li.appendChild(btn);
      list.appendChild(li);
    });

    const used = (data.characters || []).length;
    const allowed = data.slots.filter((s) => s.kind !== 'locked').length;
    $('roster-foot').textContent = `${used} de ${allowed} ranuras en uso`;
  }

  function show(id) {
    for (const panel of ['sheet', 'create', 'locked']) $(panel).classList.toggle('hidden', panel !== id);
  }

  function select(i) {
    if (busy || !data || !data.slots[i]) return;
    selected = i;
    renderSlots();
    const slot = data.slots[i];
    if (slot.kind === 'character') {
      renderSheet(cardById(slot.citizenid));
      show('sheet');
      post('select', { citizenid: slot.citizenid });
    } else if (slot.kind === 'free') {
      openCreate();
    } else {
      $('locked-label').textContent = data.lockedLabel || 'Ranura Plus';
      $('btn-store').classList.toggle('hidden', !data.storeUrl);
      show('locked');
    }
  }

  // ── Ficha ───────────────────────────────────────────
  function renderSheet(c) {
    if (!c) return;
    $('sheet-id').textContent = c.citizenid || '';
    $('sheet-first').textContent = c.firstname || '';
    $('sheet-last').textContent = c.lastname || '';
    $('sheet-job').textContent = c.job ? `${c.job}${c.grade ? ' · ' + c.grade : ''}` : 'Sin trabajo';

    const chips = $('sheet-chips');
    chips.replaceChildren();
    for (const label of [c.gender === 1 ? 'Mujer' : 'Hombre', c.nationality, c.birthdate && `Nació el ${birth(c.birthdate)}`]) {
      if (!label) continue;
      const li = document.createElement('li');
      li.textContent = label;
      chips.appendChild(li);
    }

    $('stat-cash').textContent = money(c.cash);
    $('stat-bank').textContent = money(c.bank);

    const hasLevel = Number.isFinite(c.level);
    $('stat-level').classList.toggle('hidden', !hasLevel);
    if (hasLevel) {
      $('level-num').textContent = String(c.level);
      const hasXp = Number.isFinite(c.xp) && Number.isFinite(c.xpNext) && c.xpNext > 0;
      $('level-xp').textContent = hasXp ? `${c.xp} / ${c.xpNext} XP` : `Nivel ${c.level}`;
      const pct = hasXp ? Math.max(0, Math.min(1, c.xp / c.xpNext)) : 0;
      $('hex-fill').style.strokeDashoffset = String(100 - pct * 100);
    }

    const hasTime = Number.isFinite(c.playtime);
    $('stat-time').classList.toggle('hidden', !hasTime);
    if (hasTime) $('stat-playtime').textContent = playtime(c.playtime);

    $('btn-delete').classList.toggle('hidden', !data.enableDelete);
  }

  // ── Crear ───────────────────────────────────────────
  function fillNationalities() {
    const select = $('f-nat');
    const free = $('f-nat-free');
    const search = $('f-nat-search');
    const list = data.nationalities || [];
    const limited = data.limitNationalities && list.length > 0;
    select.classList.toggle('hidden', !limited);
    search.classList.toggle('hidden', !limited || list.length < 20);
    free.classList.toggle('hidden', limited);
    if (!limited) return;
    const filter = search.value.trim().toLowerCase();
    const current = select.value || data.defaultNationality;
    select.replaceChildren();
    for (const n of list) {
      if (filter && !n.toLowerCase().includes(filter) && n !== current) continue;
      const opt = document.createElement('option');
      opt.value = n;
      opt.textContent = n;
      select.appendChild(opt);
    }
    if (list.includes(current)) select.value = current;
  }

  function setGender(g) {
    gender = g === 1 ? 1 : 0;
    for (const b of document.querySelectorAll('.toggle button')) {
      b.setAttribute('aria-checked', String(Number(b.dataset.gender) === gender));
    }
  }

  function openCreate() {
    const form = $('create-form');
    form.reset();
    for (const el of form.querySelectorAll('.is-invalid')) el.classList.remove('is-invalid');
    $('form-error').textContent = '';
    $('f-birth').min = data.dateMin || '';
    $('f-birth').max = data.dateMax || '';
    $('f-birth').value = data.dateMax || '';
    $('f-nat-search').value = '';
    fillNationalities();
    setGender(0);
    show('create');
    post('select', { gender: 0 });
    setTimeout(() => $('f-first').focus(), 50);
  }

  const NAME_RE = /^[A-Za-zÁÉÍÓÚÜÑáéíóúüñÀÈÌÒÙàèìòùÇçÃãÕõÂâÊêÔô]+(?:[ '\-][A-Za-zÁÉÍÓÚÜÑáéíóúüñÀÈÌÒÙàèìòùÇçÃãÕõÂâÊêÔô]+){0,4}$/;

  function quickCheck(values) {
    for (const [field, label] of [['firstname', 'nombre'], ['lastname', 'apellido']]) {
      const v = values[field].replace(/\s+/g, ' ').trim();
      if (v.length < 2) return [field, `Escribe el ${label}.`];
      if (v.length > 25) return [field, `El ${label} es demasiado largo (máximo 25).`];
      if (!NAME_RE.test(v)) return [field, `El ${label} solo puede llevar letras.`];
    }
    if (!values.nationality) return ['nationality', 'Elige la nacionalidad.'];
    if (!values.birthdate) return ['birthdate', 'Elige la fecha de nacimiento.'];
    return null;
  }

  const FIELD_INPUT = { firstname: 'f-first', lastname: 'f-last', nationality: 'f-nat', birthdate: 'f-birth' };

  function markInvalid(field, message) {
    for (const el of document.querySelectorAll('#create-form .is-invalid')) el.classList.remove('is-invalid');
    let id = FIELD_INPUT[field];
    if (field === 'nationality' && $('f-nat').classList.contains('hidden')) id = 'f-nat-free';
    if (id) $(id).classList.add('is-invalid');
    $('form-error').textContent = message || '';
  }

  async function submitCreate(ev) {
    ev.preventDefault();
    if (busy) return;
    const limited = !$('f-nat').classList.contains('hidden');
    const values = {
      firstname: $('f-first').value,
      lastname: $('f-last').value,
      nationality: limited ? $('f-nat').value : $('f-nat-free').value.trim(),
      gender,
      birthdate: $('f-birth').value,
    };
    const problem = quickCheck(values);
    if (problem) return markInvalid(problem[0], problem[1]);
    markInvalid(null, '');
    setBusy(true);
    const res = await post('create', values);
    setBusy(false);
    if (!res || !res.ok) markInvalid(res && res.field, (res && res.error) || 'No se pudo crear el personaje.');
  }

  // ── Jugar / eliminar ────────────────────────────────
  async function play() {
    const slot = data && data.slots[selected];
    if (busy || !slot || slot.kind !== 'character') return;
    setBusy(true);
    const res = await post('play', { citizenid: slot.citizenid });
    if (!res || !res.ok) { setBusy(false); toast('No se pudo entrar con ese personaje.'); }
  }

  function openDelete() {
    const slot = data.slots[selected];
    const c = slot && cardById(slot.citizenid);
    if (!c) return;
    $('modal-name').textContent = `${c.firstname} ${c.lastname}`;
    $('modal-input').value = '';
    $('modal-error').textContent = '';
    $('modal').classList.remove('hidden');
    setTimeout(() => $('modal-input').focus(), 50);
  }

  async function confirmDelete() {
    const slot = data.slots[selected];
    const c = slot && cardById(slot.citizenid);
    if (!c || busy) return;
    const typed = $('modal-input').value.replace(/\s+/g, ' ').trim().toLowerCase();
    if (typed !== `${c.firstname} ${c.lastname}`.toLowerCase()) {
      $('modal-error').textContent = 'El nombre no coincide.';
      return;
    }
    setBusy(true);
    const res = await post('delete', { citizenid: c.citizenid, confirm: $('modal-input').value });
    setBusy(false);
    if (res && res.ok) {
      $('modal').classList.add('hidden');
      toast('Personaje eliminado.');
    } else {
      $('modal-error').textContent = (res && res.error) || 'No se pudo eliminar.';
    }
  }

  // ── Abrir / cerrar ──────────────────────────────────
  function open(payload) {
    data = payload;
    data.slots = data.slots || [];
    const first = data.slots.findIndex((s) => s.kind === 'character');
    selected = first >= 0 ? first : Math.max(0, data.slots.findIndex((s) => s.kind === 'free'));
    $('modal').classList.add('hidden');
    $('app').classList.remove('hidden');
    renderSlots();
    select(selected);
  }

  function close() {
    $('app').classList.add('hidden');
    $('modal').classList.add('hidden');
  }

  // ── Aparición / apartamento inicial ─────────────────
  const BADGE = { last: ['Última ubicación', 'px-badge'], property: ['Tu casa', 'px-badge px-badge--gold'], point: ['Ciudad', 'px-badge px-badge--muted'], apartment: ['Gratis', 'px-badge px-badge--ok'] };
  let spawnView = null;
  let spawnSel = 0;
  let spawnSending = false;

  function renderSpawn() {
    const list = $('spawn-list');
    list.replaceChildren();
    spawnView.options.forEach((o, i) => {
      const li = document.createElement('li');
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'spawn__item' + (i === spawnSel ? ' is-active' : '');
      btn.setAttribute('role', 'option');
      btn.setAttribute('aria-selected', String(i === spawnSel));
      const img = document.createElement('div');
      img.className = 'spawn__img';
      if (o.image && /^[\w./-]+\.(jpg|jpeg|png|webp)$/.test(o.image)) img.style.backgroundImage = `url("${o.image}")`;
      const [label, cls] = BADGE[o.kind] || BADGE.point;
      const badge = document.createElement('span');
      badge.className = cls;
      badge.textContent = label;
      const body = document.createElement('div');
      body.className = 'spawn__body';
      const b = document.createElement('b'); b.textContent = o.label || '';
      const d = document.createElement('span'); d.textContent = o.detail || '';
      body.append(b, d);
      btn.append(img, badge, body);
      btn.addEventListener('click', () => { if (spawnSel === i) chooseSpawn(); else { spawnSel = i; renderSpawn(); } });
      li.appendChild(btn);
      list.appendChild(li);
    });
    const active = list.querySelector('.is-active');
    if (active && active.scrollIntoView) active.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    const cur = spawnView.options[spawnSel];
    if (cur) post('spawnFocus', { id: cur.id });   // la cámara del juego se mueve a esa opción
  }

  function openSpawn(view) {
    spawnView = view;
    spawnView.options = Array.isArray(view.options) ? view.options : [];
    spawnSel = 0;
    spawnSending = false;
    $('spawn-kicker').textContent = view.kicker || '';
    $('spawn-title').textContent = view.title || '';
    $('spawn-text').textContent = view.text || '';
    $('spawn-confirm').textContent = view.confirm || 'Aparecer';
    $('app').classList.add('hidden');
    $('spawn').classList.remove('hidden');
    renderSpawn();
  }

  async function chooseSpawn() {
    if (!spawnView || spawnSending) return;
    const opt = spawnView.options[spawnSel];
    if (!opt) return;
    spawnSending = true;
    const res = await post('spawnChoose', { id: opt.id });
    if (!res || !res.ok) spawnSending = false;
  }

  $('spawn-go').addEventListener('click', chooseSpawn);
  document.addEventListener('keydown', (e) => {
    if (!spawnView || $('spawn').classList.contains('hidden')) return;
    if (e.key === 'ArrowRight') { spawnSel = Math.min(spawnView.options.length - 1, spawnSel + 1); renderSpawn(); }
    else if (e.key === 'ArrowLeft') { spawnSel = Math.max(0, spawnSel - 1); renderSpawn(); }
    else if (e.key === 'Enter') chooseSpawn();
  });

  window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (msg.action === 'spawn' && msg.data) openSpawn(msg.data);
    else if (msg.action === 'spawnClose') { $('spawn').classList.add('hidden'); spawnView = null; }
    if (msg.action === 'open' && msg.data) open(msg.data);
    else if (msg.action === 'close') close();
    else if (msg.action === 'busy') setBusy(msg.value);
    else if (msg.action === 'toast' && msg.text) toast(String(msg.text));
  });

  // ── Eventos de la interfaz ──────────────────────────
  $('btn-play').addEventListener('click', play);
  $('btn-delete').addEventListener('click', openDelete);
  $('modal-cancel').addEventListener('click', () => $('modal').classList.add('hidden'));
  $('modal-confirm').addEventListener('click', confirmDelete);
  $('modal-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') confirmDelete(); });
  $('create-form').addEventListener('submit', submitCreate);
  $('btn-cancel').addEventListener('click', () => {
    const first = data.slots.findIndex((s) => s.kind === 'character');
    if (first >= 0) select(first);
  });
  $('f-nat-search').addEventListener('input', fillNationalities);
  $('btn-store').addEventListener('click', () => {
    if (!data.storeUrl) return;
    if (typeof window.invokeNative === 'function') window.invokeNative('openUrl', data.storeUrl);
    else window.open(data.storeUrl, '_blank', 'noopener');
  });
  for (const b of document.querySelectorAll('.toggle button')) {
    b.addEventListener('click', () => {
      setGender(Number(b.dataset.gender));
      post('select', { gender });
    });
  }
  document.addEventListener('keydown', (e) => {
    if (!data || busy || $('app').classList.contains('hidden')) return;
    if (!$('modal').classList.contains('hidden')) {
      if (e.key === 'Escape') $('modal').classList.add('hidden');
      return;
    }
    const typing = ['INPUT', 'SELECT'].includes(document.activeElement && document.activeElement.tagName);
    if (typing) return;
    if (e.key === 'ArrowDown') select(Math.min(data.slots.length - 1, selected + 1));
    else if (e.key === 'ArrowUp') select(Math.max(0, selected - 1));
    else if (e.key === 'Enter') play();
  });

  // ── Demostración (html/index.html?demo=1) ───────────
  function demoPost(name, body) {
    if (name === 'create') return { ok: false, field: 'firstname', error: 'Demostración: aquí se crearía el personaje.' };
    if (name === 'delete') return { ok: true };
    if (name === 'spawnChoose' || name === 'spawnFocus') return { ok: true };
    return { ok: true, body };
  }

  if (DEMO) {
    document.body.classList.add('demo');
    const characters = [
      { citizenid: 'PXD48213', firstname: 'Valentina', lastname: 'Ríos', gender: 1, nationality: 'Mexican', birthdate: '1997-03-12', job: 'Servicios de Emergencia', grade: 'Paramédica', cash: 95846, bank: 778358, level: 16, xp: 223, xpNext: 289, playtime: 2534400 },
      { citizenid: 'PXD10977', firstname: 'Bruno', lastname: 'Salgado', gender: 0, nationality: 'Argentine', birthdate: '1990-11-02', job: 'Taller Próxima', grade: 'Aprendiz', cash: 1200, bank: 15400, level: 3, xp: 40, xpNext: 120, playtime: 11520 },
    ];
    open({
      serverName: 'PRÓXIMA RP',
      characters,
      slots: [
        { kind: 'character', index: 1, citizenid: 'PXD48213' },
        { kind: 'character', index: 2, citizenid: 'PXD10977' },
        { kind: 'free', index: 3 },
        { kind: 'locked', index: 4 },
        { kind: 'locked', index: 5 },
      ],
      lockedLabel: 'Ranura Plus',
      storeUrl: 'https://example.com',
      enableDelete: true,
      nationalities: ['American', 'Argentine', 'Brazilian', 'Chilean', 'Colombian', 'Mexican', 'Peruvian', 'Spanish'],
      limitNationalities: true,
      defaultNationality: 'Mexican',
      dateMin: '1930-01-01',
      dateMax: '2006-12-31',
    });
    const view = params.get('view');
    if (view === 'spawn') openSpawn({ mode: 'spawn', kicker: '¿Dónde apareces?', title: 'Elige dónde empezar', text: 'Vuelve donde lo dejaste, a tu casa o a un punto de la ciudad.', confirm: 'Aparecer', options: [
      { id: 'last', kind: 'last', label: 'Última ubicación', detail: 'Donde lo dejaste', image: 'assets/spawn-ultima.jpg' },
      { id: 'property:1', kind: 'property', label: 'Del Perro Heights 12', detail: 'Tu casa', image: 'assets/spawn-casa.jpg' },
      { id: 'point:1', kind: 'point', label: 'Plaza Legion', detail: 'Centro de la ciudad', image: 'assets/spawn-centro.jpg' },
      { id: 'point:2', kind: 'point', label: 'Paleto Bay', detail: 'Pueblo del norte, junto al mar', image: 'assets/spawn-paleto.jpg' },
      { id: 'point:3', kind: 'point', label: 'Motel', detail: 'Habitaciones baratas para empezar', image: 'assets/spawn-motel.jpg' },
    ] });
    else if (view === 'apartment') openSpawn({ mode: 'apartment', kicker: 'Tu primer hogar', title: 'Elige tu apartamento', text: 'Es gratis y será tu casa en la ciudad: ahí guardas tus cosas y te cambias de ropa.', confirm: 'Mudarme aquí', options: [
      { id: 'apt:1', kind: 'apartment', label: 'Del Perro Heights', detail: 'Vistas al mar, lejos del ruido de la playa.', image: 'assets/spawn-casa.jpg' },
      { id: 'apt:3', kind: 'apartment', label: '4 Integrity Way', detail: 'En pleno centro, rodeado de rascacielos.', image: 'assets/spawn-casa.jpg' },
      { id: 'apt:5', kind: 'apartment', label: 'Richard Majestic', detail: 'Condominio de lujo junto a los estudios de música.', image: 'assets/spawn-casa.jpg' },
      { id: 'apt:6', kind: 'apartment', label: 'Tinsel Towers', detail: 'Torre residencial en Rockford Hills.', image: 'assets/spawn-casa.jpg' },
    ] });
    else if (view === 'create') select(2);
    else if (view === 'locked') select(3);
    else if (view === 'delete') openDelete();
  }
})();
