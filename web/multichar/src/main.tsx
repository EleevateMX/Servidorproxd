import { createRoot } from 'react-dom/client';
import { App } from './App';
import { DEMO } from './nui';
import './styles.css';

// Fuentes de Próxima (Inter, Sora) incrustadas en html/ui/proxima-fonts.css.
const fonts = document.createElement('link');
fonts.rel = 'stylesheet';
fonts.href = 'ui/proxima-fonts.css';
document.head.appendChild(fonts);

createRoot(document.getElementById('root')!).render(<App />);

if (DEMO) { document.body.classList.add('demo-bg'); import('./demo').then((d) => d.start()); }
