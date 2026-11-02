import { useId } from 'react';

export function Slider(props: {
  label: string; value: number; min: number; max: number; step?: number;
  onChange: (v: number) => void; format?: (v: number) => string; hint?: string; disabled?: boolean;
}) {
  const id = useId();
  const { label, value, min, max, step = 1, onChange, format, hint, disabled } = props;
  const pct = max > min ? ((value - min) / (max - min)) * 100 : 0;
  return (
    <div className="ctl">
      <div className="ctl__head">
        <label htmlFor={id}>{label}</label>
        <span className="ctl__badge">{format ? format(value) : value}</span>
      </div>
      <input id={id} type="range" min={min} max={max} step={step} value={value} disabled={disabled || max <= min}
        style={{ ['--pct' as string]: `${pct}%` }}
        onChange={(e) => onChange(Number(e.target.value))} />
      {hint ? <p className="ctl__hint">{hint}</p> : null}
    </div>
  );
}

/** − [valor / total] + para drawables y texturas (rango real del modelo). */
export function Stepper(props: {
  label: string; value: number; min: number; max: number; onChange: (v: number) => void; noneLabel?: string;
}) {
  const { label, value, min, max, onChange, noneLabel } = props;
  const total = max - min + 1;
  const shown = noneLabel && value < 0 ? noneLabel : `${value - Math.max(0, min) + 1} / ${Math.max(1, noneLabel ? max + 1 : total)}`;
  const wrap = (v: number) => (v > max ? min : v < min ? max : v);
  return (
    <div className="step">
      <span className="step__label">{label}</span>
      <div className="step__ctl">
        <button type="button" aria-label={`${label}: anterior`} disabled={max <= min} onClick={() => onChange(wrap(value - 1))}>‹</button>
        <span className="step__val">{shown}</span>
        <button type="button" aria-label={`${label}: siguiente`} disabled={max <= min} onClick={() => onChange(wrap(value + 1))}>›</button>
      </div>
    </div>
  );
}

/** Muestras de color con la paleta real del juego (GetPedHairRgbColor / GetPedMakeupRgbColor). */
export function Swatches(props: { label: string; colors: [number, number, number][]; value: number; onChange: (v: number) => void }) {
  const { label, colors, value, onChange } = props;
  return (
    <div className="ctl">
      <div className="ctl__head"><span>{label}</span><span className="ctl__badge">#{value}</span></div>
      <div className="sw" role="radiogroup" aria-label={label}>
        {colors.map((c, i) => (
          <button key={i} type="button" role="radio" aria-checked={i === value} aria-label={`${label} ${i}`}
            className={'sw__item' + (i === value ? ' is-on' : '')} style={{ background: `rgb(${c[0]}, ${c[1]}, ${c[2]})` }}
            onClick={() => onChange(i)} />
        ))}
      </div>
    </div>
  );
}

export function Fold(props: { title: string; open: boolean; onToggle: () => void; children: React.ReactNode; meta?: string }) {
  return (
    <section className={'fold' + (props.open ? ' is-open' : '')}>
      <button type="button" className="fold__head" aria-expanded={props.open} onClick={props.onToggle}>
        <span>{props.title}</span>{props.meta ? <em>{props.meta}</em> : null}<i aria-hidden="true">▾</i>
      </button>
      {props.open ? <div className="fold__body">{props.children}</div> : null}
    </section>
  );
}

export const signed = (v: number) => (v > 0 ? `+${v.toFixed(1)}` : v.toFixed(1));
export const percent = (v: number) => `${Math.round(v * 100)} %`;
