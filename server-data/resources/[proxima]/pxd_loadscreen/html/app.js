// Pantalla de carga de Próxima RP.
// Datos del servidor: window.nuiHandoverData (pxd_login: name/firstTime; pxd_loadscreen: pxd = {...}).
// Medios opcionales en assets/: background.mp4, keyart.png, slide-*.png, ciudad-*.png,
// bienvenida.mp3 (voz), music.mp3 (radio). Lo que no exista simplemente no se muestra.
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const params = new URLSearchParams(location.search);
  const demo = params.has('demo');
  const hand = window.nuiHandoverData || {};
  const data = hand.pxd || (demo ? {
    players: 37, maxPlayers: 48, discord: 'https://discord.gg/ejemplo', radioName: 'PRÓXIMA FM',
    socials: { web: 'https://ejemplo.com', instagram: 'x', youtube: 'x', tiktok: 'x' },
    mediaHint: 'Comparte tus fotos en #media de nuestro Discord',
    news: [
      { tag: 'Reglamento', title: 'Lee las normas de la ciudad antes de rolear', image: 'slide-policia.png' },
      { tag: 'Comunidad', title: 'Únete a nuestro Discord oficial', image: 'slide-barrio.png' },
      { tag: 'Modos de juego', title: 'Pulsa F7: deathmatch, rey de la colina y carreras', image: 'slide-taller.png' },
    ],
  } : {});
  const name = hand.name || (demo ? 'Edy' : '');

  // Abrir enlaces: dentro de FiveM con invokeNative('openUrl'); fuera, en otra pestaña.
  const openUrl = (url) => {
    if (!url) return;
    if (typeof window.invokeNative === 'function') window.invokeNative('openUrl', url);
    else window.open(url, '_blank', 'noopener');
  };

  // ── Cabecera ────────────────────────────────────────
  if (name) $('welcome').textContent = hand.firstTime ? `Bienvenido/a, ${name}` : `De vuelta en la ciudad, ${name}`;
  $('online').textContent = Number.isFinite(data.players) ? `${data.players}/${data.maxPlayers ?? '—'}` : '—';
  if (data.mediaHint) $('hint').textContent = data.mediaHint;
  if (data.radioName) $('radio-name').textContent = data.radioName;

  // ── Fondo: vídeo + carrusel de imágenes que existan ─
  const CANDIDATES = ['keyart.png', 'ciudad-1.png', 'slide-barrio.png', 'ciudad-2.png', 'slide-policia.png',
    'ciudad-3.png', 'slide-taller.png', 'ciudad-4.png', 'slide-emergencias.png'];
  const shown = [];
  const video = $('bg-video');
  video.addEventListener('loadeddata', () => { video.play().catch(() => {}); shown.unshift({ el: video }); start(); });
  video.addEventListener('error', () => video.remove());
  for (const file of CANDIDATES) {
    const img = new Image();
    img.alt = '';
    img.addEventListener('load', () => { $('slides').append(img); shown.push({ el: img }); start(); });
    img.src = `assets/${file}`;
  }
  let bgIndex = -1;
  let bgTimer = null;
  function nextBg() {
    if (!shown.length) return;
    shown.forEach((s) => s.el.classList.remove('is-on'));
    bgIndex = (bgIndex + 1) % shown.length;
    shown[bgIndex].el.classList.add('is-on');
  }
  function start() {
    if (bgTimer) return;
    nextBg();
    bgTimer = setInterval(nextBg, 9000);
  }

  // ── Avisos ──────────────────────────────────────────
  const news = Array.isArray(data.news) ? data.news.filter((n) => n && n.title) : [];
  let newsIndex = 0;
  function renderNews() {
    const box = $('news');
    if (!news.length) { box.classList.add('hidden'); return; }
    const n = news[newsIndex];
    $('news-tag').textContent = n.tag || '';
    $('news-title').textContent = n.title;
    const safe = typeof n.image === 'string' && /^[\w.-]+$/.test(n.image) ? n.image : '';
    $('news-bg').style.backgroundImage = safe ? `url("assets/${safe}"), linear-gradient(135deg, #1c2647, #3a1747)` : 'linear-gradient(135deg, #1c2647, #3a1747)';
    box.style.cursor = n.url ? 'pointer' : 'default';
    $('news-dots').replaceChildren(...news.map((_, i) => {
      const d = document.createElement('span');
      if (i === newsIndex) d.className = 'is-on';
      return d;
    }));
  }
  $('news').addEventListener('click', () => openUrl(news[newsIndex]?.url));
  renderNews();
  if (news.length > 1) setInterval(() => { newsIndex = (newsIndex + 1) % news.length; renderNews(); }, 6000);

  // ── Discord y redes ─────────────────────────────────
  if (data.discord) {
    $('discord').classList.remove('hidden');
    $('discord').addEventListener('click', () => openUrl(data.discord));
  }
  const ICONS = {
    web: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18"/>',
    instagram: '<rect x="4" y="4" width="16" height="16" rx="5"/><circle cx="12" cy="12" r="3.5"/><circle cx="17" cy="7" r=".6"/>',
    youtube: '<rect x="3" y="6" width="18" height="12" rx="4"/><path d="M10 9.5v5l4.5-2.5z"/>',
    tiktok: '<path d="M14 4v10.5a3.5 3.5 0 1 1-3-3.46M14 4c.5 2.5 2 4 5 4.2"/>',
  };
  const LABELS = { web: 'Web', instagram: 'Instagram', youtube: 'YouTube', tiktok: 'TikTok' };
  for (const key of Object.keys(ICONS)) {
    const url = data.socials?.[key];
    if (!url) continue;
    const b = document.createElement('button');
    b.setAttribute('aria-label', LABELS[key]);
    b.title = LABELS[key];
    b.innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true">${ICONS[key]}</svg>`; // contenido fijo, no del usuario
    b.addEventListener('click', () => openUrl(url));
    $('socials').append(b);
  }

  // ── Radio: música si existe; si no, la voz de bienvenida ─
  const music = $('music');
  const voice = $('voice');
  let source = null;
  const volKey = 'pxd_volume';
  let vol = 35;
  try { const v = localStorage.getItem(volKey); if (v !== null) vol = Number(v); } catch { /* sin almacenamiento */ }
  $('volume').value = vol;
  const applyVolume = () => { const v = $('volume').value / 100; music.volume = v; voice.volume = Math.min(1, v + 0.25); };
  applyVolume();
  $('volume').addEventListener('input', () => {
    applyVolume();
    try { localStorage.setItem(volKey, $('volume').value); } catch { /* sin almacenamiento */ }
  });
  const setPlaying = (on) => $('play').classList.toggle('is-playing', on);
  music.addEventListener('canplaythrough', () => { source = music; music.play().then(() => setPlaying(true)).catch(() => {}); }, { once: true });
  music.addEventListener('error', () => {
    if (source) return;
    source = voice;
    voice.addEventListener('canplaythrough', () => voice.play().then(() => setPlaying(true)).catch(() => {}), { once: true });
    voice.addEventListener('ended', () => setPlaying(false));
    voice.load();
  });
  $('play').addEventListener('click', () => {
    if (!source) return;
    if (source.paused) source.play().then(() => setPlaying(true)).catch(() => {});
    else { source.pause(); setPlaying(false); }
  });
  function fadeAudio() {
    const step = setInterval(() => {
      for (const a of [music, voice]) a.volume = Math.max(0, a.volume - 0.08);
      if (music.volume === 0 && voice.volume === 0) { music.pause(); voice.pause(); clearInterval(step); }
    }, 60);
  }

  // ── Consejos ────────────────────────────────────────
  const tips = [
    'F7 abre los modos de juego. Al terminar vuelves justo donde estabas.',
    'Rol ante todo: actúa como lo haría tu personaje.',
    'Lo que sabes fuera del personaje, tu personaje no lo sabe.',
    'Usa /salirmodo para dejar una partida en cualquier momento.',
  ];
  let tipIndex = Math.floor(Math.random() * tips.length);
  const showTip = () => { $('tip').textContent = tips[tipIndex++ % tips.length]; };
  showTip();
  setInterval(showTip, 8000);

  // ── Progreso real ───────────────────────────────────
  const C = 100.53;
  let shownPct = 0;
  function setProgress(fraction) {
    const pct = Math.max(shownPct, Math.min(100, Math.round(fraction * 100)));
    shownPct = pct;
    $('ring').style.strokeDashoffset = String(C * (1 - pct / 100));
    $('percent').textContent = `${pct}%`;
    $('percent').setAttribute('aria-valuenow', String(pct));
  }
  const STAGES = {
    startInitFunction: 'Iniciando el juego…',
    startDataFileEntries: 'Cargando datos del mapa…',
    performMapLoadFunction: 'Cargando la ciudad…',
    endInitFunction: 'Casi listo…',
  };
  const handlers = {
    loadProgress: (d) => setProgress(d.loadFraction || 0),
    'pxd:status': (d) => { $('status').textContent = d.text; },
    'pxd:closing': () => { setProgress(1); $('transition').classList.add('is-on'); fadeAudio(); },
  };
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (STAGES[d.eventName]) $('status').textContent = STAGES[d.eventName];
    handlers[d.eventName]?.(d);
  });

  if (demo) {
    let f = 0;
    const t = setInterval(() => { f += 0.05; setProgress(f); if (f >= 0.59) clearInterval(t); }, 50);
    $('status').textContent = STAGES.performMapLoadFunction;
    if (params.has('transition')) $('transition').classList.add('is-on');
  }
})();
