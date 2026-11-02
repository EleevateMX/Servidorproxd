# Capa de Próxima RP para ox_inventory

[ox_inventory](https://github.com/overextended/ox_inventory) (Overextended) se distribuye con licencia **GPL-3.0** (copia en `LICENSE`).

Próxima RP **no modifica su código**. Le añade dos archivos propios, que se cargan después de los suyos en `web/build/index.html`:

- `pxd.css`: estilos.
- `pxd.js`: paneles extra (barra superior, ropa, signos vitales y notificaciones).

Los archivos fuente están en `server-data/resources/[proxima]/pxd_inventory/overlay/ox_inventory/` y se publican con la misma licencia GPL-3.0. Al publicar el servidor no se distribuye una copia modificada de ox_inventory: se instala la release oficial y se le añade esta capa.

Hecho para la **versión 2.48.1**: el marcado que usa la capa sale de `web/src/components`, en el tag `v2.48.1`. Si ox_inventory cambia de versión, `pxd_updater` no aplica la capa hasta que se revise y se suba `requiresVersion` en `scripts/update-plan.json`.

`demo/index.html` es una vista previa en navegador. Reproduce su marcado y su CSS base, sin el juego.
