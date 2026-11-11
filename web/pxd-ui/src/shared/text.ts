// Texto de terceros (ox_lib, qbx_core): nunca se inserta como HTML. Se convierte en
// trozos tipados y React los pinta como nodos de texto.

export type Chunk = { kind: 'text' | 'bold' | 'italic' | 'key' | 'break'; text: string };

const MAX = 600;

/** Quita los códigos de color de FiveM (^1, ~r~), etiquetas HTML y caracteres de control. */
export function clean(raw: unknown, max = MAX): string {
  if (typeof raw !== 'string' && typeof raw !== 'number') return '';
  let s = String(raw);
  s = s.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]{0,80}>/g, '');
  s = s.replace(/\^[0-9]/g, '').replace(/~[a-zA-Z_]{1,12}~/g, '');
  // eslint-disable-next-line no-control-regex
  s = s.replace(/[\u0000-\u0009\u000B-\u001F\u007F]/g, '');
  s = s.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
  return s.length > max ? s.slice(0, max - 1) + '…' : s;
}

/**
 * Markdown mínimo de ox_lib: **negrita**, *cursiva* y saltos de línea.
 * Con `keys`, además `[E]` se convierte en una tecla.
 */
export function parse(raw: unknown, opts: { keys?: boolean; max?: number } = {}): Chunk[] {
  const s = clean(raw, opts.max);
  const out: Chunk[] = [];
  const re = opts.keys ? /(\*\*[^*\n]+\*\*|\*[^*\n]+\*|\[[A-Za-z0-9↑↓←→+ ]{1,10}\]|\n)/g : /(\*\*[^*\n]+\*\*|\*[^*\n]+\*|\n)/g;
  let last = 0;
  for (const m of s.matchAll(re)) {
    const i = m.index ?? 0;
    if (i > last) out.push({ kind: 'text', text: s.slice(last, i) });
    const t = m[0];
    if (t === '\n') out.push({ kind: 'break', text: '' });
    else if (t.startsWith('**')) out.push({ kind: 'bold', text: t.slice(2, -2) });
    else if (t.startsWith('[')) out.push({ kind: 'key', text: t.slice(1, -1).trim() });
    else out.push({ kind: 'italic', text: t.slice(1, -1) });
    last = i + t.length;
  }
  if (last < s.length) out.push({ kind: 'text', text: s.slice(last) });
  return out;
}

/** Solo colores CSS seguros (#hex o rgb/rgba numérico). */
export function safeColor(raw: unknown): string | undefined {
  if (typeof raw !== 'string') return undefined;
  const s = raw.trim();
  if (/^#[0-9a-fA-F]{3,8}$/.test(s)) return s;
  if (/^rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(,\s*(0|1|0?\.\d+)\s*)?\)$/.test(s)) return s;
  return undefined;
}

export function clamp(n: unknown, lo: number, hi: number, fallback = lo): number {
  const v = typeof n === 'number' ? n : Number(n);
  if (!Number.isFinite(v)) return fallback;
  return Math.min(hi, Math.max(lo, v));
}

export function money(n: unknown): string {
  const v = Math.floor(Number(n) || 0);
  return (v < 0 ? '-$' : '$') + Math.abs(v).toLocaleString('en-US');
}
