/* Próxima RP — paneles extra para la interfaz de ox_inventory (GPL-3.0).
 * Barra superior (nombre, ID, dinero), ranuras de ropa alrededor del personaje y
 * signos vitales. Los datos los da el recurso pxd_inventory por callbacks NUI
 * (https://pxd_inventory/...). Si no responde, solo queda el estilo nuevo.
 * Texto siempre con textContent. */
(function () {
  'use strict';
  var RES = 'pxd_inventory';
  var STAR = 'M80 12 C85 62 98 75 148 80 C98 85 85 98 80 148 C75 98 62 85 12 80 C62 75 75 62 80 12Z';
  var ICONS = {
    hat: 'M4 15h16M6 15c0-5 2.5-8 6-8s6 3 6 8M9 7.5c.8-1.2 1.8-2 3-2s2.2.8 3 2',
    mask: 'M4 8c3-2 13-2 16 0 0 6-3 10-8 10S4 14 4 8zM8 11h2.5M13.5 11H16',
    top: 'M8 4l-4 3 2 4 2-1v10h8V10l2 1 2-4-4-3c-.5 1.5-2 2.5-4 2.5S8.5 5.5 8 4z',
    pants: 'M7 3h10l1 18h-4l-2-11-2 11H6L7 3z',
    shoes: 'M3 16h18v3H3zM4 16l1-6h4l2 3 6 1c2 .3 3 1 3 2',
    ears: 'M9 4a5 5 0 0 1 8 4c0 3-3 4-3 7a3 3 0 0 1-6 0M10 9a2 2 0 0 1 4 0',
    glasses: 'M3 11h4l1 4H4zM13 11h4l1 4h-4zM8 12h4',
    neck: 'M6 4c0 6 2.5 10 6 10s6-4 6-10M12 14v3M10.5 17h3l-1.5 3z',
    watch: 'M9 3h6l1 4H8zM8 17h8l-1 4H9zM12 9.5V12l1.5 1M7 12a5 5 0 1 0 10 0 5 5 0 0 0-10 0',
    bracelet: 'M5 12a7 4 0 1 0 14 0 7 4 0 1 0-14 0M8 9.5v.1M12 8.5v.1M16 9.5v.1',
    bag: 'M7 8V6a5 5 0 0 1 10 0v2M5 8h14l-1 13H6zM9 13h6',
    under: 'M9 4h6l1 3 2 1v12H6V8l2-1zM9 4c0 1.5 1.3 2.5 3 2.5S15 5.5 15 4',
    vest: 'M8 3l4 3 4-3 3 3v14h-5l-2-3-2 3H5V6zM12 6v11',
    decal: 'M12 3l2.5 5 5.5.8-4 3.9.9 5.5L12 15.6 7.1 18.2l.9-5.5-4-3.9 5.5-.8z',
  };
  var VITALS = [
    { id: 'hunger', label: 'Comida', color: '#ffc857', d: 'M7 3v8M5 3v5a2 2 0 0 0 4 0V3M7 11v10M16 21V3c-2 0-3 3-3 7h3' },
    { id: 'thirst', label: 'Bebida', color: '#5ce1ff', d: 'M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11z' },
    { id: 'health', label: 'Salud', color: '#ff5a6e', d: 'M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z' },
    { id: 'armour', label: 'Armadura', color: '#9aa6c7', d: 'M12 3l7 3v6c0 4-3 7-7 9-4-2-7-5-7-9V6z' },
    { id: 'stress', label: 'Estrés', color: '#ff4fd8', d: 'M13 3L5 13h6l-1 8 8-10h-6z' },
  ];

  var ui = null;
  var timer = null;
  var busy = false;

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined) n.textContent = text;
    return n;
  }
  function svg(d, viewBox) {
    var ns = 'http://www.w3.org/2000/svg';
    var s = document.createElementNS(ns, 'svg');
    s.setAttribute('viewBox', viewBox || '0 0 24 24');
    var p = document.createElementNS(ns, 'path');
    p.setAttribute('d', d);
    s.appendChild(p);
    return s;
  }
  function money(n) { return '$' + Math.max(0, Math.floor(Number(n) || 0)).toLocaleString('en-US'); }

  function post(name, body) {
    // text/plain evita la petición previa de CORS; FiveM interpreta el cuerpo como JSON.
    return fetch('https://' + RES + '/' + name, { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: JSON.stringify(body || {}) })
      .then(function (r) { return r.json(); });
  }

  function build() {
    var layer = el('div'); layer.id = 'pxd-layer';
    layer.appendChild(el('div', 'pxd-shade'));
    document.body.appendChild(layer);

    var root = el('div'); root.id = 'pxd-ui';
    root.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:2;opacity:0;transition:opacity .2s ease';

    var top = el('header', 'pxd-top');
    var brand = el('div', 'pxd-brand');
    var star = svg(STAR, '0 0 160 160');
    brand.append(star, el('span', null, 'Inventario'), el('small', null, 'Arrastra para mover · clic derecho para opciones'));
    var who = el('div', 'pxd-who');
    var name = el('b', null, '');
    var pid = el('span', 'pxd-chip', '');
    who.append(name, pid);
    var moneyBox = el('div', 'pxd-money');
    var cash = el('span', 'cash'); cash.append(el('i'), el('em', null, '$0'));
    var bank = el('span', 'bank'); bank.append(el('i'), el('em', null, '$0'));
    cash.lastChild.style.fontStyle = bank.lastChild.style.fontStyle = 'normal';
    moneyBox.append(cash, bank);
    var esc = el('div', 'pxd-esc'); esc.append(el('kbd', null, 'Esc'), el('span', null, 'Cerrar'));
    top.append(brand, who, moneyBox, esc);

    var char = el('aside', 'pxd-char');
    var stage = el('div', 'pxd-stage');
    stage.appendChild(el('div', 'pxd-stage-note', 'Clic en una prenda para quitártela o ponértela'));
    var left = el('div', 'pxd-rail left');
    var right = el('div', 'pxd-rail right');
    var bottom = el('div', 'pxd-rail bottom');
    stage.append(left, right, bottom);
    var vitals = el('section', 'pxd-vitals');
    var h = el('h3', null, 'Signos vitales'); h.appendChild(el('small', null, 'Cómo está tu personaje'));
    vitals.appendChild(h);
    var bars = {};
    VITALS.forEach(function (v) {
      var row = el('div', 'pxd-vital');
      var icon = svg(v.d); icon.style.stroke = v.color;
      var bar = el('div', 'bar'); var fill = el('i'); fill.style.background = v.color; bar.appendChild(fill);
      var val = el('span'); var b = el('b', null, '—'); val.append(b, document.createTextNode(' / 100'));
      row.title = v.label;
      row.append(icon, bar, val);
      vitals.appendChild(row);
      bars[v.id] = { row: row, fill: fill, value: b };
    });
    char.append(stage, vitals);

    var notices = el('aside', 'pxd-notices');
    var nh = el('h3', null, 'Notificaciones');
    var clear = el('button', null, 'Limpiar todas'); clear.type = 'button';
    clear.addEventListener('click', function () { post('clearNotices').then(render).catch(function () {}); });
    nh.appendChild(clear);
    var list = el('div', 'pxd-notice-list');
    notices.append(nh, list);

    root.append(top, char, notices);
    document.body.appendChild(root);
    ui = { root: root, name: name, pid: pid, cash: cash.lastChild, bank: bank.lastChild, left: left, right: right, bottom: bottom,
      bars: bars, slots: {}, stage: stage, list: list, clear: clear };
  }

  function ago(at, now) {
    var s = Math.max(0, (Number(now) || 0) - (Number(at) || 0));
    if (!at || !now) return '';
    if (s < 60) return 'Hace un momento';
    if (s < 3600) return 'Hace ' + Math.floor(s / 60) + ' min';
    return 'Hace ' + Math.floor(s / 3600) + ' h';
  }

  function renderNotices(list, now) {
    ui.list.replaceChildren();
    ui.clear.style.visibility = list.length ? '' : 'hidden';
    if (!list.length) {
      var empty = el('div', 'pxd-empty');
      empty.append(svg(STAR, '0 0 160 160'), document.createTextNode('Sin notificaciones'));
      ui.list.appendChild(empty);
      return;
    }
    list.forEach(function (n) {
      var kind = ['success', 'error', 'warning'].indexOf(n.kind) >= 0 ? n.kind : 'inform';
      var card = el('div', 'pxd-notice ' + kind);
      if (n.title) card.appendChild(el('b', null, n.title));
      if (n.text) card.appendChild(el('p', null, n.text));
      var when = ago(n.at, now);
      if (when) card.appendChild(el('small', null, when));
      ui.list.appendChild(card);
    });
  }

  // Contador «usadas/total» de ranuras del inventario del jugador (la primera cuadrícula).
  function countSlots() {
    var grid = document.querySelector('.inventory-wrapper .inventory-grid-wrapper');
    if (!grid) return;
    var head = grid.querySelector('.inventory-grid-header-wrapper');
    var total = grid.querySelectorAll('.inventory-slot').length;
    var used = grid.querySelectorAll('.inventory-slot .item-slot-wrapper').length;
    var chip = head && head.querySelector('.pxd-slots');
    if (head && !chip) { chip = el('span', 'pxd-slots'); head.insertBefore(chip, head.lastChild); }
    var text = used + '/' + total;
    if (chip && chip.textContent !== text) chip.textContent = text;
  }

  function clothSlot(c) {
    var s = ui.slots[c.id];
    if (!s) {
      s = el('button', 'pxd-cloth');
      s.type = 'button';
      s.appendChild(svg(ICONS[c.icon] || ICONS.top));
      s.appendChild(el('span', 'pxd-tip', c.label || c.id));
      s.addEventListener('click', function () {
        if (busy) return;
        busy = true;
        post('toggleClothing', { id: c.id }).then(render).catch(function () {}).then(function () { busy = false; });
      });
      (c.side === 'right' ? ui.right : c.side === 'bottom' ? ui.bottom : ui.left).appendChild(s);
      ui.slots[c.id] = s;
    }
    s.className = 'pxd-cloth ' + (c.on ? 'on' : 'off');
    s.lastChild.textContent = (c.label || c.id) + (c.on ? ' · quitar' : ' · poner');
    return s;
  }

  function render(d) {
    if (!d || typeof d !== 'object') return;
    ui.root.dataset.ready = '1';
    ui.name.textContent = d.name || '';
    ui.pid.textContent = d.id || '';
    ui.pid.style.display = d.id ? '' : 'none';
    ui.cash.textContent = money(d.cash);
    ui.bank.textContent = money(d.bank);
    var v = d.vitals || {};
    VITALS.forEach(function (x) {
      var n = Math.max(0, Math.min(100, Math.round(Number(v[x.id]) || 0)));
      var b = ui.bars[x.id];
      b.fill.style.width = n + '%';
      b.value.textContent = String(n);
      var low = x.id === 'stress' ? n >= 70 : x.id !== 'armour' && n <= 20;
      b.row.className = 'pxd-vital' + (low ? ' low' : '');
    });
    var clothes = Array.isArray(d.clothing) ? d.clothing : [];
    ui.left.style.display = ui.right.style.display = ui.bottom.style.display = d.canChange === false ? 'none' : '';
    clothes.forEach(clothSlot);
    renderNotices(Array.isArray(d.notices) ? d.notices : [], d.now);
  }

  function refresh() { post('state').then(render).catch(function () { ui.root.dataset.ready = ''; }); }

  function setOpen(open) {
    if (!ui) return;
    document.body.classList.toggle('pxd-open', open);
    ui.root.style.opacity = open ? '1' : '0';
    clearInterval(timer);
    if (open) { refresh(); timer = setInterval(refresh, 1500); }
  }

  function start() {
    build();
    // ox_inventory monta .inventory-wrapper solo mientras está abierto (CSSTransition unmountOnExit).
    var open = false;
    var counting = false;
    new MutationObserver(function () {
      var now = !!document.querySelector('.inventory-wrapper');
      if (now !== open) { open = now; setOpen(open); }
      if (open && !counting) { counting = true; requestAnimationFrame(function () { countSlots(); counting = false; }); }
    }).observe(document.body, { childList: true, subtree: true });
    window.PXDInventory = { render: render, setOpen: setOpen }; // para la vista previa
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
