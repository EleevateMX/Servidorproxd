// Demostración en el navegador: index.html?demo=foot|vehicle|settings|cinema
export function demoMessages(): void {
  const view = new URLSearchParams(window.location.search).get('demo');
  if (!view) return;
  document.body.classList.add('demo');
  const send = (d: unknown) => window.postMessage(d, '*');
  const inCar = view === 'vehicle';
  window.setTimeout(() => {
    send({ action: 'config', speedUnit: 'kmh', warn: { hunger: 25, thirst: 25, health: 35, critical: 10 }, lowFuel: 20, minimapOnFoot: true });
    send({ action: 'anchor', anchor: { left: 0.014, bottom: 0.978, width: 0.1406, height: 0.1762 } });
    send({
      action: 'tick', show: true, cash: 2350, bank: 48210, health: 82, armor: inCar ? 0 : 46, hunger: 22, thirst: 64,
      stress: inCar ? 0 : 38, oxygen: -1, dead: false, talking: true, voice: 'Normal', voiceIndex: 2, radio: inCar ? 0 : 3,
      clock: '08:35', fines: 1300, invoices: inCar ? 0 : 450, payday: 720, publicId: 'PROX-7KQ2',
      street: inCar ? 'Avenida Strawberry · Calle Davis' : 'Plaza Legion', zone: inCar ? 'Strawberry' : 'Pillbox Hill',
      vehicle: inCar, fuel: 17, engine: 62, body: 34, engineOn: true, lights: 1, locked: true, seatbelt: false, harness: false, cruise: inCar,
    });
    send({ action: 'fast', compass: inCar ? 348 : 42, speed: inCar ? 128 : 0, rpm: inCar ? 72 : 0, gear: inCar ? '4' : 'P' });
    send({ action: 'money', cash: 2350, bank: 48210, changed: 'cash', amount: 450, minus: false });
    if (view === 'settings') send({ action: 'settingsPanel', open: true });
    if (view === 'cinema') send({ action: 'settings', settings: { cinema: true } });
  }, 60);
}
