# 18. Interacción con E e identidad (pxd_interact)

En Próxima RP casi todo se hace con **E**: al acercarte a algo con lo que se puede interactuar aparece un aviso «E · Recoger», «E · Darse de alta»… Si hay varias opciones, se elige con la **rueda del ratón** o las **flechas ↑/↓** y se confirma con **E**. La tecla se cambia en *Ajustes → Asignación de teclas → FiveM* («Interactuar (Próxima RP)»).

## Identidad: Desconocido · PROX-7KQ2

- Cada personaje tiene un **ID público** corto y estable: `PROX-` + 4 caracteres (sin 0/O/1/I para que no se confundan). Se crea al cargar el personaje, se guarda en su metadata de Qbox (`pxd_id`) y es único (índice en `pxd_interact/data/ids.json`).
- Encima de las personas cercanas (≤ 8 m y a la vista) se ve **«Desconocido · PROX-7KQ2»**. Si esa persona se te ha presentado, ves **su nombre**. Cuando alguien habla por voz, su etiqueta se pone en cian.
- **Presentarse**: acércate (≤ 3 m) a alguien, pulsa E → *Presentarse*. A la otra persona le llega «Aceptar presentación de PROX-…» (o *Ignorar*); si acepta, aprende tu nombre. Es en un sentido: para que tú sepas el suyo, que se presente ella.
- Los conocidos se guardan por personaje (metadata `pxd_known`, hasta 200; se olvida al más antiguo). El servidor comprueba distancia, enfriamiento (10 s), caducidad (20 s) y que ambos existan.

## Lo que ya usa la E

| Dónde | Acción |
|---|---|
| Otra persona | Presentarse |
| Objetos tirados (ox_inventory) | Recoger (abre el suelo) |
| Trabajos propios (pxd_jobs) | Darse de alta / Dejar el trabajo / Picar, Talar, Pescar… / Vender / Recoger paquetes / Entregar el paquete |

Con pxd_interact, `pxd_jobs` deja de necesitar `/dejartrabajo` (es una opción de la E). Los recursos de Qbox (taxi, mecánico, etc.) siguen con su propio sistema (ox_target o su tecla).

## API para otros recursos (cliente)

```lua
-- Zona (coords + radio)
local id = exports.pxd_interact:addZone({
    coords = vector3(x, y, z), radius = 1.5,
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

`ctx = { entity?, coords, dist, serverId?, zone? }`. Opciones: `label`, `icon` (hand, handshake, chat, box, briefcase, door, eye, car, check, close, star), `distance?`, `canInteract?`, y una de `onSelect`, `event` (evento de cliente) o `serverEvent` (+ `args`). Lo que registra un recurso se borra solo cuando ese recurso se para.

Servidor: `exports.pxd_interact:GetPublicId(src)`, `GetSourceByPublicId('PROX-7KQ2')`, `Knows(src, 'PROX-7KQ2')`.

## Arranque

Va después de `qbx_core` y `ox_inventory`, y **antes** de `pxd_jobs` (si arranca después, pxd_jobs cambia de modo solo). No necesita permisos ACE ni convars. Sin Qbox funciona con un JSON por licencia (`data/players.json`) y el nombre de FiveM.

Vista previa: `html/index.html?demo=1`, `?demo=many`, `?demo=invite`.

## Pendiente de comprobar en el juego

- Que la etiqueta no tape demasiado en grupos grandes (tamaño según distancia).
- Choques de la E con recursos de Qbox que también escuchan la tecla de contexto en el mismo sitio.
- Los objetos tirados en otras instancias (buckets): ox_inventory no deja abrirlos, pero el aviso podría verse.
