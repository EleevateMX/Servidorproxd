import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Compila pxd_hud con nombres fijos (el actualizador compara archivos por ruta).
// No se vacía la carpeta: ahí está html/ui (fuentes y tokens comunes, scripts/sync-ui.mjs).
export default defineConfig({
  root: 'hud',
  plugins: [react()],
  base: './',
  build: {
    outDir: '../../../server-data/resources/[proxima]/pxd_hud/html',
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
});
