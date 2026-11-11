// Iconos propios del kit (trazo, 24×24). Sin fuentes de iconos externas.
import type { Tone } from './model';

const PATHS: Record<Tone, string> = {
  info: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm0 7.2v6.3M12 7.4v.2',
  success: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm-4 9.2 2.8 2.8L16 9.6',
  warning: 'M12 3.6 2.8 19.4h18.4zM12 9.5v5M12 16.9v.2',
  error: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM9 9l6 6m0-6-6 6',
};

export function ToneIcon({ tone }: { tone: Tone }) {
  return (
    <svg viewBox="0 0 24 24" className="tone-icon" aria-hidden="true">
      <path d={PATHS[tone]} fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/** Estrella de Próxima. */
export function Star({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 160 160" className={className} aria-hidden="true">
      <path d="M80 12 C85 62 98 75 148 80 C98 85 85 98 80 148 C75 98 62 85 12 80 C62 75 75 62 80 12Z" fill="currentColor" />
    </svg>
  );
}
