import React from 'react';
import type { Inventory, Slot } from '../contract';
import { InventoryType } from '../contract';
import { canCraftItem, canPurchaseItem, formatWeight, getItemUrl, isSlotWithItem, itemLabel } from '../helpers';
import { useInv } from '../state';

export interface SlotProps {
  inv: Inventory;
  side: 'left' | 'right';
  item: Slot;
  dragging: boolean;
  over: boolean;
  onPointerDown(e: React.PointerEvent, item: Slot): void;
  onClick(e: React.MouseEvent, item: Slot): void;
  onDoubleClick(item: Slot): void;
}

function SlotViewInner({ inv, side, item, dragging, over, onPointerDown, onClick, onDoubleClick }: SlotProps) {
  const { state } = useInv();
  const has = isSlotWithItem(item);
  const disabled =
    !canPurchaseItem(item, { type: inv.type, groups: inv.groups }, state.left.groups) ||
    !canCraftItem(item, inv.type, state.items, state.left.items);
  const selected = state.selected?.inv === side && state.selected.slot === item.slot;
  const hotkey = inv.type === InventoryType.PLAYER && item.slot <= 5;
  const url = has ? getItemUrl(item, state.items, state.imagepath) : undefined;
  const cls = [
    'slot',
    has ? 'slot--full' : 'slot--empty',
    selected && 'is-selected',
    dragging && 'is-dragging',
    over && 'is-over',
    disabled && 'is-disabled',
    hotkey && 'slot--hot',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <div
      className={cls}
      data-drop="slot"
      data-type={inv.type}
      data-slot={item.slot}
      onPointerDown={(e) => has && !disabled && onPointerDown(e, item)}
      onClick={(e) => onClick(e, item)}
      onDoubleClick={() => has && onDoubleClick(item)}
      onContextMenu={(e) => {
        e.preventDefault();
        onClick(e, item);
      }}
    >
      {hotkey && <span className="slot__key">{item.slot}</span>}
      {has && (
        <>
          {url && <img className="slot__img" src={url} alt="" draggable={false} onError={(e) => (e.currentTarget.style.visibility = 'hidden')} />}
          <span className="slot__count">{item.count > 1 || inv.type === InventoryType.SHOP ? `${item.count.toLocaleString('es-MX')}×` : ''}</span>
          {item.weight > 0 && <span className="slot__weight">{formatWeight(item.weight)}</span>}
          {inv.type === InventoryType.SHOP && item.price !== undefined && item.price > 0 && (
            <span className={`slot__price ${item.currency && item.currency !== 'money' ? 'slot__price--alt' : ''}`}>
              {item.currency && item.currency !== 'money' && item.currency !== 'black_money' ? '' : '$'}
              {item.price.toLocaleString('es-MX')}
            </span>
          )}
          <span className="slot__label">{itemLabel(item, state.items)}</span>
          {inv.type !== InventoryType.SHOP && item.durability !== undefined && (
            <span className="slot__dur" aria-hidden>
              <i style={{ width: `${Math.max(0, Math.min(100, item.durability))}%` }} data-low={item.durability < 25 || undefined} />
            </span>
          )}
        </>
      )}
    </div>
  );
}

export const SlotView = React.memo(SlotViewInner);
