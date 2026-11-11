import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Editor } from './controls';
import { SECTION_ICONS, VIEWS } from './data';
import { STAT_KEYS, kmh, mechanicProgress, money, same, statDelta, statPercent, valueLabel } from './logic';
import { post } from './nui';
import type { AppliedMessage, Entry, OpenData, Quote, ResetResponse, SetResponse, Stats, StatsData, Value } from './types';

const METHOD_LABEL: Record<string, string> = { bank: 'Banco', cash: 'Efectivo' };

function StatsCard({ stats }: { stats: StatsData }) {
  return (
    <section className="card stats" aria-label="Estadísticas">
      <header className="card__head"><h2>Estadísticas</h2><small>antes → ahora</small></header>
      {STAT_KEYS.map(({ key, label }) => {
        const before = statPercent(stats.before[key], stats.scale[key]);
        const now = statPercent(stats.now[key], stats.scale[key]);
        const delta = statDelta(stats.before[key], stats.now[key], stats.scale[key]);
        return (
          <div key={key} className="stat">
            <div className="stat__row">
              <span>{label}</span>
              <b>
                {key === 'speed' ? `${kmh(stats.now.speed)} km/h` : now.toFixed(0)}
                {delta !== 0 && <em className={delta > 0 ? 'up' : 'down'}>{delta > 0 ? '+' : ''}{delta}</em>}
              </b>
            </div>
            <div className="bar">
              <span className="bar__now" style={{ width: `${Math.max(before, now)}%` }} data-dir={now >= before ? 'up' : 'down'} />
              <span className="bar__before" style={{ width: `${Math.min(before, now)}%` }} />
            </div>
          </div>
        );
      })}
    </section>
  );
}

export function App() {
  const [data, setData] = useState<OpenData | null>(null);
  const [values, setValues] = useState<Record<string, Value>>({});
  const [saved, setSaved] = useState<Record<string, Value>>({});
  const [catalog, setCatalog] = useState<Entry[]>([]);
  const [section, setSection] = useState('performance');
  const [open, setOpen] = useState<string | null>(null);
  const [quote, setQuote] = useState<Quote>({ lines: [], total: 0, count: 0 });
  const [stats, setStats] = useState<StatsData | null>(null);
  const [method, setMethod] = useState('bank');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ kind: 'ok' | 'error'; text: string } | null>(null);
  const [view, setView] = useState('front');
  const drag = useRef<{ x: number; y: number } | null>(null);

  const camera = useCallback((id: string) => { setView(id); void post('camera', { view: id }); }, []);

  useEffect(() => {
    const onMessage = (e: MessageEvent) => {
      const m = e.data as { action?: string } & Partial<OpenData> & AppliedMessage;
      if (m.action === 'open') {
        const d = m as unknown as OpenData;
        setData(d); setValues(d.values); setSaved(d.values); setCatalog(d.catalog); setQuote(d.quote); setStats(d.stats);
        const first = d.sections.find((s) => d.catalog.some((c) => c.section === s.id))?.id ?? 'performance';
        setSection(first); setOpen(null); setNotice(null); setBusy(false);
        setMethod(d.methods.bank ? 'bank' : 'cash');
      } else if (m.action === 'applied') {
        setBusy(false);
        if (m.ok) {
          if (m.values) { setValues(m.values); setSaved(m.values); }
          if (m.quote) setQuote(m.quote);
          if (m.stats) setStats(m.stats);
          if (m.mechanic) setData((d) => (d ? { ...d, mechanic: m.mechanic! } : d));
          const how = m.pay === 'invoice' ? 'Factura enviada al dueño' : m.pay === 'free' ? 'Sin coste' : 'Cobrado';
          setNotice({ kind: 'ok', text: `Cambios aplicados y guardados. ${how}: ${money(m.total ?? 0)}.${m.xp ? ` +${m.xp} XP de mecánico.` : ''}` });
        } else setNotice({ kind: 'error', text: m.message ?? 'No se pudo aplicar.' });
      } else if (m.action === 'close') setData(null);
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);

  const close = useCallback(() => { void post('close'); }, []);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape' && data) close(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [data, close]);

  const set = useCallback(async (entry: Entry, value: Value) => {
    setValues((v) => ({ ...v, [entry.key]: value }));
    setNotice(null);
    const r = await post<SetResponse>('set', { key: entry.key, value });
    if (!r || !r.ok) return;
    if (r.quote) setQuote(r.quote);
    if (r.stats) setStats((s) => (s ? { ...s, now: r.stats as Stats } : s));
    if (r.refresh) {
      const fresh = r.refresh;
      setCatalog((c) => c.map((e) => (fresh[e.key] ? { ...e, count: fresh[e.key]!.count, names: fresh[e.key]!.names } : e)));
      setValues((v) => ({ ...v, modFrontWheels: -1, modBackWheels: -1 }));
    }
  }, []);

  const reset = useCallback(async () => {
    const r = await post<ResetResponse>('reset');
    if (!r || !r.ok) return;
    if (r.values) setValues(r.values);
    if (r.quote) setQuote(r.quote);
    if (r.stats) setStats((s) => (s ? { ...s, now: r.stats as Stats } : s));
    setNotice(null);
  }, []);

  const apply = useCallback(async () => {
    if (busy) return;
    setBusy(true); setNotice(null);
    const r = await post<{ ok: boolean; message?: string }>('apply', { method });
    if (!r || !r.ok) { setBusy(false); setNotice({ kind: 'error', text: r?.message ?? 'No se pudo aplicar.' }); }
  }, [busy, method]);

  const entries = useMemo(() => catalog.filter((e) => e.section === section && (e.count === undefined || e.count > 0)), [catalog, section]);
  const sections = useMemo(() => (data ? data.sections.filter((s) => catalog.some((c) => c.section === s.id)) : []), [data, catalog]);
  const priceOf = useMemo(() => Object.fromEntries(quote.lines.map((l) => [l.key, l.price])), [quote]);

  if (!data || !stats) return null;
  const invoiceMode = data.mode === 'mechanic' && !data.ownsIt;
  const changed = quote.count > 0;

  return (
    <div className="garage"
      onMouseDown={(e) => { if ((e.target as HTMLElement).classList.contains('garage')) drag.current = { x: e.clientX, y: e.clientY }; }}
      onMouseMove={(e) => {
        if (!drag.current) return;
        const dx = e.clientX - drag.current.x, dy = e.clientY - drag.current.y;
        if (Math.abs(dx) + Math.abs(dy) < 4) return;
        drag.current = { x: e.clientX, y: e.clientY };
        void post('orbit', { dx, dy });
      }}
      onMouseUp={() => { drag.current = null; }} onMouseLeave={() => { drag.current = null; }}
      onWheel={(e) => { if ((e.target as HTMLElement).classList.contains('garage')) void post('orbit', { zoom: e.deltaY > 0 ? 1 : -1 }); }}>

      <aside className="panel panel--left">
        <header className="brand">
          <p className="eyebrow">Próxima · Taller</p>
          <h1>{data.vehicle.name}</h1>
          <p className="brand__meta"><span className="plate">{data.vehicle.plate}</span><span>{data.zone}</span></p>
          <p className={`mode mode--${data.mode}`}>
            {data.mode === 'self' ? 'Autoservicio' : invoiceMode ? `Trabajo para ${data.ownerName ?? 'el dueño'} · con factura` : 'Taller · tu vehículo'}
          </p>
        </header>

        <nav className="tabs" aria-label="Secciones">
          {sections.map((s) => (
            <button key={s.id} type="button" className={`tab${s.id === section ? ' is-on' : ''}`}
              onClick={() => { setSection(s.id); setOpen(null); camera(s.camera); }}>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d={SECTION_ICONS[s.id] ?? ''} /></svg>
              <span>{s.label}</span>
            </button>
          ))}
        </nav>

        <div className="entries">
          {entries.map((e) => {
            const isOpen = open === e.key;
            const dirty = !same(values[e.key], saved[e.key]);
            return (
              <section key={e.key} className={`entry${isOpen ? ' is-open' : ''}${dirty ? ' is-dirty' : ''}`}>
                <button type="button" className="entry__head" aria-expanded={isOpen}
                  onClick={() => { setOpen(isOpen ? null : e.key); if (!isOpen && e.camera) camera(e.camera); }}>
                  <span className="entry__label">{e.label}</span>
                  <span className="entry__value">{valueLabel(e, values[e.key])}</span>
                  {priceOf[e.key] !== undefined && <b className="entry__price">{priceOf[e.key] === 0 ? 'gratis' : money(priceOf[e.key]!)}</b>}
                </button>
                {isOpen && (
                  <div className="entry__body">
                    <Editor entry={e} value={values[e.key]} saved={saved[e.key]} rule={data.performance[e.key]}
                      mode={data.mode} mechLevel={data.mechanic.level} onSet={(v) => void set(e, v)} />
                  </div>
                )}
              </section>
            );
          })}
          {entries.length === 0 && <p className="empty">Este modelo no tiene opciones en esta sección.</p>}
        </div>
      </aside>

      <aside className="panel panel--right">
        <StatsCard stats={stats} />

        {data.mode === 'mechanic' && (
          <section className="card mech" aria-label="Nivel de mecánico">
            <header className="card__head"><h2>Mecánico nivel {data.mechanic.level}</h2><small>{data.mechanic.name}</small></header>
            <div className="bar"><span className="bar__before" style={{ width: `${mechanicProgress(data.mechanic.xp, data.levels, data.mechanic.level)}%` }} /></div>
            <p className="hint">{data.mechanic.xp} XP{data.mechanic.next ? ` · siguiente nivel a ${data.mechanic.next}` : ' · nivel máximo'}</p>
          </section>
        )}

        <section className="card cart" aria-label="Presupuesto">
          <header className="card__head"><h2>Presupuesto</h2><small>{quote.count} {quote.count === 1 ? 'cambio' : 'cambios'}</small></header>
          <ul className="lines">
            {quote.lines.map((l) => (
              <li key={l.key}><span>{l.label}</span><b>{l.price === 0 ? 'gratis' : money(l.price)}</b></li>
            ))}
            {quote.lines.length === 0 && <li className="lines__empty">Elige piezas para ver el precio.</li>}
          </ul>
          <div className="total"><span>Total</span><b>{money(quote.total)}</b></div>
          {data.factor < 1 && <p className="hint">Precio de taller: {Math.round((1 - data.factor) * 100)} % menos que en autoservicio.</p>}
          {quote.blocked && <p className="alert alert--error" role="alert">{quote.blocked}</p>}
          {notice && <p className={`alert alert--${notice.kind}`} role="status">{notice.text}</p>}

          {invoiceMode ? (
            <p className="hint">Se enviará una factura a {data.ownerName ?? 'el dueño'}, que debe estar a tu lado.</p>
          ) : (
            <div className="seg" role="radiogroup" aria-label="Forma de pago">
              {(['bank', 'cash'] as const).filter((m) => data.methods[m]).map((m) => (
                <button key={m} type="button" role="radio" aria-checked={method === m} className={method === m ? 'is-on' : ''} onClick={() => setMethod(m)}>
                  {METHOD_LABEL[m]}
                </button>
              ))}
            </div>
          )}

          <button type="button" className="btn btn--primary btn--block" disabled={!changed || busy || !!quote.blocked} onClick={() => void apply()}>
            {busy ? 'Aplicando…' : invoiceMode ? 'Aplicar y facturar' : 'Aplicar y pagar'}
          </button>
          <div className="row2">
            <button type="button" className="btn" disabled={!changed || busy} onClick={() => void reset()}>Deshacer</button>
            <button type="button" className="btn" onClick={close}>Salir</button>
          </div>
        </section>
      </aside>

      <footer className="views" aria-label="Cámara">
        {VIEWS.map((v) => (
          <button key={v.id} type="button" className={`chip${view === v.id ? ' is-on' : ''}`} onClick={() => camera(v.id)}>{v.label}</button>
        ))}
        <span className="views__hint">Arrastra para girar · rueda para acercar · Esc para salir</span>
      </footer>
    </div>
  );
}
