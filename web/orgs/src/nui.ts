// Puente con el cliente Lua: callbacks NUI (https://<recurso>/<nombre>) y modo demostración.
import type { RpcResult } from './types';

const w = window as unknown as { GetParentResourceName?: () => string };
const RESOURCE = typeof w.GetParentResourceName === 'function' ? w.GetParentResourceName() : 'pxd_orgs';

export const DEMO = typeof window !== 'undefined' && new URLSearchParams(window.location.search).has('demo');

type Handler = (action: string, payload: unknown) => RpcResult;
let demoHandler: Handler | null = null;
export function setDemoHandler(h: Handler) { demoHandler = h; }

async function post<T>(name: string, body: unknown): Promise<T | null> {
  try {
    const r = await fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
    });
    return (await r.json()) as T;
  } catch {
    return null;
  }
}

/** Acción en el servidor. Siempre devuelve un resultado (nunca lanza). */
export async function rpc(action: string, payload: Record<string, unknown> = {}): Promise<RpcResult> {
  if (DEMO) return demoHandler ? demoHandler(action, payload) : { ok: true };
  const res = await post<RpcResult>('rpc', { action, payload });
  return res ?? { ok: false, error: 'No se pudo contactar con el servidor.' };
}

export function close() {
  if (DEMO) return;
  void post('close', {});
}
