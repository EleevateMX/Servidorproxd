# 36. Inventario propio (React + TypeScript) sobre ox_inventory

Sustituye a la capa de docs/20. La anterior era un CSS y un script inyectados en la interfaz de ox_inventory.

**Qué cambia:** la interfaz es una aplicación propia (`web/pxd-inventory`) que reemplaza la web compilada de **ox_inventory 2.48.1** y habla con él por su **mismo contrato NUI**. ox_inventory sigue siendo el único backend de ítems, peso, metadata, almacenes y transacciones; el servidor valida cada movimiento.

## Por qué fallaba la capa anterior
- **Signos vitales con guiones.** El bundle de ox_inventory sustituye `window.fetch` por una función vacía. Por eso `pxd.js` nunca recibía `https://pxd_inventory/state`. La nueva interfaz guarda su propia referencia a `fetch` y no carga el bundle de ox_inventory.
- **Diseño a medias.** El CSS solo retocaba el DOM interno de ox_inventory.

## Piezas
| Pieza | Ruta |
|---|---|
| Fuentes de la interfaz | `web/pxd-inventory/src` (React 19 + TypeScript, Vite) |
| Compilado (versionado) | `server-data/resources/[proxima]/pxd_inventory/web/{index.html, assets/pxd-inventory.js, assets/pxd-inventory.css}` |
| Adaptador Lua | `pxd_inventory/client/main.lua` + `shared/inventory.lua` (contrato `PXDInv.CONTRACT = 2`) |
| Contrato extraído de ox_inventory | `web/pxd-inventory/contract/ox_inventory-2.48.1.json` |

**Despliegue:**
- `pxd_updater` copia los tres archivos a `ox_inventory/web/build/` con `plan.overlays` y `requiresVersion 2.48.1`. Con otra versión de ox_inventory no se copian.
- Los nombres son fijos: `SaveResourceFile` no crea carpetas, y el `fxmanifest` de ox_inventory solo sirve `web/build/index.html` y `web/build/assets/*.js|*.css`. Las fuentes (Inter y Sora, OFL) van dentro del CSS.
- **Vuelta atrás:** `pxd_update rollback <id>` restaura el `index.html` original de ox_inventory. Su `assets/index.js` e `index.css` nunca se tocan.

**Recompilar** después de cambiar las fuentes:
```bash
cd web/pxd-inventory && npm install && npm run build
```
`tests/js/inventory-web.test.mjs` falla si las fuentes cambian sin recompilar (`build-stamp.json`).

## Contrato con ox_inventory 2.48.1
Extraído de `client.lua` y `modules/**` con `RegisterNUICallback` y `SendNUIMessage`. Las pruebas `tests/contract.test.ts` comprueban que la interfaz atiende todos los mensajes y solo llama a callbacks que existen.

| Mensaje recibido | Qué hace la interfaz |
|---|---|
| `init` | Objetos, idioma, ruta de imágenes e inventario del jugador. Solo llega tras el callback `uiLoaded` |
| `setupInventory` | Abre con `leftInventory` y/o `rightInventory`; pide `getItemData` de los objetos desconocidos |
| `refreshSlots` | `items` (sin inventario o `player` → izquierda; otro → derecha), `itemCount`, `weightData`, `slotsData` |
| `closeInventory` | Cierra |
| `toggleHotbar` | Muestra las ranuras 1–5 durante 3 s |
| `displayMetadata` | Etiquetas extra de metadata en el panel de información |
| `itemNotify` | `[ítem, clave ui_*, cantidad]` → aviso breve |

| Callback llamado | Cuándo |
|---|---|
| `uiLoaded` | Al cargar |
| `getItemData` | Objeto sin datos |
| `swapItems` | Arrastrar, Ctrl+clic, Tirar/Mover y Dividir: `{fromSlot, fromType, toSlot, toType, count}`. `false` → se deshace; un número → peso del contenedor |
| `buyItem` | Arrastrar desde una tienda o pulsar Comprar. Cantidad vacía = 1 |
| `craftItem` | Fabricación |
| `useItem` | Usar, doble clic o Alt+clic |
| `giveItem` | Dar, `{slot, count}` |
| `removeAmmo` | Quitar munición |
| `removeComponent` | Quitar un accesorio del arma |
| `useButton` | Botones propios del ítem; el `id` empieza en 1 |
| `exit` | Esc o el botón de cerrar |

**Reglas de movimiento:** el cambio optimista (mover, apilar, intercambiar, la mitad con Mayús) y las comprobaciones de tienda y fabricación por rango e ingredientes son las de la interfaz original (`web/src/reducers`, `helpers`). Están portadas y probadas en `tests/store.test.ts`.

## Contrato con pxd_inventory (`https://pxd_inventory/<acción>`)
| Acción | Respuesta |
|---|---|
| `state` | `{ contract, name, id, cash, bank, vitals{health, armour, hunger, thirst, stress}, clothing[], canChange, preview }` |
| `toggleClothing {id}` | El mismo `state`, con la prenda cambiada |

Procedencia de cada dato:
- `hunger`, `thirst` y `stress`: state bags de qbx_core 1.24.1, que también lee pxd_hud; si faltan, los metadata.
- `health`: `GetEntityHealth` sobre la vida máxima del ped.
- `armour`: `GetPedArmour`.
- `cash` y `bank`: `GetPlayerData().money`, **la misma fuente que el HUD**.
- **Nada se inventa:** un dato que no llega se omite y su barra no aparece. La energía no se muestra porque Qbox no la tiene.
- `preview`: indica si la cámara del personaje está activa. Dentro de un vehículo no hay cámara.

## Uso
| Acción | Cómo |
|---|---|
| Abrir y cerrar | **I** (keybind de ox_inventory) o **Esc** |
| Mover | Arrastrar entre ranuras y entre inventarios: suelo, maletero, guantera, alijo, contenedor o tienda→bolsillos |
| Mover al otro lado | Ctrl+clic |
| La mitad | Mayús al soltar |
| Información y acciones | Clic en un objeto: Usar, Dar, Tirar (o Mover si hay otro inventario abierto), Dividir, Quitar munición, Copiar n.º de serie y los botones propios del ítem |
| Cantidad | Selector de Cantidad; vacío = todo |
| Ropa | Botones alrededor del personaje |

**Resoluciones:** marco 16:9 centrado (unidad `--u`). En 21:9 queda centrado y la columna del personaje sigue donde lo pone la cámara (`Config.camera`). En pantallas más estrechas todo se reduce proporcionalmente.

## Solo se puede comprobar dentro de FiveM
- Que el personaje quede dentro del marco: ajustar `Config.camera.side` y `distance` si hace falta.
- El arrastre con el ratón del juego (`SetNuiFocusKeepInput`).
- Los callbacks entre recursos (`https://pxd_inventory/state` desde la página de ox_inventory).
- Los avisos de ox_inventory: dar sin nadie cerca, peso excedido…
- Maletero, guantera, tiendas y fabricación con datos reales.
