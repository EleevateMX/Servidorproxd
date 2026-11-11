// Modo demostración (index.html?demo=1&view=…): datos simulados para revisar la interfaz en un navegador.
// No calcula precios reales: imita las respuestas de client/main.lua.
import { setDemoHandler } from './nui';
import type { Entry, OpenData, Quote, Value } from './types';

const names = (n: number, base: string) => Array.from({ length: n }, (_, i) => `${base} ${i + 1}`);

const catalog: Entry[] = [
  { key: 'modEngine', kind: 'level', section: 'performance', label: 'Motor', count: 4 },
  { key: 'modBrakes', kind: 'level', section: 'performance', label: 'Frenos', count: 3 },
  { key: 'modTransmission', kind: 'level', section: 'performance', label: 'Transmisión', count: 3 },
  { key: 'modSuspension', kind: 'level', section: 'performance', label: 'Suspensión', count: 4 },
  { key: 'modArmor', kind: 'level', section: 'performance', label: 'Blindaje', count: 5 },
  { key: 'modTurbo', kind: 'toggle', section: 'performance', label: 'Turbo' },
  { key: 'modSpoilers', kind: 'mod', section: 'body', label: 'Alerón', count: 6, names: names(6, 'Alerón'), camera: 'rear' },
  { key: 'modFrontBumper', kind: 'mod', section: 'body', label: 'Parachoques delantero', count: 4, names: names(4, 'Parachoques') },
  { key: 'modRearBumper', kind: 'mod', section: 'body', label: 'Parachoques trasero', count: 3, names: names(3, 'Parachoques'), camera: 'rear' },
  { key: 'modSideSkirt', kind: 'mod', section: 'body', label: 'Faldones', count: 3, names: names(3, 'Faldón'), camera: 'side' },
  { key: 'modExhaust', kind: 'mod', section: 'body', label: 'Escape', count: 5, names: names(5, 'Escape'), camera: 'rear' },
  { key: 'modHood', kind: 'mod', section: 'body', label: 'Capó', count: 7, names: names(7, 'Capó') },
  { key: 'modRoof', kind: 'mod', section: 'body', label: 'Techo', count: 2, names: names(2, 'Techo'), camera: 'top' },
  { key: 'color1', kind: 'paint', section: 'paint', label: 'Color principal' },
  { key: 'color2', kind: 'paint', section: 'paint', label: 'Color secundario' },
  { key: 'pearlescentColor', kind: 'index', section: 'paint', label: 'Perlado', min: 0, count: 243 },
  { key: 'modLivery', kind: 'mod', section: 'paint', label: 'Vinilo', count: 8, names: names(8, 'Vinilo'), camera: 'side' },
  { key: 'wheels', kind: 'index', section: 'wheels', label: 'Tipo de llanta', min: 0, count: 13 },
  { key: 'modFrontWheels', kind: 'mod', section: 'wheels', label: 'Llantas', count: 50, names: names(50, 'Llanta') },
  { key: 'modCustomTiresF', kind: 'toggle', section: 'wheels', label: 'Neumáticos personalizados' },
  { key: 'wheelColor', kind: 'index', section: 'wheels', label: 'Color de llanta', min: 0, count: 243 },
  { key: 'tyreSmokeColor', kind: 'rgb', section: 'wheels', label: 'Color del humo' },
  { key: 'modXenon', kind: 'toggle', section: 'lights', label: 'Faros de xenón' },
  { key: 'xenonColor', kind: 'index', section: 'lights', label: 'Color del xenón', min: -1, count: 13 },
  { key: 'neonEnabled', kind: 'neon', section: 'lights', label: 'Neones', camera: 'side' },
  { key: 'neonColor', kind: 'rgb', section: 'lights', label: 'Color del neón', camera: 'side' },
  { key: 'modDashboard', kind: 'mod', section: 'interior', label: 'Salpicadero', count: 4, names: names(4, 'Salpicadero') },
  { key: 'modSeats', kind: 'mod', section: 'interior', label: 'Asientos', count: 5, names: names(5, 'Asiento') },
  { key: 'modSteeringWheel', kind: 'mod', section: 'interior', label: 'Volante', count: 9, names: names(9, 'Volante') },
  { key: 'modEngineBlock', kind: 'mod', section: 'engine', label: 'Bloque del motor', count: 3, names: names(3, 'Bloque') },
  { key: 'modAirFilter', kind: 'mod', section: 'engine', label: 'Filtro de aire', count: 4, names: names(4, 'Filtro') },
  { key: 'windowTint', kind: 'index', section: 'details', label: 'Tintado de lunas', min: 0, count: 7, camera: 'side' },
  { key: 'plateIndex', kind: 'index', section: 'details', label: 'Estilo de matrícula', min: 0, count: 6 },
  { key: 'modHorns', kind: 'mod', section: 'details', label: 'Bocina', count: 30, names: names(30, 'Bocina') },
  { key: 'extras', kind: 'extras', section: 'details', label: 'Extras del modelo', ids: [1, 2, 3, 5], camera: 'side' },
];

const values: Record<string, Value> = {
  modEngine: 0, modBrakes: -1, modTransmission: -1, modSuspension: 1, modArmor: -1, modTurbo: false,
  modSpoilers: -1, modFrontBumper: 1, modRearBumper: -1, modSideSkirt: -1, modExhaust: 2, modHood: -1, modRoof: -1,
  color1: 70, color2: 0, pearlescentColor: 5, modLivery: -1, wheels: 7, modFrontWheels: 12, modCustomTiresF: false, wheelColor: 0,
  tyreSmokeColor: [255, 255, 255], modXenon: false, xenonColor: -1, neonEnabled: [false, false, false, false], neonColor: [92, 225, 255],
  modDashboard: -1, modSeats: -1, modSteeringWheel: -1, modEngineBlock: -1, modAirFilter: -1, windowTint: 0, plateIndex: 0, modHorns: -1,
  extras: { 1: 0, 2: 1, 3: 1, 5: 0 },
};

const base = 86000;
const before = { speed: 44.2, acceleration: 0.31, braking: 0.82, traction: 2.35 };

function data(mode: 'self' | 'mechanic'): OpenData {
  return {
    vehicle: { name: 'Sultan RS', plate: 'PXD 042', base },
    zone: mode === 'self' ? 'Taller de personalización · Burton' : 'Taller Central',
    mode, ownsIt: mode === 'self', ownerName: mode === 'self' ? null : 'Lía Ríos',
    methods: { bank: true, cash: true }, mechanic: { level: mode === 'self' ? 1 : 3, name: mode === 'self' ? 'Aprendiz' : 'Mecánico', xp: mode === 'self' ? 0 : 780, next: 1200, jobs: 41 },
    factor: mode === 'self' ? 1 : 0.85,
    sections: [
      { id: 'performance', label: 'Rendimiento', camera: 'side' }, { id: 'body', label: 'Carrocería', camera: 'front' },
      { id: 'paint', label: 'Pintura', camera: 'front' }, { id: 'wheels', label: 'Ruedas', camera: 'wheel' },
      { id: 'lights', label: 'Luces', camera: 'front' }, { id: 'interior', label: 'Interior', camera: 'interior' },
      { id: 'engine', label: 'Motor a la vista', camera: 'engine' }, { id: 'details', label: 'Detalles', camera: 'rear' },
    ],
    catalog, values,
    performance: {
      modEngine: { label: 'Motor', npcMax: 1, mechLevel: [1, 1, 2, 3, 4] }, modBrakes: { label: 'Frenos', npcMax: 1, mechLevel: [1, 1, 2, 3] },
      modTransmission: { label: 'Transmisión', npcMax: 1, mechLevel: [1, 1, 2, 3] }, modSuspension: { label: 'Suspensión', npcMax: 2, mechLevel: [1, 1, 1, 2, 3] },
      modArmor: { label: 'Blindaje', npcMax: -1, mechLevel: [3, 4, 5, 5, 6] }, modTurbo: { label: 'Turbo', npcMax: false, mechLevel: [3] },
    },
    levels: [{ xp: 0, name: 'Aprendiz' }, { xp: 150, name: 'Ayudante' }, { xp: 500, name: 'Mecánico' }, { xp: 1200, name: 'Oficial' }, { xp: 2600, name: 'Especialista' }, { xp: 5000, name: 'Maestro' }],
    stats: { before, now: before, scale: { speed: 70, acceleration: 0.6, braking: 1.6, traction: 3.5 } },
    quote: { lines: [], total: 0, count: 0 },
  };
}

export function start() {
  const view = new URLSearchParams(window.location.search).get('view') ?? 'self';
  const mode: 'self' | 'mechanic' = view.startsWith('mechanic') ? 'mechanic' : 'self';
  const d = data(mode);
  const changes: Record<string, Value> = {};
  const send = (msg: unknown) => window.postMessage(msg, '*');

  const quote = (): Quote => {
    const lines = Object.keys(changes).map((key) => {
      const e = catalog.find((c) => c.key === key)!;
      const v = changes[key];
      let price = 0;
      if (e.section === 'performance') price = typeof v === 'number' ? Math.max(0, (v + 1) * 0.05 * base - ((values[key] as number) + 1) * 0.05 * base) : v ? 0.12 * base : 0;
      else if (!(v === -1 || v === false)) price = 400 + 0.006 * base;
      return { key, label: e.label, price: Math.round((price * d.factor) / 10) * 10 };
    });
    const eng = changes.modEngine;
    const blocked = mode === 'self' && typeof eng === 'number' && eng > 1 ? 'Motor nivel ' + (eng + 1) + ' solo lo monta un mecánico en su taller.' : null;
    return { lines, total: lines.reduce((s, l) => s + l.price, 0), count: lines.length, blocked };
  };

  setDemoHandler((name, body) => {
    const b = body as { key?: string; value?: Value };
    if (name === 'set' && b.key) {
      if (JSON.stringify(b.value) === JSON.stringify(values[b.key])) delete changes[b.key]; else changes[b.key] = b.value;
      const eng = typeof changes.modEngine === 'number' ? changes.modEngine : (values.modEngine as number);
      const turbo = changes.modTurbo === true;
      const brk = typeof changes.modBrakes === 'number' ? changes.modBrakes : -1;
      return { ok: true, quote: quote(), stats: { speed: before.speed + eng * 1.6 + (turbo ? 2 : 0), acceleration: before.acceleration + eng * 0.035 + (turbo ? 0.05 : 0), braking: before.braking + (brk + 1) * 0.12, traction: before.traction } };
    }
    if (name === 'reset') { for (const k of Object.keys(changes)) delete changes[k]; return { ok: true, values, quote: quote(), stats: before }; }
    if (name === 'apply') {
      window.setTimeout(() => send({ action: 'applied', ok: true, total: quote().total, pay: mode === 'mechanic' ? 'invoice' : 'direct', xp: mode === 'mechanic' ? 31 : 0, quote: { lines: [], total: 0, count: 0 } }), 300);
      return { ok: true };
    }
    return { ok: true };
  });

  window.setTimeout(() => {
    send({ action: 'open', ...d });
    const click = (sel: string, t: number) => window.setTimeout(() => (document.querySelector(sel) as HTMLElement | null)?.click(), t);
    const pick = (section: number, entry: number, t: number) => { click(`.tab:nth-child(${section})`, t); click(`.entry:nth-of-type(${entry}) .entry__head`, t + 60); };
    if (view === 'self-paint') pick(3, 1, 80);
    else if (view === 'self-lights') pick(5, 3, 80);
    else if (view === 'self-wheels') pick(4, 2, 80);
    else if (view === 'self-cart' || view === 'mechanic') {
      pick(1, 1, 80);
      click('.levels .level:nth-child(4)', 220);
      click('.entry:nth-of-type(6) .entry__head', 300);
      click('.entry.is-open .toggle', 380);
      click('.tab:nth-child(2)', 460);
      click('.entry:nth-of-type(1) .entry__head', 520);
      click('.entry.is-open .stepper__btn:last-child', 600);
    } else pick(1, 1, 80);
  }, 30);
}
