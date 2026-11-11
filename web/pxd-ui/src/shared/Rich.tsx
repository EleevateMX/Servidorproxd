import type { Chunk } from './text';

/** Pinta trozos de texto ya saneados (ver text.ts). Nunca usa innerHTML. */
export function Rich({ chunks }: { chunks: Chunk[] }) {
  return (
    <>
      {chunks.map((c, i) => {
        if (c.kind === 'break') return <br key={i} />;
        if (c.kind === 'bold') return <b key={i}>{c.text}</b>;
        if (c.kind === 'italic') return <i key={i}>{c.text}</i>;
        if (c.kind === 'key') return <kbd key={i} className="key">{c.text}</kbd>;
        return <span key={i}>{c.text}</span>;
      })}
    </>
  );
}
