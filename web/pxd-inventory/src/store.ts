// Estado de la interfaz y sus transiciones (puras, probadas con Vitest).
// Las reglas de movimiento optimista son las de la interfaz original de ox_inventory 2.48.1
// (reducers setupInventory/refreshSlots/moveSlots/stackSlots/swapSlots): se pinta el cambio
// y, si el servidor lo rechaza (swapItems/buyItem/craftItem = false), se vuelve atrás.
import type {
  DisplayMetadataData,
  InitData,
  Inventory,
  ItemData,
  PxdState,
  RefreshData,
  SetupData,
  Slot,
  SlotWithItem,
} from './contract';
import { InventoryType } from './contract';
import { findAvailableSlot, isEqual as isEqualMeta, itemDurability, isSlotWithItem } from './helpers';

export interface Selection {
  inv: 'left' | 'right';
  slot: number;
}

export interface Notice {
  id: number;
  item: SlotWithItem;
  text: string;
}

export interface State {
  visible: boolean;
  left: Inventory;
  right: Inventory;
  items: Record<string, ItemData | undefined>;
  locale: Record<string, string>;
  imagepath: string;
  itemAmount: number;
  shiftPressed: boolean;
  busy: boolean;
  history?: { left: Inventory; right: Inventory };
  additionalMetadata: DisplayMetadataData;
  selected: Selection | null;
  hotbar: boolean;
  notices: Notice[];
  pxd: PxdState | null;
}

const emptyInv = (): Inventory => ({ id: '', type: '', slots: 0, maxWeight: 0, items: [] });

export const initialState: State = {
  visible: false,
  left: emptyInv(),
  right: emptyInv(),
  items: {},
  locale: {},
  imagepath: 'nui://ox_inventory/web/images',
  itemAmount: 0,
  shiftPressed: false,
  busy: false,
  additionalMetadata: [],
  selected: null,
  hotbar: false,
  notices: [],
  pxd: null,
};

export type MovePayload = {
  fromSlot: SlotWithItem;
  fromType: string;
  toSlot: Slot;
  toType: string;
  count: number;
};

export type Action =
  | { type: 'init'; data: InitData; now: number }
  | { type: 'setup'; data: SetupData; now: number }
  | { type: 'refresh'; data: RefreshData; now: number }
  | { type: 'close' }
  | { type: 'visible'; value: boolean }
  | { type: 'move'; data: MovePayload; now: number }
  | { type: 'stack'; data: MovePayload & { toSlot: SlotWithItem } }
  | { type: 'swap'; data: MovePayload & { toSlot: SlotWithItem }; now: number }
  | { type: 'pending' }
  | { type: 'fulfilled' }
  | { type: 'rejected' }
  | { type: 'containerWeight'; weight: number }
  | { type: 'amount'; value: number }
  | { type: 'shift'; value: boolean }
  | { type: 'metadata'; data: DisplayMetadataData }
  | { type: 'itemData'; name: string; data: ItemData }
  | { type: 'select'; value: Selection | null }
  | { type: 'hotbar'; value: boolean }
  | { type: 'notice'; notice: Notice }
  | { type: 'noticeDone'; id: number }
  | { type: 'pxd'; data: PxdState | null };

/** Rellena todas las ranuras (1..slots) como hace setupInventoryReducer. */
export function normalizeInventory(inv: Inventory, now: number): { inv: Inventory; unknown: string[] } {
  const list = Object.values(inv.items || {}).filter(Boolean) as Slot[];
  const unknown: string[] = [];
  const items: Slot[] = Array.from({ length: inv.slots }, (_, i) => {
    const found = list.find((it) => it?.slot === i + 1);
    if (!found || !found.name) return found ? { ...found } : { slot: i + 1 };
    unknown.push(found.name);
    return { ...found, durability: itemDurability(found.metadata, now) };
  });
  return { inv: { ...inv, items }, unknown };
}

function withItems(inv: Inventory, index: number, slot: Slot): Inventory {
  const items = inv.items.slice();
  items[index] = slot;
  return { ...inv, items };
}

/** Aplica dos cambios de ranura que pueden ser del mismo inventario. */
function applyPair(
  state: State,
  a: { side: 'left' | 'right'; index: number; slot: Slot },
  b?: { side: 'left' | 'right'; index: number; slot: Slot },
): State {
  let left = state.left;
  let right = state.right;
  for (const c of b ? [a, b] : [a]) {
    if (c.side === 'left') left = withItems(left, c.index, c.slot);
    else right = withItems(right, c.index, c.slot);
  }
  return { ...state, left, right };
}

function targetSides(fromType: string, toType?: string): { from: 'left' | 'right'; to: 'left' | 'right' } {
  const from = fromType === InventoryType.PLAYER ? 'left' : 'right';
  const to = toType ? (toType === InventoryType.PLAYER ? 'left' : 'right') : from === 'left' ? 'right' : 'left';
  return { from, to };
}

export function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'init': {
      const { locale, items, leftInventory, imagepath } = action.data;
      const mergedItems: Record<string, ItemData | undefined> = { ...state.items };
      for (const name in items) mergedItems[name] = items[name];
      return {
        ...state,
        locale: { ...state.locale, ...locale },
        items: mergedItems,
        imagepath: imagepath && imagepath !== '' ? imagepath : state.imagepath,
        left: normalizeInventory(leftInventory, action.now).inv,
        shiftPressed: false,
        busy: false,
      };
    }
    case 'setup': {
      const { leftInventory, rightInventory } = action.data;
      let next = { ...state, visible: true, shiftPressed: false, busy: false };
      if (leftInventory) next.left = normalizeInventory(leftInventory, action.now).inv;
      if (rightInventory) next.right = normalizeInventory(rightInventory, action.now).inv;
      if (next.selected) {
        const inv = next.selected.inv === 'left' ? next.left : next.right;
        if (!isSlotWithItem(inv.items[next.selected.slot - 1])) next.selected = null;
      }
      return next;
    }
    case 'refresh': {
      const p = action.data;
      let next = state;
      if (p.items) {
        const list = (Array.isArray(p.items) ? p.items : [p.items]).filter(Boolean);
        let left = next.left;
        let right = next.right;
        for (const data of list) {
          const item = { ...data.item, durability: itemDurability(data.item.metadata, action.now) };
          // Igual que ox_inventory: sin inventario o 'player' → izquierda; cualquier otro → derecha.
          const toRight = data.inventory ? data.inventory !== InventoryType.PLAYER : false;
          if (toRight) right = withItems(right, item.slot - 1, item);
          else left = withItems(left, item.slot - 1, item);
        }
        next = { ...next, left, right };
      }
      if (p.itemCount) {
        const items = { ...next.items };
        for (const [name, count] of Object.entries(p.itemCount)) {
          const d = items[name];
          if (d) items[name] = { ...d, count: d.count + count };
        }
        next = { ...next, items };
      }
      if (p.weightData) {
        const side = p.weightData.inventoryId === next.left.id ? 'left' : p.weightData.inventoryId === next.right.id ? 'right' : null;
        if (side) next = { ...next, [side]: { ...next[side], maxWeight: p.weightData.maxWeight } };
      }
      if (p.slotsData) {
        const side = p.slotsData.inventoryId === next.left.id ? 'left' : p.slotsData.inventoryId === next.right.id ? 'right' : null;
        if (side) {
          const inv = { ...next[side], slots: p.slotsData.slots };
          next = { ...next, [side]: normalizeInventory(inv, action.now).inv };
        }
      }
      return next;
    }
    case 'close':
      return { ...state, visible: false, selected: null, busy: false };
    case 'visible':
      return { ...state, visible: action.value };
    case 'move': {
      const { fromSlot, fromType, toSlot, toType, count } = action.data;
      const { from, to } = targetSides(fromType, toType);
      const src = state[from].items[fromSlot.slot - 1];
      if (!src) return state;
      const piece = fromSlot.weight / fromSlot.count;
      const moved: Slot = {
        ...src,
        count,
        weight: piece * count,
        slot: toSlot.slot,
        durability: itemDurability(src.metadata, action.now),
      };
      if (fromType === InventoryType.SHOP || fromType === InventoryType.CRAFTING) {
        return applyPair(state, { side: to, index: toSlot.slot - 1, slot: moved });
      }
      const rest: Slot =
        fromSlot.count - count > 0
          ? { ...src, count: fromSlot.count - count, weight: piece * (fromSlot.count - count) }
          : { slot: fromSlot.slot };
      return applyPair(state, { side: to, index: toSlot.slot - 1, slot: moved }, { side: from, index: fromSlot.slot - 1, slot: rest });
    }
    case 'stack': {
      const { fromSlot, fromType, toSlot, toType, count } = action.data;
      const { from, to } = targetSides(fromType, toType);
      const piece = fromSlot.weight / fromSlot.count;
      const target = state[to].items[toSlot.slot - 1];
      const stacked: Slot = { ...target, count: toSlot.count + count, weight: piece * (toSlot.count + count) };
      if (fromType === InventoryType.SHOP || fromType === InventoryType.CRAFTING) {
        return applyPair(state, { side: to, index: toSlot.slot - 1, slot: stacked });
      }
      const src = state[from].items[fromSlot.slot - 1];
      const rest: Slot =
        fromSlot.count - count > 0
          ? { ...src, count: fromSlot.count - count, weight: piece * (fromSlot.count - count) }
          : { slot: fromSlot.slot };
      return applyPair(state, { side: to, index: toSlot.slot - 1, slot: stacked }, { side: from, index: fromSlot.slot - 1, slot: rest });
    }
    case 'swap': {
      const { fromSlot, fromType, toSlot, toType } = action.data;
      const { from, to } = targetSides(fromType, toType);
      const a = state[from].items[fromSlot.slot - 1];
      const b = state[to].items[toSlot.slot - 1];
      return applyPair(
        state,
        { side: from, index: fromSlot.slot - 1, slot: { ...b, slot: fromSlot.slot, durability: itemDurability(toSlot.metadata, action.now) } },
        { side: to, index: toSlot.slot - 1, slot: { ...a, slot: toSlot.slot, durability: itemDurability(fromSlot.metadata, action.now) } },
      );
    }
    case 'pending':
      return { ...state, busy: true, history: { left: state.left, right: state.right } };
    case 'fulfilled':
      return { ...state, busy: false };
    case 'rejected':
      return state.history
        ? { ...state, left: state.history.left, right: state.history.right, busy: false }
        : { ...state, busy: false };
    case 'containerWeight': {
      const idx = state.left.items.findIndex((it) => it.metadata?.container === state.right.id);
      if (idx < 0) return state;
      return { ...state, left: withItems(state.left, idx, { ...state.left.items[idx], weight: action.weight }) };
    }
    case 'amount':
      return { ...state, itemAmount: Math.max(0, Math.floor(action.value || 0)) };
    case 'shift':
      return { ...state, shiftPressed: action.value };
    case 'metadata': {
      const add = action.data.filter((e) => !state.additionalMetadata.find((el) => el.value === e.value));
      return { ...state, additionalMetadata: [...state.additionalMetadata, ...add] };
    }
    case 'itemData':
      return { ...state, items: { ...state.items, [action.name]: action.data } };
    case 'select':
      return { ...state, selected: action.value };
    case 'hotbar':
      return { ...state, hotbar: action.value };
    case 'notice':
      return { ...state, notices: [...state.notices, action.notice].slice(-4) };
    case 'noticeDone':
      return { ...state, notices: state.notices.filter((n) => n.id !== action.id) };
    case 'pxd':
      return { ...state, pxd: action.data };
  }
}

/**
 * Traduce «soltar un objeto» en la petición al servidor y el cambio optimista,
 * igual que dnd/onDrop, onBuy y onCraft de la interfaz original.
 * target = undefined → mover al otro inventario (primer hueco o pila compatible).
 * Devuelve null si el movimiento no es válido en la interfaz.
 */
export type DropPlan =
  | { callback: 'swapItems'; request: { fromSlot: number; fromType: string; toSlot: number; toType: string; count: number }; optimistic: Action[] }
  | { callback: 'buyItem' | 'craftItem'; request: { fromSlot: number; fromType: string; toSlot: number; toType: string; count: number }; optimistic: Action[] };

export function planDrop(
  state: State,
  source: { type: string; slot: number },
  target: { type: string; slot: number } | undefined,
  now: number,
  amountOverride?: number,
): DropPlan | null {
  const { from, to } = targetSides(source.type, target?.type);
  const sourceInv = state[from];
  const targetInv = state[to];
  const sourceSlot = sourceInv.items[source.slot - 1];
  if (!isSlotWithItem(sourceSlot)) return null;
  const data = state.items[sourceSlot.name];

  // Tienda y fabricación: solo hacia el jugador.
  if (sourceInv.type === InventoryType.SHOP || sourceInv.type === InventoryType.CRAFTING) {
    if (!target || target.type !== InventoryType.PLAYER) return null;
    if (sourceSlot.count === 0) return null;
    if (!data) return null;
    const targetSlot = targetInv.items[target.slot - 1];
    if (!targetSlot) return null;
    const amount = amountOverride ?? state.itemAmount;
    const count =
      sourceInv.type === InventoryType.SHOP
        ? amount !== 0
          ? sourceSlot.count
            ? Math.min(amount, sourceSlot.count)
            : amount
          : 1
        : amount === 0
          ? 1
          : amount;
    return {
      callback: sourceInv.type === InventoryType.SHOP ? 'buyItem' : 'craftItem',
      request: { fromSlot: sourceSlot.slot, fromType: sourceInv.type, toSlot: targetSlot.slot, toType: targetInv.type, count },
      optimistic: [],
    };
  }

  if (!data) return null;
  if (targetInv.type === InventoryType.SHOP || targetInv.type === InventoryType.CRAFTING) return null;
  if (target && target.type === source.type && target.slot === source.slot) return null;

  // Contenedores (mochilas…): no dentro de otro contenedor ni moverlo mientras está abierto.
  if (sourceSlot.metadata?.container !== undefined) {
    if (targetInv.type === InventoryType.CONTAINER) return null;
    if (state.right.id === sourceSlot.metadata.container) return null;
  }

  let targetSlot: Slot | undefined;
  if (target) targetSlot = targetInv.items[target.slot - 1];
  else targetSlot = findAvailableSlot(sourceSlot, data, targetInv.items);
  if (!targetSlot) return null;
  if (targetSlot.metadata?.container !== undefined && state.right.id === targetSlot.metadata.container) return null;

  const amount = amountOverride ?? state.itemAmount;
  const count =
    amountOverride === undefined && state.shiftPressed && sourceSlot.count > 1 && sourceInv.type !== 'shop'
      ? Math.floor(sourceSlot.count / 2)
      : amount === 0 || amount > sourceSlot.count
        ? sourceSlot.count
        : amount;

  const payload: MovePayload = { fromSlot: sourceSlot, fromType: sourceInv.type, toSlot: targetSlot, toType: targetInv.type, count };
  let optimistic: Action;
  if (isSlotWithItem(targetSlot, true)) {
    optimistic =
      data.stack && targetSlot.name === sourceSlot.name && isEqualMeta(targetSlot.metadata, sourceSlot.metadata)
        ? { type: 'stack', data: { ...payload, toSlot: targetSlot } }
        : { type: 'swap', data: { ...payload, toSlot: targetSlot }, now };
  } else {
    optimistic = { type: 'move', data: payload, now };
  }
  return {
    callback: 'swapItems',
    request: { fromSlot: sourceSlot.slot, fromType: sourceInv.type, toSlot: targetSlot.slot, toType: targetInv.type, count },
    optimistic: [optimistic],
  };
}

