// Lógica pura de la interfaz (probada con Vitest). El precio y los límites reales los decide el servidor.
import type { Entry, PerfRule, Rgb, Stats, Value } from './types';

export function money(n: number): string {
  const v = Math.round(Number.isFinite(n) ? n : 0);
  return '$' + String(Math.abs(v)).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export const kmh = (mps: number): number => Math.round((Number.isFinite(mps) ? mps : 0) * 3.6);

/** Porcentaje de una barra de estadística (0–100) según la escala de la configuración. */
export function statPercent(value: number, scale: number): number {
  if (!Number.isFinite(value) || !Number.isFinite(scale) || scale <= 0) return 0;
  return Math.max(0, Math.min(100, (value / scale) * 100));
}

/** Diferencia entre antes y ahora, en puntos de barra (redondeada a una décima). */
export function statDelta(before: number, now: number, scale: number): number {
  return Math.round((statPercent(now, scale) - statPercent(before, scale)) * 10) / 10;
}

export const STAT_KEYS: { key: keyof Stats; label: string }[] = [
  { key: 'speed', label: 'Velocidad' },
  { key: 'acceleration', label: 'Aceleración' },
  { key: 'braking', label: 'Frenada' },
  { key: 'traction', label: 'Agarre' },
];

export function same(a: Value, b: Value): boolean {
  if (a === b) return true;
  if (a == null || b == null || typeof a !== 'object' || typeof b !== 'object') return false;
  const ka = Object.keys(a), kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  return ka.every((k) => (a as Record<string, unknown>)[k] === (b as Record<string, unknown>)[k]);
}

/** Rango de valores de una entrada: [mínimo, máximo]. */
export function range(entry: Entry): [number, number] {
  const count = entry.count ?? 0;
  if (entry.kind === 'mod' || entry.kind === 'level') return [-1, count - 1];
  return [entry.min ?? 0, count - 1];
}

/** Siguiente valor del selector (da la vuelta al llegar al final). */
export function step(entry: Entry, value: number, dir: 1 | -1): number {
  const [min, max] = range(entry);
  if (max < min) return min;
  const v = Number.isFinite(value) ? value : min;
  const next = v + dir;
  if (next > max) return min;
  if (next < min) return max;
  return next;
}

const INDEX_NAMES: Record<string, Record<number, string>> = {
  windowTint: { 0: 'Sin tintar', 1: 'Negro total', 2: 'Ahumado oscuro', 3: 'Ahumado claro', 4: 'De serie', 5: 'Limusina', 6: 'Verde' },
  wheels: { 0: 'Deportivas', 1: 'Muscle', 2: 'Lowrider', 3: 'SUV', 4: 'Todoterreno', 5: 'Tuner', 6: 'Moto', 7: 'Gama alta',
    8: 'Taller clásico', 9: 'Taller a medida', 10: 'Monoplaza', 11: 'Calle', 12: 'Circuito' },
  xenonColor: { [-1]: 'De serie', 0: 'Blanco', 1: 'Azul', 2: 'Azul eléctrico', 3: 'Verde menta', 4: 'Verde lima', 5: 'Amarillo',
    6: 'Dorado', 7: 'Naranja', 8: 'Rojo', 9: 'Rosa claro', 10: 'Rosa fuerte', 11: 'Morado', 12: 'Luz negra' },
  paintType1: { 0: 'Normal', 1: 'Metalizado', 2: 'Perlado', 3: 'Mate', 4: 'Metal', 5: 'Cromado' },
  paintType2: { 0: 'Normal', 1: 'Metalizado', 2: 'Perlado', 3: 'Mate', 4: 'Metal', 5: 'Cromado' },
  livery: { [-1]: 'Sin librea' },
};

/** Texto del valor actual de una entrada. */
export function valueLabel(entry: Entry, value: Value): string {
  if (entry.kind === 'toggle') return value === true ? 'Montado' : 'No';
  if (entry.kind === 'level') return typeof value === 'number' && value >= 0 ? `Nivel ${value + 1}` : 'De serie';
  if (entry.kind === 'mod') {
    if (typeof value !== 'number' || value < 0) return 'De serie';
    return entry.names?.[value] ?? `Opción ${value + 1}`;
  }
  if (entry.kind === 'index') {
    const v = typeof value === 'number' ? value : (entry.min ?? 0);
    return INDEX_NAMES[entry.key]?.[v] ?? `${entry.key === 'plateIndex' ? 'Estilo' : 'Color'} ${v + (entry.key === 'plateIndex' ? 1 : 0)}`;
  }
  if (entry.kind === 'paint') return Array.isArray(value) ? `RGB ${(value as Rgb).join(', ')}` : `Color ${typeof value === 'number' ? value : 0}`;
  if (entry.kind === 'rgb') return Array.isArray(value) ? `RGB ${(value as Rgb).join(', ')}` : '—';
  if (entry.kind === 'neon') {
    const on = Array.isArray(value) ? (value as boolean[]).filter(Boolean).length : 0;
    return on === 0 ? 'Apagados' : `${on} de 4`;
  }
  if (entry.kind === 'extras') {
    const v = (value ?? {}) as Record<string, number>;
    const on = Object.values(v).filter((x) => x === 0).length;
    return `${on} activos`;
  }
  return '';
}

/**
 * ¿Por qué no se puede montar este nivel aquí? null = sí se puede.
 * Autoservicio: hasta npcMax. Taller de jugadores: según el nivel del mecánico.
 */
export function levelLock(rule: PerfRule | undefined, level: number, mode: 'self' | 'mechanic', mechLevel: number, current: number): string | null {
  if (!rule || level <= current) return null;
  if (mode === 'self') {
    const max = typeof rule.npcMax === 'number' ? rule.npcMax : -1;
    return level > max ? 'Solo en un taller con mecánico' : null;
  }
  const need = rule.mechLevel[level] ?? rule.mechLevel[rule.mechLevel.length - 1] ?? 1;
  return mechLevel < need ? `Nivel ${need} de mecánico` : null;
}

export function toggleLock(rule: PerfRule | undefined, mode: 'self' | 'mechanic', mechLevel: number, current: boolean): string | null {
  if (!rule || current) return null;
  if (mode === 'self') return rule.npcMax === true ? null : 'Solo en un taller con mecánico';
  const need = rule.mechLevel[0] ?? 1;
  return mechLevel < need ? `Nivel ${need} de mecánico` : null;
}

export const clampByte = (n: number): number => Math.max(0, Math.min(255, Math.round(Number.isFinite(n) ? n : 0)));
export const rgbCss = (c: Rgb): string => `rgb(${clampByte(c[0])}, ${clampByte(c[1])}, ${clampByte(c[2])})`;

/** Progreso (0–100) hacia el siguiente nivel de mecánico. */
export function mechanicProgress(xp: number, levels: { xp: number }[], level: number): number {
  const cur = levels[level - 1]?.xp ?? 0;
  const next = levels[level]?.xp;
  if (next === undefined || next <= cur) return 100;
  return Math.max(0, Math.min(100, ((xp - cur) / (next - cur)) * 100));
}
