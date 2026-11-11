import { useCallback, useEffect, useRef, useState } from 'react';
import { onMessage, post, resourceName } from '../shared/nui';
import { parse } from '../shared/text';
import { Rich } from '../shared/Rich';
import { ToneIcon } from './icons';
import {
  type Alert, type Corner, type Notice, type Progress, type TextUi,
  dropNotice, leaveNotice, pushNotice, toAlert, toNotice, toProgress, toTextUi,
} from './model';

const RES = resourceName('pxd_ui');
const LEAVE_MS = 220;
const CORNERS: Corner[] = ['top', 'top-right', 'top-left', 'bottom', 'bottom-right', 'bottom-left', 'center-right', 'center-left'];

function NoticeCard({ n, onDone }: { n: Notice; onDone: (key: string, rev: number) => void }) {
  useEffect(() => {
    const t = window.setTimeout(() => onDone(n.key, n.rev), n.duration);
    return () => window.clearTimeout(t);
  }, [n.key, n.rev, n.duration, onDone]);
  const style = n.color ? ({ '--tone': n.color } as React.CSSProperties) : undefined;
  return (
    <div className={`notice notice--${n.tone}${n.leaving ? ' is-leaving' : ''}`} style={style} role="status">
      <span className="notice__icon"><ToneIcon tone={n.tone} /></span>
      <div className="notice__body">
        {n.title && <div className="notice__title">{n.title}{n.count > 1 && <span className="notice__count">×{n.count}</span>}</div>}
        {n.description && <div className="notice__text"><Rich chunks={parse(n.description)} /></div>}
        {!n.title && n.count > 1 && <span className="notice__count notice__count--solo">×{n.count}</span>}
      </div>
      {n.showDuration && <i key={n.rev} className="notice__time" style={{ animationDuration: `${n.duration}ms` }} />}
    </div>
  );
}

function ProgressView({ p }: { p: Progress }) {
  const [pct, setPct] = useState(0);
  useEffect(() => {
    const start = performance.now();
    let raf = 0;
    const tick = () => {
      const v = Math.min(100, ((performance.now() - start) / p.duration) * 100);
      setPct(v);
      if (v < 100) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [p.rev, p.duration]);
  const shown = Math.floor(pct);
  if (p.circle) {
    const C = 2 * Math.PI * 44;
    return (
      <div className={`ring ring--${p.position}`}>
        <svg viewBox="0 0 100 100" aria-hidden="true">
          <circle className="ring__track" cx="50" cy="50" r="44" />
          <circle className="ring__fill" cx="50" cy="50" r="44" strokeDasharray={C} strokeDashoffset={C * (1 - pct / 100)} />
        </svg>
        <b className="ring__pct">{shown}<small>%</small></b>
        {p.label && <span className="ring__label">{p.label}</span>}
      </div>
    );
  }
  return (
    <div className="bar">
      <div className="bar__head"><span className="bar__label">{p.label || 'En curso'}</span><b className="bar__pct">{shown}%</b></div>
      <div className="bar__track"><i style={{ width: `${pct}%` }} /></div>
    </div>
  );
}

function AlertView({ a, onResult }: { a: Alert; onResult: (r: 'confirm' | 'cancel') => void }) {
  const ok = useRef<HTMLButtonElement>(null);
  useEffect(() => { ok.current?.focus(); }, []);
  useEffect(() => {
    const fn = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { e.preventDefault(); onResult('cancel'); }
      if (e.key === 'Enter') { e.preventDefault(); onResult('confirm'); }
    };
    window.addEventListener('keydown', fn);
    return () => window.removeEventListener('keydown', fn);
  }, [onResult]);
  return (
    <div className="scrim">
      <div className={`dialog${a.centered ? ' dialog--center' : ''}`} role="alertdialog" aria-modal="true" aria-label={a.header}>
        {a.header && <h2 className="dialog__title">{a.header}</h2>}
        {a.content && <div className="dialog__text"><Rich chunks={parse(a.content, { max: 1500 })} /></div>}
        <div className="dialog__actions">
          {a.cancel && <button type="button" className="btn" onClick={() => onResult('cancel')}>{a.cancelLabel}<kbd className="key key--s">Esc</kbd></button>}
          <button type="button" ref={ok} className="btn btn--primary" onClick={() => onResult('confirm')}>{a.confirmLabel}<kbd className="key key--s">↵</kbd></button>
        </div>
      </div>
    </div>
  );
}

export function App() {
  const [notices, setNotices] = useState<Notice[]>([]);
  const [textUi, setTextUi] = useState<TextUi | null>(null);
  const [textOut, setTextOut] = useState(false);
  const [progress, setProgress] = useState<Progress | null>(null);
  const [alert, setAlert] = useState<Alert | null>(null);
  const rev = useRef(0);
  const textRev = useRef(0);

  const done = useCallback((key: string, r: number) => {
    setNotices((l) => leaveNotice(l, key, r));
    window.setTimeout(() => setNotices((l) => dropNotice(l, key)), LEAVE_MS);
  }, []);

  useEffect(() => onMessage((m) => {
    switch (m.action) {
      case 'notify': { const n = toNotice(m.data); if (n) setNotices((l) => pushNotice(l, n)); break; }
      case 'textUi': { const t = toTextUi(m.data); if (t) { textRev.current += 1; setTextOut(false); setTextUi(t); } break; }
      case 'textUiHide': {
        // Si llega otro texto antes de terminar la salida, no se borra el nuevo.
        const r = ++textRev.current;
        setTextOut(true);
        window.setTimeout(() => { if (textRev.current === r) setTextUi(null); }, 160);
        break;
      }
      case 'progress': setProgress(toProgress(m.data, m.circle === true, ++rev.current)); break;
      case 'progressCancel': case 'progressDone': setProgress(null); break;
      case 'alert': setAlert(toAlert(m.data)); break;
      case 'alertClose': setAlert(null); break;
      default: break;
    }
  }), []);

  const result = useCallback((r: 'confirm' | 'cancel') => {
    setAlert(null);
    void post(RES, 'alertResult', { result: r });
  }, []);

  useEffect(() => { void post(RES, 'ready'); }, []);

  return (
    <div className="kit">
      {CORNERS.map((c) => {
        const list = notices.filter((n) => n.position === c);
        if (!list.length) return null;
        return <div key={c} className={`stack stack--${c}`}>{list.map((n) => <NoticeCard key={n.key} n={n} onDone={done} />)}</div>;
      })}
      {textUi && (
        <div className={`hint hint--${textUi.position}${textOut ? ' is-leaving' : ''}`} style={textUi.color ? ({ '--tone': textUi.color } as React.CSSProperties) : undefined}>
          <Rich chunks={parse(textUi.text, { keys: true, max: 300 })} />
        </div>
      )}
      {progress && <ProgressView key={progress.rev} p={progress} />}
      {alert && <AlertView a={alert} onResult={result} />}
    </div>
  );
}
