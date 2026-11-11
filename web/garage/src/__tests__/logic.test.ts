import { describe, expect, it } from 'vitest';
import { kmh, levelLock, mechanicProgress, money, range, same, statDelta, statPercent, step, toggleLock, valueLabel } from '../logic';
import type { Entry, PerfRule } from '../types';

const engine: PerfRule = { label: 'Motor', npcMax: 1, mechLevel: [1, 1, 2, 3, 4] };
const turbo: PerfRule = { label: 'Turbo', npcMax: false, mechLevel: [3] };

describe('formato', () => {
  it('dinero con separador de miles y km/h', () => {
    expect(money(1234567)).toBe('$1,234,567');
    expect(money(0)).toBe('$0');
    expect(money(Number.NaN)).toBe('$0');
    expect(kmh(50)).toBe(180);
  });
});

describe('estadísticas', () => {
  it('las barras se acotan a 0–100 y la diferencia se mide en puntos', () => {
    expect(statPercent(35, 70)).toBe(50);
    expect(statPercent(999, 70)).toBe(100);
    expect(statPercent(-1, 70)).toBe(0);
    expect(statPercent(10, 0)).toBe(0);
    expect(statDelta(35, 42, 70)).toBe(10);
    expect(statDelta(42, 35, 70)).toBe(-10);
  });
});

describe('selectores', () => {
  const mod: Entry = { key: 'modSpoilers', kind: 'mod', section: 'body', label: 'Alerón', count: 3, names: ['Bajo', 'Medio', 'Alto'] };
  const tint: Entry = { key: 'windowTint', kind: 'index', section: 'details', label: 'Tintado', min: 0, count: 7 };
  const xenon: Entry = { key: 'xenonColor', kind: 'index', section: 'lights', label: 'Xenón', min: -1, count: 13 };

  it('las piezas van de «de serie» (-1) a la última y dan la vuelta', () => {
    expect(range(mod)).toEqual([-1, 2]);
    expect(step(mod, -1, 1)).toBe(0);
    expect(step(mod, 2, 1)).toBe(-1);
    expect(step(mod, -1, -1)).toBe(2);
    expect(range(tint)).toEqual([0, 6]);
    expect(range(xenon)).toEqual([-1, 12]);
  });

  it('nombres de los valores', () => {
    expect(valueLabel(mod, -1)).toBe('De serie');
    expect(valueLabel(mod, 1)).toBe('Medio');
    expect(valueLabel({ ...mod, names: undefined }, 1)).toBe('Opción 2');
    expect(valueLabel(tint, 5)).toBe('Limusina');
    expect(valueLabel(xenon, -1)).toBe('De serie');
    expect(valueLabel({ key: 'modEngine', kind: 'level', section: 'performance', label: 'Motor', count: 5 }, 2)).toBe('Nivel 3');
    expect(valueLabel({ key: 'neonEnabled', kind: 'neon', section: 'lights', label: 'Neones' }, [true, true, false, false])).toBe('2 de 4');
    expect(valueLabel({ key: 'extras', kind: 'extras', section: 'details', label: 'Extras' }, { 1: 0, 2: 1 })).toBe('1 activos');
  });

  it('compara valores simples y compuestos', () => {
    expect(same([1, 2, 3], [1, 2, 3])).toBe(true);
    expect(same([1, 2, 3], [1, 2, 4])).toBe(false);
    expect(same({ 1: 0 }, { 1: 0 })).toBe(true);
    expect(same(3, 3)).toBe(true);
    expect(same(undefined, -1)).toBe(false);
  });
});

describe('bloqueos de rendimiento', () => {
  it('autoservicio: solo hasta el nivel permitido', () => {
    expect(levelLock(engine, 1, 'self', 1, -1)).toBeNull();
    expect(levelLock(engine, 2, 'self', 6, -1)).toBe('Solo en un taller con mecánico');
    expect(toggleLock(turbo, 'self', 6, false)).toBe('Solo en un taller con mecánico');
  });

  it('taller de jugadores: según el nivel del mecánico', () => {
    expect(levelLock(engine, 3, 'mechanic', 2, -1)).toBe('Nivel 3 de mecánico');
    expect(levelLock(engine, 3, 'mechanic', 3, -1)).toBeNull();
    expect(toggleLock(turbo, 'mechanic', 2, false)).toBe('Nivel 3 de mecánico');
    expect(toggleLock(turbo, 'mechanic', 3, false)).toBeNull();
  });

  it('bajar de nivel o quitar nunca se bloquea', () => {
    expect(levelLock(engine, 1, 'self', 1, 4)).toBeNull();
    expect(toggleLock(turbo, 'self', 1, true)).toBeNull();
  });
});

describe('mecánico', () => {
  const levels = [{ xp: 0 }, { xp: 150 }, { xp: 500 }];
  it('progreso hacia el siguiente nivel', () => {
    expect(mechanicProgress(75, levels, 1)).toBe(50);
    expect(mechanicProgress(325, levels, 2)).toBe(50);
    expect(mechanicProgress(9999, levels, 3)).toBe(100);
  });
});
