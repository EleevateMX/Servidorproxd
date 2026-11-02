// Mismas reglas que shared/multichar.lua (PXDChar.validateRegistration). El servidor vuelve a validar.
import type { Identity } from './types';

const SEP = /[ \-']/;
const LETTER = /\p{L}/u;

export function cleanName(s: string): string { return s.replace(/\s+/g, ' ').trim(); }

export function validateName(raw: string, label: string): string | null {
  const s = cleanName(raw ?? '');
  if (!s) return `Escribe el ${label}.`;
  const chars = Array.from(s);
  if (chars.length < 2) return `El ${label} es demasiado corto.`;
  if (chars.length > 25) return `El ${label} es demasiado largo (máximo 25).`;
  let words = 1;
  let prev: string | null = null;
  for (const c of chars) {
    if (SEP.test(c)) {
      if (!prev || !LETTER.test(prev)) return `El ${label} solo puede llevar letras.`;
      if (c === ' ') words++;
    } else if (!LETTER.test(c)) return `El ${label} solo puede llevar letras.`;
    prev = c;
  }
  if (!prev || !LETTER.test(prev)) return `El ${label} solo puede llevar letras.`;
  if (words > 3) return `El ${label} puede tener como máximo 3 palabras.`;
  return null;
}

export function validateBirthdate(s: string, min?: string, max?: string): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s ?? '');
  if (!m) return 'Elige la fecha de nacimiento.';
  const y = +m[1]!, mo = +m[2]!, d = +m[3]!;
  const days = [31, (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (mo < 1 || mo > 12 || d < 1 || d > days[mo - 1]!) return 'La fecha de nacimiento no es válida.';
  if ((min && s < min) || (max && s > max)) return `La fecha debe estar entre ${min ?? '…'} y ${max ?? '…'}.`;
  return null;
}

export type IdentityErrors = Partial<Record<'firstname' | 'lastname' | 'birthdate' | 'nationality', string>>;

export function validateIdentity(id: Identity): IdentityErrors {
  const e: IdentityErrors = {};
  const fn = validateName(id.firstname, 'nombre'); if (fn) e.firstname = fn;
  const ln = validateName(id.lastname, 'apellido'); if (ln) e.lastname = ln;
  const bd = validateBirthdate(id.birthdate, id.dateMin, id.dateMax); if (bd) e.birthdate = bd;
  const nat = cleanName(id.nationality ?? '');
  if (!nat) e.nationality = 'Elige la nacionalidad.';
  else if (id.limitNationalities && id.nationalities?.length && !id.nationalities.some((n) => n.toLowerCase() === nat.toLowerCase())) {
    e.nationality = 'Elige una nacionalidad de la lista.';
  }
  return e;
}

/** Edad cumplida a fecha `today` (AAAA-MM-DD). */
export function ageOf(birthdate: string, today: string): number | null {
  if (validateBirthdate(birthdate)) return null;
  const [y, m, d] = birthdate.split('-').map(Number) as [number, number, number];
  const [ty, tm, td] = today.split('-').map(Number) as [number, number, number];
  return ty - y - (tm < m || (tm === m && td < d) ? 1 : 0);
}
