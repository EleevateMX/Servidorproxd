import { useEffect, useState } from 'react';
import type { SpawnView } from './types';
import { post } from './nui';

const BADGE: Record<string, [string, string]> = {
  last: ['Última ubicación', 'badge'], property: ['Tu casa', 'badge badge--gold'], point: ['Ciudad', 'badge badge--muted'], apartment: ['Gratis', 'badge badge--ok'],
};
const SAFE_IMG = /^[\w./-]+\.(jpg|jpeg|png|webp)$/;

export function Spawn(p: { view: SpawnView }) {
  const { view } = p;
  const [sel, setSel] = useState(0);
  const [sending, setSending] = useState(false);
  const opts = view.options;

  useEffect(() => { setSel(0); setSending(false); }, [view]);
  useEffect(() => { const o = opts[sel]; if (o) post('spawnFocus', { id: o.id }); }, [sel, opts]);

  const choose = async () => {
    const o = opts[sel];
    if (!o || sending) return;
    setSending(true);
    const r = await post<{ ok: boolean }>('spawnChoose', { id: o.id });
    if (!r || !r.ok) setSending(false);
  };
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') setSel((s) => Math.min(opts.length - 1, s + 1));
      else if (e.key === 'ArrowLeft') setSel((s) => Math.max(0, s - 1));
      else if (e.key === 'Enter') choose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  return (
    <section className="spawn" aria-live="polite">
      <div className="spawn__veil" aria-hidden="true" />
      <header className="spawn__head">
        <div className="spawn__top">
          <img src="logo.svg" alt="Próxima RP" className="spawn__logo" />
          <span className="steps"><b className="is-done">Personaje</b><b className="is-current">Ubicación</b></span>
        </div>
        <p className="eyebrow">{view.kicker}</p>
        <h1>{view.title}</h1>
        <p className="spawn__text">{view.text}</p>
      </header>
      <ul className="spawn__list" role="listbox" aria-label="Opciones">
        {opts.map((o, i) => {
          const [label, cls] = BADGE[o.kind] ?? BADGE.point!;
          return (
            <li key={o.id}>
              <button type="button" role="option" aria-selected={i === sel} className={'spot' + (i === sel ? ' is-on' : '')}
                onClick={() => (i === sel ? choose() : setSel(i))}>
                <span className="spot__img" style={o.image && SAFE_IMG.test(o.image) ? { backgroundImage: `url("${o.image}")` } : undefined} />
                <span className={cls}>{label}</span>
                <span className="spot__body"><b>{o.label}</b>{o.detail ? <span>{o.detail}</span> : null}</span>
              </button>
            </li>
          );
        })}
      </ul>
      <footer className="spawn__foot">
        <p className="hint"><kbd>←</kbd><kbd>→</kbd> elegir <kbd>Enter</kbd> confirmar</p>
        <button type="button" className="btn btn--primary btn--xl" onClick={choose} disabled={sending}>{view.confirm ?? 'Aparecer'}</button>
      </footer>
    </section>
  );
}
