import { describe, expect, it } from 'vitest';
import type { Inventory, ItemData } from '../src/contract';
import { canCraftItem, canPurchaseItem, itemDurability } from '../src/helpers';
import { initialState, planDrop, reducer, type State } from '../src/store';

const NOW = 1_700_000_000;
const items: Record<string, ItemData> = {
  water: { label: 'Agua', stack: true, count: 0 },
  phone: { label: 'Teléfono', stack: false, count: 0 },
  iron: { label: 'Hierro', stack: true, count: 5 },
};
const player = (list: Inventory['items']): Inventory => ({ id: '7', type: 'player', slots: 6, maxWeight: 30000, items: list });
const ground = (): Inventory => ({ id: 'newdrop', type: 'newdrop', slots: 4, maxWeight: 30000, items: [] });

function base(left = player([{ slot: 1, name: 'water', count: 4, weight: 2000 }, { slot: 3, name: 'phone', count: 1, weight: 190, metadata: { serial: 'A1' } }]), right = ground()): State {
  let s = reducer({ ...initialState, items }, { type: 'setup', data: { leftInventory: left, rightInventory: right }, now: NOW });
  return s;
}

describe('setupInventory / init', () => {
  it('rellena todas las ranuras y abre la interfaz', () => {
    const s = base();
    expect(s.visible).toBe(true);
    expect(s.left.items).toHaveLength(6);
    expect(s.left.items[1]).toEqual({ slot: 2 });
    expect(s.right.items).toHaveLength(4);
  });
  it('init guarda objetos, idioma y ruta de imágenes sin abrir', () => {
    const s = reducer(initialState, {
      type: 'init',
      data: { locale: { ui_use: 'Use' }, items, imagepath: 'nui://ox_inventory/web/images', leftInventory: player([]) },
      now: NOW,
    });
    expect(s.visible).toBe(false);
    expect(s.items.water?.label).toBe('Agua');
    expect(s.left.items).toHaveLength(6);
  });
  it('setup solo con el inventario de la derecha (suelo) conserva los bolsillos', () => {
    const s = reducer(base(), { type: 'setup', data: { rightInventory: { ...ground(), id: 'drop-1', type: 'drop' } }, now: NOW });
    expect(s.left.items[0].name).toBe('water');
    expect(s.right.type).toBe('drop');
  });
});

describe('refreshSlots', () => {
  it('sin inventario o "player" va a la izquierda; cualquier otro, a la derecha', () => {
    let s = base();
    s = reducer(s, { type: 'refresh', data: { items: [{ item: { slot: 2, name: 'water', count: 1, weight: 500 } }, { item: { slot: 1, name: 'iron', count: 2, weight: 200 }, inventory: 'trunkABC' }] }, now: NOW });
    expect(s.left.items[1].name).toBe('water');
    expect(s.right.items[0].name).toBe('iron');
  });
  it('itemCount suma a los objetos conocidos (crafteo)', () => {
    const s = reducer(base(), { type: 'refresh', data: { itemCount: { iron: 3, nope: 1 } }, now: NOW });
    expect(s.items.iron?.count).toBe(8);
  });
  it('weightData y slotsData actualizan el inventario indicado', () => {
    let s = reducer(base(), { type: 'refresh', data: { weightData: { inventoryId: '7', maxWeight: 50000 } }, now: NOW });
    expect(s.left.maxWeight).toBe(50000);
    s = reducer(s, { type: 'refresh', data: { slotsData: { inventoryId: '7', slots: 8 } }, now: NOW });
    expect(s.left.items).toHaveLength(8);
    expect(s.left.items[0].name).toBe('water');
  });
});

describe('movimientos (contrato swapItems)', () => {
  it('a una ranura vacía: move optimista y petición con la cantidad', () => {
    const s = base();
    const plan = planDrop(s, { type: 'player', slot: 1 }, { type: 'player', slot: 2 }, NOW)!;
    expect(plan.callback).toBe('swapItems');
    expect(plan.request).toEqual({ fromSlot: 1, fromType: 'player', toSlot: 2, toType: 'player', count: 4 });
    const next = plan.optimistic.reduce(reducer, s);
    expect(next.left.items[1]).toMatchObject({ name: 'water', count: 4, weight: 2000, slot: 2 });
    expect(next.left.items[0]).toEqual({ slot: 1 });
  });
  it('Mayús: la mitad; cantidad fijada: esa cantidad', () => {
    const half = planDrop({ ...base(), shiftPressed: true }, { type: 'player', slot: 1 }, { type: 'player', slot: 2 }, NOW)!;
    expect(half.request.count).toBe(2);
    const fixed = planDrop({ ...base(), itemAmount: 3 }, { type: 'player', slot: 1 }, { type: 'player', slot: 2 }, NOW)!;
    expect(fixed.request.count).toBe(3);
    const next = fixed.optimistic.reduce(reducer, base());
    expect(next.left.items[0]).toMatchObject({ count: 1, weight: 500 });
    expect(next.left.items[1]).toMatchObject({ count: 3, weight: 1500 });
  });
  it('dividir: cantidad explícita a la primera ranura vacía (aunque haya cantidad general)', () => {
    const s = { ...base(), itemAmount: 1 };
    const plan = planDrop(s, { type: 'player', slot: 1 }, { type: 'player', slot: 2 }, NOW, 2)!;
    expect(plan.request.count).toBe(2);
  });
  it('apilar si es el mismo objeto con la misma metadata; si no, intercambiar', () => {
    let s = base(player([{ slot: 1, name: 'water', count: 4, weight: 2000 }, { slot: 2, name: 'water', count: 1, weight: 500 }, { slot: 3, name: 'phone', count: 1, weight: 190 }]));
    const stack = planDrop(s, { type: 'player', slot: 1 }, { type: 'player', slot: 2 }, NOW)!;
    expect(stack.optimistic[0].type).toBe('stack');
    expect(stack.optimistic.reduce(reducer, s).left.items[1]).toMatchObject({ count: 5, weight: 2500 });
    const swap = planDrop(s, { type: 'player', slot: 1 }, { type: 'player', slot: 3 }, NOW)!;
    expect(swap.optimistic[0].type).toBe('swap');
    s = swap.optimistic.reduce(reducer, s);
    expect(s.left.items[0]).toMatchObject({ name: 'phone', slot: 1 });
    expect(s.left.items[2]).toMatchObject({ name: 'water', slot: 3 });
  });
  it('sin destino: al otro inventario (tirar al suelo) en el primer hueco o pila', () => {
    const plan = planDrop(base(), { type: 'player', slot: 1 }, undefined, NOW)!;
    expect(plan.request).toMatchObject({ toType: 'newdrop', toSlot: 1, count: 4 });
  });
  it('si el servidor rechaza, se vuelve al estado anterior', () => {
    const s = base();
    const plan = planDrop(s, { type: 'player', slot: 1 }, { type: 'player', slot: 2 }, NOW)!;
    let t = reducer(s, { type: 'pending' });
    t = plan.optimistic.reduce(reducer, t);
    expect(t.left.items[1].name).toBe('water');
    t = reducer(t, { type: 'rejected' });
    expect(t.left.items[0].name).toBe('water');
    expect(t.left.items[1].name).toBeUndefined();
    expect(t.busy).toBe(false);
  });
  it('no se suelta en tienda/fabricación, ni sobre sí mismo, ni un contenedor dentro de otro', () => {
    const shop: Inventory = { id: 'shop', type: 'shop', slots: 2, items: [{ slot: 1, name: 'water', count: 10, weight: 500, price: 5 }] };
    expect(planDrop(base(undefined, shop), { type: 'player', slot: 1 }, { type: 'shop', slot: 2 }, NOW)).toBeNull();
    expect(planDrop(base(), { type: 'player', slot: 1 }, { type: 'player', slot: 1 }, NOW)).toBeNull();
    const bag = player([{ slot: 1, name: 'water', count: 1, weight: 1, metadata: { container: 'bag1' } }]);
    const cont: Inventory = { id: 'bag2', type: 'container', slots: 2, items: [] };
    expect(planDrop(base(bag, cont), { type: 'player', slot: 1 }, { type: 'container', slot: 1 }, NOW)).toBeNull();
  });
});

describe('tienda y fabricación (buyItem / craftItem)', () => {
  const shop: Inventory = { id: 'shop', type: 'shop', slots: 2, items: [{ slot: 1, name: 'water', count: 10, weight: 500, price: 5 }] };
  it('comprar: 1 por defecto, la cantidad elegida con tope de existencias, sin cambio optimista', () => {
    const s = base(undefined, shop);
    const one = planDrop(s, { type: 'shop', slot: 1 }, { type: 'player', slot: 2 }, NOW)!;
    expect(one.callback).toBe('buyItem');
    expect(one.request).toEqual({ fromSlot: 1, fromType: 'shop', toSlot: 2, toType: 'player', count: 1 });
    expect(one.optimistic).toHaveLength(0);
    expect(planDrop({ ...s, itemAmount: 50 }, { type: 'shop', slot: 1 }, { type: 'player', slot: 2 }, NOW)!.request.count).toBe(10);
  });
  it('solo hacia los bolsillos', () => {
    expect(planDrop(base(undefined, shop), { type: 'shop', slot: 1 }, undefined, NOW)).toBeNull();
  });
  it('fabricar usa craftItem', () => {
    const craft: Inventory = { id: 'bench', type: 'crafting', slots: 1, items: [{ slot: 1, name: 'phone', count: 1, weight: 1, ingredients: { iron: 2 } }] };
    const p = planDrop(base(undefined, craft), { type: 'crafting', slot: 1 }, { type: 'player', slot: 2 }, NOW)!;
    expect(p.callback).toBe('craftItem');
  });
});

describe('reglas de la interfaz original', () => {
  it('compra con rango: número mínimo o lista exacta', () => {
    const inv = { type: 'shop', groups: { police: 0 } };
    const item = { slot: 1, name: 'water', count: 1, weight: 1, grade: 2 };
    expect(canPurchaseItem(item, inv, { police: 3 })).toBe(true);
    expect(canPurchaseItem(item, inv, { police: 1 })).toBe(false);
    expect(canPurchaseItem({ ...item, grade: [1, 4] }, inv, { police: 4 })).toBe(true);
    expect(canPurchaseItem(item, inv, undefined)).toBe(false);
    expect(canPurchaseItem({ ...item, count: 0, grade: undefined }, inv, {})).toBe(false);
  });
  it('fabricar: ingredientes por cantidad global o por durabilidad', () => {
    const it2 = { slot: 1, name: 'phone', count: 1, weight: 1, ingredients: { iron: 5 } };
    expect(canCraftItem(it2, 'crafting', items, [])).toBe(true);
    expect(canCraftItem({ ...it2, ingredients: { iron: 6 } }, 'crafting', items, [])).toBe(false);
    const tool = { ...it2, ingredients: { phone: 0.5 } };
    expect(canCraftItem(tool, 'crafting', items, [{ slot: 1, name: 'phone', count: 1, weight: 1, metadata: { durability: 60 } }])).toBe(true);
  });
  it('durabilidad con degradación por tiempo', () => {
    expect(itemDurability({ durability: 50 }, NOW)).toBe(50);
    expect(itemDurability({ durability: NOW + 30 * 60, degrade: 60 }, NOW)).toBeCloseTo(50);
    expect(itemDurability(undefined, NOW)).toBeUndefined();
  });
});
