import { useCallback, useEffect, useRef, useState } from 'react';
import type { State } from './types';
import { close, rpc } from './nui';
import { Home } from './Home';
import { Org, type OrgTab } from './Org';
import { Staff } from './Staff';

type Toast = { text: string; kind: 'ok' | 'error' } | null;
export type Section = 'main' | 'staff';

export function App() {
  const [state, setState] = useState<State | null>(null);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<Toast>(null);
  const [section, setSection] = useState<Section>('main');
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  const [orgTab, setOrgTab] = useState<OrgTab | undefined>(undefined);
  const toastTimer = useRef<number | undefined>(undefined);

  const show = useCallback((text: string, kind: 'ok' | 'error') => {
    setToast({ text, kind });
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(null), 4200);
  }, []);

  // Mensajes del cliente Lua: abrir con el estado, actualizarlo o cerrar.
  useEffect(() => {
    const onMessage = (e: MessageEvent) => {
      const d = e.data as { action?: string; state?: State; section?: Section; tab?: OrgTab } | null;
      if (!d || typeof d !== 'object') return;
      if (d.action === 'open' && d.state) { setState(d.state); setSection(d.section ?? 'main'); setOrgTab(d.tab); setToast(null); }
      else if (d.action === 'state' && d.state) setState(d.state);
      else if (d.action === 'close') setState(null);
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);

  useEffect(() => {
    if (!state) return;
    const t = window.setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { setState(null); close(); } };
    window.addEventListener('keydown', onKey);
    return () => { window.clearInterval(t); window.removeEventListener('keydown', onKey); };
  }, [state !== null]);

  /** Pide una acción al servidor y pinta el estado que devuelve. true si salió bien. */
  const act = useCallback(async (action: string, payload: Record<string, unknown> = {}) => {
    setBusy(true);
    const res = await rpc(action, payload);
    setBusy(false);
    if (res.state) setState(res.state);
    if (res.ok) { if (res.message) show(res.message, 'ok'); }
    else show(res.error ?? 'No se pudo completar.', 'error');
    return res.ok;
  }, [show]);

  if (!state) return null;
  const fonts = state.identityOptions?.fonts ?? state.create?.fonts;
  const pendingCount = state.staff?.pending.length ?? 0;

  return (
    <div className="scrim">
      <main className="window" aria-label="Organizaciones">
        <header className="window__head">
          <div>
            <p className="eyebrow">Próxima RP</p>
            <h1>Organizaciones</h1>
          </div>
          <div className="window__tools">
            {state.staff ? (
              <div className="seg seg--head">
                <button type="button" className={section === 'main' ? 'is-on' : ''} onClick={() => setSection('main')}>{state.org ? 'Mi organización' : 'Inicio'}</button>
                <button type="button" className={section === 'staff' ? 'is-on' : ''} onClick={() => setSection('staff')}>Solicitudes{pendingCount ? ` (${pendingCount})` : ''}</button>
              </div>
            ) : null}
            <button type="button" className="icon-btn" aria-label="Cerrar" onClick={() => { setState(null); close(); }}>×</button>
          </div>
        </header>
        <div className="window__body">
          {section === 'staff' && state.staff ? <Staff pending={state.staff.pending} fonts={fonts} act={act} busy={busy} />
            : state.org ? <Org key={state.org.id} state={state} org={state.org} act={act} now={now} busy={busy} initialTab={orgTab} />
            : <Home state={state} act={act} now={now} busy={busy} />}
        </div>
        {toast ? <div className={`toast toast--${toast.kind}`} role="status">{toast.text}</div> : null}
      </main>
    </div>
  );
}
