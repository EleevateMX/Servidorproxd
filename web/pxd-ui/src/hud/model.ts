// Estado puro del HUD (sin DOM): se prueba con Vitest.
import { clamp } from '../shared/text';

export const ELEMENTS = ['vitals', 'money', 'alerts', 'clock', 'compass', 'location', 'voice', 'vehicle', 'minimap'] as const;
export type ElementId = (typeof ELEMENTS)[number];
export const ELEMENT_LABELS: Record<ElementId, string> = {
  vitals: 'Salud y necesidades',
  money: 'Dinero',
  alerts: 'Paga, multas y facturas',
  clock: 'Hora e ID',
  compass: 'Brújula',
  location: 'Calle y zona',
  voice: 'Voz',
  vehicle: 'Vehículo',
  minimap: 'Minimapa',
};
export const SCALE_MIN = 0.8;
export const SCALE_MAX = 1.3;

export interface Settings { scale: number; cinema: boolean; show: Record<ElementId, boolean> }

export function defaultSettings(): Settings {
  const show = {} as Record<ElementId, boolean>;
  for (const k of ELEMENTS) show[k] = true;
  return { scale: 1, cinema: false, show };
}

/** Mismas reglas que PXDHud.sanitizeSettings (shared/hud.lua). */
export function sanitizeSettings(raw: unknown): Settings {
  const out = defaultSettings();
  if (!raw || typeof raw !== 'object') return out;
  const r = raw as Record<string, unknown>;
  const scale = Number(r.scale);
  if (Number.isFinite(scale)) out.scale = Math.round(clamp(scale, SCALE_MIN, SCALE_MAX, 1) * 20) / 20;
  out.cinema = r.cinema === true;
  if (r.show && typeof r.show === 'object') {
    const s = r.show as Record<string, unknown>;
    for (const k of ELEMENTS) if (k in s) out.show[k] = s[k] === true;
  }
  return out;
}

export interface Warn { hunger: number; thirst: number; health: number; critical: number }

export interface HudState {
  show: boolean;
  cash: number; bank: number;
  health: number; armor: number; hunger: number; thirst: number; stress: number; oxygen: number;
  dead: boolean;
  talking: boolean; voice: string; voiceIndex: number; radio: number;
  fines: number; invoices: number; payday: number;
  publicId: string; clock: string; street: string; zone: string;
  vehicle: boolean;
  speed: number; rpm: number; gear: string; fuel: number; engine: number; body: number;
  engineOn: boolean; lights: number; locked: boolean; seatbelt: boolean; harness: boolean; cruise: boolean;
  compass: number;          // rumbo sin envolver (puede pasar de 360) para animar sin saltos
  // configuración
  speedUnit: 'kmh' | 'mph'; warn: Warn; lowFuel: number; minimapOnFoot: boolean;
  settings: Settings; settingsOpen: boolean;
  delta: { text: string; minus: boolean; rev: number } | null;
}

export function initialState(): HudState {
  return {
    show: false, cash: 0, bank: 0, health: 100, armor: 0, hunger: 100, thirst: 100, stress: 0, oxygen: -1, dead: false,
    talking: false, voice: 'Normal', voiceIndex: 2, radio: 0, fines: 0, invoices: 0, payday: -1,
    publicId: '', clock: '--:--', street: '', zone: '', vehicle: false,
    speed: 0, rpm: 0, gear: 'P', fuel: 0, engine: 100, body: 100, engineOn: false, lights: 0, locked: false,
    seatbelt: false, harness: false, cruise: false, compass: 0,
    speedUnit: 'kmh', warn: { hunger: 25, thirst: 25, health: 35, critical: 10 }, lowFuel: 20, minimapOnFoot: true,
    settings: defaultSettings(), settingsOpen: false, delta: null,
  };
}

const NUM: (keyof HudState)[] = ['cash', 'bank', 'health', 'armor', 'hunger', 'thirst', 'stress', 'oxygen', 'voiceIndex', 'radio',
  'fines', 'invoices', 'payday', 'speed', 'rpm', 'fuel', 'engine', 'body', 'lights'];
const BOOL: (keyof HudState)[] = ['show', 'dead', 'talking', 'vehicle', 'engineOn', 'locked', 'seatbelt', 'harness', 'cruise'];
const STR: (keyof HudState)[] = ['voice', 'publicId', 'clock', 'street', 'zone', 'gear'];

/** Rumbo sin envolver: el equivalente a `deg` más cercano a `prev` (350 → 2 pasa a 362). */
export function unwrap(prev: number, deg: number): number {
  const d = ((((deg - prev) % 360) + 540) % 360) - 180;
  return prev + d;
}

const moneyFmt = (n: number) => (n < 0 ? '-$' : '$') + Math.abs(Math.floor(n)).toLocaleString('en-US');

/** Aplica un mensaje del cliente Lua. Solo acepta claves y tipos conocidos. */
export function reduce(s: HudState, m: Record<string, unknown>): HudState {
  switch (m.action) {
    case 'hide': return s.show ? { ...s, show: false } : s;
    case 'config': {
      const next = { ...s };
      if (m.speedUnit === 'mph' || m.speedUnit === 'kmh') next.speedUnit = m.speedUnit;
      if (typeof m.lowFuel === 'number') next.lowFuel = m.lowFuel;
      if (typeof m.minimapOnFoot === 'boolean') next.minimapOnFoot = m.minimapOnFoot;
      if (m.warn && typeof m.warn === 'object') next.warn = { ...s.warn, ...(m.warn as Partial<Warn>) };
      if (m.settings) next.settings = sanitizeSettings(m.settings);
      return next;
    }
    case 'settings': return { ...s, settings: sanitizeSettings(m.settings) };
    case 'settingsPanel': return { ...s, settingsOpen: m.open === true, settings: m.settings ? sanitizeSettings(m.settings) : s.settings };
    case 'money': {
      const next = { ...s };
      if (typeof m.cash === 'number') next.cash = m.cash;
      if (typeof m.bank === 'number') next.bank = m.bank;
      const amount = Math.abs(Number(m.amount) || 0);
      if (amount > 0) {
        const minus = m.minus === true;
        next.delta = { text: (minus ? '−' : '+') + moneyFmt(amount) + (m.changed === 'bank' ? ' · banco' : ''), minus, rev: (s.delta?.rev ?? 0) + 1 };
      }
      return next;
    }
    case 'tick': case 'fast': {
      const next = { ...s } as Record<string, unknown>;
      for (const k of NUM) if (typeof m[k] === 'number' && Number.isFinite(m[k] as number)) next[k] = m[k];
      for (const k of BOOL) if (typeof m[k] === 'boolean') next[k] = m[k];
      for (const k of STR) if (typeof m[k] === 'string') next[k] = (m[k] as string).slice(0, 120);
      if (typeof m.compass === 'number' && Number.isFinite(m.compass)) next.compass = unwrap(s.compass, m.compass);
      return next as unknown as HudState;
    }
    default: return s;
  }
}

export type Level = 'ok' | 'low' | 'critical';

/** Nivel de una barra; `inverse` cuando lo malo es tener mucho (estrés). */
export function level(value: number, warn: number, critical: number, inverse = false): Level {
  let v = clamp(value, 0, 100, 0);
  if (inverse) v = 100 - v;
  if (v <= critical) return 'critical';
  if (v <= warn) return 'low';
  return 'ok';
}

const CARDINALS = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
export function cardinal(deg: number): string {
  const d = ((deg % 360) + 360) % 360;
  return CARDINALS[Math.floor((d + 22.5) / 45) % 8] as string;
}

export interface Tick { key: number; offset: number; label: string; major: boolean }

/** Marcas visibles de la cinta de la brújula: cada `step` grados, a ±`span` del rumbo. */
export function compassTicks(heading: number, span = 60, step = 15): Tick[] {
  const out: Tick[] = [];
  const first = Math.ceil((heading - span) / step) * step;
  for (let a = first; a <= heading + span; a += step) {
    const norm = ((a % 360) + 360) % 360;
    const major = norm % 45 === 0;
    out.push({ key: a, offset: (a - heading) / span, label: major ? cardinal(norm) : norm % 30 === 0 ? String(norm) : '', major });
  }
  return out;
}

/** «12 min», «45 s» o '' si no hay dato. */
export function paydayLabel(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return '';
  if (seconds >= 60) return `${Math.ceil(seconds / 60)} min`;
  return `${Math.max(0, Math.round(seconds))} s`;
}

export function maxSpeed(unit: 'kmh' | 'mph'): number { return unit === 'mph' ? 160 : 260; }

/** Qué elementos se dibujan según los ajustes y el estado. */
export function visible(s: HudState, id: ElementId): boolean {
  if (!s.settings.show[id]) return false;
  if (id === 'vehicle') return s.vehicle;
  if (id === 'minimap') return s.vehicle || s.minimapOnFoot;
  return true;
}
