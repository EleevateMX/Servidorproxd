# 24. ox_lib y ox_target con el estilo de Próxima

Casi todo Qbox usa **ox_lib** para su interfaz: avisos (`lib.notify`), menús contextuales,
menús de lista, diálogos de entrada y de confirmación, barras y círculos de progreso, textUI y
skillcheck. La «mirilla» de interacción es **ox_target**. Cambiando esas dos webs, todo el
servidor pasa a verse con nuestro estilo, sin tocar cada recurso.

## Cómo se hace (sin recompilar)

Aquí no se pueden instalar las dependencias npm para recompilar (el entorno no deja ejecutar
código externo), así que se parte de las **builds oficiales publicadas** y se cambian con
sustituciones exactas y verificadas:

| Qué | Versión | Cómo |
|---|---|---|
| Tema de ox_lib (colores, radios, sombras, botones, diálogos, campos, tooltips…) | ox_lib **3.42.0** | Parche exacto del plan sobre `web/build/assets/index-Dqr00JhT.js`: sustituye el objeto `theme` de Mantine (aparece una sola vez) |
| Tipografía y detalles de ox_lib | 3.42.0 | Capa `pxd_theme/overlay/ox_lib/pxd.css` → `ox_lib/web/build/assets/pxd.css` + parche `</head>` en `web/build/index.html` |
| Mirilla de ox_target | ox_target **1.18.1** | Capa `pxd_theme/overlay/ox_target/style.css` → `ox_target/web/style.css` (mismas clases; el JS no cambia) + parche exacto del SVG del ojo en `web/index.html` por el destello de 4 puntas |

El tema cambia las paletas de Mantine que usan todos los componentes de ox_lib
(`dark` = noche, `cyan`/`blue` = estrella, `pink` = nova, `yellow` = oro, `red`, `teal`), así
que los avisos de éxito, error, aviso e información usan nuestros colores.

`pxd_theme` es un recurso sin scripts: solo guarda los archivos de la capa. Lo aplica
`pxd_updater` (overlays con `requiresVersion` y patches con `requires: pxd_theme`).

## Despliegue

- **Servidor nuevo (receta):** `recipe-qbox.yaml` fija ox_lib `v3.42.0` y ox_target `v1.18.1`
  (no «latest»: el parche depende de la build exacta) y aplica los mismos cambios con
  `replace_string` (modo literal) y `copy_path`.
- **Servidor en marcha:** con estas líneas en el cfg (ya en `permissions.pxd.cfg`) y reinicio:
  ```
  add_filesystem_permission pxd_updater write ox_lib
  add_filesystem_permission pxd_updater write ox_target
  add_filesystem_permission pxd_updater write pxd_theme
  ```
  Después, `pxd_update` y **reiniciar el servidor**. No reinicies ox_lib en caliente: todo
  Qbox depende de él.
- Si el servidor tiene otra versión de ox_lib u ox_target, la capa no se aplica (lo avisa el
  actualizador) y el parche del bundle no hace nada (el archivo con ese nombre no existe).

## cfg (server.qbox.cfg)

```
setr ox:primaryColor cyan     # color principal = estrella (#5ce1ff con el tema aplicado)
setr ox:primaryShade 5
set ox:txAdminNotifications 1 # avisos/MD/advertencias de txAdmin con el estilo de ox_lib
```

Las tres convars están verificadas en el código de ox_lib 3.42.0 (`resource/client.lua`,
`resource/interface/server/txadmin.lua`). Para la última, activa además en txAdmin →
Settings → Game → «Hide default announcement / direct message / warning».

## Límites conocidos

- No se puede añadir borde ni degradado a las tarjetas de avisos y menús de ox_lib: sus estilos
  usan clases con hash generadas en ejecución. Se cambian con el tema (colores, radios, sombras).
- La fuente es «Segoe UI» (de Windows, la de los jugadores), con Roboto de la propia ox_lib de reserva.
- ox_target pinta las etiquetas con `innerHTML` (código original de Overextended, sin cambios).

Capturas de comprobación (navegador, datos de ejemplo): notificaciones de los cuatro tipos,
menú contextual, menú de lista, diálogo, alerta, barra y círculo de progreso, textUI y la mirilla.
