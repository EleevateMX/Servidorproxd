import { clean, parse, safeColor, money } from '../src/shared/text';

describe('texto de terceros', () => {
  it('quita HTML, códigos de color de FiveM y caracteres de control', () => {
    expect(clean('<b>Hola</b> ^1mundo~r~!\u0007')).toBe('Hola mundo!');
    expect(clean('uno<br>dos')).toBe('uno\ndos');
    expect(clean('<script>alert(1)</script>ok')).toBe('alert(1)ok');
    expect(clean(42)).toBe('42');
    expect(clean({})).toBe('');
  });

  it('recorta lo que es demasiado largo', () => {
    expect(clean('a'.repeat(50), 10)).toHaveLength(10);
  });

  it('entiende negrita, cursiva, saltos y teclas', () => {
    expect(parse('Has cobrado **$450** hoy')).toEqual([
      { kind: 'text', text: 'Has cobrado ' }, { kind: 'bold', text: '$450' }, { kind: 'text', text: ' hoy' },
    ]);
    expect(parse('[E] Abrir', { keys: true })).toEqual([{ kind: 'key', text: 'E' }, { kind: 'text', text: ' Abrir' }]);
    expect(parse('[E] Abrir')[0]).toEqual({ kind: 'text', text: '[E] Abrir' });
    expect(parse('a\nb').map((c) => c.kind)).toEqual(['text', 'break', 'text']);
  });

  it('solo acepta colores seguros', () => {
    expect(safeColor('#5ce1ff')).toBe('#5ce1ff');
    expect(safeColor('rgba(10, 20, 30, 0.5)')).toBe('rgba(10, 20, 30, 0.5)');
    expect(safeColor('red; background:url(x)')).toBeUndefined();
    expect(safeColor('url(javascript:1)')).toBeUndefined();
  });

  it('dinero con separador de miles', () => {
    expect(money(95846)).toBe('$95,846');
    expect(money(-1200)).toBe('-$1,200');
  });
});
