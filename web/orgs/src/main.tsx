import { createRoot } from 'react-dom/client';
import { App } from './App';
import { DEMO } from './nui';
import './styles.css';

// Fuentes incrustadas en html/ui: Inter y Sora (interfaz) y las tipografías de identidad.
for (const href of ['ui/proxima-fonts.css', 'ui/orgs-fonts.css']) {
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = href;
  document.head.appendChild(link);
}

createRoot(document.getElementById('root')!).render(<App />);

if (DEMO) { document.body.classList.add('demo-bg'); import('./demo').then((d) => d.start()); }
