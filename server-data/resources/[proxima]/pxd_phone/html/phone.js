// Próxima RP — capa para el teléfono npwd 3.14.3 (se inyecta en su index.html).
// - Inicio propio (iconos, nombres en español, dock, reloj) encima del inicio de npwd,
//   que sigue en el DOM para saber qué apps hay y sus avisos.
// - Apps propias: Dynasty 8, Emergencias y Taxi. Hablan con el recurso pxd_phone
//   (https://pxd_phone/<accion>); el servidor valida todo.
// - Texto de usuario siempre con textContent.
(() => {
  'use strict';
  const RES = 'pxd_phone';
  const DEMO = !/cfx-nui-npwd/.test(location.host) && !!window.__pxdPhoneDemo;
  const doc = document;
  doc.documentElement.classList.add('pxd-phone');

  // ── Llamadas al recurso ────────────────────────────────────────────────
  async function post(action, data = {}) {
    if (DEMO) return window.__pxdPhoneDemo(action, data);
    try {
      const r = await fetch(`https://${RES}/${action}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
      });
      return await r.json();
    } catch (e) { return { error: 'Sin conexión con el servidor.' }; }
  }

  // ── Utilidades DOM ─────────────────────────────────────────────────────
  const SVGNS = 'http://www.w3.org/2000/svg';
  function el(tag, cls, text) {
    const n = doc.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  function icon(paths) {
    const s = doc.createElementNS(SVGNS, 'svg');
    s.setAttribute('viewBox', '0 0 24 24');
    for (const d of paths) {
      const p = doc.createElementNS(SVGNS, 'path');
      p.setAttribute('d', d);
      s.appendChild(p);
    }
    return s;
  }
  const money = (n) => '$' + Math.round(Number(n) || 0).toLocaleString('es-MX');

  // ── Iconos (trazos propios, 24×24) ─────────────────────────────────────
  const I = {
    phone: ['M6.6 3.5h2.6l1.4 3.6-1.9 1.4a11 11 0 0 0 6.8 6.8l1.4-1.9 3.6 1.4v2.6a2 2 0 0 1-2.2 2A16.5 16.5 0 0 1 4.6 5.7a2 2 0 0 1 2-2.2z'],
    chat: ['M4 5.5h16v10H9l-5 4v-14z', 'M8 9.5h8M8 12.5h5'],
    contacts: ['M12 12a3.6 3.6 0 1 0 0-7.2 3.6 3.6 0 0 0 0 7.2z', 'M5 20a7 7 0 0 1 14 0'],
    megaphone: ['M3.5 10v4h3l7 4V6l-7 4h-3z', 'M17 9a4 4 0 0 1 0 6', 'M7 14l1 5h2.5l-1-5'],
    camera: ['M4 8h3l1.6-2.5h6.8L17 8h3v11H4V8z', 'M12 16.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z'],
    notes: ['M6 3.5h9l3 3V20.5H6z', 'M9 10h6M9 13.5h6M9 17h4'],
    calc: ['M6 3.5h12v17H6z', 'M8.5 6.5h7v3h-7z', 'M9 13h.01M12 13h.01M15 13h.01M9 16.5h.01M12 16.5h.01M15 16.5h.01'],
    gear: ['M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z', 'M19 12a7 7 0 0 0-.1-1.2l2-1.5-2-3.4-2.3.9a7 7 0 0 0-2.1-1.2L14 3h-4l-.5 2.6a7 7 0 0 0-2.1 1.2l-2.3-.9-2 3.4 2 1.5a7 7 0 0 0 0 2.4l-2 1.5 2 3.4 2.3-.9a7 7 0 0 0 2.1 1.2L10 21h4l.5-2.6a7 7 0 0 0 2.1-1.2l2.3.9 2-3.4-2-1.5c.1-.4.1-.8.1-1.2z'],
    bird: ['M4 17c4 1 9-1 11-5l2.5-1.5L20 11l-2-2.5c-1-2-4-2.5-5.5-.5L11 10C8 10 5.5 8 4.5 6c-.5 3 .5 5.5 3 7-1.5 1-2.5 2.5-3.5 4z'],
    heart: ['M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.4 4.3 4.3 0 0 1 19.5 10C19.5 15.4 12 20 12 20z'],
    mask: ['M4 7c3-1.5 13-1.5 16 0 0 6-3.5 10-8 10S4 13 4 7z', 'M8.5 10.5h2M13.5 10.5h2'],
    car: ['M4.5 15.5l1.4-5A2 2 0 0 1 7.8 9h8.4a2 2 0 0 1 1.9 1.5l1.4 5', 'M3.5 15.5h17v3h-17z', 'M7 18.5v1.5M17 18.5v1.5'],
    mail: ['M4 6.5h16v11H4z', 'M4 7l8 6 8-6'],
    taxi: ['M9 4.5h6l1 2.5', 'M4.5 15.5l1.4-5A2 2 0 0 1 7.8 9h8.4a2 2 0 0 1 1.9 1.5l1.4 5', 'M3.5 15.5h17v3h-17z', 'M7.5 15.5h.01M16.5 15.5h.01'],
    sos: ['M12 3.5l7.5 3v5.5c0 4.4-3.2 7.6-7.5 9-4.3-1.4-7.5-4.6-7.5-9V6.5z', 'M12 8.5v5M12 16.5h.01'],
    house: ['M4 11l8-6.5 8 6.5', 'M6 9.5v10h12v-10', 'M10 19.5v-5h4v5'],
    grid: ['M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z'],
    back: ['M15 5l-7 7 7 7'],
    pin: ['M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z', 'M12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z'],
    shield: ['M12 3.5l7.5 3v5.5c0 4.4-3.2 7.6-7.5 9-4.3-1.4-7.5-4.6-7.5-9V6.5z'],
    cross: ['M9.5 4h5v5.5H20v5h-5.5V20h-5v-5.5H4v-5h5.5z'],
  };

  // ── Catálogo de apps ───────────────────────────────────────────────────
  // path = ruta de npwd (HashRouter); view = app propia.
  const KNOWN = {
    '/phone': { name: 'Llamadas', icon: I.phone, a: '#2fe08a', b: '#0b8f5a' },
    '/messages': { name: 'Mensajes', icon: I.chat, a: '#5ce1ff', b: '#1a7fd6' },
    '/contacts': { name: 'Contactos', icon: I.contacts, a: '#ffb36b', b: '#e0602a' },
    '/marketplace': { name: 'Anuncios', icon: I.megaphone, a: '#ffd76b', b: '#e09a1a' },
    '/camera': { name: 'Cámara', icon: I.camera, a: '#8b93ad', b: '#3b4260' },
    '/notes': { name: 'Notas', icon: I.notes, a: '#fff1a8', b: '#d9b43a' },
    '/calculator': { name: 'Calculadora', icon: I.calc, a: '#9aa6c7', b: '#4a5578' },
    '/settings': { name: 'Ajustes', icon: I.gear, a: '#7b8299', b: '#2d3247' },
    '/twitter': { name: 'Bleeter', icon: I.bird, a: '#6fd0ff', b: '#2a6ad6' },
    '/match': { name: 'Citas', icon: I.heart, a: '#ff7ab8', b: '#d6246e' },
    '/darkchat': { name: 'Darkchat', icon: I.mask, a: '#5a5f73', b: '#151827' },
    '/npwd_qbx_garages': { name: 'Garaje', icon: I.car, a: '#7d8cff', b: '#3b3fd6' },
    '/npwd_qbx_mail': { name: 'Correo', icon: I.mail, a: '#66e3c4', b: '#0f9c86' },
  };
  const OWN = [
    { view: 'taxi', name: 'Taxi', icon: I.taxi, a: '#ffd23f', b: '#e0a100' },
    { view: 'sos', name: 'Emergencias', icon: I.sos, a: '#ff6b6b', b: '#c4142f' },
    { view: 'd8', name: 'Dynasty 8', icon: I.house, a: '#4ade80', b: '#15803d' },
  ];
  const DOCK = ['/messages', '/phone', '/contacts', '/camera'];
  const ORDER = ['/marketplace', 'taxi', 'sos', 'd8', '/npwd_qbx_garages', '/npwd_qbx_mail', '/twitter',
    '/notes', '/calculator', '/match', '/darkchat', '/settings'];

  // Apps que npwd tiene activas: los enlaces de su cuadrícula (oculta).
  function npwdApps() {
    const out = new Map();
    for (const a of doc.querySelectorAll('#notificationAppContainer .MuiGrid-container a[href^="#/"]')) {
      const path = a.getAttribute('href').slice(1);
      const badgeEl = a.querySelector('.MuiBadge-badge');
      const badge = badgeEl && !badgeEl.classList.contains('MuiBadge-invisible') ? badgeEl.textContent : '';
      const avatar = a.querySelector('button div') || a.querySelector('button');
      out.set(path, { path, badge, avatar });
    }
    return out;
  }

  // ── Shell ──────────────────────────────────────────────────────────────
  let shell, homeView, appView, gridEl, dockEl, clockEl, dateEl;
  let currentView = null;
  let lastSignature = '';

  function tile(item, badge, extNode) {
    const btn = el('button', 'pxd-app');
    btn.type = 'button';
    const t = el('div', 'pxd-tile');
    t.style.setProperty('--a', item.a || '#2a335a');
    t.style.setProperty('--b', item.b || '#0f1428');
    if (item.icon) t.appendChild(icon(item.icon));
    else if (extNode) {
      const wrap = el('div', 'pxd-ext');
      wrap.appendChild(extNode.cloneNode(true));
      t.appendChild(wrap);
    }
    if (badge) t.appendChild(el('span', 'pxd-badge', badge));
    btn.append(t, el('span', 'pxd-name', item.name));
    btn.addEventListener('click', () => {
      if (item.view) openView(item.view);
      else location.hash = '#' + item.path;
    });
    return btn;
  }

  function renderHome(force) {
    const apps = npwdApps();
    const sig = [...apps.values()].map((x) => x.path + ':' + x.badge).join('|');
    if (!force && sig === lastSignature) return;
    lastSignature = sig;
    gridEl.replaceChildren();
    dockEl.replaceChildren();
    const used = new Set(DOCK);
    const items = [];
    for (const key of ORDER) {
      if (key.startsWith('/')) {
        if (!apps.has(key)) continue;
        items.push({ ...KNOWN[key], path: key });
        used.add(key);
      } else {
        items.push(OWN.find((o) => o.view === key));
      }
    }
    // Externas desconocidas: icono original de npwd.
    for (const [path, info] of apps) {
      if (used.has(path) || ORDER.includes(path)) continue;
      const name = path.replace(/^\/(npwd_)?(qbx_)?/, '').replace(/_/g, ' ');
      items.push({ path, name: name.charAt(0).toUpperCase() + name.slice(1), ext: info.avatar });
    }
    for (const it of items) {
      const info = it.path ? apps.get(it.path) : null;
      gridEl.appendChild(tile(it, info && info.badge, it.ext && it.ext.firstElementChild));
    }
    for (const path of DOCK) {
      if (!apps.has(path)) continue;
      dockEl.appendChild(tile({ ...KNOWN[path], path }, apps.get(path).badge));
    }
  }

  function tickClock() {
    if (!clockEl) return;
    const d = new Date();
    clockEl.textContent = d.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', hour12: false });
    const date = d.toLocaleDateString('es-MX', { weekday: 'long', day: 'numeric', month: 'long' });
    dateEl.textContent = date.charAt(0).toUpperCase() + date.slice(1);
  }

  function build(phoneEl) {
    shell = el('div', 'pxd-shell');
    homeView = el('div', 'pxd-home-view');
    const clock = el('div', 'pxd-clock');
    clockEl = el('b');
    dateEl = el('span');
    clock.append(clockEl, dateEl);
    gridEl = el('div', 'pxd-grid');
    dockEl = el('div', 'pxd-dock');
    homeView.append(clock, gridEl, dockEl);
    appView = el('div', 'pxd-appview');
    shell.append(homeView, appView);
    phoneEl.appendChild(shell);
    tickClock();
    renderHome(true);
  }

  // Coloca la capa sobre el área de apps de npwd (entre barra de estado y navegación).
  function place() {
    const phoneEl = doc.getElementById('phone');
    if (!phoneEl) return;
    if (!shell || !phoneEl.contains(shell)) build(phoneEl);
    const area = doc.getElementById('notificationAppContainer');
    if (area) {
      shell.style.top = area.offsetTop + 'px';
      shell.style.height = area.offsetHeight + 'px';
    }
    const home = location.hash === '' || location.hash === '#/' || location.hash === '#';
    doc.documentElement.classList.toggle('pxd-home', home && !currentView);
    if (!home && currentView) closeView();
    if (home && !currentView) renderHome(false);
  }

  // ── Vistas propias ─────────────────────────────────────────────────────
  let pollTimer = null;
  function openView(view) {
    currentView = view;
    shell.classList.add('is-app');
    doc.documentElement.classList.remove('pxd-home');
    appView.replaceChildren();
    const meta = OWN.find((o) => o.view === view);
    const bar = el('div', 'pxd-bar');
    const back = el('button', 'pxd-back');
    back.type = 'button';
    back.setAttribute('aria-label', 'Volver');
    back.appendChild(icon(I.back));
    back.addEventListener('click', closeView);
    const title = el('div');
    title.append(el('h2', null, meta.name), el('small', null, SUB[view]));
    bar.append(back, title);
    const body = el('div', 'pxd-body');
    appView.append(bar, body);
    VIEWS[view](body);
  }
  function closeView() {
    currentView = null;
    clearInterval(pollTimer);
    pollTimer = null;
    if (shell) shell.classList.remove('is-app');
    place();
  }
  const SUB = { d8: 'Inmobiliaria de Los Santos', sos: 'Policía y servicios médicos', taxi: 'Downtown Cab Co.' };

  function message(parent, text, isError) {
    let box = parent.querySelector(':scope > .pxd-msg');
    if (!box) { box = el('div', 'pxd-msg'); parent.appendChild(box); }
    box.className = 'pxd-msg' + (isError ? ' is-error' : '');
    box.textContent = text;
  }

  const VIEWS = {
    // Dynasty 8: propiedades en venta y las mías (qbx_properties).
    d8(body) {
      const tabs = el('div', 'pxd-tabs');
      const list = el('div');
      let data = null;
      let tab = 'sale';
      const show = () => {
        list.replaceChildren();
        if (!data) { list.appendChild(el('div', 'pxd-empty', 'Cargando…')); return; }
        if (data.error) { list.appendChild(el('div', 'pxd-empty', data.error)); return; }
        const rows = tab === 'sale' ? data.sale : data.mine;
        if (!rows || !rows.length) {
          list.appendChild(el('div', 'pxd-empty', tab === 'sale' ? 'Ahora no hay propiedades disponibles.' : 'Todavía no tienes propiedades.'));
          return;
        }
        for (const p of rows) {
          const card = el('div', 'pxd-card');
          card.appendChild(el('h3', null, p.name));
          const chip = el('span', 'pxd-chip' + (p.rentHours ? ' is-rent' : ''),
            p.rentHours ? `Alquiler cada ${p.rentHours} h` : (p.forSale ? 'En venta' : 'Tuya'));
          card.appendChild(chip);
          const row = el('div', 'pxd-row');
          row.appendChild(el('span', 'pxd-price', p.forSale ? money(p.price) : ''));
          const gps = el('button', 'pxd-btn is-ghost', 'Marcar en GPS');
          gps.type = 'button';
          gps.prepend(icon(I.pin));
          gps.querySelector('svg').setAttribute('style', 'width:15px;height:15px;stroke:currentColor;fill:none;stroke-width:2');
          gps.addEventListener('click', async () => {
            gps.disabled = true;
            const r = await post('d8_mark', { id: p.id });
            gps.textContent = r && !r.error ? 'Marcado en el mapa' : (r && r.error) || 'Error';
          });
          row.appendChild(gps);
          card.appendChild(row);
          list.appendChild(card);
        }
      };
      for (const [key, label] of [['sale', 'En venta'], ['mine', 'Mis propiedades']]) {
        const b = el('button', key === tab ? 'is-on' : '', label);
        b.type = 'button';
        b.addEventListener('click', () => {
          tab = key;
          for (const x of tabs.children) x.classList.toggle('is-on', x === b);
          show();
        });
        tabs.appendChild(b);
      }
      body.append(tabs, list);
      show();
      post('d8_list').then((r) => { data = r || { error: 'Sin respuesta.' }; if (currentView === 'd8') show(); });
    },

    // Emergencias: aviso a policía o EMS de servicio con tu ubicación (la pone el servidor).
    sos(body) {
      let service = 'police';
      const choice = el('div', 'pxd-choice');
      for (const [key, label, ic] of [['police', 'Policía', I.shield], ['ems', 'Servicios médicos', I.cross]]) {
        const b = el('button', key === service ? 'is-on' : '');
        b.type = 'button';
        b.append(icon(ic), doc.createTextNode(label));
        b.addEventListener('click', () => {
          service = key;
          for (const x of choice.children) x.classList.toggle('is-on', x === b);
        });
        choice.appendChild(b);
      }
      const field = el('textarea', 'pxd-field');
      field.maxLength = 140;
      field.placeholder = '¿Qué está pasando? (opcional)';
      const hint = el('p', 'pxd-hint', 'Se envía tu ubicación actual a quien esté de servicio. Usa este canal solo para el rol.');
      const send = el('button', 'pxd-btn is-nova is-block', 'Enviar aviso');
      send.type = 'button';
      send.addEventListener('click', async () => {
        send.disabled = true;
        const r = await post('sos_send', { service, text: field.value });
        send.disabled = false;
        if (!r || r.error) return message(body, (r && r.error) || 'No se pudo enviar.', true);
        field.value = '';
        message(body, r.message || 'Aviso enviado.', r.sent === 0);
      });
      body.append(choice, field, hint, send);
    },

    // Taxi: pedir un taxi y, si eres taxista de servicio, ver y aceptar clientes.
    taxi(body) {
      const status = el('div', 'pxd-status');
      const mine = el('div');
      const driver = el('div');
      const field = el('textarea', 'pxd-field');
      field.maxLength = 100;
      field.placeholder = 'Nota para el taxista (opcional): «estoy en la puerta del hospital»';

      const render = (s) => {
        if (currentView !== 'taxi') return;
        if (!s || s.error) { message(body, (s && s.error) || 'Sin respuesta.', true); }
        if (!s || s.error && s.drivers == null) return;
        status.replaceChildren(el('span', 'pxd-dot' + (s.drivers > 0 ? '' : ' is-off')),
          doc.createTextNode(s.drivers > 0 ? `${s.drivers} taxista(s) de servicio` : 'Ningún taxista de servicio'));
        mine.replaceChildren();
        if (s.request) {
          const card = el('div', 'pxd-card');
          card.appendChild(el('h3', null, s.request.status === 'accepted' ? 'Tu taxi va en camino' : 'Buscando taxista…'));
          card.appendChild(el('p', null, s.request.driverName ? `Taxista: ${s.request.driverName}` : 'Te avisaremos cuando alguien acepte.'));
          const cancel = el('button', 'pxd-btn is-ghost', 'Cancelar');
          cancel.type = 'button';
          cancel.addEventListener('click', async () => render(await post('taxi_cancel')));
          const row = el('div', 'pxd-row');
          row.appendChild(cancel);
          card.appendChild(row);
          mine.appendChild(card);
        } else {
          const ask = el('button', 'pxd-btn is-block', 'Pedir un taxi aquí');
          ask.type = 'button';
          ask.disabled = !(s.drivers > 0);
          ask.addEventListener('click', async () => {
            ask.disabled = true;
            render(await post('taxi_request', { text: field.value }));
          });
          mine.append(field, el('p', 'pxd-hint', 'Se envía tu ubicación al taxista que acepte.'), ask);
        }
        driver.replaceChildren();
        if (s.driver) {
          driver.appendChild(el('div', 'pxd-section', 'Clientes esperando'));
          if (!s.pending || !s.pending.length) driver.appendChild(el('div', 'pxd-empty', 'Nadie está pidiendo taxi ahora.'));
          for (const p of s.pending || []) {
            const card = el('div', 'pxd-card');
            card.appendChild(el('h3', null, `Cliente #${p.id}`));
            card.appendChild(el('p', null, p.text || 'Sin nota.'));
            const row = el('div', 'pxd-row');
            row.appendChild(el('span', 'pxd-chip', `Hace ${Math.max(1, Math.round(p.ageSec / 60))} min`));
            const ok = el('button', 'pxd-btn', 'Aceptar');
            ok.type = 'button';
            ok.addEventListener('click', async () => {
              ok.disabled = true;
              const r = await post('taxi_accept', { id: p.id });
              render(r);
              if (r && !r.error) message(body, 'Cliente aceptado: tienes la ruta en el GPS.');
            });
            row.appendChild(ok);
            card.appendChild(row);
            driver.appendChild(card);
          }
        }
      };
      body.append(status, mine, driver);
      const refresh = async () => render(await post('taxi_state'));
      refresh();
      pollTimer = setInterval(refresh, 5000);
    },
  };

  // ── Arranque ───────────────────────────────────────────────────────────
  // Cerrar la vista propia si se pulsa la barra de navegación de npwd.
  doc.addEventListener('click', (e) => {
    if (!currentView) return;
    const phoneEl = doc.getElementById('phone');
    const nav = phoneEl && phoneEl.lastElementChild;
    if (nav && nav !== shell && nav.contains(e.target)) closeView();
  }, true);
  let scheduled = false;
  const schedule = () => {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => { scheduled = false; place(); });
  };
  window.addEventListener('hashchange', place);
  new MutationObserver(schedule).observe(doc.body, { childList: true, subtree: true });
  setInterval(() => { tickClock(); place(); }, 1000);
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', place); else place();
})();
