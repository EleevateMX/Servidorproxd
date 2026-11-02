// HUD de Próxima RP. Recibe mensajes del cliente Lua (action: config | anchor | tick | money | hide).
// Todo el texto se escribe con textContent.
(() => {
  const $ = (id) => document.getElementById(id);
  const hud = $('hud');
  const root = document.documentElement.style;
  const stats = {};
  document.querySelectorAll('.stat').forEach((el) => { stats[el.dataset.k] = el; });

  const cfg = { speedUnit: 'kmh', warn: { hunger: 25, thirst: 25, health: 35, critical: 10 }, lowFuel: 20, minimapOnFoot: true, maxSpeed: 240 };
  const state = { vehicle: false, speed: 0 };
  const money = (n) => {
    const v = Math.floor(Number(n) || 0);
    return (v < 0 ? '-$' : '$') + Math.abs(v).toLocaleString('en-US');
  };

  // Fecha real del jugador (la hora es la del juego, sincronizada por el servidor).
  const dateFmt = new Intl.DateTimeFormat('es-MX', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const setDate = () => { $('date').textContent = dateFmt.format(new Date()).replace('.', ''); };
  setDate(); setInterval(setDate, 60000);

  function setStat(key, value, opts = {}) {
    const el = stats[key];
    if (!el) return;
    const off = opts.hideWhen ? opts.hideWhen(value) : false;
    el.classList.toggle('is-off', off);
    if (off) return;
    const pct = Math.max(0, Math.min(100, Number(value) || 0));
    el.querySelector('span').style.width = pct + '%';
    const crit = cfg.warn.critical ?? 10;
    const warn = opts.warn ?? -1;
    const v = opts.inverse ? 100 - pct : pct;
    el.classList.toggle('is-critical', v <= crit);
    el.classList.toggle('is-low', v > crit && v <= warn);
  }

  function applyMapVisibility() {
    hud.classList.toggle('no-map', !(state.vehicle || cfg.minimapOnFoot));
  }

  function setSpeed(speed) {
    state.speed = speed;
    $('speed').textContent = String(speed);
    const ratio = Math.max(0, Math.min(1, speed / cfg.maxSpeed));
    $('gauge').style.strokeDashoffset = String(251.3 * (1 - ratio));
    updateBelt();
  }

  function updateBelt() {
    const belt = $('belt');
    const on = state.seatbelt || state.harness;
    belt.classList.toggle('is-on', !!on);
    belt.classList.toggle('is-warn', !on && state.speed > 20);
  }

  const handlers = {
    config(d) {
      Object.assign(cfg, { speedUnit: d.speedUnit || cfg.speedUnit, lowFuel: d.lowFuel ?? cfg.lowFuel });
      if (d.warn) cfg.warn = d.warn;
      if (typeof d.minimapOnFoot === 'boolean') cfg.minimapOnFoot = d.minimapOnFoot;
      cfg.maxSpeed = cfg.speedUnit === 'mph' ? 160 : 240;
      $('unit').textContent = cfg.speedUnit === 'mph' ? 'mph' : 'km/h';
      applyMapVisibility();
    },
    anchor({ anchor: a }) {
      if (!a) return;
      root.setProperty('--map-left', (a.left * 100) + 'vw');
      root.setProperty('--map-bottom', ((1 - a.bottom) * 100) + 'vh');
      root.setProperty('--map-w', (a.width * 100) + 'vw');
      root.setProperty('--map-h', (a.height * 100) + 'vh');
    },
    hide() { hud.classList.add('is-hidden'); },
    money(d) {
      $('cash').textContent = money(d.cash);
      $('bank').textContent = money(d.bank);
      if (d.amount) {
        const el = $('delta');
        el.textContent = (d.minus ? '-' : '+') + money(Math.abs(d.amount)) + (d.changed === 'bank' ? ' banco' : '');
        el.className = 'wallet__delta ' + (d.minus ? 'minus' : 'plus');
        void el.offsetWidth; // reinicia la animación
        el.classList.add('is-in');
      }
    },
    tick(d) {
      if (d.show !== undefined) hud.classList.toggle('is-hidden', !d.show);
      if (d.cash !== undefined) $('cash').textContent = money(d.cash);
      if (d.bank !== undefined) $('bank').textContent = money(d.bank);
      if (d.health !== undefined) setStat('health', d.health, { warn: cfg.warn.health });
      if (d.armor !== undefined) setStat('armor', d.armor, { hideWhen: (v) => v <= 0 });
      if (d.hunger !== undefined) setStat('hunger', d.hunger, { warn: cfg.warn.hunger });
      if (d.thirst !== undefined) setStat('thirst', d.thirst, { warn: cfg.warn.thirst });
      if (d.stress !== undefined) setStat('stress', d.stress, { hideWhen: (v) => v <= 0, inverse: true, warn: 50 });
      if (d.oxygen !== undefined) setStat('oxygen', d.oxygen, { hideWhen: (v) => v < 0, warn: 30 });
      if (d.fines !== undefined) {
        $('fines').classList.toggle('is-on', d.fines > 0);
        $('fines-amount').textContent = money(d.fines);
      }
      if (d.dead !== undefined) hud.classList.toggle('is-dead', !!d.dead);
      if (d.clock !== undefined) $('clock').textContent = d.clock;
      if (d.talking !== undefined) $('voice').classList.toggle('is-talking', !!d.talking);
      if (d.voice !== undefined) $('voice-label').textContent = d.voice;
      if (d.voiceIndex !== undefined) $('voice').dataset.range = String(d.voiceIndex);
      if (d.radio !== undefined) {
        $('voice').classList.toggle('has-radio', d.radio > 0);
        $('radio-ch').textContent = d.radio > 0 ? String(d.radio) : '';
      }
      if (d.vehicle !== undefined) {
        state.vehicle = !!d.vehicle;
        hud.classList.toggle('in-vehicle', state.vehicle);
        applyMapVisibility();
      }
      if (d.street !== undefined) $('street').textContent = d.street || '';
      if (d.fuel !== undefined) {
        $('fuel').style.width = d.fuel + '%';
        $('car').classList.toggle('fuel-low', d.fuel <= cfg.lowFuel);
      }
      if (d.engine !== undefined) {
        $('engine').classList.toggle('is-warn', d.engine <= 40 && d.engine > 15);
        $('engine').classList.toggle('is-critical', d.engine <= 15);
      }
      if (d.seatbelt !== undefined) state.seatbelt = d.seatbelt;
      if (d.harness !== undefined) state.harness = d.harness;
      if (d.cruise !== undefined) $('cruise').classList.toggle('is-on', !!d.cruise);
      if (d.speed !== undefined) setSpeed(d.speed); else if (d.seatbelt !== undefined || d.harness !== undefined) updateBelt();
    },
  };

  window.addEventListener('message', (e) => {
    const d = e.data;
    if (d && handlers[d.action]) handlers[d.action](d);
  });

  const params = new URLSearchParams(location.search);
  if (params.has('demo')) {
    document.body.classList.add('demo');
    const send = (d) => window.postMessage(d, '*');
    const inCar = params.has('vehicle');
    send({ action: 'config', speedUnit: 'kmh', warn: cfg.warn, lowFuel: 20, minimapOnFoot: true });
    send({ action: 'anchor', anchor: { left: 0.025, bottom: 0.975, width: 0.1406, height: 0.1762 } });
    send({
      action: 'tick', show: true, cash: 95846, bank: 778358, health: 82, armor: inCar ? 0 : 46, hunger: 22, thirst: 64,
      stress: inCar ? 0 : 38, oxygen: -1, dead: false, talking: true, voice: 'Normal', voiceIndex: 2, radio: inCar ? 0 : 3,
      clock: '08:35', fines: 1300, vehicle: inCar, speed: inCar ? 128 : 0, fuel: inCar ? 17 : 0, engine: 62, seatbelt: false, harness: false,
      cruise: inCar, street: inCar ? 'Avenida Strawberry · Calle Davis' : '',
    });
    setTimeout(() => send({ action: 'money', cash: 96346, bank: 778358, changed: 'cash', amount: 500, minus: false }), 300);
    return;
  }

  // En el juego: avisar al cliente de que la NUI está lista.
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pxd_hud';
  fetch(`https://${res}/ready`, { method: 'POST', body: '{}' }).catch(() => {});
})();
