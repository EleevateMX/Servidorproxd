# 39. Entrega: inventario propio, centro administrativo y creador de personajes

- **Paquete:** `proxima-actualizacion-baba35c.zip`. Trae los 23 recursos `resources/[proxima]/*` del commit `baba35c`, más `permissions.pxd.cfg` y `proxima.cfg` (fijado a `baba35c`). No lleva datos persistentes.
- **Por qué es un paquete completo:** el actualizador no puede crear carpetas nuevas, como `pxd_inventory/web/`.

## Qué corrige

| Problema | Causa | Arreglo | Doc |
|---|---|---|---|
| F2 abre el inventario; K abre otro inventario o agacha | FiveM guarda la tecla de cada comando por jugador | Parches que renombran `inv`, `inv2` y `crouch` | 28 |
| Inventario de ox_inventory con un diseño parcial | Capa de CSS/DOM encima de su interfaz | Interfaz propia en React sobre el contrato NUI de ox_inventory | 36 |
| Signos vitales con guiones | El bundle de ox_inventory anulaba `fetch` | Datos reales de Qbox y el mismo dinero que el HUD | 36 |
| No aparece la administración | `/admin` y `/noclip` eran de qbx_adminmenu; casi todo exigía `/duty`; F10 tenía la tecla antigua | Centro en `pxd_admin`: F10, `/admin`, `/noclip`, roles con herencia y auditoría | 37 |
| `/me` duplicado con `[pxd_chat]` | Se registraba en consola dentro del comando y FXServer lo devolvía al chat | Registro en el siguiente tick | — |
| Vestidor detrás de «Elige dónde empezar» y pantallas solapadas | Cámara de la selección activa; espera fija de 1 s al apartamento | Cámara aérea propia y espera real | 38 |
| Creador de personajes | — | Creador freemode propio en 6 secciones sobre illenium-appearance | 38 |

## Instalación

**0. Antes de empezar**
- Sin jugadores conectados.
- Copia de Nodecraft y dump de la base de datos.

**1. Subir el paquete.** Sube el zip a `servers/PrxmaRPQbox_E83FED.base/`, descomprímelo y acepta sobrescribir.
- En `resources/[proxima]` debe haber 23 carpetas.
- Tienen que existir `pxd_inventory/web/index.html` y `pxd_multichar/html/assets/app.js`.

**2. Tu cuenta como superadministrador.** Opcional, pero recomendado.
- En `permissions.pxd.cfg`, descomenta y completa la línea `add_principal identifier.fivem:TU_ID group.superadmin`.
- Tu ID está en txAdmin → Players → tu jugador → IDs.

**3. Restart.** Lee los permisos nuevos. Entre ellos, el actualizador recibe permiso de escritura en `qbx_adminmenu`.

**4. Live Console: `pxd_update`.**
Deberías ver:
- «Capa visual aplicada (3 archivo(s))», el inventario nuevo;
- estos «Ajustado …»:
  - `ox_inventory/client.lua` (×2), las teclas;
  - `qbx_smallresources/qbx_crouch/client.lua`;
  - `qbx_adminmenu/server/commands.lua` (×2);
  - `qbx_properties/server/apartmentselect.lua`;
- una copia de seguridad nueva. Apunta su id.

🛑 Detente si sale «no está el texto esperado», «falta el permiso» o un SCRIPT ERROR.

**5. Restart.**

## Pruebas dentro de FiveM

| # | Prueba | ✔ si… |
|---|---|---|
| 1 | F2 y K | No abren nada; K no agacha |
| 2 | I | Se abre el inventario nuevo con tu personaje, signos vitales reales y el mismo dinero que el HUD |
| 3 | Arrastrar, Usar, Dar, Tirar, Dividir | Funcionan; ox_inventory refleja el cambio |
| 4 | E en el maletero + I | Maletero a la derecha; arrastrar entre los dos |
| 5 | Guantera, tienda, alijo | Se abren en la interfaz nueva |
| 6 | Ctrl izquierdo | Agacha; no lo hace durante el noclip |
| 7 | `/me hola`, `/do`, `/b`, `/susurrar` | Una sola línea, sin `[pxd_chat]` |
| 8 | F10 y `/admin` | Se abre el centro administrativo |
| 9 | `/noclip` | Vuelo con rueda, Espacio, X y Shift; al salir vuelves a la normalidad |
| 10 | Panel → jugador | Ir, traer, curar y congelar funcionan, y cada acción aparece en «Registro» |
| 11 | Panel → vehículos | Generar, reparar y borrar |
| 12 | Crear personaje masculino | Las 6 secciones cambian de verdad al personaje |
| 13 | Crear personaje femenino | Igual |
| 14 | Guardar → apartamento → aparecer | No se abre el editor de illenium; la vista aérea no muestra el vestidor; vuelve el HUD |
| 15 | Desconectar y reconectar | Misma cara, cabello y ropa |
| 16 | Cambiar de personaje | Las apariencias no se mezclan |
| 17 | «Elige dónde empezar» | Tarjetas legibles, sin superposiciones |

## Pendiente y no verificado

- Retratos de madre y padre (`nui-img`): si no cargan, solo se ve el nombre.
- El chat no se oculta durante el editor.
- Las tiendas de ropa y las peluquerías aún no abren el editor nuevo (el export está listo).
- El encuadre de la cámara del creador hay que comprobarlo en la sala.

## Volver atrás

- **Parches de terceros:** `pxd_update rollback <id del paso 4>`. También devuelve la interfaz original de ox_inventory.
- **Lo demás:** restaura la copia de Nodecraft.
- **Tablas nuevas:** `pxd_character_status` puede quedarse.
