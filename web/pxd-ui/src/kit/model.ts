// Estado puro del kit (sin DOM): se prueba con Vitest.
import { clamp, clean, safeColor } from '../shared/text';

export type Tone = 'info' | 'success' | 'warning' | 'error';
export type Corner =
  | 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left' | 'center-right' | 'center-left';

export interface Notice {
  key: string;            // identidad en la pila (id del emisor o uno generado)
  title: string;
  description: string;
  tone: Tone;
  duration: number;       // ms
  showDuration: boolean;
  position: Corner;
  color?: string;         // iconColor seguro
  count: number;          // veces repetido (mismo id)
  rev: number;            // cambia al repetirse: reinicia la barra de tiempo
  leaving?: boolean;
}

export const MAX_STACK = 5;
export const DEFAULT_DURATION = 3000;
const CORNERS: Corner[] = ['top', 'top-right', 'top-left', 'bottom', 'bottom-right', 'bottom-left', 'center-right', 'center-left'];

/** Tipos de ox_lib y de qbx_core ('inform', 'primary', 'police'…) a nuestros cuatro tonos. */
export function tone(raw: unknown): Tone {
  switch (typeof raw === 'string' ? raw.toLowerCase() : '') {
    case 'success': return 'success';
    case 'warning': case 'warn': return 'warning';
    case 'error': case 'danger': return 'error';
    default: return 'info';
  }
}

export function corner(raw: unknown, fallback: Corner = 'top-right'): Corner {
  return CORNERS.includes(raw as Corner) ? (raw as Corner) : fallback;
}

let seq = 0;

/** Convierte el `data` de lib.notify (NotifyProps) en un aviso nuestro. null = nada que mostrar. */
export function toNotice(data: unknown): Notice | null {
  if (!data || typeof data !== 'object') return null;
  const d = data as Record<string, unknown>;
  const title = clean(d.title, 80);
  const description = clean(d.description, 400);
  if (!title && !description) return null;
  const id = typeof d.id === 'string' || typeof d.id === 'number' ? String(d.id).slice(0, 120) : '';
  return {
    key: id ? `id:${id}` : `n:${++seq}`,
    title,
    description,
    tone: tone(d.type ?? d.status),
    duration: clamp(d.duration, 1000, 30000, DEFAULT_DURATION),
    showDuration: d.showDuration !== false,
    position: corner(d.position),
    color: safeColor(d.iconColor),
    count: 1,
    rev: 0,
  };
}

/** Añade un aviso: si ya hay uno con el mismo id lo sustituye y cuenta la repetición. */
export function pushNotice(list: Notice[], n: Notice): Notice[] {
  const i = list.findIndex((x) => x.key === n.key && !x.leaving);
  if (i >= 0) {
    const prev = list[i] as Notice;
    const next = list.slice();
    next[i] = { ...n, count: prev.count + 1, rev: prev.rev + 1 };
    return next;
  }
  const next = [...list, n];
  // Límite por esquina: se van los más antiguos.
  const same = next.filter((x) => x.position === n.position && !x.leaving);
  if (same.length > MAX_STACK) {
    const drop = same[0] as Notice;
    return next.filter((x) => x !== drop);
  }
  return next;
}

export function leaveNotice(list: Notice[], key: string, rev: number): Notice[] {
  return list.map((x) => (x.key === key && x.rev === rev ? { ...x, leaving: true } : x));
}

export function dropNotice(list: Notice[], key: string): Notice[] {
  return list.filter((x) => !(x.key === key && x.leaving));
}

// ── Text UI ────────────────────────────────────────────
export type TextPos = 'right-center' | 'left-center' | 'top-center' | 'bottom-center';
export interface TextUi { text: string; position: TextPos; color?: string }

export function toTextUi(data: unknown): TextUi | null {
  if (!data || typeof data !== 'object') return null;
  const d = data as Record<string, unknown>;
  const text = clean(d.text, 300);
  if (!text) return null;
  const pos = ['right-center', 'left-center', 'top-center', 'bottom-center'].includes(d.position as string) ? (d.position as TextPos) : 'right-center';
  return { text, position: pos, color: safeColor(d.iconColor) };
}

// ── Progreso ───────────────────────────────────────────
export interface Progress { label: string; duration: number; circle: boolean; position: 'middle' | 'bottom'; rev: number }

export function toProgress(data: unknown, circle: boolean, rev: number): Progress | null {
  if (!data || typeof data !== 'object') return null;
  const d = data as Record<string, unknown>;
  const duration = clamp(d.duration, 0, 600000, 0);
  if (duration <= 0) return null;
  return { label: clean(d.label, 80), duration, circle, position: d.position === 'middle' ? 'middle' : 'bottom', rev };
}

// ── Diálogo de confirmación ────────────────────────────
export interface Alert { header: string; content: string; cancel: boolean; confirmLabel: string; cancelLabel: string; centered: boolean }

export function toAlert(data: unknown): Alert | null {
  if (!data || typeof data !== 'object') return null;
  const d = data as Record<string, unknown>;
  const header = clean(d.header, 120);
  const content = clean(d.content, 1500);
  if (!header && !content) return null;
  const labels = (d.labels && typeof d.labels === 'object' ? d.labels : {}) as Record<string, unknown>;
  return {
    header,
    content,
    cancel: d.cancel === true,
    confirmLabel: clean(labels.confirm, 30) || 'Aceptar',
    cancelLabel: clean(labels.cancel, 30) || 'Cancelar',
    centered: d.centered === true,
  };
}
