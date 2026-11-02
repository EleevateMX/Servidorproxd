// pxd_restart — avisos de reinicio. Texto siempre con textContent.
(() => {
  const $ = (id) => document.getElementById(id);
  const RING = 339.3;
  const ICONS = {
    save: 'M5 4h11l3 3v13H5zM8 4v5h7V4M8 20v-6h8v6',
    wait: 'M12 7v5l3 2M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z',
    join: 'M10 17l5-5-5-5M15 12H3M14 4h5v16h-5',
  };
  let toastTimer = null;
  let countTimer = null;

  function toast(text) {
    const el = $('toast');
    $('toast-text').textContent = text;
    el.classList.remove('hidden');
    el.style.animation = 'none'; void el.offsetWidth; el.style.animation = '';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.add('hidden'), 9000);
  }

  function steps(list) {
    const ol = $('steps');
    ol.replaceChildren();
    for (const s of list || []) {
      const li = document.createElement('li');
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('viewBox', '0 0 24 24');
      const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      p.setAttribute('d', ICONS[s.icon] || ICONS.wait);
      svg.appendChild(p);
      const b = document.createElement('b'); b.textContent = s.title || '';
      const span = document.createElement('span'); span.textContent = s.text || '';
      li.append(svg, b, span);
      ol.appendChild(li);
    }
  }

  function screen(msg) {
    $('title').textContent = `${msg.serverName || 'PRÓXIMA RP'} se está reiniciando`;
    steps(msg.steps);
    $('toast').classList.add('hidden');
    $('screen').classList.remove('hidden');
    const total = Math.max(1, Number(msg.seconds) || 0);
    const end = Date.now() + (Number(msg.seconds) || 0) * 1000;
    clearInterval(countTimer);
    const tick = () => {
      const left = Math.max(0, Math.round((end - Date.now()) / 1000));
      $('count').textContent = left > 0 ? `Reinicio en ${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}` : 'Reiniciando…';
      $('ring').style.strokeDashoffset = String(RING * (1 - left / total));
      if (left <= 0) clearInterval(countTimer);
    };
    tick();
    countTimer = setInterval(tick, 1000);
  }

  function cancel() {
    clearInterval(countTimer);
    $('screen').classList.add('hidden');
    toast('Reinicio cancelado. ¡Sigue jugando!');
  }

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'toast') toast(String(m.text || ''));
    else if (m.action === 'screen') screen(m);
    else if (m.action === 'cancel') cancel();
  });

  // Vista previa: index.html?demo=screen | toast
  const demo = new URLSearchParams(location.search).get('demo');
  if (demo) {
    document.body.style.background = '#2a2f3a';
    const steps = [
      { icon: 'save', title: 'Guarda lo que hacías', text: 'Termina tu rol en un sitio seguro.' },
      { icon: 'wait', title: 'Espera un minuto', text: 'La ciudad vuelve enseguida.' },
      { icon: 'join', title: 'Vuelve a entrar', text: 'Búscanos en FiveM o en Recientes.' },
    ];
    if (demo === 'toast') toast('La ciudad se reinicia en 5 minutos.');
    else screen({ seconds: 42, serverName: 'PRÓXIMA RP', steps });
  }
})();
