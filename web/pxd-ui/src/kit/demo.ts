// Demostración en el navegador: index.html?demo=notify|text|progress|circle|alert|all
export function runDemo(): void {
  const view = new URLSearchParams(window.location.search).get('demo');
  if (!view) return;
  document.body.classList.add('demo');
  const send = (d: unknown) => window.postMessage(d, '*');
  const all = view === 'all';
  window.setTimeout(() => {
    if (all || view === 'notify') {
      send({ action: 'notify', data: { title: 'Paga recibida', description: 'Has cobrado **$450** de tu turno en el taller.', type: 'success', duration: 20000 } });
      send({ action: 'notify', data: { id: 'hambre', description: 'Tienes hambre. Come algo pronto.', type: 'warning', duration: 20000 } });
      send({ action: 'notify', data: { id: 'hambre', description: 'Tienes hambre. Come algo pronto.', type: 'warning', duration: 20000 } });
      send({ action: 'notify', data: { title: 'Maletero cerrado', description: 'Necesitas las llaves de este vehículo.', type: 'error', duration: 20000 } });
      send({ action: 'notify', data: { title: 'Reporte #12', description: 'Un miembro del staff está atendiendo tu reporte.', type: 'inform', duration: 20000 } });
      send({ action: 'notify', data: { description: 'Vehículo guardado en el garaje.', type: 'success', position: 'top', duration: 20000 } });
    }
    if (all || view === 'text') send({ action: 'textUi', data: { text: '[E] Abrir maletero', position: 'right-center' } });
    if (view === 'text') window.setTimeout(() => send({ action: 'textUi', data: { text: '[E] Hablar con **Marta**  \n[G] Presentarte', position: 'right-center' } }), 10);
    if (all || view === 'progress') send({ action: 'progress', data: { label: 'Reparando el motor', duration: 12000 } });
    if (view === 'circle') send({ action: 'progress', circle: true, data: { label: 'Forzando la cerradura', duration: 12000, position: 'bottom' } });
    if (view === 'alert') send({ action: 'alert', data: { header: 'Vender vehículo', content: 'Vas a vender tu **Sultan RS** por **$38,500**.\nEsta acción no se puede deshacer.', cancel: true, labels: { confirm: 'Vender', cancel: 'Volver' }, centered: true } });
  }, 60);
}
