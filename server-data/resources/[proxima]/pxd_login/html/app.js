(() => {
  'use strict';
  const inGame = typeof window.GetParentResourceName === 'function';
  const resource = inGame ? window.GetParentResourceName() : 'pxd_login';
  const $ = (id) => document.getElementById(id);

  const post = (name) => (inGame
    ? fetch(`https://${resource}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}' })
    : Promise.resolve(console.info('[demo]', name)));

  function profile(p) {
    const name = p.name || 'jugador';
    $('greeting').textContent = p.firstTime ? `Bienvenido/a a ${p.serverName || 'Próxima RP'}, ${name}` : `Bienvenido/a de nuevo, ${name}`;
    $('sub').textContent = p.firstTime ? 'Es tu primera visita. ¿Por dónde empiezas?' : `Visita número ${p.visits}. ¿Qué quieres hacer?`;
    $('choice-modes').classList.toggle('hidden', p.modesAvailable === false);
    $('choice-props').classList.toggle('hidden', !p.canEditProps);
  }

  const handlers = {
    profile,
    open: () => { $('welcome').classList.remove('hidden'); document.querySelector('.choice--primary').focus(); },
    close: () => $('welcome').classList.add('hidden'),
  };
  window.addEventListener('message', (e) => {
    const m = e.data;
    if (m && handlers[m.type]) handlers[m.type](m.data || {});
  });
  for (const b of document.querySelectorAll('[data-action]')) b.addEventListener('click', () => post(b.dataset.action));

  if (!inGame && new URLSearchParams(location.search).has('demo')) {
    profile({ name: 'Nova', serverName: 'PRÓXIMA RP', firstTime: true, visits: 1, canEditProps: true, modesAvailable: true });
    handlers.open();
  }
})();
