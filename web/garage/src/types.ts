// Contrato con client/main.lua de pxd_garage.
export type Kind = 'level' | 'toggle' | 'mod' | 'index' | 'paint' | 'rgb' | 'neon' | 'extras';
export type Rgb = [number, number, number];
export type Value = number | boolean | Rgb | boolean[] | Record<string, number> | undefined | null;

export interface Entry {
  key: string; kind: Kind; section: string; label: string;
  min?: number; count?: number; names?: string[]; ids?: number[]; camera?: string;
}
export interface Section { id: string; label: string; camera: string }
export interface QuoteLine { key: string; label: string; price: number }
export interface Quote { lines: QuoteLine[]; total: number; count: number; blocked?: string | null }
export interface Stats { speed: number; acceleration: number; braking: number; traction: number }
export interface StatsData { before: Stats; now: Stats; scale: Stats }
export interface Mechanic { level: number; name: string; xp: number; next?: number | null; jobs?: number }
export interface PerfRule { label: string; npcMax: number | boolean; mechLevel: number[] }

export interface OpenData {
  vehicle: { name: string; plate: string; base: number };
  zone: string; mode: 'self' | 'mechanic'; ownsIt: boolean; ownerName?: string | null;
  methods: Record<string, boolean>; mechanic: Mechanic; factor: number;
  sections: Section[]; catalog: Entry[]; values: Record<string, Value>;
  performance: Record<string, PerfRule>; levels: { xp: number; name: string }[];
  stats: StatsData; quote: Quote;
}
export interface SetResponse { ok: boolean; quote?: Quote; stats?: Stats; refresh?: Record<string, { count: number; names: string[] }> }
export interface ResetResponse { ok: boolean; values?: Record<string, Value>; quote?: Quote; stats?: Stats }
export interface AppliedMessage {
  ok: boolean; message?: string; total?: number; pay?: string; xp?: number; mechanic?: Mechanic | null;
  values?: Record<string, Value>; quote?: Quote; stats?: StatsData;
}
