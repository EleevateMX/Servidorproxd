// Iconos propios de Próxima (trazos SVG simples, 24×24).
export const STAR = 'M80 12 C85 62 98 75 148 80 C98 85 85 98 80 148 C75 98 62 85 12 80 C62 75 75 62 80 12Z';

export const CLOTHING_ICONS: Record<string, string> = {
  hat: 'M4 15h16M6 15c0-5 2.5-8 6-8s6 3 6 8M9 7.5c.8-1.2 1.8-2 3-2s2.2.8 3 2',
  mask: 'M4 8c3-2 13-2 16 0 0 6-3 10-8 10S4 14 4 8zM8 11h2.5M13.5 11H16',
  top: 'M8 4l-4 3 2 4 2-1v10h8V10l2 1 2-4-4-3c-.5 1.5-2 2.5-4 2.5S8.5 5.5 8 4z',
  pants: 'M7 3h10l1 18h-4l-2-11-2 11H6L7 3z',
  shoes: 'M3 16h18v3H3zM4 16l1-6h4l2 3 6 1c2 .3 3 1 3 2',
  ears: 'M9 4a5 5 0 0 1 8 4c0 3-3 4-3 7a3 3 0 0 1-6 0M10 9a2 2 0 0 1 4 0',
  glasses: 'M3 11h4l1 4H4zM13 11h4l1 4h-4zM8 12h4',
  neck: 'M6 4c0 6 2.5 10 6 10s6-4 6-10M12 14v3M10.5 17h3l-1.5 3z',
  watch: 'M9 3h6l1 4H8zM8 17h8l-1 4H9zM12 9.5V12l1.5 1M7 12a5 5 0 1 0 10 0 5 5 0 0 0-10 0',
  bracelet: 'M5 12a7 4 0 1 0 14 0 7 4 0 1 0-14 0M8 9.5v.1M12 8.5v.1M16 9.5v.1',
  bag: 'M7 8V6a5 5 0 0 1 10 0v2M5 8h14l-1 13H6zM9 13h6',
  under: 'M9 4h6l1 3 2 1v12H6V8l2-1zM9 4c0 1.5 1.3 2.5 3 2.5S15 5.5 15 4',
  vest: 'M8 3l4 3 4-3 3 3v14h-5l-2-3-2 3H5V6zM12 6v11',
  decal: 'M12 3l2.5 5 5.5.8-4 3.9.9 5.5L12 15.6 7.1 18.2l.9-5.5-4-3.9 5.5-.8z',
};

export const VITAL_ICONS: Record<string, string> = {
  health: 'M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z',
  armour: 'M12 3l7 3v6c0 4-3 7-7 9-4-2-7-5-7-9V6z',
  hunger: 'M7 3v8M5 3v5a2 2 0 0 0 4 0V3M7 11v10M16 21V3c-2 0-3 3-3 7h3',
  thirst: 'M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11z',
  stress: 'M13 3L5 13h6l-1 8 8-10h-6z',
};

export const UI_ICONS = {
  close: 'M6 6l12 12M18 6L6 18',
  weight: 'M7 8h10l3 12H4zM9.5 8a2.5 2.5 0 0 1 5 0',
  cash: 'M3 7h18v10H3zM12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM6 10v.01M18 14v.01',
  bank: 'M3 10l9-6 9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18',
  minus: 'M6 12h12',
  plus: 'M12 6v12M6 12h12',
};

export function Icon({ d, className, title }: { d: string; className?: string; title?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden={title ? undefined : true} role={title ? 'img' : undefined}>
      {title && <title>{title}</title>}
      <path d={d} />
    </svg>
  );
}

export function Star({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 160 160" aria-hidden>
      <path d={STAR} />
    </svg>
  );
}
