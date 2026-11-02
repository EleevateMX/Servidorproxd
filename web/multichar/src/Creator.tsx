import { nationalityLabel } from './nationality';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { EditorData, Identity, Limits, Look, SectionId } from './types';
import { FREEMODE, SECTION_LABEL, clone, push, randomizeSection, replace, resetSection, undo, type History } from './look';
import { ClothesSection, FaceSection, HairSection, HeritageSection, IdentitySection, SkinSection } from './sections';
import { validateIdentity, type IdentityErrors } from './validation';
import { post } from './nui';

const ICONS: Record<SectionId, string> = {
  identity: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 8a7 7 0 0 1 14 0',
  heritage: 'M7 7a3 3 0 1 0 0 .1M17 7a3 3 0 1 0 0 .1M4 20a3 3 0 0 1 6 0m4 0a3 3 0 0 1 6 0M12 14v-3',
  face: 'M12 3a7 8 0 1 0 0 16 7 8 0 1 0 0-16Zm-3 7h.01M15 10h.01M9 15c2 1.5 4 1.5 6 0',
  skin: 'M12 3c3 4 6 7 6 11a6 6 0 0 1-12 0c0-4 3-7 6-11Z',
  hair: 'M5 13c0-5 3-9 7-9s7 4 7 9M5 13c2-1 3-4 3-6m11 6c-2-1-4-3-5-6',
  clothes: 'M8 4 4 7l2 3 2-1v11h8V9l2 1 2-3-4-3c-1 2-2 3-4 3s-3-1-4-3Z',
};

export function Creator(p: { data: EditorData; error: { text: string; field?: string } | null; onClearError: () => void }) {
  const { data } = p;
  const sections = data.sections;
  const [tab, setTab] = useState<SectionId>(sections[0]!);
  const [hist, setHist] = useState<History>({ past: [], present: data.look });
  const [limits, setLimits] = useState<Limits>(data.limits);
  const [identity, setIdentity] = useState<Identity>(data.identity ?? { firstname: '', lastname: '', gender: 0, birthdate: '', nationality: '' });
  const [errors, setErrors] = useState<IdentityErrors>({});
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [portraits, setPortraits] = useState<string | null>(null);
  const last = useRef<{ key: string; t: number }>({ key: '', t: 0 });
  const look = hist.present;
  const fullData = useMemo<EditorData>(() => ({ ...data, limits }), [data, limits]);

  // Retratos de los padres (si el diccionario del juego carga).
  useEffect(() => {
    if (!sections.includes('heritage')) return;
    post<{ ok: boolean; dict?: string }>('editorPortraits').then((r) => setPortraits(r && r.ok && r.dict ? r.dict : null));
  }, [sections]);

  // Errores del servidor (registro rechazado, guardado fallido…): el editor sigue abierto.
  useEffect(() => {
    if (!p.error) return;
    setBusy(false);
    setConfirm(false);
    const f = p.error.field;
    if (f && ['firstname', 'lastname', 'birthdate', 'nationality', 'identity', 'gender'].includes(f) && sections.includes('identity')) {
      setTab('identity');
      if (f !== 'identity' && f !== 'gender') setErrors((e) => ({ ...e, [f]: p.error!.text }));
    }
  }, [p.error, sections]);

  // Cada cambio va al cliente (debounce) que lo sanea, lo aplica al ped y devuelve la versión válida.
  const sendTimer = useRef<number | undefined>(undefined);
  const sync = useCallback((next: Look) => {
    window.clearTimeout(sendTimer.current);
    sendTimer.current = window.setTimeout(async () => {
      const r = await post<{ ok: boolean; look?: Look; limits?: Limits }>('editorLook', { look: next });
      if (r && r.ok && r.look) {
        if (r.limits) setLimits(r.limits);
        setHist((h) => (JSON.stringify(h.present) === JSON.stringify(r.look) ? h : replace(h, r.look!)));
      }
    }, 45);
  }, []);

  const change = useCallback((next: Look, key: string) => {
    const now = Date.now();
    const coalesce = key === last.current.key && now - last.current.t < 600;   // arrastrar un slider = un paso
    last.current = { key, t: now };
    setHist((h) => (coalesce ? replace(h, next) : push(h, next)));
    sync(next);
  }, [sync]);

  const goTab = (t: SectionId) => { setTab(t); post('editorCamera', { section: t }); };
  const idx = sections.indexOf(tab);
  const isLast = idx === sections.length - 1;

  const doUndo = () => setHist((h) => { const n = undo(h); if (n !== h) sync(n.present); return n; });
  const doRandom = () => tab !== 'identity' && change(randomizeSection(look, tab, fullData), 'random:' + Date.now());
  const doReset = () => {
    if (tab === 'identity') return;
    change(resetSection(look, tab, data.base, data.overlays), 'reset:' + Date.now());
  };
  const onGender = (g: 0 | 1) => {
    // Ropa y cabello del otro modelo desde sus valores por defecto; herencia y rasgos se conservan.
    const def = data.defaults?.[String(g)];
    const next = def ? { ...clone(def), headBlend: look.headBlend, faceFeatures: look.faceFeatures, eyeColor: look.eyeColor } : { ...clone(look), model: g ? 'mp_f_freemode_01' : 'mp_m_freemode_01' };
    setIdentity((i) => ({ ...i, gender: g }));
    change(next, 'gender');
  };

  const next = () => {
    if (tab === 'identity') {
      const e = validateIdentity({ ...identity, gender: FREEMODE[look.model] ?? 0 });
      setErrors(e);
      if (Object.keys(e).length) return;
    }
    if (isLast) {
      if (sections.includes('identity')) {
        const e = validateIdentity({ ...identity, gender: FREEMODE[look.model] ?? 0 });
        setErrors(e);
        if (Object.keys(e).length) { goTab('identity'); return; }
      }
      p.onClearError();
      setConfirm(true);
      return;
    }
    goTab(sections[idx + 1]!);
  };

  const finish = async () => {
    if (busy) return;
    setBusy(true);
    p.onClearError();
    const r = await post<{ ok: boolean; error?: string }>('editorFinish', { look, identity: { ...identity, gender: FREEMODE[look.model] ?? 0 } });
    if (!r || !r.ok) { setBusy(false); setConfirm(false); }
  };

  // Teclado: Ctrl+Z deshacer. Ratón sobre el centro: arrastrar gira, rueda acerca.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); doUndo(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });
  const drag = useRef<{ x: number } | null>(null);
  const lastRot = useRef(0);
  const onDown = (e: React.PointerEvent) => { drag.current = { x: e.clientX }; (e.target as Element).setPointerCapture?.(e.pointerId); };
  const onMove = (e: React.PointerEvent) => {
    if (!drag.current) return;
    const dx = e.clientX - drag.current.x;
    const now = Date.now();
    if (Math.abs(dx) > 6 && now - lastRot.current > 40) {
      post('editorCamera', { rotate: Math.max(-20, Math.min(20, dx * 0.4)) });
      drag.current = { x: e.clientX };
      lastRot.current = now;
    }
  };
  const onUp = () => { drag.current = null; };
  const onWheel = (e: React.WheelEvent) => post('editorCamera', { zoom: e.deltaY > 0 ? 0.08 : -0.08 });

  const title = data.title ?? (data.mode === 'create' ? 'Crear personaje' : 'Editar apariencia');
  const fullName = `${identity.firstname} ${identity.lastname}`.trim();

  return (
    <div className="creator">
      <aside className="panel" aria-label={title}>
        <header className="panel__head">
          <div>
            <p className="eyebrow">{data.mode === 'create' ? `Paso ${idx + 1} de ${sections.length}` : 'Apariencia'}</p>
            <h1>{title}</h1>
          </div>
          <button type="button" className="icon-btn" onClick={doUndo} disabled={hist.past.length === 0} title="Deshacer (Ctrl+Z)" aria-label="Deshacer">↶</button>
        </header>
        <nav className="tabs" role="tablist" style={{ gridTemplateColumns: `repeat(${sections.length}, minmax(0, 1fr))` }}>
          {sections.map((s, i) => (
            <button key={s} type="button" role="tab" aria-selected={s === tab} className={'tab' + (s === tab ? ' is-on' : '') + (i < idx ? ' is-done' : '')}
              onClick={() => goTab(s)} title={SECTION_LABEL[s]}>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d={ICONS[s]} /></svg>
              <span>{SECTION_LABEL[s]}</span>
            </button>
          ))}
        </nav>
        {p.error && !confirm ? <div className="banner" role="alert">{p.error.text}</div> : null}
        <div className="panel__body">
          {tab === 'identity' ? <IdentitySection identity={identity} errors={errors} onIdentity={(i) => { setIdentity(i); setErrors({}); }} look={look} onGender={onGender} /> : null}
          {tab === 'heritage' ? <HeritageSection look={look} onChange={change} portraits={portraits} /> : null}
          {tab === 'face' ? <FaceSection look={look} onChange={change} data={fullData} /> : null}
          {tab === 'skin' ? <SkinSection look={look} onChange={change} data={fullData} /> : null}
          {tab === 'hair' ? <HairSection look={look} onChange={change} data={fullData} /> : null}
          {tab === 'clothes' ? <ClothesSection look={look} onChange={change} data={fullData} /> : null}
        </div>
        <footer className="panel__foot">
          <button type="button" className="btn btn--ghost" onClick={() => idx > 0 && goTab(sections[idx - 1]!)} disabled={idx === 0}>Anterior</button>
          <button type="button" className="btn btn--ghost" onClick={doRandom} disabled={tab === 'identity'}>Aleatorio</button>
          <button type="button" className="btn btn--ghost" onClick={doReset} disabled={tab === 'identity'}>Restablecer</button>
          <button type="button" className="btn btn--primary" onClick={next}>{isLast ? (data.mode === 'create' ? 'Finalizar' : 'Guardar') : 'Siguiente'}</button>
        </footer>
        {data.mode !== 'recover' ? (
          <button type="button" className="link" onClick={() => post('editorCancel')}>{data.mode === 'create' ? 'Volver a la selección' : 'Cancelar y salir'}</button>
        ) : null}
      </aside>

      <div className="stage" onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp} onWheel={onWheel} aria-hidden="true" />

      <aside className="cam" aria-label="Cámara">
        <div className="cam__group">
          {(['body', 'torso', 'face', 'hair'] as const).map((k) => (
            <button key={k} type="button" className="cam__btn" onClick={() => post('editorCamera', { preset: k })}>
              {{ body: 'Cuerpo', torso: 'Torso', face: 'Rostro', hair: 'Cabello' }[k]}
            </button>
          ))}
        </div>
        <div className="cam__group cam__group--row">
          <button type="button" className="cam__btn" aria-label="Girar a la izquierda" onClick={() => post('editorCamera', { rotate: -20 })}>⟲</button>
          <button type="button" className="cam__btn" aria-label="Girar a la derecha" onClick={() => post('editorCamera', { rotate: 20 })}>⟳</button>
          <button type="button" className="cam__btn" aria-label="Acercar" onClick={() => post('editorCamera', { zoom: -0.12 })}>＋</button>
          <button type="button" className="cam__btn" aria-label="Alejar" onClick={() => post('editorCamera', { zoom: 0.12 })}>－</button>
        </div>
        <button type="button" className="cam__btn cam__btn--wide" onClick={() => post('editorCamera', { reset: true })}>Restaurar vista</button>
        <p className="cam__help">Arrastra sobre el personaje para girarlo · rueda para acercar · Ctrl+Z deshace</p>
      </aside>

      {confirm ? (
        <div className="modal" role="dialog" aria-modal="true" aria-labelledby="confirm-title">
          <div className="modal__card">
            <h2 id="confirm-title">{data.mode === 'create' ? '¿Crear este personaje?' : '¿Guardar los cambios?'}</h2>
            {data.mode === 'create' ? (
              <dl className="sum">
                <dt>Nombre</dt><dd>{fullName}</dd>
                <dt>Sexo</dt><dd>{FREEMODE[look.model] === 1 ? 'Femenino' : 'Masculino'}</dd>
                <dt>Nacimiento</dt><dd>{identity.birthdate}</dd>
                <dt>Nacionalidad</dt><dd>{nationalityLabel(identity.nationality)}</dd>
              </dl>
            ) : null}
            <p className="modal__text">{data.mode === 'create'
              ? 'El nombre y la fecha no se podrán cambiar después. La apariencia sí, en peluquerías, tiendas y clínicas.'
              : data.price ? `Coste: $${data.price}.` : 'Se guardará tu nueva apariencia.'}</p>
            {p.error ? <div className="banner" role="alert">{p.error.text}</div> : null}
            <div className="modal__actions">
              <button type="button" className="btn btn--ghost" onClick={() => setConfirm(false)} disabled={busy}>Seguir editando</button>
              <button type="button" className="btn btn--primary" onClick={finish} disabled={busy}>{busy ? 'Guardando…' : data.mode === 'create' ? 'Crear personaje' : 'Guardar'}</button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
