// Comunicación con el cliente Lua (callbacks NUI del propio recurso).
declare function GetParentResourceName(): string;

export const inGame = typeof (globalThis as { GetParentResourceName?: unknown }).GetParentResourceName === 'function';

export function resourceName(fallback: string): string {
  return inGame ? GetParentResourceName() : fallback;
}

/** POST a un callback NUI. En el navegador (demo) no hace nada. */
export function post<T = unknown>(resource: string, name: string, body: unknown = {}): Promise<T | undefined> {
  if (!inGame) return Promise.resolve(undefined);
  return fetch(`https://${resource}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
    .then((r) => r.json() as Promise<T>)
    .catch(() => undefined);
}

/** Escucha los mensajes de SendNUIMessage (y los de la demo). */
export function onMessage(handler: (msg: { action?: string; [k: string]: unknown }) => void): () => void {
  const fn = (e: MessageEvent) => {
    const d = e.data;
    if (d && typeof d === 'object' && typeof (d as { action?: unknown }).action === 'string') handler(d as { action: string });
  };
  window.addEventListener('message', fn);
  return () => window.removeEventListener('message', fn);
}

/** Tokens y fuentes comunes de Próxima (html/ui, scripts/sync-ui.mjs). */
export function loadCommonUi(): void {
  for (const href of ['ui/proxima-fonts.css', 'ui/proxima-ui.css']) {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    document.head.prepend(link);
  }
}
