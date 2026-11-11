import { useCallback, useEffect, useReducer } from 'react';
import { onMessage, post, resourceName } from '../shared/nui';
import { money } from '../shared/text';
import { Icon, Star } from './icons';
import {
  ELEMENTS, ELEMENT_LABELS, SCALE_MAX, SCALE_MIN, type ElementId, type HudState, type Level, type Settings,
  cardinal, compassTicks, defaultSettings, initialState, level, maxSpeed, paydayLabel, reduce, visible,
} from './model';

const RES = resourceName('pxd_hud');

// ── Constantes vitales: anillo con icono ────────────────
function Ring({ icon, value, tone, lvl, title }: { icon: string; value: number; tone: string; lvl: Level; title: string }) {
  const C = 2 * Math.PI * 15;
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div className={`ring ring--${tone} is-${lvl}`} title={title}>
      <svg viewBox="0 0 36 36" aria-hidden="true">
        <circle className="ring__bg" cx="18" cy="18" r="15" />
        <circle className="ring__fill" cx="18" cy="18" r="15" strokeDasharray={C} strokeDashoffset={C * (1 - pct / 100)} />
      </svg>
      <Icon name={icon} />
    </div>
  );
}

function Vitals({ s }: { s: HudState }) {
  const c = s.warn.critical;
  return (
    <div className={`vitals${s.dead ? ' is-dead' : ''}`}>
      <Ring icon="heart" value={s.health} tone="health" lvl={level(s.health, s.warn.health, c)} title="Salud" />
      {s.armor > 0 && <Ring icon="shield" value={s.armor} tone="armor" lvl="ok" title="Armadura" />}
      <Ring icon="food" value={s.hunger} tone="food" lvl={level(s.hunger, s.warn.hunger, c)} title="Hambre" />
      <Ring icon="drop" value={s.thirst} tone="water" lvl={level(s.thirst, s.warn.thirst, c)} title="Sed" />
      {s.stress > 0 && <Ring icon="brain" value={s.stress} tone="stress" lvl={level(s.stress, 50, 20, true)} title="Estrés" />}
      {s.oxygen >= 0 && <Ring icon="bubble" value={s.oxygen} tone="oxygen" lvl={level(s.oxygen, 30, c)} title="Oxígeno" />}
    </div>
  );
}

// ── Brújula ─────────────────────────────────────────────
function Compass({ heading }: { heading: number }) {
  const deg = ((Math.round(heading) % 360) + 360) % 360;
  return (
    <div className="compass" aria-label={`Rumbo ${deg} grados`}>
      <div className="compass__tape">
        {compassTicks(heading).map((t) => (
          <span key={t.key} className={`tick${t.major ? ' tick--major' : ''}${t.label === 'N' ? ' tick--north' : ''}`} style={{ left: `${50 + t.offset * 50}%`, opacity: 1 - Math.min(1, Math.abs(t.offset)) ** 3 }}>
            <i />{t.label && <b>{t.label}</b>}
          </span>
        ))}
      </div>
      <div className="compass__head"><b>{cardinal(deg)}</b><span>{deg}°</span></div>
    </div>
  );
}

// ── Vehículo ────────────────────────────────────────────
// Arcos de 240° centrados en (120, 100). pathLength = 100: el relleno va en porcentaje.
const ARC = 'M 36.86 148 A 96 96 0 1 1 203.14 148';
const RPM_ARC = 'M 54.18 138 A 76 76 0 1 1 185.82 138';

function Vehicle({ s }: { s: HudState }) {
  const ratio = Math.max(0, Math.min(1, s.speed / maxSpeed(s.speedUnit)));
  const rpm = Math.max(0, Math.min(1, s.rpm / 100));
  const belted = s.seatbelt || s.harness;
  const fuelLow = s.fuel <= s.lowFuel;
  return (
    <div className={`car${s.engineOn ? '' : ' is-off'}`}>
      <svg className="car__dial" viewBox="0 0 240 160" aria-hidden="true">
        <defs>
          <linearGradient id="pxd-speed" x1="0" x2="1"><stop offset="0" stopColor="#5ce1ff" /><stop offset="1" stopColor="#ff4fd8" /></linearGradient>
        </defs>
        <path className="dial__track" d={ARC} />
        <path className="dial__speed" d={ARC} pathLength={100} strokeDasharray={100} strokeDashoffset={100 * (1 - ratio)} />
        <path className="dial__track dial__track--thin" d={RPM_ARC} />
        <path className={`dial__rpm${rpm > 0.86 ? ' is-red' : ''}`} d={RPM_ARC} pathLength={100} strokeDasharray={100} strokeDashoffset={100 * (1 - rpm)} />
      </svg>
      <div className="car__center">
        <b className="car__speed">{s.speed}</b>
        <span className="car__unit">{s.speedUnit === 'mph' ? 'mph' : 'km/h'}</span>
      </div>
      <div className="car__gear" title="Marcha"><b>{s.gear}</b></div>
      <div className={`car__fuel${fuelLow ? ' is-low' : ''}`} title="Combustible">
        <Icon name="fuel" /><i><span style={{ width: `${s.fuel}%` }} /></i><b>{s.fuel}%</b>
      </div>
      <div className="car__flags">
        <span className={`flag ${belted ? 'is-on' : s.speed > 20 ? 'is-alert' : 'is-off'}`} title="Cinturón"><Icon name="belt" /></span>
        <span className={`flag ${s.engine <= 15 ? 'is-alert' : s.engine <= 40 ? 'is-warn' : 'is-idle'}`} title="Motor"><Icon name="engine" /></span>
        <span className={`flag ${s.body <= 15 ? 'is-alert' : s.body <= 40 ? 'is-warn' : 'is-idle'}`} title="Carrocería"><Icon name="body" /></span>
        <span className={`flag ${s.lights === 2 ? 'is-high' : s.lights === 1 ? 'is-on' : 'is-idle'}`} title="Luces"><Icon name="lights" /></span>
        <span className={`flag ${s.locked ? 'is-on' : 'is-idle'}`} title="Seguro"><Icon name="lock" /></span>
        <span className={`flag ${s.cruise ? 'is-on' : 'is-idle'}`} title="Control de crucero"><Icon name="cruise" /></span>
      </div>
    </div>
  );
}

// ── Ajustes (/hud) ──────────────────────────────────────
function SettingsPanel({ settings, onChange, onClose }: { settings: Settings; onChange: (s: Settings) => void; onClose: () => void }) {
  useEffect(() => {
    const fn = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.preventDefault(); onClose(); } };
    window.addEventListener('keydown', fn);
    return () => window.removeEventListener('keydown', fn);
  }, [onClose]);
  const toggle = (id: ElementId) => onChange({ ...settings, show: { ...settings.show, [id]: !settings.show[id] } });
  return (
    <div className="scrim">
      <div className="panel" role="dialog" aria-modal="true" aria-label="Ajustes del HUD">
        <header className="panel__head">
          <div><span className="eyebrow">Próxima RP</span><h2>Ajustes del HUD</h2></div>
          <button type="button" className="btn btn--ghost" onClick={onClose}>Cerrar<kbd>Esc</kbd></button>
        </header>
        <div className="panel__grid">
          {ELEMENTS.map((id) => (
            <button key={id} type="button" role="switch" aria-checked={settings.show[id]} className={`opt${settings.show[id] ? ' is-on' : ''}`} onClick={() => toggle(id)}>
              <span>{ELEMENT_LABELS[id]}</span><i className="switch" />
            </button>
          ))}
        </div>
        <label className="scale">
          <span>Tamaño</span>
          <input type="range" min={SCALE_MIN} max={SCALE_MAX} step={0.05} value={settings.scale} onChange={(e) => onChange({ ...settings, scale: Number(e.target.value) })} />
          <b>{Math.round(settings.scale * 100)}%</b>
        </label>
        <footer className="panel__foot">
          <button type="button" role="switch" aria-checked={settings.cinema} className={`opt opt--wide${settings.cinema ? ' is-on' : ''}`} onClick={() => onChange({ ...settings, cinema: !settings.cinema })}>
            <span>Modo cine <small>oculta todo el HUD · /hudcine</small></span><i className="switch" />
          </button>
          <button type="button" className="btn" onClick={() => onChange(defaultSettings())}>Restablecer</button>
        </footer>
      </div>
    </div>
  );
}

export function App({ demoState }: { demoState?: Partial<HudState> }) {
  const [s, dispatch] = useReducer(reduce, undefined, () => ({ ...initialState(), ...demoState }));

  useEffect(() => onMessage((m) => {
    if (m.action === 'anchor' && m.anchor && typeof m.anchor === 'object') {
      const a = m.anchor as Record<string, number>;
      const root = document.documentElement.style;
      root.setProperty('--map-left', `${(a.left ?? 0) * 100}vw`);
      root.setProperty('--map-bottom', `${(1 - (a.bottom ?? 1)) * 100}vh`);
      root.setProperty('--map-w', `${(a.width ?? 0.14) * 100}vw`);
      root.setProperty('--map-h', `${(a.height ?? 0.176) * 100}vh`);
      return;
    }
    dispatch(m);
  }), []);

  useEffect(() => { void post(RES, 'ready'); }, []);
  useEffect(() => { document.documentElement.style.setProperty('--hud-scale', String(s.settings.scale)); }, [s.settings.scale]);

  const change = useCallback((next: Settings) => {
    dispatch({ action: 'settings', settings: next });
    void post(RES, 'saveSettings', next);
  }, []);
  const close = useCallback(() => {
    dispatch({ action: 'settingsPanel', open: false });
    void post(RES, 'closeSettings');
  }, []);

  const on = (id: ElementId) => visible(s, id);
  const hidden = !s.show || s.settings.cinema;
  const payday = paydayLabel(s.payday);
  const hasAlerts = payday !== '' || s.fines > 0 || s.invoices > 0;

  return (
    <>
      <div className={`hud${hidden ? ' is-hidden' : ''}${on('minimap') ? '' : ' no-map'}${s.vehicle ? ' in-vehicle' : ''}`}>
        {on('minimap') && <div className="map-frame" aria-hidden="true"><i /><i /><i /><i /></div>}

        <div className="dock">
          {on('vitals') && <Vitals s={s} />}
        </div>

        <div className="side">
          {on('voice') && (
            <div className={`voice${s.talking ? ' is-talking' : ''}`} data-range={s.voiceIndex}>
              <Icon name="mic" />
              <span className="voice__range"><i /><i /><i /></span>
              <span className="voice__label">{s.voice}</span>
              {s.radio > 0 && <span className="voice__radio"><Icon name="radio" /><b>{s.radio}</b></span>}
            </div>
          )}
          {on('clock') && (
            <div className="clock">
              <Star className="clock__star" /><b>{s.clock}</b>
              {s.publicId && <span className="clock__id">{s.publicId}</span>}
            </div>
          )}
        </div>

        {(on('compass') || on('location')) && (
          <div className="north">
            {on('compass') && <Compass heading={s.compass} />}
            {on('location') && (s.street || s.zone) && (
              <div className="place"><Icon name="pin" /><b>{s.street || s.zone}</b>{s.street && s.zone && <span>{s.zone}</span>}</div>
            )}
          </div>
        )}

        <div className="east">
          {on('money') && (
            <div className="wallet">
              <div className="wallet__row" title="Efectivo"><Icon name="cash" className="ic--cash" /><b>{money(s.cash)}</b></div>
              <div className="wallet__row wallet__row--bank" title="Banco"><Icon name="bank" className="ic--bank" /><b>{money(s.bank)}</b></div>
              {s.delta && <span key={s.delta.rev} className={`wallet__delta ${s.delta.minus ? 'minus' : 'plus'}`}>{s.delta.text}</span>}
            </div>
          )}
          {on('alerts') && hasAlerts && (
            <div className="chips">
              {payday !== '' && <span className="chip chip--pay" title="Próxima paga"><Icon name="clock" />Paga en <b>{payday}</b></span>}
              {s.fines > 0 && <span className="chip chip--debt" title="Multas pendientes"><Icon name="shield" />Multas <b>{money(s.fines)}</b></span>}
              {s.invoices > 0 && <span className="chip chip--debt" title="Facturas pendientes"><Icon name="ticket" />Facturas <b>{money(s.invoices)}</b></span>}
            </div>
          )}
        </div>

        {on('vehicle') && <Vehicle s={s} />}
      </div>
      {s.settingsOpen && <SettingsPanel settings={s.settings} onChange={change} onClose={close} />}
    </>
  );
}
