-- Configuración de pxd_jobs: trabajos legales que Qbox no trae.
-- Coordenadas en metros del mapa de GTA V. Las marcadas «revisar en el juego» son
-- aproximadas: el staff puede añadir puntos donde esté con /pxd_jobpunto (ver docs/15).
Config = {}

local function p(x, y, z) return { x = x, y = y, z = z } end

-- Si es true, para trabajar hay que tener ese trabajo como principal en Qbox
-- (se consigue en el punto de alta de cada trabajo). Sin Qbox, basta con darse de alta.
Config.requireJob = true

-- Tope de lo que se puede ganar en una hora con estos trabajos (anti-abuso).
Config.maxEarningsPerHour = 6000

-- Permiso para añadir puntos en el juego.
Config.ace = 'pxd.jobs.edit'
Config.dataFile = 'data/points.json'

-- Rango único de Qbox para los trabajos propios (sin sueldo fijo: se cobra por tarea).
local grades = { [0] = { name = 'Trabajador', payment = 0 } }

Config.jobs = {
    miner = {
        label = 'Minero',
        kind = 'gather',
        grades = grades,
        blip = { sprite = 306, color = 5 },          -- radar_cratedrop
        signOn = p(2944.5, 2746.6, 43.3),          -- cantera Davis Quartz (revisar en el juego)
        work = {
            label = 'Picar roca',
            scenario = 'WORLD_HUMAN_CONST_DRILL',
            seconds = 8, radius = 3.0, cooldown = 120, yield = { 1, 2 },
            points = {                              -- revisar en el juego
                p(2952.6, 2782.0, 41.2), p(2938.6, 2771.3, 39.7), p(2969.0, 2775.1, 38.5),
                p(2926.4, 2794.6, 40.6), p(2959.3, 2810.8, 42.4),
            },
        },
        sell = { label = 'Vender mineral', point = p(1109.0, -2008.0, 30.9), radius = 4.0, price = 35 }, -- fundición (revisar)
        maxCarry = 20, unit = 'mineral',
    },
    lumberjack = {
        label = 'Leñador',
        kind = 'gather',
        grades = grades,
        blip = { sprite = 141, color = 25 },         -- radar_hunting
        signOn = p(-567.4, 5253.2, 70.5),          -- aserradero de Paleto (revisar)
        work = {
            label = 'Talar árbol',
            scenario = 'WORLD_HUMAN_HAMMERING',
            seconds = 9, radius = 3.0, cooldown = 150, yield = { 1, 2 },
            points = {                              -- revisar en el juego
                p(-532.3, 5300.6, 76.1), p(-505.2, 5281.4, 80.6), p(-598.7, 5307.2, 70.3),
                p(-617.9, 5283.6, 69.1), p(-547.1, 5340.8, 74.9),
            },
        },
        sell = { label = 'Vender madera', point = p(-581.0, 5328.0, 70.2), radius = 4.0, price = 30 },
        maxCarry = 20, unit = 'tronco',
    },
    fisher = {
        label = 'Pescador',
        kind = 'gather',
        grades = grades,
        blip = { sprite = 356, color = 3 },          -- radar_dock
        signOn = p(-1847.7, -1196.2, 14.3),        -- muelle de Del Perro (revisar)
        work = {
            label = 'Pescar',
            scenario = 'WORLD_HUMAN_STAND_FISHING',
            seconds = 12, radius = 2.5, cooldown = 90, yield = { 1, 1 },
            points = {                              -- revisar en el juego
                p(-1838.4, -1268.2, 8.6), p(-1848.6, -1254.7, 8.6),
                p(-1862.3, -1240.3, 8.6), p(-1826.1, -1281.4, 8.6),
            },
        },
        sell = { label = 'Vender pescado', point = p(-1816.0, -1193.0, 14.3), radius = 4.0, price = 45 },
        maxCarry = 15, unit = 'pescado',
    },
    courier = {
        label = 'Repartidor',
        kind = 'delivery',
        grades = grades,
        blip = { sprite = 501, color = 47 },         -- radar_package
        signOn = p(-440.6, -2795.6, 7.3),          -- depósito (revisar en el juego)
        depot = { label = 'Recoger paquete', point = p(-436.0, -2790.0, 6.0), radius = 4.0 },
        deliver = {
            label = 'Entregar paquete',
            scenario = 'WORLD_HUMAN_CLIPBOARD',
            radius = 6.0,
            base = 120, perKm = 60,
            maxSpeed = 45,       -- m/s: más rápido que esto se considera trampa (teletransporte)
            minSeconds = 20,
            -- Calles de la ruta de basura oficial de Qbox (qbx_garbagejob), verificadas.
            drops = {
                p(-168.07, -1662.8, 33.31), p(118.06, -1943.96, 20.43), p(297.94, -2018.26, 20.49),
                p(424.98, -1523.57, 29.28), p(488.49, -1284.1, 29.24), p(307.47, -1033.6, 29.03),
                p(239.19, -681.5, 37.15), p(543.51, -204.41, 54.16), p(268.72, -25.92, 73.36),
                p(267.03, 276.01, 105.54), p(21.65, 375.44, 112.67), p(-546.9, 286.57, 82.85),
                p(-683.23, -169.62, 37.74), p(-771.02, -218.06, 37.05), p(-1057.06, -515.45, 35.83),
            },
        },
    },
}
