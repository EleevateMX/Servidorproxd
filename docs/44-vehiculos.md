# 44. Vehículos: taller de personalización, tuning y mecánicos por nivel (`pxd_garage`)

**Estado:** implementado y con pruebas automáticas (19 en Lua, 9 en Vitest, 4 en Node). **No instalado en Nodecraft, no probado en FiveM.**

## Qué hace

| Pieza | Cómo |
|---|---|
| **Taller con interfaz propia** | Al entrar con tu vehículo en un taller y pulsar E se abre la interfaz de Próxima (React + TypeScript). Cada cambio se ve al instante en el vehículo real, con cámara por sección. El carrito muestra el precio; «Aplicar» cobra y guarda; «Salir» o Esc deja el vehículo exactamente como estaba |
| **Tuning con estadísticas** | Motor, frenos, transmisión, suspensión, blindaje y turbo por niveles. Panel de velocidad, aceleración, frenada y agarre con el antes y el después, leídos del juego |
| **Mecánicos por nivel** | Experiencia por reparar piezas en el banco de trabajo y por trabajos de personalización cobrados. 6 niveles (Aprendiz → Maestro). El tuning alto solo lo monta un mecánico con nivel suficiente |
| **Dos formas de usarlo** | **Autoservicio** (talleres del mapa): el dueño paga en el acto y el rendimiento está limitado. **Taller de jugadores** (`job = 'mechanic'`): lo usa un mecánico de servicio, las piezas salen un 15 % más baratas y el dueño recibe una **factura** de `pxd_economy` |

## Qué se reutiliza (un solo dueño por dato)

| Dato | Dueño | Cómo lo usa pxd_garage |
|---|---|---|
| Propiedad del vehículo y mods guardados | **qbx_vehicles 1.4.2** (`player_vehicles.mods`) | `GetVehicleIdByPlate`, `GetPlayerVehicle` y `SaveVehicle(entidad, { props })`. No hay segunda tabla de vehículos |
| Formato de los mods | **ox_lib 3.42.0** | Cada pieza del catálogo es una clave de `lib.getVehicleProperties`; la vista previa usa `lib.setVehicleProperties`. Así qbx_garages vuelve a aplicar lo guardado sin cambios |
| Daño y reparación | **vehiclehandler 1.4.7** y **qbx_mechanicjob** | No se tocan. Solo se escucha `vehiclemod:server:updatePart` para dar experiencia al reparar |
| Precio del modelo | **qbx_core 1.24.1** (`GetVehiclesByName(modelo).price`) | Base de los precios |
| Cobro y facturas | **pxd_economy** | `ChargeToAccount` (taller con cuenta) e `IssueInvoice` / `CancelInvoice` (taller de jugadores) |
| Auditoría | **pxd_audit** | Categoría `taller` |

Lo que **sustituye**: el menú de **qbx_customs 0.1.0** en esas mismas zonas (parches de abajo). qbx_customs sigue arrancado porque aporta los colores camaleón (`carcols_gen9.meta`).

## Seguridad: qué valida el servidor

El cliente solo envía `{ clave = valor }`. En `apply` el servidor:
1. Comprueba la sesión, que el jugador sigue **dentro de la zona**, **al volante** y con el **mismo vehículo**.
2. Comprueba que el vehículo está registrado y, en autoservicio, que **es suyo**; en un taller de jugadores, que es **mecánico de servicio** de ese trabajo.
3. Valida cada clave contra el catálogo (tipo y rango). Matrícula, salud, gasolina o modelo **no** son personalizables.
4. Vuelve a leer lo guardado en qbx_vehicles, calcula los cambios reales y **recalcula el precio** (el cliente nunca manda importes).
5. Aplica los límites de rendimiento (autoservicio o nivel del mecánico).
6. Cobra (nunca saldo negativo) → guarda → si el guardado falla, **devuelve el dinero** o cancela la factura.
7. Guarda las props fusionadas en el servidor: salud del motor y la carrocería leídas con natives de servidor y gasolina del state bag de ox_fuel.

## Precios (`config.lua`)

- `base` = precio del modelo, acotado entre $15 000 y $600 000 ($40 000 si no se conoce).
- Cada cambio estético: `flat + pct × base` según la sección. Volver a «de serie» es gratis.
- Rendimiento: fracción de `base` acumulada por nivel; se cobra la **diferencia** con el nivel que ya tenía.
- Importes en múltiplos de 10. En taller de jugadores, ×0,85.

| Mejora | Autoservicio hasta | Nivel de mecánico por nivel de pieza |
|---|---|---|
| Motor | nivel 2 | 1, 1, 2, 3, 4 |
| Frenos / Transmisión | nivel 2 | 1, 1, 2, 3 |
| Suspensión | nivel 3 | 1, 1, 1, 2, 3 |
| Blindaje | no | 3, 4, 5, 5, 6 |
| Turbo | no | 3 |

## Mecánicos

- Tablas nuevas (`CREATE TABLE IF NOT EXISTS`): `pxd_mechanic_stats` (experiencia) y `pxd_mechanic_log` (trabajos).
- Experiencia: 12 por pieza reparada en el banco (misma pieza del mismo vehículo, una vez cada 10 min) y 15 + 2 por cada $1 000 del trabajo de personalización (máx. 80). Tope diario: 600.
- Niveles: Aprendiz 0 · Ayudante 150 · Mecánico 500 · Oficial 1 200 · Especialista 2 600 · Maestro 5 000.
- Exports de servidor: `GetMechanicLevel(id o citizenid)` → nivel, experiencia, nombre; `AddMechanicXp(src, cantidad, tipo, detalle)`.
- Comandos: `/mecanico` (tu nivel); `pxd_garage_xp <citizenid> <xp>` (consola o ACE `pxd.garage.manage`).
- **Preparado, no implementado:** asistencia a domicilio desde el nivel 4 (`Config.mechanic.homeServiceLevel`).

**Limitación conocida:** la experiencia por reparación se basa en un evento que lanza el cliente de qbx_mechanicjob. Un cliente manipulado podría simular reparaciones; por eso hay enfriamiento por pieza y tope diario, y la experiencia solo desbloquea niveles de tuning.

## Gasolina regular / extra / premium (gancho preparado, sin aplicar)

`ox_fuel` 1.5.4 (commit `84f93ba`) expone:
- export de servidor `setPaymentMethod(fn(playerId, price) → boolean)`: sustituye el cobro. Sirve para enviar el dinero a la cuenta de la gasolinera;
- export de cliente `setMoneyCheck(fn)`;
- evento `ox_fuel:pay(price, fuel, netid)`: **el precio lo calcula el cliente** (`config.priceTick` por tic) y el servidor no lo recalcula.

Para tipos de gasolina haría falta:
1. un parche en `client/fuel.lua` (`price += config.priceTick`) para que el precio por tic dependa del tipo elegido;
2. recalcular en el servidor el precio a partir de los litros (hoy se confía en el cliente);
3. guardar el tipo en el state bag del vehículo y que `pxd_garage` penalice a los coches de gama alta con gasolina barata.

Queda para la oleada de gasolineras; **no se aplica ningún parche a ox_fuel**.

## Integración (lo hace quien mantiene el plan)

**`server.qbox.cfg`** (después de `pxd_economy`): `ensure pxd_garage`. Añadir `pxd_garage` a `QBOX_ONLY` en `tests/js/deploy.test.mjs` y `'test_garage'` a `tests/lua/run.lua`.

**`scripts/update-plan.json`:** `pxd_garage` en `autostart` (después de `pxd_economy`) y estos parches (texto verificado: 1 coincidencia en cada fuente fijada, y el archivo parcheado compila):

```json
{ "resource": "qbx_customs", "path": "client/zones.lua", "requires": "pxd_garage", "requiresVersion": "0.1.0",
  "find": "CreateThread(function()\n    for _, v in ipairs(sharedConfig.zones) do",
  "replace": "CreateThread(function()\n    if GetResourceState('pxd_garage') ~= 'missing' then return end -- Próxima: el taller es pxd_garage (docs/44)\n    for _, v in ipairs(sharedConfig.zones) do",
  "why": "un solo taller: las zonas y el menú de qbx_customs no se crean si está pxd_garage" },
{ "resource": "qbx_customs", "path": "server/main.lua", "requires": "pxd_garage", "requiresVersion": "0.1.0",
  "find": "RegisterNetEvent('qbx_customs:server:saveVehicleProps', function()\n    local src = source --[[@as number]]",
  "replace": "RegisterNetEvent('qbx_customs:server:saveVehicleProps', function()\n    if GetResourceState('pxd_garage') == 'started' then return end -- Próxima: solo guarda pxd_garage, tras validar y cobrar\n    local src = source --[[@as number]]",
  "why": "nadie guarda mods sin pasar por el cobro de pxd_garage" },
{ "resource": "qbx_mechanicjob", "path": "server/main.lua", "requires": "pxd_garage",
  "find": "RegisterNetEvent('qb-vehicletuning:server:SaveVehicleProps', function(vehicleProps)\n    if not isVehicleOwned(vehicleProps.plate) then return end",
  "replace": "RegisterNetEvent('qb-vehicletuning:server:SaveVehicleProps', function(vehicleProps)\n    if GetResourceState('pxd_garage') == 'started' then return end -- Próxima: evita guardar mods sin validar ni cobrar\n    if not isVehicleOwned(vehicleProps.plate) then return end",
  "why": "ese evento aceptaba mods de cualquier cliente para cualquier matrícula (su propio cliente ya no lo usa)" }
```
La receta (`recipe-qbox.yaml`) necesita los mismos tres `replace_string`.

**`permissions.pxd.cfg`:**
```
add_filesystem_permission pxd_updater write pxd_garage
add_filesystem_permission pxd_updater write qbx_customs
add_filesystem_permission pxd_updater write qbx_mechanicjob
add_ace group.admin pxd.garage.manage allow
```

**Otros:** `scripts/sync-ui.mjs` ya incluye `pxd_garage` en `TARGETS` (fuentes comunes). Regenerar `update-manifest.json`. Añadir este documento al índice del README.

## Pruebas

- `tests/lua/test_garage.lua` (19): catálogo y rangos, precio recalculado, límites de rendimiento, zonas, sesión, cobro y reembolso (sumidero, cuenta y factura), eventos manipulados, experiencia y niveles.
- `web/garage` (Vitest, 9): formato, estadísticas, selectores y bloqueos.
- `tests/js/garage-web.test.mjs` (4): build al día, nombres fijos, callbacks y claves del catálogo.
- Capturas: `node web/garage/scripts/shots.mjs <carpeta>` (6 vistas × 1280×720, 1920×1080 y 2560×1080; falla si hay errores de página o desbordes).

## Solo se puede verificar dentro de FiveM

1. Entrar con un vehículo propio en un taller, pulsar E: se abre la interfaz, sin HUD, y el menú antiguo de qbx_customs no aparece (con los parches).
2. Cada control cambia el vehículo real; los nombres de las piezas salen del juego; al cambiar de tipo de llanta se actualiza la lista.
3. La cámara encuadra bien cada sección en coches, motos y furgonetas (valores en `VIEWS` de `client/main.lua`).
4. **Si las estadísticas cambian al montar motor, frenos o turbo.** Se leen con `GetVehicleEstimatedMaxSpeed`, `GetVehicleAcceleration`, `GetVehicleMaxBraking` y `GetVehicleMaxTraction`; si alguna no refleja los mods en la build 3751, habrá que calcularla de otra forma.
5. Aplicar: cobra lo que marcaba el presupuesto, guardar en garaje y volver a sacar conserva los cambios.
6. Salir sin aplicar: el vehículo queda exactamente igual.
7. Taller de jugadores (hay que definir su polígono en `Config.zones`): factura al dueño, experiencia y bloqueo por nivel.
8. Reparar una pieza en el banco de qbx_mechanicjob suma experiencia (`/mecanico`).
