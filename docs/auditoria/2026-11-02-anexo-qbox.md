# Auditoría del stack Qbox de Próxima RP (solo lectura)

Fuentes: `Servidorproxd/recipe-qbox.yaml`, `server-data/server.qbox.cfg`, `permissions*.cfg`; código de terceros en `/tmp/claude-0/src/` (abreviado `src/`). Los clones locales son **HEAD de main** (shallow); en los recursos que la receta baja como «release latest» la versión real instalada puede ser más antigua que el clon. Leyenda: ✅ verificado en código · ⚠️ verificado en código pero sin probar en juego · ❓ sin verificar.

## 1. Árbol de recursos de la receta

| Carpeta | Recurso | Origen en la receta | Versión que se ve (clon / tag más alto) |
|---|---|---|---|
| raíz | permissions.cfg, ox.cfg, voice.cfg, misc.cfg, qbox.sql, items.lua | `txAdminRecipe` ref **main** | commit 0a12aa7 (21-oct-2026) |
| [cfx-default] | cfx-server-data/resources (sin `chat`) | **main** | c6afa39 |
| [standalone] | bob74_ipl | ref **master** | ❓ no clonado |
| | safecracker, mhacking, ultra-voltlab, MugShotBase64 | ref **main** | ❓ no clonados |
| | scully_emotemenu | main | 2.1.0 (494cd18) |
| | screencapture | release **latest** | tag v1.0.0-preview-0.0.2; `provide 'screenshot-basic'` (fxmanifest main) |
| | Renewed-Banking | release latest | 2.1.4 (tag v2.1.4) |
| | illenium-appearance | release latest | v5.7.0 (+ parches de tema y `Ped=false`) |
| | mana_audio, Renewed-Weathersync, vehiclehandler | release latest | tags v1.1.1 / v1.1.8 / v1.4.7; ❓ código no clonado |
| | xt-prison | release latest | fxmanifest 1.4.8 (tags con formato `v.1.4.x`) |
| [qbx] | qbx_idcard, qbx_scoreboard, qbx_vehicleshop, qbx_seatbelt, qbx_ambulancejob, qbx_medical, qbx_radialmenu, qbx_police, qbx_vehiclekeys, qbx_cityhall | ref **main** | commits de sept. 2026 |
| | qbx_core | release latest | v1.24.1 |
| | qbx_vehicles / qbx_garages / qbx_management / qbx_spawn / qbx_customs / qbx_adminmenu / qbx_smallresources / qbx_density | release latest | v1.4.2 / v1.1.4 / v1.4.0 / v0.1.1 / v0.1.0 (clon 0.1.1) / v0.1.0 / v0.2.0 / v1.0.1 |
| | Fase 2: qbx_mechanicjob, towjob, taxijob, truckerjob, garbagejob, busjob, newsjob, recyclejob, diving, divegear, vineyard, scrapyard, **qbx_properties** | ref **main** | 0.0.1 (properties) / 1.0.x |
| [voice] | pma-voice, qbx_radio | main | pma-voice 7.0.1 |
| [ox] | ox_lib, ox_target, oxmysql, ox_doorlock, ox_inventory | release latest | ox_lib v3.42.0, ox_target v1.18.1, oxmysql v2.14.3, ox_doorlock v1.23.0, ox_inventory v2.48.1 (+ overlay `pxd.css/js`) |
| | ox_fuel | main | 1.5.4 |
| [npwd] | npwd | **tag fijo 3.14.3** | 3.14.3 |
| | qbx_npwd | main | su `config.json` sustituye al de npwd |
| [npwd-apps] | npwd_qbx_garages, npwd_qbx_mail | release latest | 1.1.0 / 1.0.0 |
| [proxima] | 15 recursos `pxd_*` | este repositorio (HEAD) | — |

**Lo que arranca el cfg** (`server.qbox.cfg:79-109`): `mapmanager`, `chat` (el chat del sistema, `resources_useSystemChat true`, porque la carpeta `chat` se borra en la línea 119 de la receta), `spawnmanager`, `baseevents`; después `ox_lib`, `qbx_core`, `ox_target`, `[ox]`, `[qbx]`, `[standalone]`, `[voice]`, `pxd_voice`, `[assets]`, `[npwd-apps]`, `qbx_npwd`, `npwd` y los `pxd_*`. No se arranca nada más de `[cfx-default]`. **`[assets]` no existe**: la receta no crea esa carpeta, así que `ensure [assets]` (línea 91) solo deja un aviso ❓. No se instalan qbx_hud (lo sustituye pxd_hud; el clon solo sirve de referencia), ni qbx_apartments, ni qbx_houses.

## 2. Dependencias

Solo se listan las declaradas y los exports que se usan de verdad (grep de `exports.X` / `GetResourceState`).

| Recurso | Declaradas en fxmanifest | Exports de otros recursos que usa |
|---|---|---|
| qbx_core | /server:10731, /onesync, ox_lib, oxmysql | ox_inventory, qbx_vehicles, qbx_vehiclekeys, qbx_idcard (ítems iniciales), illenium-appearance, Renewed-Banking (nóminas de sociedad), spawnmanager |
| ox_inventory | /server:6116, /onesync, oxmysql, ox_lib | qbx_core ≥1.18.1 y qbx_vehicles ≥1.2.0 (comprobados con `assert` en `modules/bridge/qbx/server.lua:1-2`), ox_target, npwd |
| ox_target / ox_fuel / scully | ox_lib / ox_lib + ox_inventory / ox_lib | ox_target: qbx_core, ox_inventory |
| Renewed-Banking | — | qbx_core (detectado al cargar), ox_target; `qb-phone` solo si `renewedMultiJob` (false) |
| qbx_ambulancejob | qbx_core, qbx_medical, ox_lib, ox_inventory | ox_target, Renewed-Banking |
| qbx_medical | ox_lib, qbx_core | spawnmanager, monitor (txAdmin) |
| qbx_police | — | qbx_core, ox_inventory, Renewed-Banking, qbx_vehiclekeys, ox_target, xt-prison/qbx_prison (estado) |
| qbx_vehicleshop | — | qbx_core, qbx_vehicles, qbx_vehiclekeys, ox_target, Renewed-Banking, npwd |
| qbx_garages | — | qbx_core, qbx_vehicles, qbx_vehiclekeys (estado) |
| qbx_vehiclekeys | — | qbx_core, qbx_vehicles, ox_inventory |
| qbx_properties | — | qbx_core, ox_inventory, qbx_garages, illenium-appearance |
| qbx_spawn | — | qbx_core, qbx_properties (estado) |
| qbx_management / cityhall / customs | — | qbx_core (+ ox_target) / qbx_core, qbx_idcard / qbx_core |
| qbx_idcard | ox_lib, MugShotBase64 | ox_inventory, qbx_core |
| qbx_radio | pma-voice | qbx_core |
| qbx_adminmenu | — | qbx_core, pma-voice, qbx_vehicles, qbx_vehiclekeys, qbx_medical, qbx_customs, ox_inventory |
| npwd | screenshot-basic, pma-voice | (lo cubre screencapture con `provide`) |
| qbx_npwd | — | npwd, qbx_core, ox_inventory |
| npwd_qbx_garages | — | qbx_garages (hace `assert` de que está arrancado al cargar), qbx_core, npwd |
| npwd_qbx_mail | — | qbx_core, npwd |
| xt-prison | — | qbx_core, ox_inventory, ox_target, ox_doorlock, scully_emotemenu; opcionales no instalados: xt-prisonjobs, randol_medical, ND_MDT, ps-dispatch |
| trabajos qbx_* | casi ninguno declara | qbx_core, ox_target, ox_inventory, scully (mecánico) |

Riesgo de orden: casi ningún qbx_* declara dependencias y funciona por el orden de `ensure` (ox → qbx → standalone). Hay dos problemas reales de orden, explicados en el punto 4.

## 3. Flujos reales

### a) Dinero y banco
- **Cuentas**: `cash`/`bank`/`crypto`, con 500/5000/0 iniciales (`qbx_core/config/server.lua:8`). Solo `cash` y `crypto` no pueden quedar en negativo (`:9`; comprobación en `server/player.lua:1500-1508`). **El banco puede quedar en negativo** ✅.
- **Efectivo = ítem `money`** de ox_inventory (`inventory:accounts ["money"]`; `qbx_core/server/player.lua:12,85,1411`) ✅. Al reaparecer en el hospital se vacía el inventario (punto f), y eso incluye el efectivo.
- **Renewed-Banking** 2.1.4: crea `bank_accounts_new` y `player_transactions` al arrancar (`server/main.lua:736-741`; también lo hace `qbox.sql`). Al arrancar crea una cuenta por cada trabajo y banda de qbx_core (`:32-60`). Exports: `getAccountMoney`, `addAccountMoney`, `removeAccountMoney`, `handleTransaction`, `GetJobAccount`, `CreateJobAccount`, `addAccountMember`, `removeAccountMember`, `getAccountTransactions`, `changeAccountName` (`:191-692`). Además implementa los exports de `qb-management` (`server/framework.lua:21-30`). En el banco de Pacific/Paleto (`createAccounts=true`) se pueden crear cuentas compartidas con miembros. Solo ven la cuenta de empresa los rangos con `bankAuth` (`framework.lua:181-185`; en qbx_core lo tienen los jefes de police/bcso/sasp/ambulance/realestate/taxi/cardealer/mechanic y de las bandas). Con `renewedMultiJob=false` solo cuenta el trabajo principal (`framework.lua:147-165`). ⚠️ Guarda `Jobs` al arrancar, así que los cambios de rango o trabajos creados en caliente no se ven hasta reiniciar.
- **Nóminas**: cada 10 min (`config/server.lua:10`) se pagan `grade.payment` al banco y solo si se está de servicio (`server/loops.lua:48-74`). `paycheckSociety = false` (`config/server.lua:11`), así que **el dinero se crea de la nada** y no sale de la cuenta de la empresa ✅. Con `true` lo descontaría de Renewed-Banking (`:128-134`) y avisaría «empresa sin fondos».
- **Fuentes de dinero (inflación)**: nóminas, comisión del 10 % del concesionario además del precio completo para la sociedad (`qbx_vehicleshop/server/main.lua:214-218`) y `/paylawyer`, que paga a un abogado sin quitar dinero a nadie (`qbx_police/server/commands.lua:328`).
- **Sumideros (el dinero desaparece)**: tiendas de ox_inventory, tuneo (`qbx_customs/server/main.lua:16-31`), compra y alquiler de casas, depósito de la grúa y licencias. Los únicos ingresos que van a una sociedad son las multas y el radar (→ `police`), el check-in del hospital (→ `ambulance`) y las ventas con vendedor (→ trabajo del vendedor).

### b) Vehículos: la cadena funciona, con matices
1. **Compra** (`qbx_vehicleshop/server/main.lua:164-198`): solo en tiendas `free-use` (las tres configuradas). El pago va en efectivo o por banco con comprobación de saldo (`server/utils.lua:70-82`), y después `qbx_vehicles:CreatePlayerVehicle({model, citizenid})` ✅. El concesionario `managed` con el trabajo `cardealer` está **comentado** (`config/shared.lua:287-291`), así que el trabajo `cardealer` existe pero no tiene tienda. La financiación está activa, con cuotas cada 24 h y embargo (`config/server.lua:3-9`, `server/finance.lua`).
2. **Registro**: tabla `player_vehicles` (`qbx_vehicles/vehicles.sql`), con `citizenid` como FK a `players` (ON DELETE CASCADE), `plate` UNIQUE y `state` 0=fuera, 1=garaje, 2=incautado (`server/main.lua:9-12,176-187`) ✅.
3. **Garajes** (qbx_garages 1.1.4): al aparcar se llama a `SaveVehicle` con props y se borra la entidad (`server/main.lua:291-318`). Para sacarlo se comprueba que sea del jugador y que el grupo sea el primario; en el depósito se cobra `depotPrice` por efectivo y luego por banco, con comprobación de saldo (`server/spawn-vehicle.lua:30-38,116-131`). Como `autoRespawn=false` (`config/server.lua:10`) y `qbx:enableVehiclePersistence false`, tras un reinicio los coches que estaban fuera se recogen en el depósito ✅.
4. **Llaves** (virtuales, sin ítem): el statebag `vehicleid` hace que qbx_vehiclekeys ponga `owner=citizenid` (`server/keys.lua:152-158`), y el dueño siempre tiene llaves (`:116-129`). El concesionario llama a `GiveKeys` (`config/server.lua:13-16`); el garaje lanza `vehiclekeys:client:SetOwner`, que tiene puente (`bridge/qb/client.lua:11`) ✅.
5. **Maletero y guantera**: ox_inventory usa `player_vehicles.id` (`modules/bridge/qbx/server.lua:8-10,112-115`) y crea las columnas `trunk`/`glovebox` si faltan (`modules/mysql/server.lua:51-68`). Se guardan para los vehículos con dueño ✅.
6. **Tuneo**: qbx_customs cobra y guarda `mods` por matrícula (`server/main.lua:80-85`). Sin restricción de trabajo por defecto: el ejemplo está comentado (`config/shared.lua:7-9`). qbx_mechanicjob repara por piezas con ítems y tiene almacén. ⚠️ El estado de las piezas solo se guarda en BD con el evento `vehiclemod:server:saveStatus`, «used in old qb-garages» (`server/main.lua:139-143`), al que qbx_garages no llama, así que **el desgaste de piezas se pierde al reiniciar**.

### c) Propiedades (qbx_properties 0.0.1, «todo» en su README)
- Las tablas se crean al arrancar (`server/property.lua:509-516`) ✅, como dice la receta.
- **Casas en venta**: solo existen si alguien con el trabajo `realestate` las crea con `/createproperty` (`server/realtor.lua:4-12`). **No hay casas predefinidas**.
- **Compra**: intenta cobrar en efectivo y luego por banco sin comprobar saldo (`:489`). ⚠️ Como el banco admite negativo, **se puede comprar cualquier casa sin dinero**. El dinero no va a ninguna sociedad.
- **Alquiler** ⚠️: `startRentThread()` se llama **sin `propertyId`** (`:470`), así que el alquiler no se cobra hasta el siguiente reinicio, cuando se relanza bien (`:518-520`).
- **Llaves**: `keyholders` (JSON de citizenids) con alta y baja (`:281-330`) y timbre o invitar a entrar (`:174,261`).
- **Alijo**: ox_inventory `qbx_properties_<nombre>`, con dueño y protegido por un hook que exige estar dentro (`:10-23,45`).
- **Garaje** de la propiedad vía `qbx_garages:RegisterGarage` (`:397-411`).
- **Decoración**: catálogo gratuito, solo para el dueño, guardado en `properties_decorations` (`:546-567`).
- **Apartamento inicial**: con `startingApartment=true` (`qbx_core/config/client.lua:10`) al crear personaje se elige apartamento (`server/apartmentselect.lua:5-76`) y luego se abre el editor de ropa.
- **qbx_spawn** ofrece como punto de aparición las propiedades de las que eres dueño (`server/main.lua:52-63`) y te mete dentro (`client/main.lua:227`). pxd_multichar replica este flujo.

### d) Empresas y organizaciones
- **Trabajos** definidos en `qbx_core/shared/jobs.lua`: police, bcso, sasp, ambulance, realestate, taxi, bus, cardealer, mechanic, judge, lawyer, reporter, trucker, tow, garbage, vineyard, hotdog. Bandas en `gangs.lua`. Admite varios trabajos, pero el cfg lo limita a **1 trabajo y 1 banda** (`qbx:max_jobs_per_player 1`, `setjob_replaces true`).
- **qbx_management**: contratar a jugadores cercanos, despedir (también desconectados), ascender y ver un registro de fichajes (`player_jobs_activity`, `server/storage.lua`) ✅. **No gestiona fondos.** Editar rangos (nombre, sueldo, isboss, bankAuth) requiere `qbx:enableGroupManagement`, que **está a `false`** en el cfg (`server/main.lua:8,364-394`). **Solo hay zonas de jefe para las bandas lostmc y vagos** (`config/server.lua:11-31`); ningún recurso instalado llama a `RegisterBossMenu`, así que **police, ambulance, mechanic, etc. no tienen menú de jefe** ⚠️.
- **Fondos de sociedad**: solo en Renewed-Banking (cajero o banco, rangos con `bankAuth`).

### e) Policía y justicia
- **Multas** `/fine` (`qbx_police/server/main.lua:596-657`): cobro **inmediato** del banco (que puede quedar en negativo) e ingreso en Renewed-Banking `police`. **No queda registro** salvo `lib.logger` si `fineLogger=true`, que está a `false` (`config/shared.lua:5`). No hay multas pendientes ni pago posterior. Igual con `BillPlayer` (`:291-302`) y con el radar (`:163-169`).
- **Esposas**: ítem `handcuffs` y metadata `ishandcuffed` (`:218-226,334-338`) ✅. También escoltar, meter en vehículo, registrar, `/seizecash`, pruebas (sangre, huellas, casquillos con bolsas), `/flagplate`, `/plateinfo`, ANPR, cámaras, pinchos, grúa e incautación, y `/grantlicense` y `/revokelicense`.
- **Cárcel**: xt-prison gestiona `injail` en la metadata (`bridge/server/qbx.lua:38`) con `/jail`, `/unjail`, `/jailtime` y `/prisoners`. Conflicto en el punto 4.
- **Expediente**: solo `metadata.criminalrecord = {hasRecord, date}` (`qbx_police/server/main.lua:320`). **No hay MDT** ni historial de delitos.
- **Radio**: qbx_radio sobre pma-voice. ⚠️ Ver el problema del ítem `radio` en el punto 4.
- **Justicia**: los trabajos `judge` y `lawyer` existen, junto con el ítem `lawyerpass` y `/paylawyer`, pero no hay ningún recurso de juicios.

### f) EMS y medicina
- qbx_medical guarda `isdead`/`inlaststand` en la metadata (`server/main.lua:38-39`). Al reconectar se restaura la muerte o el last stand (`client/load-unload.lua:17-26`) junto con la vida y el chaleco (`qbx_core/server/player.lua:1203`) ✅. **Las heridas y el sangrado viven en statebags** (`shared/main.lua:1`), así que **no persisten**. El last stand pasa a muerte (`deathTime` 300 s).
- qbx_ambulancejob:
  - **check-in**: solo con menos de 2 médicos de servicio (`hospital.lua:230-243`). Cuesta 2000 del banco (puede quedar en negativo), que van a la sociedad `ambulance` (`:101-102`).
  - **reaparecer**: borra el inventario (`wipeInvOnRespawn=true`; `config/server.lua:3`, `hospital.lua:157-158,314`).
  - **otras funciones**: camas, tratar, reanimar, alertas a EMS, armería y almacén. `RegisterShop` **existe** en ox_inventory 2.48.1 (`modules/shops/server.lua:117`), así que el aviso no aplica ✅.

### g) Documentos
- **qbx_cityhall**: reimprime `id_card`, `driver_license` y `weaponlicense` por 50 en efectivo si `metadata.licences[id|driver|weapon]` es true (`server/main.lua:41-63`). Ofrece trabajos públicos (`:67-84`). No hay autoescuela ni examen.
- **qbx_idcard**: crea el ítem con metadatos y foto de MugShotBase64 (`bridge/framework/qbox.lua:26-56`).
- **Ítems iniciales**: DNI y carné (`qbx_core/config/shared.lua:6-15`).
- **Licencias por defecto**: id y driver true, weapon false (`player.lua:689-693`). Ammu-Nation exige la licencia `weapon` (`ox_inventory` bridge `hasLicense`).

### h) Teléfono (npwd 3.14.3 + qbx_npwd)
- **Número e identidad**: `charinfo.phone` se copia en `players.phone_number` (`qbx_npwd/server.lua:21-37`). Hace falta el ítem `phone` (`PhoneAsItem`).
- **Con datos reales en BD** (`npwd/import.sql`):
  - contactos, mensajes y notas;
  - llamadas con `pma-voice:setCallChannel` (`apps/game/client/calls/cl_calls.service.ts:125`);
  - Twitter, Match y DarkChat;
  - calculadora y ajustes.
- **Marketplace**: `persistListings:false`, así que los anuncios se borran al desconectarse (`player.service.ts:236`).
- **Cámara, galería y notas de voz**: suben a fivemanage (`config.json` `images.url` y `voiceMessage.url`) con `SCREENSHOT_BASIC_TOKEN` y `NPWD_AUDIO_TOKEN`. **Los dos están vacíos en el cfg, así que no funcionan.** Además es un servicio externo; si es de pago, hay que pedir permiso al propietario (regla 6).
- **Navegador**: desactivado.
- **Garaje** (npwd_qbx_garages): solo lista vehículos con estado y garaje (`server/server.lua:7-39`). No los saca.
- **Correo** (npwd_qbx_mail): tabla `player_mails`, eventos `qb-phone:server:sendNewMail(ToOffline)` (`server/server.lua:112-120`). Lo usa al menos qbx_ambulancejob.
- **No hay app de banco.**
- ⚠️ `import.sql` tiene varios `CREATE TABLE` sin `IF NOT EXISTS` (líneas 39, 157, 169, 203, 215, 226), así que relanzar la receta sobre una BD existente falla en ese paso.

### i) Inventario (ox_inventory 2.48.1)
- **Ajustes de `ox.cfg`**: framework `qbx`, 50 huecos y 85 kg, `inventory:police` police/bcso/sasp. Los ítems vienen de `txAdminRecipe/items.lua`.
- **Tiendas** (`data/shops.lua`): General, Liquor, YouTool, Ammunation y armería de policía. Los precios varían (`randomprices true`) y el dinero desaparece.
- **Alijos**: los de `data/stashes.lua` (policelocker, emslocker), los registrados por recursos (EMS, mecánico, propiedades) y la limpieza de alijos sin cambios tras 6 meses.
- **Otros**: maleteros y guanteras en BD, botín aleatorio en coches ajenos y contenedores, y drops con prop.
- **Metadatos**: durabilidad, número de serie, `registered` y DNI con foto.
- El inventario del jugador se guarda en `players.inventory`.

## 4. Duplicidades, conflictos y avisos

1. **Cárcel duplicada** ⚠️. qbx_police calcula `IsUsingXTPrison` al cargar (`server/main.lua:8`), pero `[qbx]` arranca antes que `[standalone]`. Al arrancar el servidor xt-prison aún no está iniciado, así que qbx_police registra su `/jail` y `/unjail` y su manejador de `police:server:JailPlayer` (`commands.lua:146-167`, `main.lua:304-332`). xt-prison registra los mismos (`sv_commands.lua:35,113`, `bridge/compat/server.lua:20`). Resultado: dos comandos con el mismo nombre (❓ cuál gana) y dos manejadores del evento. En el cliente la comprobación sí ve xt-prison, porque se hace después.
2. **Alijos de qbx_police sin registrar** ⚠️. Solo se registran en `onServerResourceStart` de `ox_inventory` (`main.lua:660-675`), y ox_inventory arranca antes. Las papeleras `policetrash_N` no existen. `policelocker` sí funciona porque también está en `ox_inventory/data/stashes.lua`, aunque eso es una definición duplicada.
3. **Ítem `radio` roto** ⚠️. `items.lua` (receta oficial) lo define con `consume = 0` y `client.event = 'mm_radio:client:use'` (`txAdminRecipe/items.lua:208-216`). Como `consume` vale 0, ox_inventory toma la rama de consumo y no llama al `CreateUseableItem('radio')` de qbx_radio (`ox_inventory/server.lua:484-505`, `qbx_radio/server/main.lua:6`). Después lanza un evento de `mm_radio`, que no está instalado. `jammer` y `radiocell` también apuntan a mm_radio.
4. **Banco en negativo** (diseño de qbx_core). Las multas, `BillPlayer`, el check-in y la compra de casas siempre se cobran.
5. **Admin**: hay tres paneles (txAdmin, qbx_adminmenu con `/admin`, `/noclip` y `/report`, y pxd_admin con `/soporte`, `/staff` y F10). Hay dos sistemas de reportes (`/report` y `/soporte`).
6. **HUD y voz**: pma-voice muestra su propia interfaz (`voice_enableUi 1`) además de pxd_hud. qbx_smallresources/qbx_hudcomponents también toca el HUD nativo.
7. **Chat**: `/me` y `/ooc` de qbx_core conviven con pxd_chat ❓.
8. **Comandos repetidos**: `/givecash` existe en Renewed-Banking (y ❓ en otros). `/jail` y `/unjail` (punto 1).
9. **Teclas por defecto que chocan**:
   - **LMENU**: ox_target y radio de pma-voice (`voice_defaultRadio "LMENU"`).
   - **K**: maletero de ox_inventory y agacharse (qbx_crouch).
   - **H**: manos arriba (scully) y buscar llaves (qbx_vehiclekeys).
   - **B**: señalar (scully) y cinturón (qbx_seatbelt).
   - **E**: placaje, empujar vehículo y teletransportes.
   - **F1**: barra rápida de ox_inventory; ❓ la tecla del radial de qbx_radialmenu no se ha verificado.
10. **Daños de vehículo**: los efectos de qbx_mechanicjob (`client/damage-effects.lua`) conviven con vehiclehandler ❓ (no clonado).
11. **Varios**:
    - `illenium-appearance` y `xt-prison` traen soporte para qb-target, pero no se usa (ox_target hace `provide 'qtarget'`).
    - Renewed-Banking hace `provide 'qb-management'`, lo que no choca con qbx_management.
    - `qbx_npwd` se arranca antes que `npwd`. Al reiniciarlo en caliente llama a `exports.npwd` (sin problema al arrancar el servidor).
12. **El token de la cámara se envía al cliente** (`npwd/apps/game/server/photo/photo.controller.ts:52`). Así funciona npwd, pero hay que tenerlo en cuenta si se configura.

## 5. Sistemas de rol que no cubre ningún recurso instalado
- **Emergencias y justicia**: bomberos; MDT, base de datos policial, órdenes de busca, informes y fichas; juicios, abogados y fiscalía (solo hay trabajos vacíos `judge` y `lawyer`); multas pendientes, facturas e impuestos; centralita o dispatch (solo alertas básicas de qbx_police y EMS, sin ps-dispatch).
- **Negocios y economía**: negocios de jugadores con stock, cajas registradoras o restaurantes (hotdog es un trabajo sin recurso); concesionario gestionado por jugadores (desactivado); inmobiliaria con comisión; app de banco en el teléfono; seguros de vehículo; lotería y casino.
- **Crimen**: drogas, territorios y guerras de bandas; robos a tiendas, bancos o joyería (safecracker, mhacking y ultra-voltlab son minijuegos sin escenarios de robo); blanqueo (existe el ítem `black_money`, pero nadie lo usa); mercado negro.
- **Vehículos**: autoescuela y exámenes; ITV y permisos por tipo de vehículo; desgaste persistente de piezas (punto b6).
- **Vida diaria**: hambre y sed sí existen (qbx_core); faltan necesidades avanzadas como estrés o higiene; también mascotas y gimnasio ❓ (no comprobado).
- **Propiedades**: catálogo de casas predefinidas, alquiler fiable (bug b) y muebles de pago.
- **Mensajería**: correo y anuncios persistentes, porque el marketplace no guarda los anuncios.
