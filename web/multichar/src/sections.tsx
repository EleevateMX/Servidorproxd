import { useState } from 'react';
import type { EditorData, Identity, Look } from './types';
import { Fold, Slider, Stepper, Swatches, percent, signed } from './controls';
import { EYE_COLOR_NAMES, NATURAL_EYES, PARENT_NAMES, portraitTexture } from './data';
import { FATHERS, FREEMODE, MOTHERS, clone, drawablesOf, getComponent, getProp, setComponent, setProp, texturesFor } from './look';
import type { IdentityErrors } from './validation';

type Change = (next: Look, key: string) => void;

// ── A. Identidad ──────────────────────────────────────
export function IdentitySection(p: {
  identity: Identity; errors: IdentityErrors; onIdentity: (i: Identity) => void; look: Look; onGender: (g: 0 | 1) => void;
}) {
  const { identity: id, errors, onIdentity } = p;
  const gender = FREEMODE[p.look.model] ?? 0;
  const set = (k: keyof Identity, v: string) => onIdentity({ ...id, [k]: v });
  return (
    <div className="sec">
      <div className="row2">
        <Field label="Nombre" error={errors.firstname}>
          <input value={id.firstname} maxLength={25} autoComplete="off" onChange={(e) => set('firstname', e.target.value)} aria-invalid={!!errors.firstname} />
        </Field>
        <Field label="Apellido" error={errors.lastname}>
          <input value={id.lastname} maxLength={25} autoComplete="off" onChange={(e) => set('lastname', e.target.value)} aria-invalid={!!errors.lastname} />
        </Field>
      </div>
      <Field label="Sexo">
        <div className="seg" role="radiogroup" aria-label="Sexo">
          {(['Masculino', 'Femenino'] as const).map((t, g) => (
            <button key={t} type="button" role="radio" aria-checked={gender === g} className={gender === g ? 'is-on' : ''}
              onClick={() => gender !== g && p.onGender(g as 0 | 1)}>{t}</button>
          ))}
        </div>
        <p className="ctl__hint">Cambiar el sexo restablece la ropa y el cabello; la herencia y los rasgos se conservan.</p>
      </Field>
      <div className="row2">
        <Field label="Fecha de nacimiento" error={errors.birthdate}>
          <input type="date" value={id.birthdate} min={id.dateMin} max={id.dateMax} onChange={(e) => set('birthdate', e.target.value)} aria-invalid={!!errors.birthdate} />
        </Field>
        <Field label="Nacionalidad" error={errors.nationality}>
          {id.limitNationalities && id.nationalities?.length ? (
            <select value={id.nationality} onChange={(e) => set('nationality', e.target.value)} aria-invalid={!!errors.nationality}>
              {id.nationalities.map((n) => <option key={n} value={n}>{n}</option>)}
            </select>
          ) : (
            <input value={id.nationality} maxLength={30} onChange={(e) => set('nationality', e.target.value)} aria-invalid={!!errors.nationality} />
          )}
        </Field>
      </div>
    </div>
  );
}

function Field(p: { label: string; error?: string; children: React.ReactNode }) {
  return (
    <label className={'field' + (p.error ? ' has-error' : '')}>
      <span className="field__label">{p.label}</span>
      {p.children}
      {p.error ? <span className="field__error" role="alert">{p.error}</span> : null}
    </label>
  );
}

// ── B. Herencia ───────────────────────────────────────
function Parent(p: { label: string; ids: number[]; value: number; onChange: (v: number) => void; portraits: string | null }) {
  const [broken, setBroken] = useState<Record<number, boolean>>({});
  const idx = Math.max(0, p.ids.indexOf(p.value));
  const go = (d: number) => p.onChange(p.ids[(idx + d + p.ids.length) % p.ids.length]!);
  const src = p.portraits && !broken[p.value] ? `https://nui-img/${p.portraits}/${portraitTexture(p.value)}` : null;
  return (
    <div className="parent">
      <div className="parent__pic">
        {src ? <img src={src} alt="" onError={() => setBroken((b) => ({ ...b, [p.value]: true }))} /> : <span aria-hidden="true">{(PARENT_NAMES[p.value] ?? '?').slice(0, 1)}</span>}
      </div>
      <div className="parent__info">
        <span className="parent__label">{p.label}</span>
        <b>{PARENT_NAMES[p.value] ?? `#${p.value}`}</b>
        <span className="parent__n">{idx + 1} / {p.ids.length}</span>
      </div>
      <div className="parent__nav">
        <button type="button" aria-label={`${p.label}: anterior`} onClick={() => go(-1)}>‹</button>
        <button type="button" aria-label={`${p.label}: siguiente`} onClick={() => go(1)}>›</button>
      </div>
    </div>
  );
}

export function HeritageSection(p: { look: Look; onChange: Change; portraits: string | null }) {
  const hb = p.look.headBlend;
  const set = (patch: Partial<typeof hb>, key: string) => { const n = clone(p.look); n.headBlend = { ...hb, ...patch }; p.onChange(n, key); };
  return (
    <div className="sec">
      <Parent label="Madre" ids={MOTHERS} value={hb.shapeFirst} portraits={p.portraits} onChange={(v) => set({ shapeFirst: v, skinFirst: v }, 'mother')} />
      <Parent label="Padre" ids={FATHERS} value={hb.shapeSecond} portraits={p.portraits} onChange={(v) => set({ shapeSecond: v, skinSecond: v }, 'father')} />
      <Slider label="Parecido de cara (madre ↔ padre)" value={hb.shapeMix} min={0} max={1} step={0.01} format={percent}
        onChange={(v) => set({ shapeMix: v }, 'shapeMix')} />
      <Slider label="Tono de piel (madre ↔ padre)" value={hb.skinMix} min={0} max={1} step={0.01} format={percent}
        onChange={(v) => set({ skinMix: v }, 'skinMix')} />
    </div>
  );
}

// ── C. Estructura facial ──────────────────────────────
export function FaceSection(p: { look: Look; onChange: Change; data: EditorData }) {
  const [open, setOpen] = useState<string>(p.data.regions[0]?.id ?? 'nose');
  return (
    <div className="sec">
      {p.data.regions.map((r) => {
        const feats = p.data.features.filter((f) => f.region === r.id);
        return (
          <Fold key={r.id} title={r.label} open={open === r.id} onToggle={() => setOpen(open === r.id ? '' : r.id)} meta={`${feats.length}`}>
            {feats.map((f) => (
              <Slider key={f.key} label={f.label} value={p.look.faceFeatures[f.key] ?? 0} min={-1} max={1} step={0.1} format={signed}
                onChange={(v) => { const n = clone(p.look); n.faceFeatures[f.key] = v; p.onChange(n, 'ff:' + f.key); }} />
            ))}
          </Fold>
        );
      })}
    </div>
  );
}

// ── D. Piel y E. Cabello: overlays ────────────────────
function OverlayCtl(p: { idx: number; look: Look; data: EditorData; onChange: Change }) {
  const def = p.data.overlays[p.idx]!;
  const o = p.look.headOverlays[def.key] ?? { style: 0, opacity: 0, color: 0, secondColor: 0 };
  const max = Math.max(0, (p.data.limits.overlays[String(p.idx)] ?? 1) - 1);
  const set = (patch: Partial<typeof o>, key: string) => { const n = clone(p.look); n.headOverlays[def.key] = { ...o, ...patch }; p.onChange(n, key + def.key); };
  const palette = def.colorType === 2 ? p.data.palettes.makeup : p.data.palettes.hair;
  return (
    <>
      <Slider label="Tipo" value={o.style} min={0} max={max} onChange={(v) => set({ style: v, opacity: o.opacity || 1 }, 'st:')} format={(v) => `${v + 1} / ${max + 1}`} />
      <Slider label="Opacidad" value={o.opacity} min={0} max={1} step={0.1} format={percent} onChange={(v) => set({ opacity: v }, 'op:')}
        hint={o.opacity === 0 ? 'Con opacidad 0 no se ve.' : undefined} />
      {def.colorType ? <Swatches label="Color" colors={palette} value={o.color} onChange={(v) => set({ color: v, secondColor: def.colorType === 1 ? v : o.secondColor }, 'co:')} /> : null}
    </>
  );
}

export function SkinSection(p: { look: Look; data: EditorData; onChange: Change }) {
  const [open, setOpen] = useState('eyes');
  return (
    <div className="sec">
      <Fold title="Color de ojos" open={open === 'eyes'} onToggle={() => setOpen(open === 'eyes' ? '' : 'eyes')} meta={EYE_COLOR_NAMES[p.look.eyeColor]}>
        <Slider label="Color" value={p.look.eyeColor} min={0} max={EYE_COLOR_NAMES.length - 1}
          format={(v) => EYE_COLOR_NAMES[v] ?? String(v)} hint={p.look.eyeColor >= NATURAL_EYES ? 'Lentillas de fantasía.' : undefined}
          onChange={(v) => { const n = clone(p.look); n.eyeColor = v; p.onChange(n, 'eyes'); }} />
      </Fold>
      {p.data.overlays.map((o, i) => o.section !== 'skin' ? null : (
        <Fold key={o.key} title={o.label} open={open === o.key} onToggle={() => setOpen(open === o.key ? '' : o.key)}
          meta={(p.look.headOverlays[o.key]?.opacity ?? 0) > 0 ? 'Activo' : 'No'}>
          <OverlayCtl idx={i} look={p.look} data={p.data} onChange={p.onChange} />
        </Fold>
      ))}
    </div>
  );
}

export function HairSection(p: { look: Look; data: EditorData; onChange: Change }) {
  const [open, setOpen] = useState('hair');
  const female = FREEMODE[p.look.model] === 1;
  const h = p.look.hair;
  const styles = drawablesOf(p.data.limits, 'component', 2);
  const tex = texturesFor(p.data.limits, 'component', 2, h.style);
  const setHair = (patch: Partial<typeof h>, key: string) => { const n = clone(p.look); n.hair = { ...h, ...patch }; p.onChange(n, key); };
  return (
    <div className="sec">
      <Fold title="Peinado" open={open === 'hair'} onToggle={() => setOpen(open === 'hair' ? '' : 'hair')} meta={`${h.style + 1} / ${styles}`}>
        <Slider label="Peinado" value={h.style} min={0} max={styles - 1} format={(v) => `${v + 1} / ${styles}`} onChange={(v) => setHair({ style: v, texture: 0 }, 'hs')} />
        <Slider label="Variante" value={h.texture} min={0} max={tex - 1} format={(v) => `${v + 1} / ${tex}`} onChange={(v) => setHair({ texture: v }, 'ht')} />
        <Swatches label="Color" colors={p.data.palettes.hair} value={h.color} onChange={(v) => setHair({ color: v }, 'hc')} />
        <Swatches label="Reflejos" colors={p.data.palettes.hair} value={h.highlight} onChange={(v) => setHair({ highlight: v }, 'hh')} />
      </Fold>
      {p.data.overlays.map((o, i) => {
        if (o.section !== 'hair') return null;
        if (female && (o.key === 'beard' || o.key === 'chestHair')) return null;
        return (
          <Fold key={o.key} title={o.label} open={open === o.key} onToggle={() => setOpen(open === o.key ? '' : o.key)}
            meta={(p.look.headOverlays[o.key]?.opacity ?? 0) > 0 ? 'Activo' : 'No'}>
            <OverlayCtl idx={i} look={p.look} data={p.data} onChange={p.onChange} />
          </Fold>
        );
      })}
    </div>
  );
}

// ── F. Vestuario ──────────────────────────────────────
const GROUPS: { id: string; label: string; match: (kind: string, id: number) => boolean }[] = [
  { id: 'top', label: 'Parte superior', match: (k, id) => k === 'component' && (id === 11 || id === 8 || id === 3) },
  { id: 'bottom', label: 'Parte inferior y calzado', match: (k, id) => k === 'component' && (id === 4 || id === 6) },
  { id: 'acc', label: 'Accesorios', match: (k, id) => k === 'prop' || (k === 'component' && (id === 7 || id === 5)) },
];

export function ClothesSection(p: { look: Look; data: EditorData; onChange: Change }) {
  const [open, setOpen] = useState('top');
  const gender = String(FREEMODE[p.look.model] ?? 0);
  const outfits = p.data.outfits[gender] ?? [];
  const wear = (i: number) => {
    let n = clone(p.look);
    const o = outfits[i]!;
    for (const c of o.components) n = setComponent(n, c.component_id, c.drawable, c.texture);
    for (const pr of o.props ?? []) n = setProp(n, pr.prop_id, pr.drawable, pr.texture);
    p.onChange(n, 'outfit');
  };
  const garment = (c: EditorData['clothes'][number]) => {
    if (c.kind === 'component') {
      const cur = getComponent(p.look, c.id);
      const n = drawablesOf(p.data.limits, 'component', c.id);
      const t = texturesFor(p.data.limits, 'component', c.id, cur.drawable);
      return (
        <div className="garment" key={'c' + c.id}>
          <Stepper label={c.label} value={cur.drawable} min={0} max={n - 1} onChange={(v) => p.onChange(setComponent(p.look, c.id, v, 0), 'c' + c.id)} />
          <Stepper label="Textura" value={cur.texture} min={0} max={t - 1} onChange={(v) => p.onChange(setComponent(p.look, c.id, cur.drawable, v), 'ct' + c.id)} />
        </div>
      );
    }
    const cur = getProp(p.look, c.id);
    const n = drawablesOf(p.data.limits, 'prop', c.id);
    const t = cur.drawable >= 0 ? texturesFor(p.data.limits, 'prop', c.id, cur.drawable) : 1;
    return (
      <div className="garment" key={'p' + c.id}>
        <Stepper label={c.label} value={cur.drawable} min={-1} max={n - 1} noneLabel="Ninguno" onChange={(v) => p.onChange(setProp(p.look, c.id, v, 0), 'p' + c.id)} />
        {cur.drawable >= 0 ? <Stepper label="Textura" value={cur.texture} min={0} max={t - 1} onChange={(v) => p.onChange(setProp(p.look, c.id, cur.drawable, v), 'pt' + c.id)} /> : null}
      </div>
    );
  };
  return (
    <div className="sec">
      {outfits.length ? (
        <div className="chips" aria-label="Conjuntos iniciales">
          {outfits.map((o, i) => <button key={o.id} type="button" className="chip" onClick={() => wear(i)}>{o.label}</button>)}
        </div>
      ) : null}
      {GROUPS.map((g) => {
        const items = p.data.clothes.filter((c) => g.match(c.kind, c.id));
        if (!items.length) return null;
        return (
          <Fold key={g.id} title={g.label} open={open === g.id} onToggle={() => setOpen(open === g.id ? '' : g.id)} meta={`${items.length}`}>
            {items.map(garment)}
          </Fold>
        );
      })}
    </div>
  );
}
