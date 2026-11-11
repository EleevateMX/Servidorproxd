// Piezas comunes de la interfaz de organizaciones.
import { useEffect, type ReactNode } from 'react';
import type { Font } from './types';
import { fontFamily, sampleOf } from './lib';

/** Insignia de la organización: iniciales sobre su color. */
export function Emblem(p: { emblem: string; color: string; font?: string; fonts?: Font[]; size?: 's' | 'm' | 'l' }) {
  return (
    <span className={`emblem emblem--${p.size ?? 'm'}`} style={{ background: p.color, fontFamily: fontFamily(p.fonts, p.font ?? 'sora') }}>
      {p.emblem}
    </span>
  );
}

/** Nombre escrito con la tipografía y el color de la organización. */
export function OrgName(p: { name: string; color: string; font: string; fonts?: Font[]; className?: string }) {
  return <span className={`orgname ${p.className ?? ''}`} style={{ color: p.color, fontFamily: fontFamily(p.fonts, p.font) }}>{p.name}</span>;
}

export function Field(p: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="field">
      <span className="field__label">{p.label}</span>
      {p.children}
      {p.hint ? <span className="field__hint">{p.hint}</span> : null}
    </label>
  );
}

export function Swatches(p: { colors: string[]; value: string; onChange?: (c: string) => void }) {
  return (
    <div className="swatches" role="radiogroup" aria-label="Color">
      {p.colors.map((c) => (
        <button key={c} type="button" role="radio" aria-checked={c === p.value} aria-label={c} disabled={!p.onChange}
          className={`swatch ${c === p.value ? 'is-on' : ''}`} style={{ background: c }} onClick={() => p.onChange?.(c)} />
      ))}
    </div>
  );
}

export function FontPicker(p: { fonts: Font[]; value: string; sample: string; color: string; onChange?: (id: string) => void }) {
  return (
    <div className="fonts" role="radiogroup" aria-label="Tipografía">
      {p.fonts.map((f) => (
        <button key={f.id} type="button" role="radio" aria-checked={f.id === p.value} disabled={!p.onChange}
          className={`fontcard ${f.id === p.value ? 'is-on' : ''}`} onClick={() => p.onChange?.(f.id)}>
          <span className="fontcard__sample" style={{ fontFamily: fontFamily(p.fonts, f.id), color: p.color }}>{sampleOf(p.sample)}</span>
          <span className="fontcard__label">{f.label}</span>
        </button>
      ))}
    </div>
  );
}

/** Ventana de confirmación. Escape o «Volver» la cierran sin hacer nada. */
export function Modal(p: { title: string; children: ReactNode; confirm: string; danger?: boolean; disabled?: boolean; onConfirm: () => void; onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); p.onClose(); } };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [p.onClose]);
  return (
    <div className="modal" role="dialog" aria-modal="true" aria-label={p.title}>
      <div className="modal__box">
        <h3>{p.title}</h3>
        <div className="modal__body">{p.children}</div>
        <div className="modal__foot">
          <button type="button" className="btn" onClick={p.onClose}>Volver</button>
          <button type="button" className={`btn ${p.danger ? 'btn--danger' : 'btn--primary'}`} disabled={p.disabled} onClick={p.onConfirm}>{p.confirm}</button>
        </div>
      </div>
    </div>
  );
}

export function Empty(p: { children: ReactNode }) {
  return <p className="empty">{p.children}</p>;
}
