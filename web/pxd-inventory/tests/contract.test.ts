// Contrato con ox_inventory 2.48.1: lo extraído de su client.lua (contract/ox_inventory-2.48.1.json)
// frente a lo que esta interfaz atiende y llama. Y contrato con pxd_inventory (adaptador Lua).
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { HANDLED_MESSAGES, PXD_CALLBACKS, PXD_CONTRACT, USED_CALLBACKS } from '../src/contract';

const here = fileURLToPath(new URL('..', import.meta.url));
const fixture = JSON.parse(readFileSync(join(here, 'contract/ox_inventory-2.48.1.json'), 'utf8')) as { messages: string[]; callbacks: string[] };
const files: string[] = [];
const walk = (d: string) => {
  for (const n of readdirSync(d)) {
    const p = join(d, n);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(ts|tsx)$/.test(n)) files.push(p);
  }
};
walk(join(here, 'src'));
const src = files.map((f) => readFileSync(f, 'utf8')).join('\n');
const adapterLua = readFileSync(join(here, '../../server-data/resources/[proxima]/pxd_inventory/client/main.lua'), 'utf8');
const adapterShared = readFileSync(join(here, '../../server-data/resources/[proxima]/pxd_inventory/shared/inventory.lua'), 'utf8');

describe('contrato ox_inventory 2.48.1', () => {
  it('atiende todos los mensajes que envía client.lua', () => {
    for (const m of fixture.messages) {
      expect(HANDLED_MESSAGES as readonly string[]).toContain(m);
      expect(src).toContain(`case '${m}'`);
    }
  });
  it('solo llama a callbacks que existen en client.lua', () => {
    const called = [...src.matchAll(/oxNui\(\s*'([A-Za-z]+)'/g)].map((m) => m[1]);
    expect(called.length).toBeGreaterThan(5);
    for (const c of called) expect(fixture.callbacks).toContain(c);
    for (const c of USED_CALLBACKS) expect(fixture.callbacks).toContain(c);
  });
  it('cubre todos los callbacks de client.lua', () => {
    for (const c of fixture.callbacks) expect(USED_CALLBACKS as string[]).toContain(c);
  });
  it('avisa uiLoaded al cargar (sin él ox_inventory no envía init)', () => {
    expect(src).toMatch(/oxNui\('uiLoaded'/);
  });
  it('no sustituye window.fetch ni usa HTML crudo', () => {
    expect(src).not.toMatch(/window\.fetch\s*=/);
    expect(src).not.toMatch(/dangerouslySetInnerHTML|innerHTML/);
  });
});

describe('contrato pxd_inventory (adaptador)', () => {
  it('cada acción que usa la interfaz está registrada en client/main.lua', () => {
    for (const c of PXD_CALLBACKS) expect(adapterLua).toContain(`RegisterNUICallback('${c}'`);
    const called = [...src.matchAll(/pxdNui<?[^(]*>?\(\s*'([A-Za-z]+)'/g)].map((m) => m[1]);
    for (const c of called) expect(PXD_CALLBACKS as readonly string[]).toContain(c);
  });
  it('misma versión de contrato en Lua y en la interfaz', () => {
    expect(adapterShared).toContain(`PXDInv.CONTRACT = ${PXD_CONTRACT}`);
  });
});
