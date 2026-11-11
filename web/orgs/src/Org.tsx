// Mi organización: miembros, fondos, identidad, invitaciones y ajustes.
import { useState } from 'react';
import type { Member, OrgView, State } from './types';
import { Emblem, Empty, Field, FontPicker, Modal, OrgName, Swatches } from './ui';
import { actionLabel, canKick, cleanEmblem, gradeOptions, money, repProgress, timeLeft } from './lib';

type Act = (action: string, payload?: Record<string, unknown>) => Promise<boolean>;
export type OrgTab = 'members' | 'funds' | 'identity' | 'invites' | 'settings';
type Tab = OrgTab;
type Confirm = { kind: 'kick' | 'transfer'; member: Member } | { kind: 'leave' } | { kind: 'dissolve' } | null;

const TABS: { id: Tab; label: string }[] = [
  { id: 'members', label: 'Miembros' }, { id: 'funds', label: 'Fondos' }, { id: 'identity', label: 'Identidad' },
  { id: 'invites', label: 'Invitar' }, { id: 'settings', label: 'Ajustes' },
];

export function Org(p: { state: State; org: OrgView; act: Act; now: number; busy: boolean; initialTab?: Tab }) {
  const { state, org, act, now, busy } = p;
  const [tab, setTab] = useState<Tab>(p.initialTab ?? 'members');
  const [confirm, setConfirm] = useState<Confirm>(null);
  const [typed, setTyped] = useState('');
  const fonts = state.identityOptions?.fonts;
  const online = org.members.filter((m) => m.online).length;

  const run = async (action: string, payload?: Record<string, unknown>) => { const ok = await act(action, payload); if (ok) { setConfirm(null); setTyped(''); } };

  return (
    <div className="org">
      <aside className="org__side">
        <Emblem emblem={org.emblem} color={org.color} font={org.font} fonts={fonts} size="l" />
        <OrgName name={org.name} color={org.color} font={org.font} fonts={fonts} className="orgname--l" />
        <p className="muted">{org.typeLabel}{org.motto ? ` · «${org.motto}»` : ''}</p>
        <div className="level">
          <div className="level__head"><b>Nivel {org.level}</b><span>{org.reputation}{org.nextRep ? ` / ${org.nextRep}` : ''} rep.</span></div>
          <div className="bar"><i style={{ width: `${Math.round(repProgress(org) * 100)}%`, background: org.color }} /></div>
        </div>
        <dl className="facts">
          <dt>Tu rango</dt><dd>{org.gradeName}</dd>
          <dt>Miembros</dt><dd>{org.members.length} de {org.slots} · {online} en línea</dd>
          <dt>Fondos</dt><dd>{org.funds == null ? 'No disponible' : money(org.funds)}</dd>
        </dl>
        <nav className="nav" aria-label="Secciones">
          {TABS.map((t) => <button key={t.id} type="button" className={tab === t.id ? 'is-on' : ''} onClick={() => setTab(t.id)}>{t.label}</button>)}
        </nav>
      </aside>

      <section className="org__main">
        {tab === 'members' ? <Members org={org} selfId={state.me.citizenid} act={act} busy={busy} onConfirm={setConfirm} /> : null}
        {tab === 'funds' ? <Funds org={org} act={act} busy={busy} /> : null}
        {tab === 'identity' ? <IdentityTab state={state} org={org} act={act} busy={busy} /> : null}
        {tab === 'invites' ? <Invites org={org} act={act} busy={busy} now={now} /> : null}
        {tab === 'settings' ? (
          <div>
            <h2>Ajustes</h2>
            {org.perms.leader ? (
              <div className="card card--danger">
                <b>Disolver la organización</b>
                <p className="muted">Todos los miembros quedan fuera y los fondos van a tu banco. La ficha se conserva en el historial del servidor, pero no se puede recuperar.</p>
                <button className="btn btn--danger" onClick={() => setConfirm({ kind: 'dissolve' })}>Disolver…</button>
                <p className="field__hint">Para dejar el liderazgo sin disolverla, transfiérelo desde la lista de miembros.</p>
              </div>
            ) : (
              <div className="card">
                <b>Salir de la organización</b>
                <p className="muted">Perderás tu rango. Para volver necesitarás una nueva invitación.</p>
                <button className="btn btn--danger" onClick={() => setConfirm({ kind: 'leave' })}>Salir…</button>
              </div>
            )}
          </div>
        ) : null}
      </section>

      {confirm?.kind === 'kick' ? (
        <Modal title={`Expulsar a ${confirm.member.name}`} confirm="Expulsar" danger disabled={busy} onClose={() => setConfirm(null)}
          onConfirm={() => run('kick', { citizenid: confirm.member.citizenid })}>
          <p>Dejará de pertenecer a «{org.name}». Queda registrado en el historial.</p>
        </Modal>
      ) : null}
      {confirm?.kind === 'transfer' ? (
        <Modal title="Transferir el liderazgo" confirm="Transferir" danger disabled={busy} onClose={() => setConfirm(null)}
          onConfirm={() => run('transfer', { citizenid: confirm.member.citizenid })}>
          <p><b>{confirm.member.name}</b> pasará a liderar «{org.name}» y tú quedarás un rango por debajo. No se puede deshacer por tu cuenta.</p>
        </Modal>
      ) : null}
      {confirm?.kind === 'leave' ? (
        <Modal title="Salir de la organización" confirm="Salir" danger disabled={busy} onClose={() => setConfirm(null)} onConfirm={() => run('leave')}>
          <p>Vas a dejar «{org.name}».</p>
        </Modal>
      ) : null}
      {confirm?.kind === 'dissolve' ? (
        <Modal title="Disolver la organización" confirm="Disolver para siempre" danger disabled={busy || typed.trim().toLowerCase() !== org.name.toLowerCase()}
          onClose={() => { setConfirm(null); setTyped(''); }} onConfirm={() => run('dissolve', { confirm: typed.trim() })}>
          <p>Escribe <b>{org.name}</b> para confirmar.</p>
          <input autoFocus value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={org.name} />
        </Modal>
      ) : null}
    </div>
  );
}

function Members(p: { org: OrgView; selfId: string; act: Act; busy: boolean; onConfirm: (c: Confirm) => void }) {
  const { org, selfId, act, busy } = p;
  return (
    <div className="pane">
      <h2>Miembros <small>{org.members.length} de {org.slots}</small></h2>
      <ul className="list list--scroll">
        {org.members.map((m) => {
          const options = gradeOptions(org, m, selfId);
          return (
            <li key={m.citizenid} className="row row--member">
              <span className={`dot ${m.online ? 'dot--ok' : ''}`} title={m.online ? 'En línea' : 'Desconectado'} />
              <div className="row__main">
                <b>{m.name}{m.citizenid === selfId ? ' (tú)' : ''}</b>
                <span className="muted">{m.gradeName}{m.online ? '' : ' · desconectado'}</span>
              </div>
              <span className="row__btns">
                {options.length > 0 ? (
                  <select aria-label={`Rango de ${m.name}`} value="" disabled={busy}
                    onChange={(e) => { if (e.target.value !== '') void act('setGrade', { citizenid: m.citizenid, grade: Number(e.target.value) }); }}>
                    <option value="">Cambiar rango…</option>
                    {options.map((g) => <option key={g.level} value={g.level}>{g.name}</option>)}
                  </select>
                ) : null}
                {org.perms.leader && m.citizenid !== selfId ? <button className="btn btn--s" disabled={busy} onClick={() => p.onConfirm({ kind: 'transfer', member: m })}>Ceder liderazgo</button> : null}
                {canKick(org, m, selfId) ? <button className="btn btn--s btn--ghost-danger" disabled={busy} onClick={() => p.onConfirm({ kind: 'kick', member: m })}>Expulsar</button> : null}
              </span>
            </li>
          );
        })}
      </ul>
      {org.history && org.history.length > 0 ? (
        <details className="history">
          <summary>Historial reciente</summary>
          <ul>
            {org.history.map((h, i) => (
              <li key={i}><b>{actionLabel(h.action)}</b> {h.actor_name ?? ''}{h.amount ? ` · ${money(h.amount)}` : ''}{h.detail ? ` · ${h.detail}` : ''}</li>
            ))}
          </ul>
        </details>
      ) : null}
    </div>
  );
}

function Funds(p: { org: OrgView; act: Act; busy: boolean }) {
  const { org, act, busy } = p;
  const methods = (['bank', 'cash'] as const).filter((m) => org.fundMethods[m]);
  const [amount, setAmount] = useState('');
  const [method, setMethod] = useState<string>(methods[0] ?? 'bank');
  const [out, setOut] = useState('');
  const n = Math.floor(Number(amount));
  const o = Math.floor(Number(out));
  if (org.funds == null) {
    return (
      <div className="pane">
        <h2>Fondos</h2>
        <div className="note">La cuenta de la organización estará disponible tras el próximo reinicio del servidor.</div>
      </div>
    );
  }
  return (
    <div className="pane">
      <h2>Fondos</h2>
      <div className="balance"><span>Cuenta de la organización</span><b>{money(org.funds)}</b></div>
      <div className="row2">
        <div className="card">
          <b>Aportar</b>
          <Field label="Importe"><input inputMode="numeric" value={amount} onChange={(e) => setAmount(e.target.value.replace(/\D/g, ''))} placeholder="0" /></Field>
          <div className="seg">
            {methods.map((m) => <button key={m} type="button" className={method === m ? 'is-on' : ''} onClick={() => setMethod(m)}>{m === 'bank' ? 'Banco' : 'Efectivo'}</button>)}
          </div>
          <button className="btn btn--primary btn--block" disabled={busy || !(n >= 1)} onClick={async () => { if (await act('deposit', { amount: n, method })) setAmount(''); }}>Aportar {n >= 1 ? money(n) : ''}</button>
        </div>
        <div className="card">
          <b>Retirar</b>
          {org.perms.funds ? (
            <>
              <Field label="Importe" hint="Va a tu banco y queda registrado"><input inputMode="numeric" value={out} onChange={(e) => setOut(e.target.value.replace(/\D/g, ''))} placeholder="0" /></Field>
              <button className="btn btn--block" disabled={busy || !(o >= 1) || o > org.funds} onClick={async () => { if (await act('withdraw', { amount: o })) setOut(''); }}>Retirar {o >= 1 ? money(o) : ''}</button>
            </>
          ) : <p className="muted">Tu rango no permite retirar fondos.</p>}
        </div>
      </div>
    </div>
  );
}

function IdentityTab(p: { state: State; org: OrgView; act: Act; busy: boolean }) {
  const { org, act, busy } = p;
  const opts = p.state.identityOptions ?? { colors: [org.color], fonts: [], mottoMax: 60 };
  const [color, setColor] = useState(org.color);
  const [font, setFont] = useState(org.font);
  const [emblem, setEmblem] = useState(org.emblem);
  const [motto, setMotto] = useState(org.motto ?? '');
  const can = org.perms.identity;
  const dirty = color !== org.color || font !== org.font || emblem !== org.emblem || motto.trim() !== (org.motto ?? '');
  return (
    <div className="pane">
      <h2>Identidad</h2>
      <div className="row2 row2--wide">
        <div>
          <Field label="Color"><Swatches colors={opts.colors} value={color} onChange={can ? setColor : undefined} /></Field>
          <Field label="Tipografía"><FontPicker fonts={opts.fonts} value={font} sample={org.name} color={color} onChange={can ? setFont : undefined} /></Field>
          <div className="row2">
            <Field label="Emblema" hint="1 a 3 letras"><input value={emblem} maxLength={3} disabled={!can} onChange={(e) => setEmblem(cleanEmblem(e.target.value))} /></Field>
            <Field label="Lema"><input value={motto} maxLength={opts.mottoMax} disabled={!can} onChange={(e) => setMotto(e.target.value)} /></Field>
          </div>
        </div>
        <div className="preview">
          <p className="eyebrow">Así se verá en grafitis y en el mapa</p>
          <Emblem emblem={emblem || '?'} color={color} font={font} fonts={opts.fonts} size="l" />
          <OrgName name={org.name} color={color} font={font} fonts={opts.fonts} className="orgname--xl" />
          {motto.trim() ? <p className="preview__motto">«{motto.trim()}»</p> : null}
        </div>
      </div>
      {can ? (
        <div className="actions">
          <button className="btn btn--primary" disabled={busy || !dirty || !emblem} onClick={() => act('identity', { color, font, emblem, motto: motto.trim() })}>Guardar identidad</button>
        </div>
      ) : <p className="field__hint">Solo los rangos altos pueden cambiar la identidad.</p>}
    </div>
  );
}

function Invites(p: { org: OrgView; act: Act; busy: boolean; now: number }) {
  const { org, act, busy, now } = p;
  if (!org.perms.invite) return <div className="pane"><h2>Invitar</h2><Empty>Tu rango no permite invitar.</Empty></div>;
  const left = org.slots - org.members.length - org.invites.length;
  return (
    <div className="pane">
      <h2>Invitar <small>{Math.max(0, left)} plazas libres</small></h2>
      <p className="muted">Personas cerca de ti que no pertenecen a ninguna organización.</p>
      {org.nearby.length === 0 ? <Empty>No hay nadie cerca a quien invitar.</Empty> : null}
      <ul className="list">
        {org.nearby.map((n) => (
          <li key={n.id} className="row">
            <div className="row__main"><b>{n.name}</b><span className="muted">ID {n.id}</span></div>
            <button className="btn btn--s btn--primary" disabled={busy || left < 1} onClick={() => act('invite', { target: n.id })}>Invitar</button>
          </li>
        ))}
      </ul>
      <h2>Invitaciones enviadas</h2>
      {org.invites.length === 0 ? <Empty>No hay invitaciones pendientes.</Empty> : null}
      <ul className="list">
        {org.invites.map((i) => (
          <li key={i.citizenid} className="row">
            <div className="row__main"><b>{i.name}</b><span className="muted">Invitó {i.by} · caduca en {timeLeft(i.expires, now)}</span></div>
            <button className="btn btn--s" disabled={busy} onClick={() => act('inviteCancel', { citizenid: i.citizenid })}>Retirar</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
