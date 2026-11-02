// Contrato con ox_inventory 2.48.1 (client.lua) y con pxd_inventory (adaptador de Próxima).
// ox_inventory sigue siendo el backend: esta interfaz solo pinta lo que recibe y pide cambios
// por sus callbacks NUI; el servidor de ox_inventory valida y responde.

// ── Tipos que envía ox_inventory ───────────────────────────────────────────
export type Metadata = Record<string, any>;

export interface Slot {
  slot: number;
  name?: string;
  count?: number;
  weight?: number;
  metadata?: Metadata;
  durability?: number;
  price?: number;
  currency?: string;
  ingredients?: Record<string, number>;
  duration?: number;
  image?: string;
  grade?: number | number[];
}

export interface SlotWithItem extends Slot {
  name: string;
  count: number;
  weight: number;
}

export interface Inventory {
  id: string;
  type: string;
  slots: number;
  items: Slot[];
  maxWeight?: number;
  weight?: number;
  label?: string;
  groups?: Record<string, number>;
}

export interface ItemButton {
  label: string;
  group?: string;
}

export interface ItemData {
  name?: string;
  label: string;
  stack: boolean;
  usable?: boolean;
  close?: boolean;
  count: number;
  description?: string;
  buttons?: ItemButton[];
  ammoName?: string;
  image?: string;
}

export const InventoryType = {
  PLAYER: 'player',
  SHOP: 'shop',
  CONTAINER: 'container',
  CRAFTING: 'crafting',
  NEWDROP: 'newdrop',
} as const;

// ── Mensajes (SendNUIMessage) que esta interfaz atiende ────────────────────
export interface InitData {
  locale: Record<string, string>;
  items: Record<string, ItemData>;
  leftInventory: Inventory;
  imagepath: string;
}
export interface SetupData {
  leftInventory?: Inventory;
  rightInventory?: Inventory;
}
export interface RefreshItem {
  item: Slot;
  inventory?: string;
}
export interface RefreshData {
  items?: RefreshItem | RefreshItem[];
  itemCount?: Record<string, number>;
  weightData?: { inventoryId: string; maxWeight: number };
  slotsData?: { inventoryId: string; slots: number };
}
export type ItemNotifyData = [item: SlotWithItem, text: string, count?: number];
export type DisplayMetadataData = Array<{ metadata: string; value: string }>;

export const HANDLED_MESSAGES = [
  'init',
  'setupInventory',
  'refreshSlots',
  'closeInventory',
  'toggleHotbar',
  'displayMetadata',
  'itemNotify',
  // No lo envía client.lua 2.48.1, pero su interfaz lo atendía: se mantiene por compatibilidad.
  'setInventoryVisible',
] as const;

// ── Callbacks NUI de ox_inventory que esta interfaz usa ─────────────────────
export interface MoveRequest {
  fromSlot: number;
  fromType: string;
  toSlot: number;
  toType: string;
  count: number;
}

export interface OxCallbacks {
  uiLoaded: { req: Record<string, never>; res: number };
  getItemData: { req: string; res: ItemData | null };
  swapItems: { req: MoveRequest; res: boolean | number };
  buyItem: { req: MoveRequest; res: boolean };
  craftItem: { req: MoveRequest; res: boolean };
  useItem: { req: number; res: number };
  giveItem: { req: { slot: number; count: number }; res: number };
  removeAmmo: { req: number; res: number };
  removeComponent: { req: { component: string; slot: number }; res: number };
  useButton: { req: { id: number; slot: number }; res: number };
  exit: { req: undefined; res: number };
}

export const USED_CALLBACKS: Array<keyof OxCallbacks> = [
  'uiLoaded',
  'getItemData',
  'swapItems',
  'buyItem',
  'craftItem',
  'useItem',
  'giveItem',
  'removeAmmo',
  'removeComponent',
  'useButton',
  'exit',
];

// ── Adaptador de Próxima (pxd_inventory, https://pxd_inventory/<acción>) ────
export interface PxdVitals {
  health?: number;
  armour?: number;
  hunger?: number;
  thirst?: number;
  stress?: number;
}
export interface PxdClothingSlot {
  id: string;
  label: string;
  icon: string;
  side: 'left' | 'right' | 'bottom';
  on: boolean;
}
export interface PxdState {
  contract?: number;
  name?: string;
  id?: string;
  cash?: number;
  bank?: number;
  vitals?: PxdVitals;
  clothing?: PxdClothingSlot[];
  canChange?: boolean;
  preview?: boolean;
}
export const PXD_CONTRACT = 2;
export const PXD_CALLBACKS = ['state', 'toggleClothing'] as const;
