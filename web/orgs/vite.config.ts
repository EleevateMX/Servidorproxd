import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// La compilación va al recurso con nombres fijos (el actualizador compara archivos por ruta).
// No se vacía la carpeta: ahí están las fuentes incrustadas (html/ui).
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: '../../server-data/resources/[proxima]/pxd_orgs/html',
    emptyOutDir: false,
    target: 'chrome90',
    cssCodeSplit: false,
    assetsInlineLimit: 0,
    modulePreload: false,
    rollupOptions: {
      output: {
        entryFileNames: 'assets/app.js',
        chunkFileNames: 'assets/app-[name].js',
        assetFileNames: (info) => (info.name && info.name.endsWith('.css') ? 'assets/app.css' : 'assets/[name][extname]'),
        inlineDynamicImports: true,
      },
    },
  },
  test: { environment: 'node', globals: true },
});
