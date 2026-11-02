# 25. Mapa: puntos en español (`pxd_blips`)

Los recursos de la receta crean sus puntos del mapa con nombres en inglés («Shop», «Public Parking»…). `pxd_blips` los recorre por sprite cada 10 s y les pone un nombre en español coherente y un tamaño común, para que el mapa de pausa y su lista lateral de «Puntos de interés» queden ordenados y en español.

- Solo toca blips **de corto alcance** (los de la ciudad). Así no cambia avisos de policía/EMS, rutas de trabajo ni jugadores, que son de largo alcance. Excepción explícita: la zona de buceo.
- Cuando varios recursos usan el mismo sprite, una regla con zona (`near`) decide: p. ej. el sprite 60 es «Comisaría» salvo junto a la prisión («Prisión»); el 326 es «Concesionario» en Premium Deluxe y «Vehículos de trabajo» en grúas/camioneros.
- No crea puntos nuevos salvo los de `Config.points` (vacío: los recursos ya crean los suyos; solo se añadirían con coordenadas sacadas de sus configs).
- Categorías propias (`SET_BLIP_CATEGORY` 12–133 + `BLIP_CAT_n`) preparadas pero desactivadas (`Config.useCategories = false`): con ellas la leyenda agrupa bajo el nombre de la categoría en lugar de listar cada punto.

Natives (citizenfx/natives, HUD): `GetFirstBlipInfoId`, `GetNextBlipInfoId`, `DoesBlipExist`, `IsBlipShortRange`, `GetBlipInfoIdCoord`, `SetBlipScale`, `SetBlipColour`, `SetBlipCategory`, `BeginTextCommandSetBlipName` / `AddTextComponentSubstringPlayerName` / `EndTextCommandSetBlipName`, `AddBlipForCoord`, `SetBlipSprite`, `SetBlipAsShortRange`, `RemoveBlip`; `AddTextEntry` (FiveM).

## Tabla

| Sprite | Nombre | Origen |
|---|---|---|
| 487 | Ayuntamiento | qbx_cityhall (City Services) |
| 60 | Comisaría | qbx_police (stations) |
| 60 | Prisión (zona) | xt-prison (prisión) |
| 61 | Hospital | qbx_ambulancejob (stations) |
| 61 | Enfermería de la prisión (zona) | xt-prison (cl_infirmary) |
| 273 | Comedor de la prisión (zona) | xt-prison (cl_canteen) |
| 108 | Banco | Renewed-Banking |
| 459 | Noticias Weazel | qbx_newsjob |
| 59 | Tienda | 24/7 «Shop» |
| 93 | Licorería | «Liquor Store» |
| 402 | Ferretería | «YouTool» |
| 110 | Armería | «Ammunation» / «Police Armoury» |
| 403 | Botiquín | «Medicine Cabinet» |
| 366 | Tienda de ropa | «Clothing Store» |
| 71 | Peluquería | «Barber» |
| 75 | Tatuajes | «Tattoo Shop» |
| 102 | Cirugía estética | «Plastic Surgeon» |
| 361 | Gasolinera | ox_fuel |
| 357 | Parking público | qbx_garages |
| 360 | Hangar | qbx_garages |
| 359 | Depósito aéreo | qbx_garages (Air Depot) |
| 68 | Depósito de vehículos | qbx_garages (Impound Lot) |
| 356 | Embarcadero (3 zonas) | qbx_garages: LSYMC, Paleto, Millars Boathouse |
| 356 | (se respeta) | el resto (p. ej. pxd_jobs pescador) ya trae nombre |
| 326 | Concesionario (zona) | qbx_vehicleshop Premium Deluxe Motorsport |
| 326 | Vehículos de trabajo | qbx_towjob / qbx_truckerjob |
| 410 | Concesionario náutico | qbx_vehicleshop Marina Shop |
| 251 | Concesionario de aeronaves | qbx_vehicleshop Air Shop |
| 72 | Taller de tuneo | qbx_customs |
| 446 | Taller mecánico | qbx_mechanicjob |
| 513 | Cochera de autobuses | qbx_busjob |
| 318 | Basurero municipal | qbx_garbagejob |
| 198 | Taxis | qbx_taxijob |
| 477 | Grúas | qbx_towjob (Towing HQ) |
| 479 | Camioneros | qbx_truckerjob (Truck Shed) |
| 365 | Centro de reciclaje | qbx_recyclejob |
| 380 | Desguace | qbx_scrapyard |
| 810 | Entrega de chatarra | qbx_scrapyard |
| 827 | Viñedo | qbx_vineyard |
| 270 | Bodega del viñedo | qbx_vineyard |
| 729 | Zona de buceo | qbx_diving |

Las zonas (`near`) usan coordenadas de las configs: prisión (xt-prison `configs/prisonbreak.lua` Center), embarcaderos (qbx_garages `config/server.lua`), Premium Deluxe (qbx_vehicleshop `config/shared.lua`).

## Integración

- `ensure pxd_blips` después de los recursos que crean puntos (da igual el orden: revisa cada 10 s).
- Sin permisos ni convars. Para que el actualizador lo mantenga: `add_filesystem_permission pxd_updater write pxd_blips`.
- Para añadir un nombre: una línea en `Config.rules` con el sprite (lista de sprites: https://docs.fivem.net/docs/game-references/blips/).
