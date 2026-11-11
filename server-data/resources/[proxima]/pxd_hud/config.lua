-- Configuración de pxd_hud (interfaz en pantalla de Próxima RP).
Config = {}

Config.speedUnit = 'kmh'          -- 'kmh' o 'mph'
Config.minimapOnFoot = true       -- minimapa también a pie (false: solo en vehículo)
Config.tickMs = 250               -- cada cuánto se leen los datos del jugador
Config.fastMsFoot = 150           -- brújula a pie
Config.fastMsVehicle = 80         -- velocidad, RPM, marcha y brújula en vehículo
Config.settingsKey = 'pxd_hud:settings'   -- KVP con los ajustes del jugador
Config.lowFuel = 20               -- aviso de combustible bajo (%)

-- Avisos de las barras (en %): a partir de aquí la barra cambia de color.
Config.warn = { hunger = 25, thirst = 25, health = 35, critical = 10 }

-- Estrés (mismo comportamiento que qbx_hud, para no romper qbx_vehiclekeys, qbx_medical…).
Config.stress = {
    enabled = true,
    -- Límites del servidor para hud:server:GainStress / RelieveStress (eventos de red
    -- que cualquier cliente puede lanzar). Compatibles con lo que hacen qbx_medical
    -- (alivia 100 al curarte), qbx_ambulancejob (12-24 por analgésico),
    -- qbx_consumables (15-18) y qbx_vehiclekeys (gana 1-4).
    limits = {
        relieve = { maxPerCall = 100, cooldown = 2, window = 120, maxPerWindow = 100 },
        gain    = { maxPerCall = 10,  cooldown = 0, window = 60,  maxPerWindow = 40 },
    },
    disableForLEO = true,           -- los trabajos de tipo 'leo' no acumulan estrés
    chance = 0.1,                   -- probabilidad de ganar estrés por disparo (0-1)
    minForShaking = 50,             -- a partir de aquí, visión borrosa de vez en cuando
    minSpeed = 180,                 -- velocidad (km/h o mph según speedUnit) que da estrés sin cinturón
    minSpeedBuckled = 1000,         -- con cinturón (1000 = nunca)
    whitelistedWeapons = { 'weapon_petrolcan', 'weapon_hazardcan', 'weapon_fireextinguisher' }, -- no dan estrés
    blurIntensity = {
        { min = 50, max = 60, intensity = 1500 },
        { min = 60, max = 70, intensity = 2000 },
        { min = 70, max = 80, intensity = 2500 },
        { min = 80, max = 90, intensity = 2700 },
        { min = 90, max = 100, intensity = 3000 },
    },
    effectInterval = {
        { min = 50, max = 60, timeout = 55000 },
        { min = 60, max = 70, timeout = 45000 },
        { min = 70, max = 80, timeout = 35000 },
        { min = 80, max = 90, timeout = 25000 },
        { min = 90, max = 100, timeout = 17000 },
    },
}
