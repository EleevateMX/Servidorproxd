import { MAX_STACK, dropNotice, leaveNotice, pushNotice, toAlert, toNotice, toProgress, toTextUi, tone, type Notice } from '../src/kit/model';

const notice = (d: Record<string, unknown>) => toNotice(d) as Notice;

describe('avisos', () => {
  it('convierte los tipos de ox_lib y qbx_core en cuatro tonos', () => {
    expect(tone('inform')).toBe('info');
    expect(tone('primary')).toBe('info');
    expect(tone('success')).toBe('success');
    expect(tone('warning')).toBe('warning');
    expect(tone('error')).toBe('error');
    expect(tone(undefined)).toBe('info');
  });

  it('normaliza un NotifyProps: duración, posición y color seguros', () => {
    const n = notice({ title: 'Hola', description: 'x', type: 'error', duration: 999999, position: 'nope', iconColor: 'javascript:1' });
    expect(n.tone).toBe('error');
    expect(n.duration).toBe(30000);
    expect(n.position).toBe('top-right');
    expect(n.color).toBeUndefined();
    expect(toNotice({})).toBeNull();
    expect(toNotice(null)).toBeNull();
    expect(notice({ description: 'x', status: 'success' }).tone).toBe('success');   // lib.defaultNotify
  });

  it('el mismo id sustituye al anterior y cuenta la repetición', () => {
    let list: Notice[] = [];
    list = pushNotice(list, notice({ id: 'hambre', description: 'Tienes hambre' }));
    list = pushNotice(list, notice({ id: 'hambre', description: 'Tienes hambre' }));
    expect(list).toHaveLength(1);
    expect(list[0]?.count).toBe(2);
    expect(list[0]?.rev).toBe(1);
    list = pushNotice(list, notice({ description: 'otro' }));
    expect(list).toHaveLength(2);
  });

  it('como mucho MAX_STACK por esquina: se va el más antiguo', () => {
    let list: Notice[] = [];
    for (let i = 0; i < MAX_STACK + 2; i++) list = pushNotice(list, notice({ description: `n${i}` }));
    expect(list).toHaveLength(MAX_STACK);
    expect(list[0]?.description).toBe('n2');
  });

  it('salir solo afecta a la revisión que venció (un aviso repetido se queda)', () => {
    let list = pushNotice([], notice({ id: 'a', description: 'x' }));
    list = pushNotice(list, notice({ id: 'a', description: 'x' }));      // rev 1
    list = leaveNotice(list, 'id:a', 0);                                 // vence el temporizador viejo
    expect(list[0]?.leaving).toBeUndefined();
    list = leaveNotice(list, 'id:a', 1);
    expect(list[0]?.leaving).toBe(true);
    expect(dropNotice(list, 'id:a')).toHaveLength(0);
  });
});

describe('indicación, progreso y diálogo', () => {
  it('Text UI: texto obligatorio y posición conocida', () => {
    expect(toTextUi({ text: '[E] Abrir' })).toEqual({ text: '[E] Abrir', position: 'right-center', color: undefined });
    expect(toTextUi({ text: 'x', position: 'top-center' })?.position).toBe('top-center');
    expect(toTextUi({ text: '' })).toBeNull();
  });

  it('progreso: duración válida, círculo y posición', () => {
    expect(toProgress({ label: 'Reparando', duration: 5000 }, false, 1)).toEqual({ label: 'Reparando', duration: 5000, circle: false, position: 'bottom', rev: 1 });
    expect(toProgress({ duration: 2000, position: 'middle' }, true, 2)?.position).toBe('middle');
    expect(toProgress({ duration: 0 }, false, 3)).toBeNull();
    expect(toProgress({ duration: 'x' }, false, 3)).toBeNull();
  });

  it('diálogo: etiquetas por defecto en español y cancelar opcional', () => {
    const a = toAlert({ header: 'Vender', content: '¿Seguro?' });
    expect(a).toMatchObject({ cancel: false, confirmLabel: 'Aceptar', cancelLabel: 'Cancelar' });
    expect(toAlert({ header: 'x', cancel: true, labels: { confirm: 'Vender' } })).toMatchObject({ cancel: true, confirmLabel: 'Vender' });
    expect(toAlert({})).toBeNull();
  });
});
