// Estado compartido de la interfaz y operaciones que hablan con ox_inventory / pxd_inventory.
import React, { createContext, useContext, useEffect, useMemo, useReducer, useRef } from 'react';
import type { ItemData, PxdState, Slot } from './contract';
import { InventoryType } from './contract';
import { findAvailableSlot, isSlotWithItem } from './helpers';
import { NOTIFY } from './i18n';
import { oxNui, pxdNui } from './nui';
import { initialState, planDrop, reducer, type Action, type State } from './store';

export const now = () => Math.floor(Date.now() / 1000);

export interface Ops {
  /** Soltar un objeto: target undefined = al otro inventario. amount fija la cantidad (dividir). */
  drop(source: { type: string; slot: number }, target?: { type: string; slot: number }, amount?: number): Promise<boolean>;
  use(slot: number): void;
  give(slot: number): void;
  split(type: string, slot: number, count: number): Promise<boolean>;
  removeAmmo(slot: number): void;
  removeComponent(slot: number, component: string): void;
  useButton(slot: number, index: number): void;
  exit(): void;
  toggleClothing(id: string): Promise<void>;
  copy(text: string): void;
  ensureItemData(names: string[]): void;
}

const Ctx = createContext<{ state: State; dispatch: React.Dispatch<Action>; ops: Ops } | null>(null);

export function useInv() {
  const c = useContext(Ctx);
  if (!c) throw new Error('InventoryProvider ausente');
  return c;
}

export function InventoryProvider({ children, initial }: { children: React.ReactNode; initial?: Partial<State> }) {
  const [state, dispatch] = useReducer(reducer, { ...initialState, ...initial });
  const ref = useRef(state);
  ref.current = state;
  const requested = useRef(new Set<string>());

  const ops = useMemo<Ops>(() => {
    const run = async (plan: ReturnType<typeof planDrop>) => {
      if (!plan || ref.current.busy) return false;
      dispatch({ type: 'pending' });
      for (const a of plan.optimistic) dispatch(a);
      try {
        const res = await oxNui(plan.callback, plan.request);
        if (res === false || res === undefined) {
          dispatch({ type: 'rejected' });
          return false;
        }
        if (typeof res === 'number' && plan.callback === 'swapItems') dispatch({ type: 'containerWeight', weight: res });
        dispatch({ type: 'fulfilled' });
        return true;
      } catch {
        dispatch({ type: 'rejected' });
        return false;
      }
    };
    return {
      drop: (source, target, amount) => run(planDrop(ref.current, source, target, now(), amount)),
      use: (slot) => void oxNui('useItem', slot).catch(() => undefined),
      give: (slot) => void oxNui('giveItem', { slot, count: ref.current.itemAmount }).catch(() => undefined),
      split: (type, slot, count) => {
        const s = ref.current;
        const inv = type === InventoryType.PLAYER ? s.left : s.right;
        const empty = inv.items.find((it) => it.name === undefined);
        if (!empty) return Promise.resolve(false);
        return run(planDrop(s, { type, slot }, { type, slot: empty.slot }, now(), count));
      },
      removeAmmo: (slot) => void oxNui('removeAmmo', slot).catch(() => undefined),
      removeComponent: (slot, component) => void oxNui('removeComponent', { component, slot }).catch(() => undefined),
      // ox_inventory numera los botones desde 1 (useButton(id) → buttons[id]).
      useButton: (slot, index) => void oxNui('useButton', { id: index + 1, slot }).catch(() => undefined),
      exit: () => {
        dispatch({ type: 'close' });
        void oxNui('exit').catch(() => undefined);
      },
      toggleClothing: async (id) => {
        const v = await pxdNui<PxdState>('toggleClothing', { id });
        if (v) dispatch({ type: 'pxd', data: v });
      },
      copy: (text) => {
        const el = document.createElement('textarea');
        el.value = text;
        document.body.appendChild(el);
        el.select();
        try {
          document.execCommand('copy');
        } finally {
          el.remove();
        }
      },
      ensureItemData: (names) => {
        for (const name of names) {
          if (ref.current.items[name] || requested.current.has(name)) continue;
          requested.current.add(name);
          oxNui('getItemData', name)
            .then((d) => {
              if (d && (d as ItemData).label) dispatch({ type: 'itemData', name, data: d as ItemData });
            })
            .catch(() => undefined);
        }
      },
    };
  }, []);

  return <Ctx.Provider value={{ state, dispatch, ops }}>{children}</Ctx.Provider>;
}

/** Primer destino válido en los bolsillos para comprar o fabricar con un botón. */
export function playerTargetFor(state: State, item: Slot): number | undefined {
  if (!isSlotWithItem(item)) return undefined;
  const data = state.items[item.name];
  if (!data) return state.left.items.find((s) => s.name === undefined)?.slot;
  return findAvailableSlot(item, data, state.left.items)?.slot;
}

/** Escucha los mensajes de ox_inventory (window.postMessage desde client.lua). */
export function useNuiMessages() {
  const { dispatch, ops, state } = useInv();
  const hotbarTimer = useRef<number | undefined>(undefined);
  const hotbarOn = useRef(false);
  hotbarOn.current = state.hotbar;

  useEffect(() => {
    const onMessage = (e: MessageEvent) => {
      const msg = e.data as { action?: string; data?: any };
      if (!msg || typeof msg.action !== 'string') return;
      const data = msg.data;
      switch (msg.action) {
        case 'init':
          if (data) dispatch({ type: 'init', data, now: now() });
          break;
        case 'setupInventory': {
          if (!data) break;
          dispatch({ type: 'setup', data, now: now() });
          const names: string[] = [];
          for (const inv of [data.leftInventory, data.rightInventory]) {
            if (!inv?.items) continue;
            for (const it of Object.values(inv.items) as Slot[]) if (it?.name) names.push(it.name);
          }
          ops.ensureItemData(names);
          break;
        }
        case 'refreshSlots':
          if (data) dispatch({ type: 'refresh', data, now: now() });
          break;
        case 'closeInventory':
          dispatch({ type: 'close' });
          break;
        case 'setInventoryVisible':
          dispatch({ type: 'visible', value: !!data });
          break;
        case 'toggleHotbar':
          window.clearTimeout(hotbarTimer.current);
          if (hotbarOn.current) dispatch({ type: 'hotbar', value: false });
          else {
            dispatch({ type: 'hotbar', value: true });
            hotbarTimer.current = window.setTimeout(() => dispatch({ type: 'hotbar', value: false }), 3000);
          }
          break;
        case 'displayMetadata':
          if (Array.isArray(data)) dispatch({ type: 'metadata', data });
          break;
        case 'itemNotify':
          if (Array.isArray(data) && data[0]) {
            const id = Date.now() + Math.random();
            dispatch({ type: 'notice', notice: { id, item: data[0], text: noticeText(data[1], data[2]) } });
            window.setTimeout(() => dispatch({ type: 'noticeDone', id }), 2500);
          }
          break;
      }
    };
    window.addEventListener('message', onMessage);
    // Sin este aviso ox_inventory no envía «init» (client.lua espera client.uiLoaded).
    oxNui('uiLoaded', {}).catch(() => undefined);
    return () => window.removeEventListener('message', onMessage);
  }, [dispatch, ops]);
}

let localeRef: Record<string, string> = {};
export const setNoticeLocale = (l: Record<string, string>) => (localeRef = l);
function noticeText(key: string, count?: number) {
  const base = NOTIFY[key] || localeRef[key] || key;
  return count ? `${base} ${count}x` : base;
}
