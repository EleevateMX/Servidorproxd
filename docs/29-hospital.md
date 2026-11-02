# 29. Hospital: reanimación, reaparición y auditoría

El médico tiene consecuencias de rol, pero no castiga de más. Lo gestiona `pxd_compat` (módulo médico) sobre qbx_medical y qbx_ambulancejob, sin modificarlos: solo cambia una opción de configuración.

## Qué pasa en cada caso

Comprobado en el código de las versiones fijadas (qbx_medical `b5649d2`, qbx_ambulancejob `0c2ca3c`).

| Caso | Cómo ocurre | Inventario |
|---|---|---|
| **Muerte / last stand** | qbx_medical cambia el estado de muerte (`isdead`/`inlaststand` en la metadata) | No se toca |
| **Reanimación por EMS** | `exports.qbx_medical:Revive` (desde `hospital:server:RevivePlayer` de qbx_ambulancejob o al tratar en cama) → en el cliente, `qbx_medical:client:playerRevived` | **No se pierde nada**. Ninguno de los dos recursos borra el inventario en este camino |
| **Reaparecer en el hospital** | Callback `qbx_medical:server:respawn` → evento `qbx_medical:server:playerRespawned` (qbx_medical `server/main.lua`). Lo escuchan qbx_ambulancejob (cama, factura) y pxd_compat | Solo se retiran los objetos **confiscables** (abajo) |

## Qué se conserva y qué se retira al reaparecer

Se configura en `pxd_compat/config.lua` → `Config.medical`.

**Siempre se conserva:**
- `money`. Es el efectivo, que en Qbox es un ítem de ox_inventory: está protegido aunque alguien lo añada por error a la lista de confiscables.
- El banco, que no es un ítem.
- Las llaves de vehículos, que en Qbox son virtuales.

**Lista `protected`:** documentos (`id_card`, `driver_license`, `weaponlicense`, `lawyerpass`), `phone`, `radio`, `harness`, `walking_stick`, `binoculars` y `lighter`. También las herramientas que ox_inventory trata como armas pero son legales: linterna, extintor, garrafa de gasolina, `HAZARDCAN`, `FERTILIZERCAN` y detector de metales.

**Se retiran:**
- Todo lo que empiece por `WEAPON_` (armas) o por `ammo-` (munición), salvo lo protegido.
- La lista administrativa `confiscate`: `black_money`, drogas (`crack_baggy`, `cokebaggy`, `coke_brick`, `coke_small_brick`, `xtcbaggy`, `meth`, `oxy`, `weed_*`, `joint`), `thermite`, `gatecrack` y `trojan_usb`.

Todos los nombres se han comprobado en `items.lua` de la receta y en `data/weapons.lua` de ox_inventory 2.48.1.

El resto (comida, bebida, herramientas, materiales…) se conserva.

**Garantías:**
- La retirada la hace el servidor: lee el inventario con `GetInventoryItems` y quita objeto a objeto con `RemoveItem(src, nombre, cantidad, nil, slot)`. Si una retirada falla, ese objeto se queda y no se registra.
- Si el evento se repite, no retira dos veces (ventana `dedupeMs`, 30 s; qbx_medical ya bloquea 30 s su propia reaparición).
- El jugador recibe un aviso breve: «En el hospital te han retirado: Pistola, Munición 9mm, Bolsa de coca.».

## Cambio necesario en qbx_ambulancejob (configuración)

Hay que desactivar el borrado completo, porque si sigue activo qbx_ambulancejob vacía **todo** el inventario, efectivo incluido.

| | Valor |
|---|---|
| Archivo | `resources/[qbx]/qbx_ambulancejob/config/server.lua` (commit `0c2ca3c`, línea 3) |
| Buscar | `    wipeInvOnRespawn = true, -- Enable to disable removing all items from player on respawn` |
| Reemplazar por | `    wipeInvOnRespawn = false, -- Enable to disable removing all items from player on respawn` |

Si pxd_compat arranca y la opción sigue en `true`, lo avisa en la consola.

## Auditoría común (`pxd_compat`)

Pensada para que la usen todos los sistemas: hospital, multas, economía, staff…

```lua
-- Registrar (servidor)
local id = exports.pxd_compat:Audit({
    category = 'medical',      -- obligatorio: medical | fines | economy | staff | …
    action = 'confiscate',     -- obligatorio
    actor = 'hospital',        -- quién lo hace: citizenid, 'sistema', 'hospital'…
    target = 'ABC12345',       -- a quién afecta (citizenid)
    data = { item = 'WEAPON_PISTOL', count = 1, serial = '…', reason = 'respawn' },
})
-- Consultar (más reciente primero)
local list = exports.pxd_compat:GetAudit({ category = 'medical', target = 'ABC12345', limit = 50 })
```

- Cada entrada guarda `id` (creciente), `at` (hora del servidor), `resource` (quién llamó), `category`, `action`, `actor`, `target` y `data`.
- Se guarda en `pxd_compat/data/audit.json` y solo conserva las `Config.audit.maxEntries` más recientes (5000). La carpeta `data/` no la toca el actualizador.
- Pendiente (etapa A de economía): llevarla a una tabla de MariaDB para que haya consultas e informes sin límite.

## Pruebas

`tests/lua/test_compat.lua` (7 pruebas de hospital y auditoría):
- al reaparecer solo se retira lo confiscable;
- el dinero queda intacto;
- la reanimación no toca nada;
- el evento repetido no retira dos veces;
- la auditoría se escribe y se recorta;
- avisa si `wipeInvOnRespawn` sigue en `true`.

Las pruebas usan versiones simuladas de ox_inventory y qbx_core. **Falta probarlo dentro de FiveM** (docs/26, sección 4).

## Sin verificar en el juego

- **Orden de los dos manejadores del evento** (qbx_ambulancejob y pxd_compat). No importa con `wipeInvOnRespawn = false`, porque qbx_ambulancejob ya no toca el inventario.
- **Que `label` venga en los objetos que devuelve `GetInventoryItems`.** Si no viene, el aviso usa el nombre interno.
- **Reaparición en la cárcel** (`injail > 0`): pasa por el mismo evento, así que se aplica la misma política.
