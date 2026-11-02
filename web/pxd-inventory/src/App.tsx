import React, { useCallback, useEffect, useRef, useState } from 'react';
import type { PxdState, Slot } from './contract';
import { InventoryType } from './contract';
import { getItemUrl, isSlotWithItem } from './helpers';
import { pxdNui } from './nui';
import { setNoticeLocale, useInv, useNuiMessages } from './state';
import { CharacterPanel, DetailsPanel, Hotbar, InventoryPanel, Notices, TopBar, type SlotHandlers } from './components/Panels';

interface DragState {
  side: 'left' | 'right';
  type: string;
  slot: number;
  x: number;
  y: number;
  startX: number;
  startY: number;
  active: boolean;
  image?: string;
}

function dropTargetAt(x: number, y: number): { kind: string; type?: string; slot?: number } | null {
  const el = document.elementFromPoint(x, y)?.closest('[data-drop]') as HTMLElement | null;
  if (!el) return null;
  return { kind: el.dataset.drop!, type: el.dataset.type, slot: el.dataset.slot ? Number(el.dataset.slot) : undefined };
}

export default function App() {
  useNuiMessages();
  const { state, dispatch, ops } = useInv();
  const [drag, setDrag] = useState<DragState | null>(null);
  const [over, setOver] = useState<{ type: string; slot: number } | null>(null);
  const dragRef = useRef<DragState | null>(null);
  dragRef.current = drag;

  useEffect(() => {
    setNoticeLocale(state.locale);
  }, [state.locale]);

  // Datos de Próxima (signos vitales, dinero, ropa) mientras el inventario está abierto.
  useEffect(() => {
    if (!state.visible) return;
    let alive = true;
    const tick = async () => {
      const v = await pxdNui<PxdState>('state');
      if (alive) dispatch({ type: 'pxd', data: v ?? null });
    };
    void tick();
    const id = window.setInterval(tick, 1000);
    return () => {
      alive = false;
      window.clearInterval(id);
    };
  }, [state.visible, dispatch]);

  // Teclado: Esc cierra (como useExitListener de ox_inventory); Mayús para «la mitad».
  useEffect(() => {
    const down = (e: KeyboardEvent) => e.key === 'Shift' && dispatch({ type: 'shift', value: true });
    const up = (e: KeyboardEvent) => {
      if (e.key === 'Shift') dispatch({ type: 'shift', value: false });
      if (e.code === 'Escape' && state.visible) ops.exit();
    };
    window.addEventListener('keydown', down);
    window.addEventListener('keyup', up);
    return () => {
      window.removeEventListener('keydown', down);
      window.removeEventListener('keyup', up);
    };
  }, [dispatch, ops, state.visible]);

  // Arrastre con el puntero (más fiable en el navegador del juego que el drag & drop de HTML5).
  useEffect(() => {
    const move = (e: PointerEvent) => {
      const d = dragRef.current;
      if (!d) return;
      const active = d.active || Math.hypot(e.clientX - d.startX, e.clientY - d.startY) > 5;
      setDrag({ ...d, x: e.clientX, y: e.clientY, active });
      if (active) {
        const t = dropTargetAt(e.clientX, e.clientY);
        setOver(t?.kind === 'slot' && t.type && t.slot ? { type: t.type, slot: t.slot } : null);
      }
    };
    const up = (e: PointerEvent) => {
      const d = dragRef.current;
      if (!d) return;
      setDrag(null);
      setOver(null);
      if (!d.active) return;
      const t = dropTargetAt(e.clientX, e.clientY);
      if (!t) return;
      if (t.kind === 'slot' && t.type && t.slot) {
        if (t.type === InventoryType.SHOP || t.type === InventoryType.CRAFTING) return;
        void ops.drop({ type: d.type, slot: d.slot }, { type: t.type, slot: t.slot });
      } else if (t.kind === 'use' && d.type === InventoryType.PLAYER) ops.use(d.slot);
      else if (t.kind === 'give' && d.type === InventoryType.PLAYER) ops.give(d.slot);
    };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
    return () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
    };
  }, [ops]);

  useEffect(() => {
    if (!state.visible) {
      setDrag(null);
      setOver(null);
    }
  }, [state.visible]);

  const handlers: SlotHandlers = {
    onPointerDown: useCallback(
      (e: React.PointerEvent, item: Slot) => {
        if (e.button !== 0 || state.busy) return;
        const el = (e.currentTarget as HTMLElement).dataset;
        const type = el.type!;
        const side = type === InventoryType.PLAYER ? 'left' : 'right';
        setDrag({
          side,
          type,
          slot: item.slot,
          x: e.clientX,
          y: e.clientY,
          startX: e.clientX,
          startY: e.clientY,
          active: false,
          image: isSlotWithItem(item) ? getItemUrl(item, state.items, state.imagepath) : undefined,
        });
      },
      [state.busy, state.items, state.imagepath],
    ),
    onClick: useCallback(
      (e: React.MouseEvent, item: Slot) => {
        if (!isSlotWithItem(item)) return;
        const type = (e.currentTarget as HTMLElement).dataset.type!;
        const side = type === InventoryType.PLAYER ? 'left' : 'right';
        if (e.ctrlKey && type !== InventoryType.SHOP && type !== InventoryType.CRAFTING) {
          void ops.drop({ type, slot: item.slot });
          return;
        }
        if (e.altKey && type === InventoryType.PLAYER) {
          ops.use(item.slot);
          return;
        }
        dispatch({ type: 'select', value: { inv: side, slot: item.slot } });
      },
      [dispatch, ops],
    ),
    onDoubleClick: useCallback(
      (item: Slot) => {
        if (state.selected?.inv === 'left' && isSlotWithItem(item)) ops.use(item.slot);
      },
      [ops, state.selected],
    ),
  };

  return (
    <div className={`root ${state.visible ? 'is-open' : ''}`}>
      <Hotbar />
      <Notices />
      {state.visible && (
        <div className={`stage ${state.busy ? 'is-busy' : ''}`}>
          <div className="frame">
            <TopBar />
            <main className="layout">
              <CharacterPanel />
              <InventoryPanel inv={state.left} side="left" drag={drag?.active ? drag : null} over={over} handlers={handlers} />
              <InventoryPanel inv={state.right} side="right" drag={drag?.active ? drag : null} over={over} handlers={handlers} />
              <DetailsPanel />
            </main>
          </div>
          {drag?.active && (
            <div className="ghost" style={{ transform: `translate(${drag.x}px, ${drag.y}px)` }}>
              {drag.image && <img src={drag.image} alt="" />}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
