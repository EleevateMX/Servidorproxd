-- Configuración de pxd_blips: nombres en español para los puntos que crean otros
-- recursos (por sprite) y puntos propios. Fuentes de cada sprite: docs/25-mapa.md.
Config = {}

-- Cada cuánto se revisan los blips (otros recursos los crean al arrancar o al cambiar
-- de trabajo). Barato: solo recorre los sprites de la tabla.
Config.intervalMs = 10000

-- Tamaño común para los puntos de la ciudad (nil = respetar el de cada recurso).
Config.scale = 0.75

-- Agrupar en el mapa por categorías propias (SET_BLIP_CATEGORY 12-133 + BLIP_CAT_n).
-- Desactivado: la leyenda de GTA agrupa entonces bajo el nombre de la categoría en vez
-- de listar cada punto por su nombre, que es lo que se pidió.
Config.useCategories = false
Config.categories = {
    servicios = { index = 12, label = 'Servicios' },
    tiendas   = { index = 13, label = 'Tiendas' },
    vehiculos = { index = 14, label = 'Vehículos' },
    trabajos  = { index = 15, label = 'Trabajos' },
}

-- Reglas: sprite → nombre. `near = { x, y, r }` para sprites que usan varios recursos.
-- `skip = true` para no tocar un blip concreto. `colour` y `scale` son opcionales.
Config.rules = {
    -- Servicios públicos
    { sprite = 487, name = 'Ayuntamiento', category = 'servicios' },                 -- qbx_cityhall (City Services)
    { sprite = 60,  name = 'Comisaría', category = 'servicios' },                     -- qbx_police (stations)
    { sprite = 60,  name = 'Prisión', category = 'servicios',
      near = { x = 1699.86, y = 2605.15, r = 250.0 } },                                -- xt-prison (configs/prisonbreak.lua Center)
    { sprite = 61,  name = 'Hospital', category = 'servicios' },                      -- qbx_ambulancejob (stations)
    { sprite = 61,  name = 'Enfermería de la prisión', category = 'servicios',
      near = { x = 1699.86, y = 2605.15, r = 250.0 } },                                -- xt-prison (cl_infirmary)
    { sprite = 273, name = 'Comedor de la prisión', category = 'servicios',
      near = { x = 1699.86, y = 2605.15, r = 250.0 } },                                -- xt-prison (cl_canteen)
    { sprite = 108, name = 'Banco', category = 'servicios' },                         -- Renewed-Banking
    { sprite = 459, name = 'Noticias Weazel', category = 'servicios' },               -- qbx_newsjob

    -- Tiendas (ox_inventory data/shops.lua, illenium-appearance Config.Blips)
    { sprite = 59,  name = 'Tienda', category = 'tiendas' },                          -- 24/7 «Shop»
    { sprite = 93,  name = 'Licorería', category = 'tiendas' },                       -- «Liquor Store»
    { sprite = 402, name = 'Ferretería', category = 'tiendas' },                      -- «YouTool»
    { sprite = 110, name = 'Armería', category = 'tiendas' },                         -- «Ammunation» / «Police Armoury»
    { sprite = 403, name = 'Botiquín', category = 'tiendas' },                        -- «Medicine Cabinet»
    { sprite = 366, name = 'Tienda de ropa', category = 'tiendas' },                  -- «Clothing Store»
    { sprite = 71,  name = 'Peluquería', category = 'tiendas' },                      -- «Barber»
    { sprite = 75,  name = 'Tatuajes', category = 'tiendas' },                        -- «Tattoo Shop»
    { sprite = 102, name = 'Cirugía estética', category = 'tiendas' },                -- «Plastic Surgeon»
    { sprite = 361, name = 'Gasolinera', category = 'tiendas' },                      -- ox_fuel

    -- Vehículos
    { sprite = 357, name = 'Parking público', category = 'vehiculos' },               -- qbx_garages
    { sprite = 360, name = 'Hangar', category = 'vehiculos' },                        -- qbx_garages
    { sprite = 359, name = 'Depósito aéreo', category = 'vehiculos' },                -- qbx_garages (Air Depot)
    { sprite = 68,  name = 'Depósito de vehículos', category = 'vehiculos' },         -- qbx_garages (Impound Lot)
    { sprite = 356, name = 'Embarcadero', category = 'vehiculos',
      near = { x = -794.64, y = -1510.89, r = 60.0 } },                                -- qbx_garages LSYMC Boathouse
    { sprite = 356, name = 'Embarcadero', category = 'vehiculos',
      near = { x = -277.4, y = 6637.01, r = 60.0 } },                                  -- qbx_garages Paleto Boathouse
    { sprite = 356, name = 'Embarcadero', category = 'vehiculos',
      near = { x = 1299.02, y = 4216.42, r = 60.0 } },                                 -- qbx_garages Millars Boathouse
    { sprite = 356, skip = true },                                                     -- el resto (p. ej. pxd_jobs pescador) ya trae nombre
    { sprite = 326, name = 'Concesionario', category = 'vehiculos',
      near = { x = -45.67, y = -1098.34, r = 60.0 } },                                 -- qbx_vehicleshop Premium Deluxe Motorsport
    { sprite = 326, name = 'Vehículos de trabajo', category = 'trabajos' },           -- qbx_towjob / qbx_truckerjob
    { sprite = 410, name = 'Concesionario náutico', category = 'vehiculos' },         -- qbx_vehicleshop Marina Shop
    { sprite = 251, name = 'Concesionario de aeronaves', category = 'vehiculos' },    -- qbx_vehicleshop Air Shop
    { sprite = 72,  name = 'Taller de tuneo', category = 'vehiculos' },               -- qbx_customs
    { sprite = 446, name = 'Taller mecánico', category = 'trabajos' },                -- qbx_mechanicjob

    -- Trabajos
    { sprite = 513, name = 'Cochera de autobuses', category = 'trabajos' },           -- qbx_busjob
    { sprite = 318, name = 'Basurero municipal', category = 'trabajos' },             -- qbx_garbagejob
    { sprite = 198, name = 'Taxis', category = 'trabajos' },                          -- qbx_taxijob
    { sprite = 477, name = 'Grúas', category = 'trabajos' },                          -- qbx_towjob (Towing HQ)
    { sprite = 479, name = 'Camioneros', category = 'trabajos' },                     -- qbx_truckerjob (Truck Shed)
    { sprite = 365, name = 'Centro de reciclaje', category = 'trabajos' },            -- qbx_recyclejob
    { sprite = 380, name = 'Desguace', category = 'trabajos' },                       -- qbx_scrapyard
    { sprite = 810, name = 'Entrega de chatarra', category = 'trabajos' },            -- qbx_scrapyard
    { sprite = 827, name = 'Viñedo', category = 'trabajos' },                         -- qbx_vineyard
    { sprite = 270, name = 'Bodega del viñedo', category = 'trabajos' },              -- qbx_vineyard
    { sprite = 729, name = 'Zona de buceo', category = 'trabajos', longRange = true }, -- qbx_diving
}

-- Puntos propios. Coordenadas SOLO de configs de recursos (cita la fuente).
-- Vacío por defecto: los recursos de la receta ya crean sus puntos.
-- Ejemplo (no activado: la comisaría de Vinewood está comentada en qbx_police, así
-- que no tiene servicio y un punto en el mapa confundiría):
-- { coords = vec3(637.1, 1.6, 81.8), sprite = 60, colour = 29, name = 'Comisaría de Vinewood' }, -- qbx_police config/shared.lua
Config.points = {}
