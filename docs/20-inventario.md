# 20. Inventario de Próxima RP

> **Sustituido por docs/36-inventario.md:** ahora la interfaz es una aplicación propia (React) sobre ox_inventory. Lo de abajo describe la capa anterior; la ropa, la cámara y los signos vitales se mantienen.

Se abre con **I**. Es el inventario de ox_inventory con la capa visual de Próxima y el recurso `pxd_inventory`.

## Qué se ve

| Zona | Contenido |
|---|---|
| Arriba | Nombre del personaje, su ID (`PROX-…`, de `pxd_interact`, si existe), efectivo y banco, y «Esc · Cerrar» |
| Izquierda | El personaje en 3D, con el fondo desenfocado por la cámara. Alrededor, 15 ranuras de ropa: 5 a cada lado y 4 abajo. Debajo, los **signos vitales**: comida, bebida, salud, armadura y estrés, de 0 a 100 |
| Centro | Tu inventario en 4 columnas, con el contador de ranuras (p. ej. 8/20) y el peso; los botones Usar / Dar / Cerrar; y el inventario de al lado (suelo, maletero, tienda…) |
| Derecha | **Notificaciones** recientes, con «Limpiar todas» |

La barra rápida (F1) usa el mismo estilo.

## Ropa

Al hacer clic en una ranura, la prenda se quita o se vuelve a poner. Las prendas son las de la lista `Config.clothing` de `pxd_inventory/config.lua`: sombrero, máscara, torso, pantalón, zapatos, pendientes, gafas, collar, reloj, pulsera, camiseta interior, chaleco, mochila e insignia.

- Solo funciona con personajes **freemode** (`mp_m_freemode_01` y `mp_f_freemode_01`), que son los que pueden cambiarse de ropa. Con otro modelo, las ranuras no aparecen.
- La ropa «sin prenda» usa los mismos valores que la ropa base de qbx_core.
- Quitarse algo **no se guarda**: el aspecto guardado sigue siendo el de illenium-appearance, así que al reconectar vuelve la ropa guardada.

## Cómo está hecho

**1. Capa visual.**
- No ha hecho falta recompilar la interfaz de ox_inventory, que es React (no se pueden instalar sus dependencias en este entorno).
- Se le añaden `pxd.css` y `pxd.js`: el actualizador o la receta inserta en su `index.html`, antes de `</head>`, las líneas que los cargan.
- `pxd.js` sabe si el inventario está abierto porque ox_inventory solo monta `.inventory-wrapper` mientras lo está.

**2. Datos.**
- `pxd.js` pide a `https://pxd_inventory/state` el nombre, el dinero, los signos vitales, la ropa y las notificaciones. Para la ropa llama a `toggleClothing`, y para limpiar notificaciones, a `clearNotices`.
- Esta comunicación entre recursos funciona por cómo está hecho FiveM (comprobado en `citizenfx/fivem`):
  - `ResourceUI.cpp` solo bloquea llamadas de otros recursos si el que las recibe tiene página propia y activa el modo estricto. `pxd_inventory` no tiene página.
  - `RPCSchemeHandler.cpp` responde con `access-control-allow-origin: *`.
  - `ResourceUICallbacks.cpp` interpreta el cuerpo como JSON sin mirar el `Content-Type`. Por eso `pxd.js` envía `text/plain` y se evita la petición previa de CORS.
- Los callbacks solo devuelven datos del propio jugador y cambian la ropa de su propio personaje.

**3. Cámara.**
- Mientras ox_inventory tiene el state bag local `invOpen` (`client.player:set` de ox_lib), una cámara enfoca al personaje en el hueco de la izquierda, con profundidad de campo, como en la selección de personaje de qbx_core.
- No se activa dentro de un vehículo.
- Se configura en `Config.camera`.

**4. Notificaciones.**
- Se guardan las que llegan por los eventos de red `ox_lib:notify` y `QBCore:Notify`.
- Las que un recurso muestra con `lib.notify` directamente en el cliente no se guardan.

## Configuración del servidor

En `server.qbox.cfg`, ya incluidas:

```
setr inventory:keys ["I", "K", "F1"]   # I inventario, K maletero/guantera, F1 barra rápida
setr inventory:screenblur false        # el desenfoque lo pone la cámara
ensure pxd_inventory
```

En `permissions.pxd.cfg`:

```
add_filesystem_permission pxd_updater write ox_inventory
```

Los jugadores que ya habían entrado conservan la tecla que tenían guardada (F2 o TAB). Pueden cambiarla en *Ajustes → Asignación de teclas → FiveM → ox_inventory*.

## Despliegue

**Servidor nuevo:** `recipe-qbox.yaml` copia `pxd.css` y `pxd.js` a `ox_inventory/web/build/assets/` y añade las dos líneas al `index.html`.

**Servidor en marcha (Nodecraft):**
1. Sube `pxd_inventory` con el paquete de instalación (`scripts/build-package.sh`).
2. Añade la línea `add_filesystem_permission` en el CFG Editor y cambia `inventory:keys` y `inventory:screenblur`.
3. Reinicia el servidor.
4. Ejecuta `pxd_update`, que:
   - copia la capa a `ox_inventory` (los «overlays» del manifiesto), solo si su versión es la 2.48.1 y la copia local tiene la huella SHA-256 esperada;
   - aplica el cambio del `index.html`;
   - pide reiniciar.
5. Reinicia otra vez: ox_inventory solo recarga su interfaz al arrancar. El actualizador no lo reinicia en caliente, porque pararlo también para los recursos que dependen de él.

## Límites conocidos

- **Barra rápida:** en ox_inventory 2.48.1 tiene 5 ranuras fijas (`slice(0, 5)` en su `InventoryHotbar.tsx`). Para tener 8 habría que recompilar su interfaz.
- **Energía:** no hay barra de energía porque Qbox no tiene ese dato. Se muestra el estrés.
- **Ropa como objetos:** no está hecho. Sería que quitarse una prenda la guarde como objeto con `{componente, drawable, textura}` y ponerla desde el inventario. Plan:
  1. Un objeto `ropa` en `ox_inventory/data/items.lua`, con `client.export` hacia `pxd_inventory`.
  2. Al quitar la prenda, el servidor crea el objeto con la metadata.
  3. Al usar el objeto, se pone la prenda y se guarda con illenium-appearance (comprobar su export para guardar el aspecto).
  4. Validar en el servidor que el componente y el drawable sean válidos para el modelo.
- **Sin probar dentro del juego:** las llamadas entre recursos, el encuadre de la cámara y que no se vea el desenfoque de ox. Se ha probado en navegador con `vendor/ox_inventory/demo/index.html`.
