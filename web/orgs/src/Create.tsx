// Formulario para fundar: tipo, nombre, identidad con vista previa y cofundadores cercanos.
import { useMemo, useState } from 'react';
import type { CreateInfo } from './types';
import { Emblem, Empty, Field, FontPicker, OrgName, Swatches } from './ui';
import { cleanEmblem, createBlocker, emblemFrom, money, type CreateForm } from './lib';

type Act = (action: string, payload?: Record<string, unknown>) => Promise<boolean>;

export function Create(p: { info: CreateInfo; act: Act; busy: boolean; onBack: () => void }) {
  const { info } = p;
  const [form, setForm] = useState<CreateForm>({
    type: info.types[0]?.id ?? '', name: '', color: info.colors[0] ?? '#5ce1ff', font: info.fonts[0]?.id ?? 'sora', emblem: '', motto: '', founders: [],
  });
  const [emblemEdited, setEmblemEdited] = useState(false);
  const emblem = emblemEdited ? form.emblem : emblemFrom(form.name || 'Org');
  const full = { ...form, emblem };
  const blocker = useMemo(() => createBlocker(full, info), [full, info]);
  const set = <K extends keyof CreateForm>(k: K, v: CreateForm[K]) => setForm((f) => ({ ...f, [k]: v }));
  const toggle = (id: number) => set('founders', form.founders.includes(id) ? form.founders.filter((x) => x !== id) : [...form.founders, id]);

  const submit = async () => {
    if (blocker) return;
    const ok = await p.act('createStart', { type: form.type, name: form.name.trim(), color: form.color, font: form.font, emblem, motto: form.motto.trim(), founders: form.founders });
    if (ok) p.onBack();
  };

  return (
    <div className="cols">
      <section className="col">
        <h2>Nueva organización</h2>
        <Field label="Tipo">
          <div className="seg" role="radiogroup" aria-label="Tipo">
            {info.types.map((t) => (
              <button key={t.id} type="button" role="radio" aria-checked={form.type === t.id} className={form.type === t.id ? 'is-on' : ''} onClick={() => set('type', t.id)}>{t.label}</button>
            ))}
          </div>
        </Field>
        <div className="row2">
          <Field label="Nombre" hint={`De ${info.nameMin} a ${info.nameMax} caracteres`}>
            <input value={form.name} maxLength={info.nameMax} onChange={(e) => set('name', e.target.value)} placeholder="Los Reyes del Sur" />
          </Field>
          <Field label="Emblema" hint="1 a 3 letras">
            <input value={emblem} maxLength={3} onChange={(e) => { setEmblemEdited(true); set('emblem', cleanEmblem(e.target.value)); }} />
          </Field>
        </div>
        <Field label="Lema (opcional)">
          <input value={form.motto} maxLength={info.mottoMax} onChange={(e) => set('motto', e.target.value)} placeholder="Una frase que os defina" />
        </Field>
        <Field label="Color"><Swatches colors={info.colors} value={form.color} onChange={(c) => set('color', c)} /></Field>
        <Field label="Tipografía">
          <FontPicker fonts={info.fonts} value={form.font} sample={form.name.trim() || 'Nombre'} color={form.color} onChange={(id) => set('font', id)} />
        </Field>
      </section>

      <section className="col">
        <div className="preview">
          <p className="eyebrow">Así se verá</p>
          <Emblem emblem={emblem} color={form.color} font={form.font} fonts={info.fonts} size="l" />
          <OrgName name={form.name.trim() || 'Nombre de la organización'} color={form.color} font={form.font} fonts={info.fonts} className="orgname--xl" />
          {form.motto.trim() ? <p className="preview__motto">«{form.motto.trim()}»</p> : null}
        </div>

        <h2>Cofundadores {info.minFounders > 1 ? `(${form.founders.length + 1} de ${info.minFounders})` : '(opcional)'}</h2>
        {info.nearby.length === 0 ? <Empty>No hay nadie cerca sin organización. Reúnete con quienes vayan a fundarla contigo.</Empty> : null}
        <ul className="list list--scroll list--short">
          {info.nearby.map((n) => (
            <li key={n.id} className="row">
              <label className="pick">
                <input type="checkbox" checked={form.founders.includes(n.id)} onChange={() => toggle(n.id)} />
                <b>{n.name}</b><span className="tag">ID {n.id}</span>
              </label>
            </li>
          ))}
        </ul>

        <ul className="reqs">
          {info.requirements.filter((r) => r.id !== 'founders').map((r) => (
            <li key={r.id} className={r.ok ? 'is-ok' : ''}><span className="check">{r.ok ? '✓' : '·'}</span>{r.label}<small>{r.detail}</small></li>
          ))}
        </ul>
        {blocker ? <p className="field__hint field__hint--warn">{blocker}</p> : null}
        <div className="actions">
          <button className="btn" onClick={p.onBack}>Volver</button>
          <button className="btn btn--primary" disabled={!!blocker || p.busy} onClick={submit}>
            {info.minFounders > 1 ? 'Proponer a los cofundadores' : 'Continuar'}
          </button>
        </div>
        <p className="field__hint">
          {info.cost > 0 ? `La tasa de ${money(info.cost)} se cobra al confirmar, cuando todos hayan aceptado. ` : ''}
          {info.approval === 'staff' && !info.staff ? 'Después la revisa el staff.' : ''}
        </p>
      </section>
    </div>
  );
}
