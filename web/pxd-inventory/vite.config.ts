import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

// El resultado se versiona en pxd_inventory/web y pxd_updater lo copia a ox_inventory/web/build
// (plan.overlays). Nombres FIJOS sin hash: SaveResourceFile no crea carpetas ni conoce nombres nuevos,
// y el fxmanifest de ox_inventory solo sirve web/build/index.html y web/build/assets/*.js|*.css.
// Todo (fuentes incluidas) va dentro de esos dos archivos.
const outDir = fileURLToPath(new URL('../../server-data/resources/[proxima]/pxd_inventory/web', import.meta.url));

export default defineConfig({
  plugins: [react()],
  base: './',
  publicDir: false,
  build: {
    outDir,
    emptyOutDir: true,
    target: 'chrome103',
    modulePreload: false,
    cssCodeSplit: false,
    assetsInlineLimit: 1024 * 1024,
    reportCompressedSize: false,
    rollupOptions: {
      output: {
        entryFileNames: 'assets/pxd-inventory.js',
        chunkFileNames: 'assets/pxd-inventory-[name].js',
        assetFileNames: (info) => (info.names?.[0]?.endsWith('.css') ? 'assets/pxd-inventory.css' : 'assets/[name][extname]'),
        inlineDynamicImports: true,
      },
    },
  },
  test: {
    globals: true,
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
} as any);
