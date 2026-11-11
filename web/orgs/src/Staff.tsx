// Solicitudes pendientes (solo staff con pxd.orgs.manage; el servidor vuelve a comprobarlo).
import { useState } from 'react';
import type { Font, PendingView } from './types';
import { Emblem, Empty, Modal, OrgName } from './ui';
import { money } from './lib';

type Act = (action: string, payload?: Record<string, unknown>) => Promise<boolean>;

export function Staff(p: { pending: PendingView[]; fonts?: Font[]; act: Act; busy: boolean }) {
  const [rejecting, setRejecting] = useState<PendingView | null>(null);
  const [reason, setReason] = useState('');
  return (
    <div className="pane">
      <h2>Solicitudes pendientes <small>{p.pending.length}</small></h2>
      {p.pending.length === 0 ? <Empty>No hay solicitudes por revisar.</Empty> : null}
      <ul className="list list--scroll">
        {p.pending.map((o) => (
          <li key={o.id} className="row row--tall">
            <Emblem emblem={o.emblem} color={o.color} font={o.font} fonts={p.fonts} />
            <div className="row__main">
              <OrgName name={o.name} color={o.color} font={o.font} fonts={p.fonts} />
              <span className="muted">#{o.id} · {o.typeLabel} · Fundan: {o.founders.map((f) => f.name).join(', ')}{o.cost > 0 ? ` · tasa ${money(o.cost)}` : ''}</span>
              {o.motto ? <span className="muted">«{o.motto}»</span> : null}
            </div>
            <span className="row__btns">
              <button className="btn btn--s" disabled={p.busy} onClick={() => { setRejecting(o); setReason(''); }}>Rechazar…</button>
              <button className="btn btn--s btn--primary" disabled={p.busy} onClick={() => p.act('approve', { id: o.id })}>Aprobar</button>
            </span>
          </li>
        ))}
      </ul>
      {rejecting ? (
        <Modal title={`Rechazar «${rejecting.name}»`} confirm="Rechazar" danger disabled={p.busy || reason.trim().length < 3} onClose={() => setRejecting(null)}
          onConfirm={async () => { if (await p.act('reject', { id: rejecting.id, reason: reason.trim() })) setRejecting(null); }}>
          <p>Se devuelve la tasa a quien la solicitó. El motivo se le muestra y queda en la auditoría.</p>
          <input autoFocus value={reason} maxLength={200} onChange={(e) => setReason(e.target.value)} placeholder="Motivo (obligatorio)" />
        </Modal>
      ) : null}
    </div>
  );
}
