import { useEffect, useState } from 'react';
import type { Card, SelectionData } from './types';
import { post } from './nui';

const money = (n: number) => '$' + Math.floor(n).toLocaleString('en-US');
function hours(s?: number) { if (!s) return null; const h = Math.floor(s / 3600); return h >= 1 ? `${h} h jugadas` : `${Math.max(1, Math.floor(s / 60))} min jugados`; }

export function Selection(p: { data: SelectionData; busy: boolean; toast: (t: string) => void }) {
  const { data } = p;
  const byId = new Map(data.characters.map((c) => [c.citizenid, c]));
  const [sel, setSel] = useState(0);
  const [del, setDel] = useState<Card | null>(null);
  const slot = data.slots[sel];
  const card = slot && slot.kind === 'character' ? byId.get(slot.citizenid) : undefined;

  useEffect(() => { setSel(0); }, [data]);
  const choose = (i: number) => {
    setSel(i);
    const s = data.slots[i];
    if (s && s.kind === 'character') post('select', { citizenid: s.citizenid });
  };

  const play = async () => {
    if (!card || p.busy) return;
    const r = await post<{ ok: boolean; error?: string }>('play', { citizenid: card.citizenid });
    if (r && !r.ok && r.error) p.toast(r.error);
  };
  const create = async () => {
    const r = await post<{ ok: boolean; error?: string }>('createStart');
    if (r && !r.ok && r.error) p.toast(r.error);
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (del) return;
      if (e.key === 'ArrowDown') choose(Math.min(data.slots.length - 1, sel + 1));
      else if (e.key === 'ArrowUp') choose(Math.max(0, sel - 1));
      else if (e.key === 'Enter' && card) play();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  return (
    <div className="select">
      <aside className="panel panel--select" aria-label="Mis personajes">
        <header className="panel__head">
          <div>
            <p className="eyebrow">{data.serverName}</p>
            <h1>Mis personajes</h1>
          </div>
          <span className="steps"><b className="is-current">Personaje</b><b>Ubicación</b></span>
        </header>
        <ul className="slots" role="listbox" aria-label="Ranuras">
          {data.slots.map((s, i) => {
            const c = s.kind === 'character' ? byId.get(s.citizenid) : undefined;
            const dead = c?.status === 'dead';
            return (
              <li key={i}>
                <button type="button" role="option" aria-selected={i === sel}
                  className={'slot' + (i === sel ? ' is-on' : '') + (dead ? ' is-dead' : '') + (s.kind === 'locked' ? ' is-locked' : '')}
                  onClick={() => choose(i)}>
                  <span className="slot__n">{s.index}</span>
                  <span className="slot__icon" aria-hidden="true">{c ? (dead ? '✝' : c.gender === 1 ? '♀' : '♂') : s.kind === 'free' ? '+' : '🔒'}</span>
                  <span className="slot__name">
                    {c ? `${c.firstname} ${c.lastname}${dead ? ' (R.I.P.)' : ''}` : s.kind === 'free' ? 'Ranura disponible' : data.lockedLabel ?? 'Ranura bloqueada'}
                  </span>
                  <span className="slot__state">{c ? (dead ? 'R.I.P.' : 'Activo') : s.kind === 'free' ? 'Libre' : ''}</span>
                </button>
                {i === sel && s.kind === 'free' ? (
                  <div className="slot__free">
                    <p>Ranura libre para crear un nuevo personaje.</p>
                    <button type="button" className="btn btn--primary btn--block" onClick={create} disabled={p.busy}>Crear personaje</button>
                  </div>
                ) : null}
                {i === sel && s.kind === 'locked' ? (
                  <div className="slot__free"><p>Esta ranura se desbloquea con Próxima Plus.</p></div>
                ) : null}
              </li>
            );
          })}
        </ul>
      </aside>

      {card ? (
        <aside className="panel panel--info" aria-label="Personaje seleccionado">
          <p className="eyebrow">Ranura {slot?.index}</p>
          <h2>{card.firstname} {card.lastname}</h2>
          <span className={'pill' + (card.status === 'dead' ? ' pill--dead' : ' pill--ok')}>{card.status === 'dead' ? 'R.I.P.' : 'Activo'}</span>
          <dl className="sum">
            {card.job ? <><dt>Trabajo</dt><dd>{card.job}{card.grade ? ` · ${card.grade}` : ''}</dd></> : null}
            <dt>Última ubicación</dt><dd>{card.location ?? 'Sin registrar'}</dd>
            <dt>Efectivo</dt><dd>{money(card.cash)}</dd>
            <dt>Banco</dt><dd>{money(card.bank)}</dd>
            {card.level ? <><dt>Nivel</dt><dd>{card.level}{hours(card.playtime) ? ` · ${hours(card.playtime)}` : ''}</dd></> : null}
            {card.nationality ? <><dt>Nacionalidad</dt><dd>{card.nationality}</dd></> : null}
          </dl>
          <div className="panel__foot panel__foot--col">
            <button type="button" className="btn btn--primary btn--block" onClick={play} disabled={p.busy || card.status === 'dead'}>
              {card.status === 'dead' ? 'No disponible' : 'Jugar'}
            </button>
            {data.enableDelete ? <button type="button" className="link link--danger" onClick={() => setDel(card)}>Eliminar personaje</button> : null}
          </div>
        </aside>
      ) : null}

      {del ? <DeleteModal card={del} onClose={() => setDel(null)} toast={p.toast} /> : null}
    </div>
  );
}

function DeleteModal(p: { card: Card; onClose: () => void; toast: (t: string) => void }) {
  const [text, setText] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const name = `${p.card.firstname} ${p.card.lastname}`;
  const go = async () => {
    setBusy(true);
    const r = await post<{ ok: boolean; error?: string }>('delete', { citizenid: p.card.citizenid, confirm: text });
    setBusy(false);
    if (r && r.ok) { p.toast('Personaje eliminado.'); p.onClose(); } else setError(r?.error ?? 'No se pudo eliminar.');
  };
  return (
    <div className="modal" role="dialog" aria-modal="true" aria-labelledby="del-title">
      <div className="modal__card">
        <h2 id="del-title">Eliminar a {name}</h2>
        <p className="modal__text">Se borra para siempre, con su dinero, objetos y propiedades. Escribe su nombre completo para confirmar.</p>
        <label className="field"><span className="field__label">Nombre completo</span>
          <input value={text} onChange={(e) => { setText(e.target.value); setError(''); }} placeholder={name} autoFocus />
          {error ? <span className="field__error" role="alert">{error}</span> : null}
        </label>
        <div className="modal__actions">
          <button type="button" className="btn btn--ghost" onClick={p.onClose}>Cancelar</button>
          <button type="button" className="btn btn--danger" onClick={go} disabled={busy || !text.trim()}>Eliminar</button>
        </div>
      </div>
    </div>
  );
}
