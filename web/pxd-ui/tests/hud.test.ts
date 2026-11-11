import {
  ELEMENTS, cardinal, compassTicks, defaultSettings, initialState, level, paydayLabel, reduce, sanitizeSettings, unwrap, visible,
} from '../src/hud/model';

describe('HUD · ajustes', () => {
  it('ajustes por defecto: todo visible, escala 100 %, sin modo cine', () => {
    const s = defaultSettings();
    expect(s.scale).toBe(1);
    expect(s.cinema).toBe(false);
    for (const k of ELEMENTS) expect(s.show[k]).toBe(true);
  });

  it('sanea lo que llegue: escala acotada y solo elementos conocidos', () => {
    const s = sanitizeSettings({ scale: 9, cinema: 'sí', show: { vitals: false, hack: true, money: 'no' } });
    expect(s.scale).toBe(1.3);
    expect(s.cinema).toBe(false);
    expect(s.show.vitals).toBe(false);
    expect(s.show.money).toBe(false);
    expect((s.show as Record<string, boolean>).hack).toBeUndefined();
    expect(sanitizeSettings('x')).toEqual(defaultSettings());
    expect(sanitizeSettings({ scale: 0.93 }).scale).toBe(0.95);
  });
});

describe('HUD · estado', () => {
  it('aplica solo claves conocidas con su tipo', () => {
    let s = initialState();
    s = reduce(s, { action: 'tick', show: true, cash: 500, health: 'mal', evil: 1, street: 'Plaza Legion', vehicle: true });
    expect(s.show).toBe(true);
    expect(s.cash).toBe(500);
    expect(s.health).toBe(100);
    expect(s.street).toBe('Plaza Legion');
    expect((s as unknown as Record<string, unknown>).evil).toBeUndefined();
  });

  it('el dinero muestra la diferencia y la del banco lo indica', () => {
    let s = reduce(initialState(), { action: 'money', cash: 600, bank: 5000, changed: 'cash', amount: 100, minus: false });
    expect(s.cash).toBe(600);
    expect(s.delta?.text).toBe('+$100');
    s = reduce(s, { action: 'money', cash: 600, bank: 4000, changed: 'bank', amount: 1000, minus: true });
    expect(s.delta?.text).toBe('−$1,000 · banco');
    expect(s.delta?.rev).toBe(2);
  });

  it('la brújula no salta al cruzar el norte', () => {
    expect(unwrap(350, 2)).toBe(362);
    expect(unwrap(5, 355)).toBe(-5);
    expect(unwrap(100, 110)).toBe(110);
    let s = reduce(initialState(), { action: 'fast', compass: 350 });
    expect(s.compass).toBe(-10);                       // desde 0, el camino corto a 350 es −10
    s = reduce(s, { action: 'fast', compass: 4 });
    expect(s.compass).toBe(4);                         // y de −10 a 4 son 14 grados, sin dar la vuelta
  });

  it('puntos cardinales en español y marcas de la cinta', () => {
    expect(cardinal(0)).toBe('N');
    expect(cardinal(270)).toBe('O');
    expect(cardinal(315)).toBe('NO');
    expect(cardinal(364)).toBe('N');
    const ticks = compassTicks(350);
    const north = ticks.find((t) => t.label === 'N');
    expect(north?.key).toBe(360);
    expect(north?.offset).toBeCloseTo(10 / 60);
    expect(ticks.every((t) => Math.abs(t.offset) <= 1)).toBe(true);
  });

  it('niveles de aviso, también inversos (estrés)', () => {
    expect(level(50, 25, 10)).toBe('ok');
    expect(level(20, 25, 10)).toBe('low');
    expect(level(5, 25, 10)).toBe('critical');
    expect(level(90, 50, 20, true)).toBe('critical');
    expect(level(30, 50, 20, true)).toBe('ok');
  });

  it('cuenta atrás de la paga: minutos, segundos o nada', () => {
    expect(paydayLabel(720)).toBe('12 min');
    expect(paydayLabel(61)).toBe('2 min');
    expect(paydayLabel(45)).toBe('45 s');
    expect(paydayLabel(-1)).toBe('');
  });

  it('qué se dibuja: ajustes, vehículo y minimapa a pie', () => {
    let s = reduce(initialState(), { action: 'tick', show: true, vehicle: false });
    expect(visible(s, 'vehicle')).toBe(false);
    expect(visible(s, 'minimap')).toBe(true);
    s = reduce(s, { action: 'config', minimapOnFoot: false });
    expect(visible(s, 'minimap')).toBe(false);
    s = reduce(s, { action: 'tick', vehicle: true });
    expect(visible(s, 'minimap')).toBe(true);
    s = reduce(s, { action: 'settings', settings: { show: { vehicle: false } } });
    expect(visible(s, 'vehicle')).toBe(false);
    expect(visible(s, 'vitals')).toBe(true);
  });
});
