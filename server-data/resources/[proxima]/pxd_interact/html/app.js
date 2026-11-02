// pxd_interact — aviso «E · acción» y avisos cortos. Texto siempre con textContent.
(() => {
  const $ = (id) => document.getElementById(id);
  const SVG = 'http://www.w3.org/2000/svg';
  const ICONS = {
    hand: 'M8 13V5.5a1.5 1.5 0 0 1 3 0V12M11 11V4.5a1.5 1.5 0 0 1 3 0V12M14 11.5V6a1.5 1.5 0 0 1 3 0v8a6 6 0 0 1-6 6h-1a6 6 0 0 1-4.6-2.2L3 14.5a1.5 1.5 0 0 1 2.3-1.9L8 15',
    handshake: 'M3 12l4-4 4 2 3-2 7 6M7 8l-4 4 5 5 2-2M14 8l3 3M11 14l2 2M13 12l2 2',
    chat: 'M4 5h16v10H9l-5 4z',
    box: 'M3 7l9-4 9 4-9 4-9-4zM3 7v10l9 4 9-4V7M12 11v10',
    briefcase: 'M4 8h16v11H4zM9 8V5h6v3M4 13h16',
    door: 'M6 3h10v18H6zM13 12h.01',
    eye: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
    car: 'M5 16h14M6 16l1.5-5h9L18 16M7 19a1 1 0 1 0 0-2 1 1 0 0 0 0 2zM17 19a1 1 0 1 0 0-2 1 1 0 0 0 0 2z',
    check: 'M5 12l4 4 10-10',
    close: 'M6 6l12 12M18 6L6 18',
    star: 'M12 3l2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5z',
  };
  const STAR = 'M80 12 C85 62 98 75 148 80 C98 85 85 98 80 148 C75 98 62 85 12 80 C62 75 75 62 80 12Z';

  function icon(name) {
    const svg = document.createElementNS(SVG, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('class', 'icon');
    const p = document.createElementNS(SVG, 'path');
    p.setAttribute('d', ICONS[name] || ICONS.hand);
    svg.appendChild(p);
    return svg;
  }

  let keyLabel = 'E';
  function renderOptions(list, selected) {
    const ol = $('options');
    ol.replaceChildren();
    list.forEach((o, i) => {
      const li = document.createElement('li');
      li.className = 'opt' + (i + 1 === selected ? ' is-on' : '');
      const k = document.createElement('span'); k.className = 'key'; k.textContent = keyLabel;
      const l = document.createElement('span'); l.className = 'label'; l.textContent = String(o.label || '');
      li.append(k, icon(o.icon), l);
      ol.appendChild(li);
    });
    $('hint').classList.toggle('hidden', list.length < 2);
    $('prompt').classList.remove('hidden');
  }

  function select(selected) {
    [...$('options').children].forEach((li, i) => li.classList.toggle('is-on', i + 1 === selected));
  }

  function toast(text) {
    const el = document.createElement('div');
    el.className = 'toast';
    const svg = document.createElementNS(SVG, 'svg'); svg.setAttribute('viewBox', '0 0 160 160');
    const p = document.createElementNS(SVG, 'path'); p.setAttribute('d', STAR); svg.appendChild(p);
    const span = document.createElement('span'); span.textContent = text;
    el.append(svg, span);
    $('toasts').appendChild(el);
    while ($('toasts').children.length > 3) $('toasts').firstChild.remove();
    setTimeout(() => el.classList.add('is-out'), 4200);
    setTimeout(() => el.remove(), 4600);
  }

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'options') { keyLabel = String(m.key || 'E').toUpperCase().slice(0, 3); renderOptions(m.list || [], m.selected || 1); }
    else if (m.action === 'select') select(m.selected);
    else if (m.action === 'hide') $('prompt').classList.add('hidden');
    else if (m.action === 'pressed') {
      const on = $('options').querySelector('.is-on');
      if (on) { on.classList.add('is-pressed'); setTimeout(() => on.classList.remove('is-pressed'), 150); }
    }
    else if (m.action === 'notify') toast(String(m.text || ''));
  });

  // Vista previa: index.html?demo=1 (una opción) | ?demo=many | ?demo=invite
  const demo = new URLSearchParams(location.search).get('demo');
  if (demo) {
    document.body.style.background = '#2a2f3a';
    const post = (data) => window.postMessage(data, '*');
    if (demo === 'many') {
      post({ action: 'options', key: 'E', selected: 2, list: [
        { label: 'Darse de alta: Minero', icon: 'briefcase' },
        { label: 'Dejar el trabajo de Minero', icon: 'close' },
        { label: 'Presentarse', icon: 'handshake' },
      ] });
    } else if (demo === 'invite') {
      post({ action: 'options', key: 'E', selected: 1, list: [
        { label: 'Aceptar presentación de PROX-7KQ2', icon: 'handshake' },
        { label: 'Ignorar', icon: 'close' },
      ] });
      post({ action: 'notify', text: 'PROX-7KQ2 quiere presentarse.' });
    } else {
      post({ action: 'options', key: 'E', selected: 1, list: [{ label: 'Recoger', icon: 'hand' }] });
    }
  }
})();
