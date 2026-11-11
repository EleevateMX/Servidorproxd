// Sin organización: invitaciones, propuestas para cofundar, solicitud pendiente, fundar y directorio.
import { useState } from 'react';
import type { State } from './types';
import { Emblem, Empty, OrgName } from './ui';
import { money, timeLeft } from './lib';
import { Create } from './Create';

type Act = (action: string, payload?: Record<string, unknown>) => Promise<boolean>;

export function Home(p: { state: State; act: Act; now: number; busy: boolean }) {
  const { state, act, now, busy } = p;
  const [creating, setCreating] = useState(false);
  const fonts = state.create?.fonts;
  const d = state.draft;

  if (creating && state.create && !d && !state.pending) return <Create info={state.create} act={act} busy={busy} onBack={() => setCreating(false)} />;

  return (
    <div className="cols">
      <section className="col">
        {state.otherGang ? <div className="note">Perteneces a «{state.otherGang}», una banda que no se gestiona desde aquí.</div> : null}

        {d ? (
          <div className="card card--accent">
            <p className="eyebrow">Fundación en curso · caduca en {timeLeft(d.expires, now)}</p>
            <div className="idrow">
              <Emblem emblem={d.identity.emblem} color={d.identity.color} font={d.identity.font} fonts={fonts} size="l" />
              <div>
                <OrgName name={d.name} color={d.identity.color} font={d.identity.font} fonts={fonts} className="orgname--l" />
                <p className="muted">{d.typeLabel} · {d.count} de {d.needed} fundadores</p>
              </div>
            </div>
            <ul className="list">
              <li className="row"><span className="dot dot--ok" /> <b>{state.me.name}</b><span className="tag">Tú</span></li>
              {d.founders.map((f) => (
                <li key={f.citizenid} className="row">
                  <span className={`dot ${f.accepted ? 'dot--ok' : ''}`} /> <b>{f.name}</b>
                  <span className="tag">{f.accepted ? 'Acepta' : 'Esperando respuesta'}</span>
                </li>
              ))}
            </ul>
            <div className="actions">
              <button className="btn" disabled={busy} onClick={() => act('createCancel')}>Cancelar</button>
              <button className="btn btn--primary" disabled={busy || d.count < d.needed} onClick={() => act('createConfirm')}>
                {d.cost > 0 ? `Fundar · pagar ${money(d.cost)}` : 'Fundar'}
              </button>
            </div>
            {d.count < d.needed ? <p className="field__hint">Tus cofundadores deben aceptar con /{state.command} y seguir cerca de ti.</p> : null}
          </div>
        ) : null}

        {state.pending ? (
          <div className="card">
            <p className="eyebrow">Solicitud pendiente de aprobación</p>
            <div className="idrow">
              <Emblem emblem={state.pending.emblem} color={state.pending.color} font={state.pending.font} fonts={fonts} size="l" />
              <div>
                <OrgName name={state.pending.name} color={state.pending.color} font={state.pending.font} fonts={fonts} className="orgname--l" />
                <p className="muted">{state.pending.typeLabel} · {state.pending.founders.map((f) => f.name).join(', ')}</p>
              </div>
            </div>
            <p className="field__hint">El staff la revisará. Si se rechaza, se devuelve la tasa{state.pending.cost > 0 ? ` (${money(state.pending.cost)})` : ''}.</p>
          </div>
        ) : null}

        <h2>Invitaciones</h2>
        {state.invites.length === 0 && state.founding.length === 0 ? <Empty>No tienes invitaciones pendientes.</Empty> : null}
        <ul className="list">
          {state.founding.map((f) => (
            <li key={f.creator} className="row row--tall">
              <Emblem emblem={f.emblem} color={f.color} font={f.font} fonts={fonts} />
              <div className="row__main">
                <OrgName name={f.name} color={f.color} font={f.font} fonts={fonts} />
                <span className="muted">{f.by} te propone fundarla · {f.typeLabel} · {timeLeft(f.expires, now)}</span>
              </div>
              {f.accepted ? <span className="tag tag--ok">Aceptada</span> : (
                <span className="row__btns">
                  <button className="btn btn--s" disabled={busy} onClick={() => act('founderAnswer', { creator: f.creator, accept: false })}>Rechazar</button>
                  <button className="btn btn--s btn--primary" disabled={busy || !!state.otherGang} onClick={() => act('founderAnswer', { creator: f.creator, accept: true })}>Aceptar</button>
                </span>
              )}
            </li>
          ))}
          {state.invites.map((i) => (
            <li key={i.id} className="row row--tall">
              <Emblem emblem={i.emblem} color={i.color} font={i.font} fonts={fonts} />
              <div className="row__main">
                <OrgName name={i.name} color={i.color} font={i.font} fonts={fonts} />
                <span className="muted">{i.by} te invita · {i.typeLabel} · {timeLeft(i.expires, now)}</span>
              </div>
              <span className="row__btns">
                <button className="btn btn--s" disabled={busy} onClick={() => act('inviteAnswer', { org: i.id, accept: false })}>Rechazar</button>
                <button className="btn btn--s btn--primary" disabled={busy || !!state.otherGang} onClick={() => act('inviteAnswer', { org: i.id, accept: true })}>Unirme</button>
              </span>
            </li>
          ))}
        </ul>

        {state.create && !d && !state.pending ? (
          <div className="card card--cta">
            <h2>Funda tu organización</h2>
            <p className="muted">Banda, grupo o club de motos con su nombre, color y tipografía. {state.create.approval === 'staff' && !state.create.staff ? 'El staff aprueba cada solicitud.' : ''}</p>
            <ul className="reqs">
              {state.create.requirements.map((r) => (
                <li key={r.id} className={r.ok ? 'is-ok' : ''}><span className="check">{r.ok ? '✓' : '·'}</span>{r.label}<small>{r.detail}</small></li>
              ))}
            </ul>
            <button className="btn btn--primary" disabled={state.create.blocked} onClick={() => setCreating(true)}>Crear organización</button>
            {state.create.blocked ? <p className="field__hint">Ya perteneces a una banda: sal de ella primero.</p> : null}
          </div>
        ) : null}
      </section>

      <section className="col">
        <h2>Organizaciones de la ciudad</h2>
        {state.directory.length === 0 ? <Empty>Todavía no hay organizaciones oficiales.</Empty> : null}
        <ul className="list list--scroll">
          {state.directory.map((o) => (
            <li key={o.id} className="row row--tall">
              <Emblem emblem={o.emblem} color={o.color} font={o.font} fonts={fonts} />
              <div className="row__main">
                <span className="orgname" style={{ color: o.color, fontFamily: `'${o.fontFamily}', 'Sora', sans-serif` }}>{o.name}</span>
                <span className="muted">{o.typeLabel} · nivel {o.level}{o.motto ? ` · «${o.motto}»` : ''}</span>
              </div>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
