import { createRoot } from 'react-dom/client';
import App from './App';
import { InventoryProvider } from './state';
import './styles.css';

// El navegador del juego no debe iniciar arrastres nativos (imágenes, texto).
window.addEventListener('dragstart', (e) => e.preventDefault());

createRoot(document.getElementById('root')!).render(
  <InventoryProvider>
    <App />
  </InventoryProvider>,
);
