// Comunicación con el cliente de FiveM.
// - ox_inventory: https://<recurso padre>/<callback> (el padre es ox_inventory, cuya ui_page es esta página).
// - pxd_inventory: https://pxd_inventory/<acción> (callbacks NUI entre recursos; pxd_inventory no tiene
//   ui_page, así que FiveM los acepta desde esta página).
// Se guarda la referencia original de fetch al cargar: la interfaz antigua de ox_inventory la anulaba
// sustituyéndola por una función vacía, y eso dejaba sin datos la capa anterior (signos vitales con guiones).
import type { OxCallbacks } from './contract';

const nativeFetch: typeof fetch = window.fetch.bind(window);

declare global {
  interface Window {
    GetParentResourceName?: () => string;
    invokeNative?: unknown;
  }
}

export const isBrowser = () => !window.invokeNative && !window.GetParentResourceName;
export const parentResource = () => (window.GetParentResourceName ? window.GetParentResourceName() : 'ox_inventory');

async function post<T>(resource: string, name: string, body: unknown): Promise<T | undefined> {
  const resp = await nativeFetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body === undefined ? {} : body),
  });
  const text = await resp.text();
  return text ? (JSON.parse(text) as T) : undefined;
}

/** Callback de ox_inventory. Rechaza si FiveM no responde (la interfaz deshace el cambio). */
export function oxNui<K extends keyof OxCallbacks>(name: K, data?: OxCallbacks[K]['req']): Promise<OxCallbacks[K]['res'] | undefined> {
  return post<OxCallbacks[K]['res']>(parentResource(), name, data);
}

/** Acción del adaptador de Próxima. Devuelve undefined si pxd_inventory no está en marcha. */
export async function pxdNui<T>(name: string, data?: unknown): Promise<T | undefined> {
  try {
    return await post<T>('pxd_inventory', name, data);
  } catch {
    return undefined;
  }
}
