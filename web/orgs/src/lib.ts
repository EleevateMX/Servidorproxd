// Lógica pura de la interfaz (con pruebas en __tests__/lib.test.ts). El servidor vuelve a validar todo.
import type { CreateInfo, Font, Member, OrgView } from './types';

export const money = (n: number | null | undefined): string => '$' + Math.floor(n ?? 0).toLocaleString('es-ES').replace(/ /g, '.');

export function fontFamily(fonts: Font[] | undefined, id: string): string {
  const f = (fonts ?? []).find((x) => x.id === id);
  return `'${f ? f.family : 'Sora'}', 'Sora', 'Inter', sans-serif`;
}

/** Emblema por iniciales (mismo criterio que O.emblemFrom en Lua): hasta 3 letras. */
export function emblemFrom(name: string): string {
  const out: string[] = [];
  for (const word of name.split(/[\s\-.&]+/)) {
    const first = word.normalize('NFD').replace(/[̀-ͯ]/g, '').charAt(0).toUpperCase();
    if (/^[A-Z0-9]$/.test(first)) out.push(first);
    if (out.length === 3) break;
  }
  return out.length ? out.join('') : 'ORG';
}

/** Muestra corta del nombre para las tarjetas de tipografía (palabras enteras, unas 10 letras). */
export function sampleOf(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean);
  let out = '';
  for (const w of words) {
    if (out && (out + ' ' + w).length > 10) break;
    out = out ? out + ' ' + w : w;
  }
  return (out || 'Nombre').slice(0, 12);
}

export const cleanEmblem = (s: string): string => s.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 3);

/** Progreso (0–1) hacia el siguiente nivel. 1 si ya es el máximo. */
export function repProgress(org: Pick<OrgView, 'reputation' | 'levelRep' | 'nextRep'>): number {
  if (!org.nextRep || org.nextRep <= org.levelRep) return 1;
  return Math.max(0, Math.min(1, (org.reputation - org.levelRep) / (org.nextRep - org.levelRep)));
}

/** Rangos que `actor` puede poner a `m`: por debajo del suyo, distintos del actual y nunca el más alto. */
export function gradeOptions(org: Pick<OrgView, 'grade' | 'grades' | 'perms'>, m: Member, selfId: string): { level: number; name: string }[] {
  if (!org.perms.manage || m.citizenid === selfId || m.grade >= org.grade) return [];
  const top = Math.max(...org.grades.map((g) => g.level));
  return org.grades.filter((g) => g.level < org.grade && g.level < top && g.level !== m.grade);
}

export const canKick = (org: Pick<OrgView, 'grade' | 'perms'>, m: Member, selfId: string): boolean =>
  org.perms.manage && m.citizenid !== selfId && m.grade < org.grade;

export interface CreateForm { type: string; name: string; color: string; font: string; emblem: string; motto: string; founders: number[] }

/** Motivo por el que aún no se puede enviar la fundación, o null si está lista. */
export function createBlocker(form: CreateForm, info: CreateInfo): string | null {
  if (info.blocked) return 'Ya perteneces a una banda. Sal de ella primero.';
  const name = form.name.trim();
  if (name.length < info.nameMin || name.length > info.nameMax) return `El nombre debe tener de ${info.nameMin} a ${info.nameMax} caracteres.`;
  if (!info.types.some((t) => t.id === form.type)) return 'Elige el tipo de organización.';
  if (!cleanEmblem(form.emblem)) return 'El emblema son de 1 a 3 letras o números.';
  if (form.motto.length > info.mottoMax) return 'El lema es demasiado largo.';
  if (1 + form.founders.length < info.minFounders) return `Elige ${info.minFounders - 1} cofundador(es) entre las personas que tienes cerca.`;
  if (!info.staff) {
    const missing = info.requirements.find((r) => r.id !== 'founders' && !r.ok);
    if (missing) return `Requisito pendiente: ${missing.label}.`;
  }
  return null;
}

export function timeLeft(expires: number, now: number): string {
  const s = Math.max(0, Math.floor(expires - now));
  if (s < 60) return `${s} s`;
  return `${Math.ceil(s / 60)} min`;
}

const ACTIONS: Record<string, string> = {
  requested: 'Solicitud enviada', official: 'Organización oficial', invite: 'Invitación', join: 'Se une', kick: 'Expulsión',
  promote: 'Ascenso', demote: 'Descenso', transfer: 'Liderazgo transferido', leave: 'Sale', deposit: 'Aportación', withdraw: 'Retiro',
  identity: 'Identidad', reputation: 'Reputación', dissolved: 'Disuelta', rejected: 'Rechazada',
};
export const actionLabel = (a: string): string => ACTIONS[a] ?? a;
