import { useCallback, useEffect, useState } from 'react';
import type { EditorData, SelectionData, SpawnView } from './types';
import { Selection } from './Selection';
import { Creator } from './Creator';
import { Spawn } from './Spawn';

// Una sola pantalla a la vez: selección, editor o aparición (nunca superpuestas).
type Screen = { kind: 'none' } | { kind: 'select'; data: SelectionData } | { kind: 'editor'; data: EditorData; key: number } | { kind: 'spawn'; view: SpawnView };

export function App() {
  const [screen, setScreen] = useState<Screen>({ kind: 'none' });
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [editorError, setEditorError] = useState<{ text: string; field?: string } | null>(null);

  const showToast = useCallback((t: string) => { setToast(t); window.setTimeout(() => setToast(null), 3800); }, []);

  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      const m = (e.data ?? {}) as { action?: string; data?: unknown; value?: unknown; text?: unknown; field?: unknown };
      switch (m.action) {
        case 'open': if (m.data) setScreen({ kind: 'select', data: m.data as SelectionData }); break;
        case 'close': setScreen((s) => (s.kind === 'select' ? { kind: 'none' } : s)); break;
        case 'busy': setBusy(!!m.value); break;
        case 'toast': if (typeof m.text === 'string') showToast(m.text); break;
        case 'spawn': if (m.data) setScreen({ kind: 'spawn', view: m.data as SpawnView }); break;
        case 'spawnClose': setScreen((s) => (s.kind === 'spawn' ? { kind: 'none' } : s)); break;
        case 'editor': if (m.data) { setEditorError(null); setScreen({ kind: 'editor', data: m.data as EditorData, key: Date.now() }); } break;
        case 'editorClose': setScreen((s) => (s.kind === 'editor' ? { kind: 'none' } : s)); break;
        case 'editorError': if (typeof m.text === 'string') setEditorError({ text: m.text, field: typeof m.field === 'string' ? m.field : undefined }); break;
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, [showToast]);

  return (
    <>
      {screen.kind === 'select' ? <Selection data={screen.data} busy={busy} toast={showToast} /> : null}
      {screen.kind === 'editor' ? <Creator key={screen.key} data={screen.data} error={editorError} onClearError={() => setEditorError(null)} /> : null}
      {screen.kind === 'spawn' ? <Spawn view={screen.view} /> : null}
      {toast ? <div className="toast" role="status">{toast}</div> : null}
    </>
  );
}
