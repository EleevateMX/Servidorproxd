import { describe, expect, it } from 'vitest';
import { FATHERS, MOTHERS, MAX_UNDO, push, randomizeSection, replace, resetSection, setComponent, setProp, texturesFor, undo, type History } from '../look';
import type { EditorData, Look } from '../types';

const OVERLAYS: EditorData['overlays'] = [
  { key: 'blemishes', label: '', colorType: 0, section: 'skin' }, { key: 'beard', label: '', colorType: 1, section: 'hair' },
  { key: 'eyebrows', label: '', colorType: 1, section: 'hair' }, { key: 'makeUp', label: '', colorType: 2, section: 'skin' },
];
const FEATURES = Array.from({ length: 20 }, (_, i) => ({ key: 'f' + i, label: '', region: 'nose' }));
function look(model = 'mp_m_freemode_01'): Look {
  return {
    model, eyeColor: 0, tattoos: {},
    headBlend: { shapeFirst: 21, shapeSecond: 0, shapeThird: 0, skinFirst: 21, skinSecond: 0, skinThird: 0, shapeMix: 0.5, skinMix: 0.5, thirdMix: 0 },
    faceFeatures: Object.fromEntries(FEATURES.map((f) => [f.key, 0])),
    headOverlays: Object.fromEntries(OVERLAYS.map((o) => [o.key, { style: 0, opacity: 0, color: 0, secondColor: 0 }])),
    components: [2, 3, 4, 6, 8, 11].map((id) => ({ component_id: id, drawable: 0, texture: 0 })),
    props: [0, 1].map((id) => ({ prop_id: id, drawable: -1, texture: -1 })),
    hair: { style: 0, texture: 0, color: 0, highlight: 0 },
  };
}
const limits: EditorData['limits'] = {
  overlays: { '0': 24, '1': 29, '2': 34, '3': 75 }, hairColors: 64, makeupColors: 64,
  components: { '2': { drawables: 79, textures: 3 }, '3': { drawables: 196, textures: 1 }, '4': { drawables: 150, textures: 4, texturesFor: { '7': 9 } },
    '6': { drawables: 102, textures: 1 }, '8': { drawables: 189, textures: 1 }, '11': { drawables: 400, textures: 1 } },
  props: { '0': { drawables: 180, textures: 1 }, '1': { drawables: 40, textures: 1 } },
};
const seq = (vals: number[]) => { let i = 0; return () => vals[i++ % vals.length]!; };

describe('deshacer', () => {
  it('apila cambios, deshace en orden y no apila cambios idénticos', () => {
    let h: History = { past: [], present: look() };
    const a = { ...look(), eyeColor: 3 };
    const b = { ...look(), eyeColor: 5 };
    h = push(h, a); h = push(h, b); h = push(h, b);
    expect(h.past).toHaveLength(2);
    h = undo(h); expect(h.present.eyeColor).toBe(3);
    h = undo(h); expect(h.present.eyeColor).toBe(0);
    expect(undo(h)).toBe(h);
  });
  it('la versión saneada del cliente no añade un paso; la pila tiene tope', () => {
    let h: History = { past: [], present: look() };
    h = replace(push(h, { ...look(), eyeColor: 1 }), { ...look(), eyeColor: 2 });
    expect(h.past).toHaveLength(1); expect(h.present.eyeColor).toBe(2);
    for (let i = 0; i < MAX_UNDO + 20; i++) h = push(h, { ...look(), eyeColor: i + 10 });
    expect(h.past.length).toBe(MAX_UNDO);
  });
});

describe('restablecer y aleatorio por sección', () => {
  it('restablecer solo toca su sección', () => {
    const base = look();
    const edited = { ...look(), eyeColor: 9, headBlend: { ...base.headBlend, shapeMix: 0.9 }, hair: { ...base.hair, style: 12 } };
    const r = resetSection(edited, 'heritage', base, OVERLAYS);
    expect(r.headBlend.shapeMix).toBe(0.5); expect(r.eyeColor).toBe(9); expect(r.hair.style).toBe(12);
    expect(resetSection(edited, 'skin', base, OVERLAYS).eyeColor).toBe(0);
    expect(resetSection(edited, 'hair', base, OVERLAYS).hair.style).toBe(0);
  });
  it('herencia aleatoria: madre de la lista de madres, padre de la de padres, mezclas 0..1', () => {
    for (let k = 0; k < 50; k++) {
      const r = randomizeSection(look(), 'heritage', { limits, overlays: OVERLAYS, features: FEATURES });
      expect(MOTHERS).toContain(r.headBlend.shapeFirst); expect(FATHERS).toContain(r.headBlend.shapeSecond);
      expect(r.headBlend.skinFirst).toBe(r.headBlend.shapeFirst);
      expect(r.headBlend.shapeMix).toBeGreaterThanOrEqual(0); expect(r.headBlend.shapeMix).toBeLessThanOrEqual(1);
    }
  });
  it('rasgos aleatorios dentro de -1..1 y con un decimal (como guarda illenium)', () => {
    const r = randomizeSection(look(), 'face', { limits, overlays: OVERLAYS, features: FEATURES });
    for (const f of FEATURES) { const v = r.faceFeatures[f.key]!; expect(Math.abs(v)).toBeLessThanOrEqual(1); expect(Math.round(v * 10) / 10).toBe(v); }
  });
  it('cabello y ropa aleatorios no salen de los rangos reales del modelo', () => {
    const top = randomizeSection(look(), 'hair', { limits, overlays: OVERLAYS, features: FEATURES }, seq([0.9999]));
    expect(top.hair.style).toBe(78);
    expect(top.headOverlays.beard!.style).toBe(28);
    const clothes = randomizeSection(look(), 'clothes', { limits, overlays: OVERLAYS, features: FEATURES }, seq([0.9999]));
    expect(clothes.components.find((c) => c.component_id === 11)!.drawable).toBe(399);
    expect(clothes.components.find((c) => c.component_id === 4)!.drawable).toBe(149);
  });
  it('una mujer no recibe barba aleatoria', () => {
    for (let k = 0; k < 30; k++) expect(randomizeSection(look('mp_f_freemode_01'), 'hair', { limits, overlays: OVERLAYS, features: FEATURES }).headOverlays.beard!.opacity).toBe(0);
  });
});

describe('ropa', () => {
  it('cambiar de prenda pone la textura a 0; las texturas dependen del drawable', () => {
    const l = setComponent(look(), 4, 7, 0);
    expect(l.components.find((c) => c.component_id === 4)).toEqual({ component_id: 4, drawable: 7, texture: 0 });
    expect(texturesFor(limits, 'component', 4, 7)).toBe(9);
    expect(texturesFor(limits, 'component', 4, 1)).toBe(4);
  });
  it('quitar un accesorio deja drawable -1 y textura -1 (formato de illenium)', () => {
    expect(setProp(setProp(look(), 0, 5, 2), 0, -1, 3).props.find((p) => p.prop_id === 0)).toEqual({ prop_id: 0, drawable: -1, texture: -1 });
  });
});
