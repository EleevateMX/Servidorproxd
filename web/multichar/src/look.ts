// Lógica pura del editor en la interfaz: rutas, deshacer, restablecer y aleatorio.
// El cliente Lua vuelve a sanear todo con los rangos reales del modelo (client/editor.lua).
import type { EditorData, Limits, Look, SectionId } from './types';

export const FREEMODE: Record<string, 0 | 1> = { mp_m_freemode_01: 0, mp_f_freemode_01: 1 };
export const MODELS = ['mp_m_freemode_01', 'mp_f_freemode_01'] as const;

export function clone<T>(v: T): T { return JSON.parse(JSON.stringify(v)) as T; }

// ── Pila de cambios (deshacer) ─────────────────────────
export interface History { past: Look[]; present: Look }
export const MAX_UNDO = 60;

export function push(h: History, next: Look): History {
  if (JSON.stringify(next) === JSON.stringify(h.present)) return h;
  const past = [...h.past, h.present];
  if (past.length > MAX_UNDO) past.shift();
  return { past, present: next };
}
export function undo(h: History): History {
  const prev = h.past[h.past.length - 1];
  if (!prev) return h;
  return { past: h.past.slice(0, -1), present: prev };
}
/** El cliente devolvió la versión saneada: sustituye sin añadir a la pila. */
export function replace(h: History, present: Look): History { return { past: h.past, present }; }

// ── Lecturas y escrituras ─────────────────────────────
export function getComponent(look: Look, id: number) {
  return look.components.find((c) => c.component_id === id) ?? { component_id: id, drawable: 0, texture: 0 };
}
export function getProp(look: Look, id: number) {
  return look.props.find((p) => p.prop_id === id) ?? { prop_id: id, drawable: -1, texture: -1 };
}
export function setComponent(look: Look, id: number, drawable: number, texture: number): Look {
  const next = clone(look);
  const c = next.components.find((x) => x.component_id === id);
  if (c) { c.drawable = drawable; c.texture = texture; } else next.components.push({ component_id: id, drawable, texture });
  return next;
}
export function setProp(look: Look, id: number, drawable: number, texture: number): Look {
  const next = clone(look);
  const p = next.props.find((x) => x.prop_id === id);
  const t = drawable < 0 ? -1 : texture;
  if (p) { p.drawable = drawable; p.texture = t; } else next.props.push({ prop_id: id, drawable, texture: t });
  return next;
}
export function texturesFor(limits: Limits, kind: 'component' | 'prop', id: number, drawable: number): number {
  const r = (kind === 'component' ? limits.components : limits.props)[String(id)];
  if (!r) return 1;
  return Math.max(1, r.texturesFor?.[String(drawable)] ?? r.textures ?? 1);
}
export function drawablesOf(limits: Limits, kind: 'component' | 'prop', id: number): number {
  const r = (kind === 'component' ? limits.components : limits.props)[String(id)];
  return Math.max(kind === 'prop' ? 0 : 1, r?.drawables ?? 1);
}

/** Cambiar de sexo empieza desde la apariencia por defecto del otro modelo (la da el cliente). */
export function withModel(look: Look, gender: 0 | 1): Look {
  const next = clone(look);
  next.model = MODELS[gender];
  return next;
}

// ── Restablecer sección ───────────────────────────────
export function resetSection(look: Look, section: SectionId, base: Look, overlays: EditorData['overlays']): Look {
  const out = clone(look);
  const b = clone(base);
  if (section === 'heritage') out.headBlend = b.headBlend;
  else if (section === 'face') out.faceFeatures = b.faceFeatures;
  else if (section === 'skin' || section === 'hair') {
    if (section === 'skin') out.eyeColor = b.eyeColor; else out.hair = b.hair;
    for (const o of overlays) if (o.section === section && b.headOverlays[o.key]) out.headOverlays[o.key] = b.headOverlays[o.key]!;
  } else if (section === 'clothes') { out.components = b.components; out.props = b.props; }
  return out;
}

// ── Aleatorio dentro de los rangos reales ─────────────
export type Rng = () => number;   // [0, 1)
const int = (rng: Rng, a: number, b: number) => a + Math.floor(rng() * (b - a + 1));
const r1 = (v: number) => Math.round(v * 10) / 10;
const r2 = (v: number) => Math.round(v * 100) / 100;

export const MOTHERS = [...Array.from({ length: 21 }, (_, i) => 21 + i), 45];
export const FATHERS = [...Array.from({ length: 21 }, (_, i) => i), 42, 43, 44];

export function randomizeSection(look: Look, section: SectionId, data: Pick<EditorData, 'limits' | 'overlays' | 'features'>, rng: Rng = Math.random): Look {
  const out = clone(look);
  const { limits } = data;
  const female = FREEMODE[out.model] === 1;
  if (section === 'heritage') {
    const m = MOTHERS[int(rng, 0, MOTHERS.length - 1)]!, f = FATHERS[int(rng, 0, FATHERS.length - 1)]!;
    out.headBlend = { ...out.headBlend, shapeFirst: m, skinFirst: m, shapeSecond: f, skinSecond: f, shapeMix: r2(rng()), skinMix: r2(rng()) };
  } else if (section === 'face') {
    for (const f of data.features) out.faceFeatures[f.key] = r1((rng() * 2 - 1) * 0.6);
  } else if (section === 'skin') {
    out.eyeColor = int(rng, 0, 13);
    data.overlays.forEach((o, i) => {
      if (o.section !== 'skin') return;
      const max = Math.max(0, (limits.overlays[String(i)] ?? 1) - 1);
      const on = o.colorType === 2 ? female && rng() < 0.5 : rng() < 0.35;
      out.headOverlays[o.key] = { style: int(rng, 0, max), opacity: on ? r1(0.3 + rng() * 0.7) : 0, color: int(rng, 0, Math.max(0, limits.makeupColors - 1)), secondColor: 0 };
    });
  } else if (section === 'hair') {
    const color = int(rng, 0, Math.min(63, Math.max(0, limits.hairColors - 1)));
    out.hair = { style: int(rng, 0, drawablesOf(limits, 'component', 2) - 1), texture: 0, color, highlight: color };
    out.headOverlays.eyebrows = { style: int(rng, 0, Math.max(0, (limits.overlays['2'] ?? 1) - 1)), opacity: r1(0.6 + rng() * 0.4), color, secondColor: color };
    out.headOverlays.beard = { style: int(rng, 0, Math.max(0, (limits.overlays['1'] ?? 1) - 1)), opacity: !female && rng() < 0.6 ? r1(0.5 + rng() * 0.5) : 0, color, secondColor: color };
  } else if (section === 'clothes') {
    for (const id of [11, 8, 4, 6]) {
      const n = drawablesOf(limits, 'component', id);
      const c = out.components.find((x) => x.component_id === id);
      if (c) { c.drawable = int(rng, 0, n - 1); c.texture = 0; }
    }
  }
  return out;
}

export const SECTION_LABEL: Record<SectionId, string> = {
  identity: 'Identidad', heritage: 'Herencia', face: 'Rasgos', skin: 'Piel', hair: 'Cabello', clothes: 'Ropa',
};
