// Utilidades puras (portadas de la interfaz original de ox_inventory 2.48.1, web/src/helpers).
import type { Inventory, ItemData, Metadata, Slot, SlotWithItem } from './contract';
import { InventoryType } from './contract';

export const isSlotWithItem = (slot: Slot | undefined, strict = false): slot is SlotWithItem =>
  !!slot &&
  ((slot.name !== undefined && slot.weight !== undefined) ||
    (strict && slot.name !== undefined && slot.count !== undefined && slot.weight !== undefined));

export function isEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a === undefined || b === undefined || a === null || b === null) {
    // ox_inventory compara metadata con lodash.isEqual: {} y undefined NO son iguales.
    return false;
  }
  if (typeof a !== 'object' || typeof b !== 'object') return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a as object);
  const kb = Object.keys(b as object);
  if (ka.length !== kb.length) return false;
  return ka.every((k) => isEqual((a as any)[k], (b as any)[k]));
}

export const canStack = (source: Slot, target: Slot) =>
  source.name === target.name && isEqual(source.metadata, target.metadata);

export function findAvailableSlot(item: Slot, data: ItemData, items: Slot[]): Slot | undefined {
  if (!data.stack) return items.find((t) => t.name === undefined);
  const stackable = items.find((t) => t.name === item.name && isEqual(t.metadata, item.metadata));
  return stackable || items.find((t) => t.name === undefined);
}

export function itemDurability(metadata: Metadata | undefined, curTime: number): number | undefined {
  if (metadata?.durability === undefined) return undefined;
  let d = metadata.durability as number;
  if (d > 100 && metadata.degrade) d = ((metadata.durability - curTime) / (60 * metadata.degrade)) * 100;
  if (d < 0) d = 0;
  return d;
}

export const getTotalWeight = (items: Slot[]) =>
  items.reduce((t, s) => (isSlotWithItem(s) ? t + s.weight : t), 0);

export function canPurchaseItem(item: Slot, inv: { type: string; groups?: Record<string, number> }, playerGroups?: Record<string, number>) {
  if (inv.type !== InventoryType.SHOP || !isSlotWithItem(item)) return true;
  if (item.count !== undefined && item.count === 0) return false;
  if (item.grade === undefined || !inv.groups) return true;
  if (!playerGroups) return false;
  const req = Object.keys(inv.groups);
  for (const g of req) {
    const grade = playerGroups[g];
    if (grade === undefined) continue;
    if (Array.isArray(item.grade)) {
      if (item.grade.includes(grade)) return true;
    } else if (grade >= item.grade) return true;
  }
  return false;
}

export function canCraftItem(item: Slot, inventoryType: string, items: Record<string, ItemData | undefined>, left: Slot[]) {
  if (!isSlotWithItem(item) || inventoryType !== InventoryType.CRAFTING) return true;
  if (!item.ingredients) return true;
  const remaining = Object.entries(item.ingredients).filter(([name, count]) => {
    const global = items[name];
    if (count >= 1 && global && global.count >= count) return false;
    const has = left.find((p) => isSlotWithItem(p) && p.name === name && count < 1 && (p.metadata?.durability ?? -1) >= count * 100);
    return !has;
  });
  return remaining.length === 0;
}

export function getItemUrl(item: string | Slot, items: Record<string, ItemData | undefined>, imagepath: string): string | undefined {
  if (typeof item === 'object') {
    if (!item.name) return undefined;
    if (item.metadata?.imageurl) return String(item.metadata.imageurl);
    if (item.metadata?.image) return `${imagepath}/${item.metadata.image}.png`;
  }
  const name = typeof item === 'object' ? (item.name as string) : item;
  const data = items[name];
  if (data?.image) return data.image;
  return `${imagepath}/${name}.png`;
}

export function itemLabel(item: Slot, items: Record<string, ItemData | undefined>) {
  return (item.metadata?.label as string | undefined) || (item.name ? items[item.name]?.label : undefined) || item.name || '';
}

/** Gramos → texto en español ("1,25 kg", "300 g"). */
export function formatWeight(grams: number): string {
  if (!grams || grams <= 0) return '0 kg';
  if (grams >= 1000) return `${(grams / 1000).toLocaleString('es-MX', { maximumFractionDigits: 2 })} kg`;
  return `${Math.round(grams).toLocaleString('es-MX')} g`;
}

export const formatMoney = (n: number | undefined) =>
  '$' + Math.max(0, Math.floor(Number(n) || 0)).toLocaleString('es-MX');

/** Nombre visible del inventario de la derecha según su tipo (ox_inventory). */
export function rightTitle(inv: Inventory): string {
  switch (inv.type) {
    case 'newdrop':
    case 'drop':
      return 'Suelo';
    case 'trunk':
      return 'Maletero';
    case 'glovebox':
      return 'Guantera';
    case 'shop':
      return inv.label || 'Tienda';
    case 'crafting':
      return inv.label || 'Fabricación';
    case 'container':
      return inv.label || 'Contenedor';
    case 'player':
    case 'otherplayer':
      return inv.label || 'Otra persona';
    case 'policeevidence':
      return 'Evidencias';
    default:
      return inv.label || 'Almacén';
  }
}
