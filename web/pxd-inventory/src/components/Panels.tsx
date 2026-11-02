import { useMemo, useState } from 'react';
import type { Inventory, Slot } from '../contract';
import { InventoryType } from '../contract';
import {
  canCraftItem,
  canPurchaseItem,
  formatMoney,
  formatWeight,
  getItemUrl,
  getTotalWeight,
  isSlotWithItem,
  itemLabel,
  rightTitle,
} from '../helpers';
import { T } from '../i18n';
import { CLOTHING_ICONS, Icon, Star, UI_ICONS, VITAL_ICONS } from '../icons';
import { playerTargetFor, useInv } from '../state';
import { SlotView, type SlotProps } from './SlotView';

type SlotHandlers = Pick<SlotProps, 'onPointerDown' | 'onClick' | 'onDoubleClick'>;

// ── Barra superior ────────────────────────────────────────────────────────
export function TopBar() {
  const { state, ops } = useInv();
  const p = state.pxd;
  return (
    <header className="topbar">
      <div className="brand">
        <Star className="brand__star" />
        <div>
          <b className="brand__name">PRÓXIMA</b>
          <span className="brand__title">{T.title}</span>
        </div>
      </div>
      <div className="who">
        {p?.name && <b className="who__name">{p.name}</b>}
        {p?.id && <span className="who__id">{p.id}</span>}
      </div>
      <div className="money">
        {typeof p?.cash === 'number' && (
          <span className="money__item" title={T.cash}>
            <Icon d={UI_ICONS.cash} /> {formatMoney(p.cash)}
          </span>
        )}
        {typeof p?.bank === 'number' && (
          <span className="money__item money__item--bank" title={T.bank}>
            <Icon d={UI_ICONS.bank} /> {formatMoney(p.bank)}
          </span>
        )}
      </div>
      <button className="iconbtn" onClick={() => ops.exit()} aria-label={T.close}>
        <Icon d={UI_ICONS.close} />
        <kbd>ESC</kbd>
      </button>
    </header>
  );
}

// ── Personaje: ropa alrededor de la vista previa y signos vitales ─────────
const VITAL_ORDER: Array<{ id: 'health' | 'armour' | 'hunger' | 'thirst' | 'stress'; label: string }> = [
  { id: 'health', label: T.health },
  { id: 'armour', label: T.armour },
  { id: 'hunger', label: T.hunger },
  { id: 'thirst', label: T.thirst },
  { id: 'stress', label: T.stress },
];

export function CharacterPanel() {
  const { state, ops } = useInv();
  const p = state.pxd;
  const clothing = p?.clothing ?? [];
  const col = (side: 'left' | 'right' | 'bottom') =>
    clothing
      .filter((c) => c.side === side)
      .map((c) => (
        <button
          key={c.id}
          className={`cloth ${c.on ? 'is-on' : 'is-off'}`}
          disabled={!p?.canChange}
          title={c.label}
          onClick={() => ops.toggleClothing(c.id)}
        >
          <Icon d={CLOTHING_ICONS[c.icon] ?? CLOTHING_ICONS.decal} />
          <span>{c.label}</span>
        </button>
      ));
  const vitals = VITAL_ORDER.filter((v) => typeof p?.vitals?.[v.id] === 'number');
  return (
    <section className="character" aria-label={T.clothing}>
      <div className="character__stage">
        <div className="character__col">{col('left')}</div>
        <div className="character__preview">
          <span className="corner corner--tl" />
          <span className="corner corner--tr" />
          <span className="corner corner--bl" />
          <span className="corner corner--br" />
          {p && p.preview === false && <p className="character__hint">{T.previewOff}</p>}
        </div>
        <div className="character__col">{col('right')}</div>
      </div>
      {clothing.some((c) => c.side === 'bottom') && <div className="character__row">{col('bottom')}</div>}
      {vitals.length > 0 && (
        <ul className="vitals">
          {vitals.map((v) => {
            const val = Math.max(0, Math.min(100, Math.round(p!.vitals![v.id] as number)));
            return (
              <li key={v.id} className={`vital vital--${v.id}`}>
                <Icon d={VITAL_ICONS[v.id]} />
                <span className="vital__label">{v.label}</span>
                <span className="vital__bar">
                  <i style={{ width: `${val}%` }} />
                </span>
                <b className="vital__val">{val}</b>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

// ── Rejilla de un inventario ──────────────────────────────────────────────
export function InventoryPanel({
  inv,
  side,
  drag,
  over,
  handlers,
}: {
  inv: Inventory;
  side: 'left' | 'right';
  drag: { side: string; slot: number } | null;
  over: { type: string; slot: number } | null;
  handlers: SlotHandlers;
}) {
  const weight = useMemo(() => Math.floor(getTotalWeight(inv.items) * 1000) / 1000, [inv.items]);
  const pct = inv.maxWeight ? Math.min(100, (weight / inv.maxWeight) * 100) : 0;
  const title = side === 'left' ? T.pockets : rightTitle(inv);
  const used = inv.items.filter((i) => isSlotWithItem(i)).length;
  const ground = inv.type === 'newdrop' || inv.type === 'drop';
  return (
    <section className={`panel panel--${side} panel--${inv.type || 'none'}`} aria-label={title}>
      <header className="panel__head">
        <div>
          <h2>{title}</h2>
          <span className="panel__sub">
            {used}/{inv.slots} {T.slots}
          </span>
        </div>
        {!!inv.maxWeight && (
          <span className="panel__weight">
            <Icon d={UI_ICONS.weight} /> {formatWeight(weight)} / {formatWeight(inv.maxWeight)}
          </span>
        )}
      </header>
      {!!inv.maxWeight && (
        <div className="meter" data-level={pct > 90 ? 'high' : pct > 70 ? 'mid' : 'ok'}>
          <i style={{ width: `${pct}%` }} />
        </div>
      )}
      <div className={`grid ${ground && used === 0 ? 'grid--ground' : ''}`} style={{ pointerEvents: undefined }}>
        {inv.items.map((item) => (
          <SlotView
            key={`${inv.type}-${inv.id}-${item.slot}`}
            inv={inv}
            side={side}
            item={item}
            dragging={!!drag && drag.side === side && drag.slot === item.slot}
            over={!!over && over.type === inv.type && over.slot === item.slot}
            {...handlers}
          />
        ))}
        {ground && used === 0 && <p className="grid__empty">{T.emptySecondary}</p>}
      </div>
    </section>
  );
}

// ── Información del objeto seleccionado y acciones ────────────────────────
function plain(md: string) {
  // ox_inventory admite markdown simple en las descripciones; aquí se muestra como texto.
  return md.replace(/\*\*|__|`/g, '').replace(/\s{2,}\n/g, '\n');
}

export function DetailsPanel() {
  const { state, dispatch, ops } = useInv();
  const [splitting, setSplitting] = useState<number | null>(null);
  const sel = state.selected;
  const inv = sel ? (sel.inv === 'left' ? state.left : state.right) : null;
  const item: Slot | undefined = sel && inv ? inv.items[sel.slot - 1] : undefined;
  // En tienda y fabricación, cantidad vacía = 1 unidad (como ox_inventory); en el resto, todo.
  const unitDefault = !!inv && (inv.type === InventoryType.SHOP || inv.type === InventoryType.CRAFTING) && !!item?.name;

  const amount = (
    <div className="amount">
      <span className="amount__label">{T.amount}</span>
      <button className="iconbtn iconbtn--s" onClick={() => dispatch({ type: 'amount', value: Math.max(0, state.itemAmount - 1) })} aria-label="−">
        <Icon d={UI_ICONS.minus} />
      </button>
      <input
        className="amount__input"
        inputMode="numeric"
        value={state.itemAmount === 0 ? '' : String(state.itemAmount)}
        placeholder={unitDefault ? '1' : T.amountAll}
        onChange={(e) => dispatch({ type: 'amount', value: parseInt(e.target.value.replace(/\D/g, ''), 10) || 0 })}
      />
      <button className="iconbtn iconbtn--s" onClick={() => dispatch({ type: 'amount', value: state.itemAmount + 1 })} aria-label="+">
        <Icon d={UI_ICONS.plus} />
      </button>
    </div>
  );

  if (!sel || !inv || !item || !isSlotWithItem(item)) {
    return (
      <aside className="details details--empty" data-drop="actions">
        <div className="details__placeholder">
          <Star className="details__star" />
          <p>{T.noSelection}</p>
        </div>
        <div className="details__foot">
          {amount}
          <p className="hints">{T.hints}</p>
        </div>
      </aside>
    );
  }

  const data = state.items[item.name];
  const label = itemLabel(item, state.items);
  const url = getItemUrl(item, state.items, state.imagepath);
  const description = (item.metadata?.description as string | undefined) || data?.description;
  const isPlayer = inv.type === InventoryType.PLAYER;
  const isShop = inv.type === InventoryType.SHOP;
  const isCraft = inv.type === InventoryType.CRAFTING;
  const ground = state.right.type === 'newdrop' || state.right.type === 'drop';
  const canAct = canPurchaseItem(item, { type: inv.type, groups: inv.groups }, state.left.groups) && canCraftItem(item, inv.type, state.items, state.left.items);
  const ammoName = data?.ammoName && state.items[data.ammoName]?.label;
  const components: string[] = Array.isArray(item.metadata?.components) ? item.metadata!.components : [];
  const piece = item.count > 0 ? item.weight / item.count : 0;
  const pieceCount = item.count;

  const toPlayer = () => {
    const slot = playerTargetFor(state, item);
    if (slot !== undefined) void ops.drop({ type: inv.type, slot: item.slot }, { type: InventoryType.PLAYER, slot });
  };

  return (
    <aside className="details" data-drop="actions" key={`${sel.inv}-${sel.slot}-${item.name}`}>
      <div className="details__hero">
        <div className="details__img">{url && <img src={url} alt="" draggable={false} onError={(e) => (e.currentTarget.style.visibility = 'hidden')} />}</div>
        <div className="details__title">
          <h3>{label}</h3>
          <span className="details__meta">
            {isShop
              ? `${T.stock}: ${pieceCount.toLocaleString('es-MX')} · ${formatWeight(item.weight)} c/u`
              : `${pieceCount.toLocaleString('es-MX')}× · ${formatWeight(item.weight)}${pieceCount > 1 && piece > 0 ? ` (${formatWeight(piece)} c/u)` : ''}`}
          </span>
          {item.metadata?.type && <span className="tag">{String(item.metadata.type)}</span>}
        </div>
      </div>

      <div className="details__body">
        {description && <p className="details__desc">{plain(String(description))}</p>}
        <dl className="facts">
          {item.durability !== undefined && !isShop && (
            <div className="fact">
              <dt>{T.durability}</dt>
              <dd>
                <span className="fact__bar">
                  <i style={{ width: `${Math.max(0, Math.min(100, item.durability))}%` }} />
                </span>
                {Math.trunc(item.durability)}%
              </dd>
            </div>
          )}
          {item.metadata?.ammo !== undefined && (
            <div className="fact">
              <dt>{T.ammo}</dt>
              <dd>{String(item.metadata.ammo)}</dd>
            </div>
          )}
          {ammoName && (
            <div className="fact">
              <dt>{T.ammoType}</dt>
              <dd>{ammoName}</dd>
            </div>
          )}
          {item.metadata?.serial && (
            <div className="fact">
              <dt>{T.serial}</dt>
              <dd className="mono">{String(item.metadata.serial)}</dd>
            </div>
          )}
          {item.metadata?.weapontint && (
            <div className="fact">
              <dt>{T.tint}</dt>
              <dd>{String(item.metadata.weapontint)}</dd>
            </div>
          )}
          {state.additionalMetadata.map((m) =>
            item.metadata && item.metadata[m.metadata] !== undefined && item.metadata[m.metadata] !== '' ? (
              <div className="fact" key={m.metadata}>
                <dt>{m.value}</dt>
                <dd>{String(item.metadata[m.metadata])}</dd>
              </div>
            ) : null,
          )}
          {isShop && item.price !== undefined && (
            <div className="fact">
              <dt>{T.price}</dt>
              <dd>
                {item.currency && item.currency !== 'money' && item.currency !== 'black_money'
                  ? `${item.price.toLocaleString('es-MX')} ${state.items[item.currency]?.label ?? item.currency}`
                  : formatMoney(item.price)}
              </dd>
            </div>
          )}
          {isCraft && (
            <div className="fact">
              <dt>{T.duration}</dt>
              <dd>{((item.duration ?? 3000) / 1000).toLocaleString('es-MX')} s</dd>
            </div>
          )}
        </dl>
        {isCraft && item.ingredients && (
          <ul className="ingredients">
            <li className="ingredients__title">{T.ingredients}</li>
            {Object.entries(item.ingredients)
              .sort((a, b) => a[1] - b[1])
              .map(([name, count]) => (
                <li key={name}>
                  <img src={getItemUrl(name, state.items, state.imagepath)} alt="" onError={(e) => (e.currentTarget.style.visibility = 'hidden')} />
                  <span>
                    {count >= 1
                      ? `${count}× ${state.items[name]?.label || name}`
                      : count === 0
                        ? state.items[name]?.label || name
                        : `${count * 100}% ${state.items[name]?.label || name}`}
                  </span>
                </li>
              ))}
          </ul>
        )}
        {isPlayer && components.length > 0 && (
          <div className="components">
            <span className="components__title">{T.attachments}</span>
            {components.map((c) => (
              <button key={c} className="chip" onClick={() => ops.removeComponent(item.slot, c)}>
                {state.items[c]?.label || c} · {T.removeAttachment}
              </button>
            ))}
          </div>
        )}
      </div>

      {splitting !== null && (
        <div className="split">
          <b>{T.splitTitle}</b>
          <p>{T.splitHint}</p>
          <div className="split__row">
            <input type="range" min={1} max={item.count - 1} value={splitting} onChange={(e) => setSplitting(parseInt(e.target.value, 10))} />
            <b className="split__val">{splitting}</b>
          </div>
          <div className="split__actions">
            <button className="btn btn--ghost" onClick={() => setSplitting(null)}>
              {T.cancel}
            </button>
            <button
              className="btn btn--primary"
              onClick={async () => {
                const n = splitting;
                setSplitting(null);
                await ops.split(inv.type, item.slot, n);
              }}
            >
              {T.confirm}
            </button>
          </div>
        </div>
      )}

      <div className="details__actions">
        {isPlayer && (
          <>
            <button className="btn btn--primary" data-drop="use" onClick={() => ops.use(item.slot)}>
              {T.use}
            </button>
            <button className="btn" data-drop="give" onClick={() => ops.give(item.slot)}>
              {T.give}
            </button>
            <button className="btn" onClick={() => void ops.drop({ type: InventoryType.PLAYER, slot: item.slot })}>
              {ground ? T.drop : T.move}
            </button>
            {item.count > 1 && data?.stack !== false && (
              <button className="btn" onClick={() => setSplitting(Math.max(1, Math.floor(item.count / 2)))}>
                {T.split}
              </button>
            )}
            {Number(item.metadata?.ammo) > 0 && (
              <button className="btn btn--ghost" onClick={() => ops.removeAmmo(item.slot)}>
                {T.removeAmmo}
              </button>
            )}
            {item.metadata?.serial && (
              <button className="btn btn--ghost" onClick={() => ops.copy(String(item.metadata!.serial))}>
                {T.copySerial}
              </button>
            )}
            {(data?.buttons ?? []).map((b, i) => (
              <button key={`${b.label}-${i}`} className="btn btn--ghost" onClick={() => ops.useButton(item.slot, i)}>
                {b.group ? `${b.group}: ${b.label}` : b.label}
              </button>
            ))}
          </>
        )}
        {!isPlayer && (
          <>
            <button className="btn btn--primary" disabled={!canAct} onClick={toPlayer}>
              {isShop ? T.buy : isCraft ? T.craft : T.move}
            </button>
            {!isShop && !isCraft && item.count > 1 && data?.stack !== false && (
              <button className="btn" onClick={() => setSplitting(Math.max(1, Math.floor(item.count / 2)))}>
                {T.split}
              </button>
            )}
          </>
        )}
      </div>
      <div className="details__foot">{amount}</div>
    </aside>
  );
}

// ── Barra rápida (toggleHotbar) y avisos de objetos (itemNotify) ──────────
export function Hotbar() {
  const { state } = useInv();
  if (!state.hotbar || state.visible) return null;
  return (
    <div className="hotbar">
      {state.left.items.slice(0, 5).map((item) => {
        const has = isSlotWithItem(item);
        return (
          <div key={item.slot} className={`slot slot--hot ${has ? 'slot--full' : 'slot--empty'}`}>
            <span className="slot__key">{item.slot}</span>
            {has && (
              <>
                <img className="slot__img" src={getItemUrl(item, state.items, state.imagepath)} alt="" onError={(e) => (e.currentTarget.style.visibility = 'hidden')} />
                <span className="slot__count">{item.count > 1 ? `${item.count}×` : ''}</span>
                <span className="slot__label">{itemLabel(item, state.items)}</span>
              </>
            )}
          </div>
        );
      })}
    </div>
  );
}

export function Notices() {
  const { state } = useInv();
  return (
    <div className="notices" aria-live="polite">
      {state.notices.map((n) => (
        <div className="notice" key={n.id}>
          <img src={getItemUrl(n.item, state.items, state.imagepath)} alt="" onError={(e) => (e.currentTarget.style.visibility = 'hidden')} />
          <div>
            <b>{n.text}</b>
            <span>{itemLabel(n.item, state.items)}</span>
          </div>
        </div>
      ))}
    </div>
  );
}

export type { SlotHandlers };
