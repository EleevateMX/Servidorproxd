import { describe, expect, it } from 'vitest';
import { ageOf, validateBirthdate, validateIdentity, validateName } from '../validation';

describe('identidad (mismas reglas que PXDChar.validateRegistration)', () => {
  it('nombres con acentos, guion y apóstrofo; sin números ni más de 3 palabras', () => {
    expect(validateName('José Ángel', 'nombre')).toBeNull();
    expect(validateName("O'Neil-Ríos", 'apellido')).toBeNull();
    expect(validateName('A', 'nombre')).toMatch(/corto/);
    expect(validateName('R2D2', 'nombre')).toMatch(/letras/);
    expect(validateName('Uno Dos Tres Cuatro', 'nombre')).toMatch(/3 palabras/);
    expect(validateName('x'.repeat(26), 'nombre')).toMatch(/largo/);
    expect(validateName('Ana-', 'nombre')).toMatch(/letras/);
  });
  it('fechas reales y dentro del rango', () => {
    expect(validateBirthdate('2000-02-29', '1930-01-01', '2006-12-31')).toBeNull();
    expect(validateBirthdate('2001-02-29')).toMatch(/no es válida/);
    expect(validateBirthdate('2010-01-01', '1930-01-01', '2006-12-31')).toMatch(/entre/);
    expect(ageOf('1997-03-12', '2026-11-02')).toBe(29);
  });
  it('nacionalidad de la lista cuando está limitada', () => {
    const base = { firstname: 'Ana', lastname: 'Lima', gender: 1 as const, birthdate: '1995-05-05', nationality: 'Martian', nationalities: ['Mexican'], limitNationalities: true };
    expect(validateIdentity(base).nationality).toMatch(/lista/);
    expect(validateIdentity({ ...base, nationality: 'mexican' })).toEqual({});
  });
});
