// Pantalla de carga de Próxima RP: progreso real (loadProgress), datos de handover,
// consejos rotativos y medios opcionales (vídeo/imagen/voz de assets/).
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const demo = new URLSearchParams(location.search).has('demo');
  const handover = window.nuiHandoverData || (demo ? { name: 'Nova' } : {});

  // Medios opcionales: si no existen, se queda el cielo CSS.
  const video = $('bg-video');
  const image = $('bg-image');
  video.addEventListener('loadeddata', () => { video.classList.remove('hidden'); image.classList.add('hidden'); });
  video.addEventListener('error', () => video.remove());
  image.addEventListener('load', () => { if (video.classList.contains('hidden')) image.classList.remove('hidden'); });
  image.addEventListener('error', () => image.remove());

  if (handover.name) $('welcome').textContent = `Bienvenido/a, ${handover.name}`;
  if (handover.firstTime) $('status').textContent = 'Preparando tu primera llegada…';

  // Consejos (sin promesas ni novedades: solo cómo funciona el servidor).
  const tips = [
    'Pulsa F7 para abrir los modos de juego: todos contra todos, por equipos, rey de la colina y carreras.',
    'Las partidas se juegan en un mundo aparte: al terminar vuelves justo donde estabas.',
    'Rol primero: actúa como lo haría tu personaje y respeta el rol de los demás.',
    'Nada de metagaming: lo que ves fuera del personaje no lo sabe tu personaje.',
    'El staff diseña escenarios con el editor de props (F6). Si tienes una idea, propónla.',
    'Usa /salirmodo si quieres abandonar una partida en cualquier momento.',
  ];
  let tipIndex = Math.floor(Math.random() * tips.length);
  const showTip = () => {
    const p = $('tip');
    p.style.opacity = 0;
    setTimeout(() => { p.textContent = tips[tipIndex % tips.length]; p.style.opacity = 1; tipIndex++; }, 350);
  };
  showTip();
  setInterval(showTip, 7000);

  // Progreso
  let shown = 0;
  const setProgress = (fraction) => {
    const pct = Math.max(shown, Math.min(100, Math.round(fraction * 100)));
    shown = pct;
    $('bar-fill').style.width = `${pct}%`;
    $('bar').setAttribute('aria-valuenow', String(pct));
    $('percent').textContent = `${pct}%`;
  };

  const STAGES = {
    startInitFunction: 'Iniciando el juego…',
    startDataFileEntries: 'Cargando datos del mapa…',
    performMapLoadFunction: 'Cargando la ciudad…',
    endInitFunction: 'Casi listo…',
  };

  const handlers = {
    loadProgress: (d) => setProgress(d.loadFraction || 0),
    onLogLine: (d) => { $('log').textContent = d.message || ''; },
    'pxd:status': (d) => { $('status').textContent = d.text; },
    'pxd:closing': () => { setProgress(1); document.body.classList.add('closing'); fadeVoice(); },
  };
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (STAGES[d.eventName]) $('status').textContent = STAGES[d.eventName];
    const h = handlers[d.eventName];
    if (h) h(d);
  });

  // Voz de bienvenida opcional (assets/bienvenida.mp3), con M para silenciar.
  const voice = $('voice');
  voice.volume = 0.6;
  voice.addEventListener('canplaythrough', () => { voice.play().catch(() => {}); }, { once: true });
  voice.addEventListener('error', () => $('mute-hint').classList.add('hidden'));
  function fadeVoice() {
    const step = setInterval(() => {
      voice.volume = Math.max(0, voice.volume - 0.1);
      if (voice.volume === 0) { voice.pause(); clearInterval(step); }
    }, 60);
  }
  document.addEventListener('keydown', (e) => {
    if (e.key.toLowerCase() === 'm') {
      voice.muted = !voice.muted;
      video.muted = true;
      $('mute-hint').textContent = voice.muted ? 'M: activar sonido' : 'M: silenciar';
    }
  });

  if (demo) {
    let f = 0;
    const t = setInterval(() => { f += 0.07; setProgress(f); if (f >= 0.62) clearInterval(t); }, 60);
    $('status').textContent = STAGES.performMapLoadFunction;
    $('log').textContent = 'Mounted pxd_gamemodes (at nui://pxd_gamemodes)';
  }
})();
