// Controles del taller: cada uno propone un valor; quien decide si vale y cuánto cuesta es el servidor.
import { useState } from 'react';
import { NEON_SIDES, PAINT_GROUPS, RGB_PRESETS, paintHex } from './data';
import { clampByte, levelLock, rgbCss, step, toggleLock, valueLabel } from './logic';
import type { Entry, PerfRule, Rgb, Value } from './types';

type Set = (value: Value) => void;

export function Stepper({ entry, value, onSet }: { entry: Entry; value: number; onSet: Set }) {
  return (
    <div className="stepper">
      <button type="button" className="stepper__btn" aria-label="Anterior" onClick={() => onSet(step(entry, value, -1))}>‹</button>
      <div className="stepper__value">
        <b>{valueLabel(entry, value)}</b>
        <small>{value < 0 ? 'de serie' : `${value + 1} de ${entry.count ?? 0}`}</small>
      </div>
      <button type="button" className="stepper__btn" aria-label="Siguiente" onClick={() => onSet(step(entry, value, 1))}>›</button>
    </div>
  );
}

export function Levels(p: { entry: Entry; value: number; saved: number; rule?: PerfRule; mode: 'self' | 'mechanic'; mechLevel: number; onSet: Set }) {
  const levels: number[] = [-1];
  for (let i = 0; i < (p.entry.count ?? 0); i++) levels.push(i);
  return (
    <div className="levels" role="radiogroup" aria-label={p.entry.label}>
      {levels.map((l) => {
        const lock = levelLock(p.rule, l, p.mode, p.mechLevel, p.saved);
        return (
          <button key={l} type="button" role="radio" aria-checked={p.value === l} title={lock ?? undefined}
            className={`level${p.value === l ? ' is-on' : ''}${lock ? ' is-locked' : ''}`} onClick={() => p.onSet(l)}>
            {l < 0 ? 'Serie' : l + 1}
            {lock && <i aria-hidden="true">🔒</i>}
          </button>
        );
      })}
    </div>
  );
}

export function Toggle({ on, label, lock, onSet }: { on: boolean; label: string; lock?: string | null; onSet: (v: boolean) => void }) {
  return (
    <button type="button" role="switch" aria-checked={on} className={`toggle${on ? ' is-on' : ''}${lock ? ' is-locked' : ''}`}
      title={lock ?? undefined} onClick={() => onSet(!on)}>
      <span className="toggle__dot" />
      <span>{label}</span>
      {lock && <small>{lock}</small>}
    </button>
  );
}

export function RgbPicker({ value, onSet }: { value: Rgb; onSet: (v: Rgb) => void }) {
  const ch = ['R', 'G', 'B'] as const;
  return (
    <div className="rgb">
      <div className="rgb__preview" style={{ background: rgbCss(value) }} />
      <div className="rgb__sliders">
        {ch.map((c, i) => (
          <label key={c} className="rgb__row">
            <span>{c}</span>
            <input type="range" min={0} max={255} value={value[i]} aria-label={c}
              onChange={(e) => { const next: Rgb = [value[0], value[1], value[2]]; next[i] = clampByte(Number(e.target.value)); onSet(next); }} />
            <b>{value[i]}</b>
          </label>
        ))}
      </div>
      <div className="swatches swatches--small">
        {RGB_PRESETS.map((c) => (
          <button key={c.join('-')} type="button" className="swatch" style={{ background: rgbCss(c) }} aria-label={`RGB ${c.join(', ')}`} onClick={() => onSet([c[0], c[1], c[2]])} />
        ))}
      </div>
    </div>
  );
}

export function Palette({ value, onSet, max }: { value: number; onSet: (v: number) => void; max?: number }) {
  const [group, setGroup] = useState(() => PAINT_GROUPS.find((g) => g.ids.includes(value))?.id ?? 'classic');
  const g = PAINT_GROUPS.find((x) => x.id === group) ?? PAINT_GROUPS[0]!;
  return (
    <div className="palette">
      <div className="chips">
        {PAINT_GROUPS.map((x) => (
          <button key={x.id} type="button" className={`chip${x.id === group ? ' is-on' : ''}`} onClick={() => setGroup(x.id)}>{x.label}</button>
        ))}
      </div>
      <div className="swatches">
        {g.ids.filter((id) => max === undefined || id <= max).map((id) => (
          <button key={id} type="button" className={`swatch${id === value ? ' is-on' : ''}`} style={{ background: paintHex(id) }}
            aria-label={`Color ${id}`} title={`Color ${id}`} onClick={() => onSet(id)} />
        ))}
      </div>
    </div>
  );
}

export function Paint({ value, onSet }: { value: Value; onSet: Set }) {
  const custom = Array.isArray(value);
  const [tab, setTab] = useState<'palette' | 'rgb'>(custom ? 'rgb' : 'palette');
  const rgb: Rgb = custom ? (value as Rgb) : [92, 225, 255];
  return (
    <div className="paint">
      <div className="seg">
        <button type="button" className={tab === 'palette' ? 'is-on' : ''} onClick={() => setTab('palette')}>Paleta</button>
        <button type="button" className={tab === 'rgb' ? 'is-on' : ''} onClick={() => setTab('rgb')}>A medida</button>
      </div>
      {tab === 'palette'
        ? <Palette value={typeof value === 'number' ? value : -1} onSet={onSet} />
        : <RgbPicker value={rgb} onSet={onSet} />}
    </div>
  );
}

export function Neon({ value, onSet }: { value: boolean[]; onSet: Set }) {
  return (
    <div className="grid2">
      {NEON_SIDES.map((side, i) => (
        <Toggle key={side} on={value[i] === true} label={side}
          onSet={(v) => { const next = [0, 1, 2, 3].map((k) => (k === i ? v : value[k] === true)); onSet(next); }} />
      ))}
    </div>
  );
}

export function Extras({ entry, value, onSet }: { entry: Entry; value: Record<string, number>; onSet: Set }) {
  const ids = entry.ids ?? [];
  // En GTA, 0 = extra puesto y 1 = quitado.
  const full = () => Object.fromEntries(ids.map((id) => [String(id), value[String(id)] === 0 ? 0 : 1]));
  return (
    <div className="grid2">
      {ids.map((id) => (
        <Toggle key={id} on={value[String(id)] === 0} label={`Extra ${id}`}
          onSet={(v) => onSet({ ...full(), [String(id)]: v ? 0 : 1 })} />
      ))}
    </div>
  );
}

/** Editor de una entrada del catálogo según su tipo. */
export function Editor(p: {
  entry: Entry; value: Value; saved: Value; rule?: PerfRule; mode: 'self' | 'mechanic'; mechLevel: number; onSet: Set;
}) {
  const { entry, value, onSet } = p;
  if (entry.kind === 'level') {
    return <Levels entry={entry} value={typeof value === 'number' ? value : -1} saved={typeof p.saved === 'number' ? p.saved : -1}
      rule={p.rule} mode={p.mode} mechLevel={p.mechLevel} onSet={onSet} />;
  }
  if (entry.kind === 'toggle') {
    return <Toggle on={value === true} label={value === true ? 'Montado' : 'Sin montar'}
      lock={toggleLock(p.rule, p.mode, p.mechLevel, p.saved === true)} onSet={onSet} />;
  }
  if (entry.kind === 'mod') return <Stepper entry={entry} value={typeof value === 'number' ? value : -1} onSet={onSet} />;
  if (entry.kind === 'index') {
    if (entry.key === 'pearlescentColor' || entry.key === 'wheelColor' || entry.key === 'interiorColor' || entry.key === 'dashboardColor') {
      return <Palette value={typeof value === 'number' ? value : -1} onSet={onSet} />;
    }
    return <Stepper entry={entry} value={typeof value === 'number' ? value : (entry.min ?? 0)} onSet={onSet} />;
  }
  if (entry.kind === 'paint') return <Paint value={value} onSet={onSet} />;
  if (entry.kind === 'rgb') return <RgbPicker value={Array.isArray(value) ? (value as Rgb) : [255, 255, 255]} onSet={onSet} />;
  if (entry.kind === 'neon') return <Neon value={Array.isArray(value) ? (value as boolean[]) : [false, false, false, false]} onSet={onSet} />;
  if (entry.kind === 'extras') return <Extras entry={entry} value={(value ?? {}) as Record<string, number>} onSet={onSet} />;
  return null;
}
