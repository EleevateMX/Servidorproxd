import { createRoot } from 'react-dom/client';
import { loadCommonUi } from '../shared/nui';
import { App } from './App';
import { demoMessages } from './demo';
import './styles.css';

loadCommonUi();
createRoot(document.getElementById('root') as HTMLElement).render(<App />);
demoMessages();
