// Puente con el cliente Lua: callbacks NUI (https://<recurso>/<nombre>) y modo demostración.
const RESOURCE = typeof (window as unknown as { GetParentResourceName?: () => string }).GetParentResourceName === 'function'
  ? (window as unknown as { GetParentResourceName: () => string }).GetParentResourceName()
  : 'pxd_multichar';

export const DEMO = typeof window !== 'undefined' && new URLSearchParams(window.location.search).has('demo');

type Handler = (name: string, body: unknown) => unknown;
let demoHandler: Handler | null = null;
export function setDemoHandler(h: Handler) { demoHandler = h; }

export async function post<T = { ok?: boolean; error?: string }>(name: string, body: unknown = {}): Promise<T | null> {
  if (DEMO) return (demoHandler ? demoHandler(name, body) : { ok: true }) as T;
  try {
    const r = await fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
    });
    return (await r.json()) as T;
  } catch {
    return null;
  }
}
