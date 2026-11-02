# 18. Interacción con E e identidad (pxd_interact)

En Próxima RP casi todo se hace con **E**: al acercarte a algo con lo que se puede interactuar aparece un aviso «E · Recoger», «E · Darse de alta»… Si hay varias opciones, se elige con la **rueda del ratón** y se confirma con **E** (las flechas ya no: ↑ abre el teléfono). La tecla se cambia en *Ajustes → Asignación de teclas → FiveM* («Interactuar (Próxima RP)»).

Este recurso también lleva **B** (recoger del suelo) y **Ctrl izquierdo** (agacharse). Tabla completa de teclas y conflictos: [28-controles.md](28-controles.md).

## Identidad: Desconocido · PROX-7KQ2

- Cada personaje tiene un **ID público** corto y estable: `PROX-` + 4 caracteres (sin 0/O/1/I para que no se confundan). Se crea al cargar el personaje, se guarda en su metadata de Qbox (`pxd_id`) y es único (índice en `pxd_interact/data/ids.json`).
- Encima de las personas cercanas (≤ 8 m y a la vista) se ve **«Desconocido · PROX-7KQ2»**. Si esa persona se te ha presentado, ves **su nombre**. Cuando alguien habla por voz, su etiqueta se pone en cian.
- **Presentarse**: acércate (≤ 3 m) a alguien, pulsa E → *Presentarse*. A la otra persona le llega «Aceptar presentación de PROX-…» (o *Ignorar*); si acepta, aprende tu nombre. Es en un sentido: para que tú sepas el suyo, que se presente ella.
- Los conocidos se guardan por personaje (metadata `pxd_known`, hasta 200; se olvida al más antiguo). El servidor comprueba distancia, enfriamiento (10 s), caducidad (20 s) y que ambos existan.

## Lo que ya usa la E

Una pulsación = una acción: se ejecuta la opción marcada (la primera de la lista).

| Prioridad | Dónde | Acción |
|---|---|---|
| 100 | Invitación recibida | Aceptar / Ignorar presentación |
| 35 | NPC y objetos registrados (`addLocalEntity`, `addModel`) | Lo que registre cada recurso |
| 30 | Zonas (`addZone`), entre ellas los trabajos propios (pxd_jobs) | Darse de alta / Dejar el trabajo / Picar, Talar, Pescar… / Vender / Recoger paquetes / Entregar el paquete |
| 25 | Parte trasera de un vehículo | **«E · Abrir maletero»**: abre directamente el maletero de ox_inventory, sin menú intermedio. Si está cerrado con llave: «Maletero cerrado» |
| 10 | Otra persona | Presentarse |

Los puntos que un recurso registra a propósito (p. ej. «Entregar el paquete» junto a tu furgoneta) van antes que el maletero, que se detecta en cualquier coche; el maletero sigue en la lista y se elige con la rueda. Hay un nivel 40 (`PXDInteract.PRIORITY.job`) para acciones de trabajo que deban ganar a todo salvo invitaciones.
A igual prioridad gana lo más cercano. Una zona puede pasar su propia `priority`.

**Maletero.** Usa los mismos datos y comprobaciones que ox_inventory 2.48.1 (`data/vehicles.lua`: modelos sin maletero, motor delante, puertas traseras de furgonetas; a menos de 1,5 m del punto del maletero). Después, ox_inventory vuelve a comprobar en el servidor la distancia y el cierre antes de abrir. Solo a pie.

**Cuándo la E no es de pxd_interact** (no aparece el aviso ni hace nada):

- Otro recurso muestra su aviso con ox_lib (puertas de ox_doorlock, teletransportes de qbx_teleports…).
- Hay una puerta de ox_doorlock al alcance.
- Corres o esprintas (placaje de qbx_tackle) o mantienes Mayús (empujar vehículo de qbx_vehiclepush).
- Estás a menos de 3 m de un surtidor de ox_fuel (repostar). Modelos en `Config.fuelPumps`.

ox_target (Alt) sigue funcionando aparte; tiene su propia opción de maletero, que no choca con la E.

## B: recoger del suelo

- Al acercarte (≤ 1,6 m) a un objeto tirado (drop de ox_inventory) aparece **«B · Recoger botella de agua»** (con «×N» si es un montón). Al pulsar B se recoge el primer hueco del drop entero, sin abrir el inventario.
- Varios cerca: el más cercano; si están casi a la misma distancia (±15 cm), el que tienes delante.
- Sin nada cerca, B no hace nada. Inventario lleno: «No te cabe en el inventario.» y el objeto se queda en el suelo.
- No funciona en vehículo, muerto, con el inventario abierto ni con la pausa o una interfaz abierta.
- **El servidor lo valida todo**: que el drop y el hueco existan, distancia (≤ 3 m), que no estés en vehículo ni muerto, y que te quepa (`CanCarryItem`). Un bloqueo por drop (3 s) impide que dos personas lo recojan a la vez. Primero se quita del drop y luego se añade al jugador; si eso falla, vuelve al drop. Si el drop queda vacío y nadie lo tiene abierto, se elimina. Enfriamiento de 0,4 s por jugador.
- No hay inventario paralelo: son los drops de ox_inventory. El nombre que se ve lo da el servidor (solo si estás cerca).
- Instancias (buckets): el cliente solo muestra los drops de tu instancia (como ox_inventory). ox_inventory 2.48.1 no guarda la instancia del drop en el servidor, así que el servidor valida la distancia, igual que el propio ox_inventory.

## Ctrl izquierdo: agacharse

Alterna agachado/de pie. Usa el mismo estado que qbx_crouch (state bag `crouch`, sincronizado con los demás); si qbx_smallresources no está, aplica la animación por su cuenta. No funciona en vehículo, nadando, en el suelo ni muerto (te levanta solo). El sigilo nativo de GTA (también en Ctrl) se desactiva a pie para que no haya dos modos de agacharse.

## API para otros recursos (cliente)

```lua
-- Zona (coords + radio)
local id = exports.pxd_interact:addZone({
    coords = vector3(x, y, z), radius = 1.5, priority = 20,   -- opcional (ver tabla)
    options = {
        { label = 'Abrir', icon = 'door', canInteract = function(ctx) return true end, onSelect = function(ctx) ... end },
        { label = 'Llamar', icon = 'chat', serverEvent = 'mi_recurso:llamar', args = { ... } },
    },
})
exports.pxd_interact:removeZone(id)

exports.pxd_interact:addLocalEntity(entity, options, distance)   -- removeLocalEntity(id)
exports.pxd_interact:addModel({ 'prop_atm_01' }, options, distance) -- removeModel(id)
exports.pxd_interact:addGlobalPlayer(options)  -- ctx.serverId; removeGlobalPlayer(id)
exports.pxd_interact:addTemporary(options, seconds, priority)      -- removeTemporary(id)
exports.pxd_interact:disable(true|false)
exports.pxd_interact:notify('Texto')          -- aviso corto
exports.pxd_interact:setTagsEnabled(true|false)
```

`ctx = { entity?, coords, dist, serverId?, zone? }`. Opciones: `label`, `icon` (hand, handshake, chat, box, briefcase, door, eye, car, check, close, star, lock), `distance?`, `canInteract?`, y una de `onSelect`, `event` (evento de cliente) o `serverEvent` (+ `args`). Lo que registra un recurso se borra solo cuando ese recurso se para.

Servidor: `exports.pxd_interact:GetPublicId(src)`, `GetSourceByPublicId('PROX-7KQ2')`, `Knows(src, 'PROX-7KQ2')`.

## Arranque

Va después de `qbx_core` y `ox_inventory`, y **antes** de `pxd_jobs` (si arranca después, pxd_jobs cambia de modo solo). No necesita permisos ACE. Las convars de teclas de otros recursos (ox_inventory, scully_emotemenu) y el ajuste de qbx_crouch están en [28-controles.md](28-controles.md). Sin Qbox funciona con un JSON por licencia (`data/players.json`) y el nombre de FiveM.

Vista previa: `html/index.html?demo=1`, `?demo=many`, `?demo=invite`, `?demo=pickup`.

## Pendiente de comprobar en el juego

- Que la etiqueta no tape demasiado en grupos grandes (tamaño según distancia).
- Choques de la E con recursos de Qbox que también escuchan la tecla de contexto en el mismo sitio.
- Los objetos tirados en otras instancias (buckets): el cliente los filtra por `LocalPlayer.state.instance`; comprobar que no se ven.
- Maletero: modelos raros (furgonetas, motor delante) y que la puerta se cierra al cerrar el inventario.
- B: varios jugadores pulsando a la vez sobre el mismo objeto; objetos con metadata (armas, documentos).
- Ctrl: que la animación se ve igual para los demás y que apuntar/correr no se rompen.
