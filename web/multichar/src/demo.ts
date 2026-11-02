// Modo demostración (index.html?demo=1&view=…): datos simulados para revisar la interfaz
// en un navegador. Los rangos y paletas reales los cuenta el juego; aquí son de ejemplo.
import { setDemoHandler } from './nui';
import type { ClothesDef, EditorData, Look, SectionId } from './types';

const FEATURES = [
  ['noseWidth', 'Anchura', 'nose'], ['nosePeakHigh', 'Altura de la punta', 'nose'], ['nosePeakSize', 'Largo de la punta', 'nose'],
  ['noseBoneHigh', 'Altura del tabique', 'nose'], ['nosePeakLowering', 'Caída de la punta', 'nose'], ['noseBoneTwist', 'Desviación del tabique', 'nose'],
  ['eyeBrownHigh', 'Altura', 'brows'], ['eyeBrownForward', 'Profundidad', 'brows'], ['cheeksBoneHigh', 'Altura', 'cheekbones'],
  ['cheeksBoneWidth', 'Anchura', 'cheekbones'], ['cheeksWidth', 'Volumen', 'cheeks'], ['eyesOpening', 'Apertura', 'eyes'],
  ['lipsThickness', 'Grosor', 'lips'], ['jawBoneWidth', 'Anchura', 'jaw'], ['jawBoneBackSize', 'Forma', 'jaw'],
  ['chinBoneLowering', 'Altura', 'chin'], ['chinBoneLenght', 'Largo', 'chin'], ['chinBoneSize', 'Anchura', 'chin'],
  ['chinHole', 'Hoyuelo', 'chin'], ['neckThickness', 'Grosor', 'neck'],
].map(([key, label, region]) => ({ key: key!, label: label!, region: region! }));
const OVERLAYS = [
  ['blemishes', 'Acné e imperfecciones', 0, 'skin'], ['beard', 'Barba', 1, 'hair'], ['eyebrows', 'Cejas', 1, 'hair'], ['ageing', 'Arrugas', 0, 'skin'],
  ['makeUp', 'Maquillaje', 2, 'skin'], ['blush', 'Colorete', 2, 'skin'], ['complexion', 'Tez', 0, 'skin'], ['sunDamage', 'Daño solar', 0, 'skin'],
  ['lipstick', 'Pintalabios', 2, 'skin'], ['moleAndFreckles', 'Lunares y pecas', 0, 'skin'], ['chestHair', 'Vello corporal', 1, 'hair'], ['bodyBlemishes', 'Manchas corporales', 0, 'skin'],
].map(([key, label, colorType, section]) => ({ key: key as string, label: label as string, colorType: colorType as 0 | 1 | 2, section: section as 'skin' | 'hair' }));

function look(female: boolean): Look {
  const ff: Record<string, number> = {};
  for (const f of FEATURES) ff[f.key] = 0;
  const ho: Look['headOverlays'] = {};
  for (const o of OVERLAYS) ho[o.key] = { style: 0, opacity: o.key === 'eyebrows' ? 1 : 0, color: 0, secondColor: 0 };
  return {
    model: female ? 'mp_f_freemode_01' : 'mp_m_freemode_01',
    headBlend: female ? { shapeFirst: 45, shapeSecond: 21, shapeThird: 0, skinFirst: 20, skinSecond: 15, skinThird: 0, shapeMix: 0.3, skinMix: 0.1, thirdMix: 0 }
      : { shapeFirst: 29, shapeSecond: 12, shapeThird: 0, skinFirst: 29, skinSecond: 12, skinThird: 0, shapeMix: 0.5, skinMix: 0.5, thirdMix: 0 },
    faceFeatures: ff, headOverlays: ho,
    components: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map((id) => ({ component_id: id, drawable: id === 11 || id === 8 || id === 3 ? 15 : 0, texture: 0 })),
    props: [0, 1, 2, 6, 7].map((id) => ({ prop_id: id, drawable: -1, texture: -1 })),
    hair: { style: female ? 15 : 0, texture: 0, color: 0, highlight: 0 }, eyeColor: 0, tattoos: {},
  };
}
function hsl(h: number, s: number, l: number): [number, number, number] {
  const a = s * Math.min(l, 1 - l);
  const f = (n: number) => { const k = (n + h / 30) % 12; return Math.round(255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)))); };
  return [f(0), f(8), f(4)];
}
const hairPalette = Array.from({ length: 64 }, (_, i) => (i < 30 ? hsl(25, 0.45, 0.06 + i * 0.022) : hsl((i - 30) * 11, 0.6, 0.45)));
const makeupPalette = Array.from({ length: 64 }, (_, i) => hsl((i * 17) % 360, 0.55, 0.35 + (i % 4) * 0.08));

function editorData(mode: EditorData['mode'], sections: SectionId[]): EditorData {
  const limits: EditorData['limits'] = { overlays: {}, components: {}, props: {}, hairColors: 64, makeupColors: 64 };
  OVERLAYS.forEach((_, i) => { limits.overlays[String(i)] = [24, 29, 34, 15, 75, 7, 12, 11, 10, 18, 17, 12][i]!; });
  for (const id of [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) limits.components[String(id)] = { drawables: [46, 190, 79, 196, 150, 100, 102, 160, 189, 57, 140, 400][id]!, textures: 6 };
  for (const id of [0, 1, 2, 6, 7]) limits.props[String(id)] = { drawables: 180, textures: 8 };
  const base = look(false);
  return {
    mode, title: mode === 'create' ? 'Crear personaje' : mode === 'recover' ? 'Completa tu apariencia' : 'Peluquería', sections, look: base, base,
    identity: { firstname: 'Valentina', lastname: 'Ríos', gender: 0, birthdate: '1997-03-12', nationality: 'Mexican',
      nationalities: ['American', 'Argentine', 'Brazilian', 'Chilean', 'Colombian', 'Mexican', 'Peruvian', 'Spanish'], limitNationalities: true, dateMin: '1930-01-01', dateMax: '2006-12-31' },
    limits, palettes: { hair: hairPalette, makeup: makeupPalette },
    regions: [['nose', 'Nariz'], ['brows', 'Cejas'], ['cheekbones', 'Pómulos'], ['cheeks', 'Mejillas'], ['eyes', 'Ojos'], ['lips', 'Labios'], ['jaw', 'Mandíbula'], ['chin', 'Mentón'], ['neck', 'Cuello']].map(([id, label]) => ({ id: id!, label: label! })),
    features: FEATURES, overlays: OVERLAYS,
    clothes: ([[11, 'Prenda superior'], [8, 'Camiseta interior'], [3, 'Brazos'], [4, 'Pantalón'], [6, 'Calzado'], [7, 'Cuello y cadenas'], [5, 'Bolsa']]
      .map(([id, label]) => ({ kind: 'component', id: id as number, label: label as string })) as ClothesDef[])
      .concat([[0, 'Sombrero'], [1, 'Gafas'], [2, 'Pendientes'], [6, 'Reloj'], [7, 'Pulsera']].map(([id, label]) => ({ kind: 'prop', id: id as number, label: label as string })) as ClothesDef[]),
    outfits: { '0': [{ id: 'basic', label: 'Básico', components: [] }], '1': [{ id: 'basic', label: 'Básico', components: [] }] },
    defaults: { '0': look(false), '1': look(true) },
  };
}

const send = (action: string, data?: unknown, extra: Record<string, unknown> = {}) => window.postMessage({ action, data, ...extra }, '*');

export function start() {
  setDemoHandler((name, body) => {
    if (name === 'editorLook') return { ok: true, look: (body as { look: Look }).look };
    if (name === 'editorPortraits') return { ok: false };
    if (name === 'editorFinish') { window.setTimeout(() => send('editorError', undefined, { text: 'Demostración: aquí se crearía el personaje.' }), 300); return { ok: true }; }
    if (name === 'createStart') { send('editor', editorData('create', ['identity', 'heritage', 'face', 'skin', 'hair', 'clothes'])); return { ok: true }; }
    return { ok: true };
  });
  const view = new URLSearchParams(window.location.search).get('view') ?? 'select';
  const sel = {
    serverName: 'PRÓXIMA RP', enableDelete: true, lockedLabel: 'Ranura Plus',
    characters: [
      { citizenid: 'PXD48213', firstname: 'Valentina', lastname: 'Ríos', gender: 1, nationality: 'Mexican', job: 'Servicios de Emergencia', grade: 'Paramédica', cash: 95846, bank: 778358, level: 16, playtime: 2534400, status: 'active', location: 'Alta St, Pillbox Hill' },
      { citizenid: 'PXD10977', firstname: 'Bruno', lastname: 'Salgado', gender: 0, nationality: 'Argentine', job: 'Taller Próxima', grade: 'Aprendiz', cash: 1200, bank: 15400, level: 3, playtime: 11520, status: 'dead', location: 'Paleto Blvd, Paleto Bay' },
    ],
    slots: [{ kind: 'character', index: 1, citizenid: 'PXD48213' }, { kind: 'character', index: 2, citizenid: 'PXD10977' }, { kind: 'free', index: 3 }, { kind: 'locked', index: 4 }],
  };
  const spawn = { mode: 'spawn', kicker: '¿Dónde apareces?', title: 'Elige dónde empezar', text: 'Vuelve donde lo dejaste, a tu casa o a un punto de la ciudad.', confirm: 'Aparecer', options: [
    { id: 'last', kind: 'last', label: 'Última ubicación', detail: 'Donde lo dejaste', image: 'assets/spawn-ultima.jpg' },
    { id: 'property:1', kind: 'property', label: 'Del Perro Heights 12', detail: 'Tu casa', image: 'assets/spawn-casa.jpg' },
    { id: 'point:1', kind: 'point', label: 'Plaza Legion', detail: 'Centro de la ciudad', image: 'assets/spawn-centro.jpg' },
    { id: 'point:2', kind: 'point', label: 'Paleto Bay', detail: 'Pueblo del norte, junto al mar', image: 'assets/spawn-paleto.jpg' },
    { id: 'point:3', kind: 'point', label: 'Motel', detail: 'Habitaciones baratas para empezar', image: 'assets/spawn-motel.jpg' },
  ] };
  const all: SectionId[] = ['identity', 'heritage', 'face', 'skin', 'hair', 'clothes'];
  window.setTimeout(() => {
    if (view === 'select') send('open', sel);
    else if (view === 'free') { send('open', { ...sel }); window.setTimeout(() => window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown' })), 50); window.setTimeout(() => window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown' })), 100); }
    else if (view === 'spawn') send('spawn', spawn);
    else if (view === 'recover') send('editor', editorData('recover', all.slice(1)));
    else if (view === 'barber') send('editor', editorData('edit', ['hair']));
    else if (view.startsWith('create')) {
      send('editor', editorData('create', all));
      const sec = view.split('-')[1];
      if (sec) window.setTimeout(() => (document.querySelector(`.tab:nth-child(${all.indexOf(sec as SectionId) + 1})`) as HTMLButtonElement | null)?.click(), 80);
    } else if (view === 'confirm') {
      send('editor', editorData('create', all));
      window.setTimeout(() => (document.querySelector('.tab:nth-child(6)') as HTMLButtonElement | null)?.click(), 60);
      window.setTimeout(() => (document.querySelector('.panel__foot .btn--primary') as HTMLButtonElement | null)?.click(), 120);
    }
  }, 30);
}
