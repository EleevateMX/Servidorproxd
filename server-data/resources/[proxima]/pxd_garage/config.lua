-- Configuración de pxd_garage. docs/44-vehiculos.md
Config = {}

-- ── Zonas ─────────────────────────────────────────────────────────────────
-- Polígonos (x, y) con la altura `z` del suelo. Son los talleres del mapa de GTA V
-- (las mismas ubicaciones que traía qbx_customs).
--   job      = nil  → autoservicio: el dueño paga en el acto.
--   job      = 'mechanic' → taller de jugadores: lo usa un mecánico de servicio y el dueño recibe factura.
--   account  = cuenta de Renewed-Banking que recibe el cobro del autoservicio (nil = el dinero sale de circulación).
Config.zones = {
    { id = 'burton', label = 'Taller de personalización · Burton', z = 38.6,
      points = { { -344.36, -121.92 }, { -319.43, -130.65 }, { -324.77, -147.93 }, { -348.59, -139.1 } } },
    { id = 'aeropuerto', label = 'Taller de personalización · Aeropuerto', z = 13.15,
      points = { { -1147.7, -1990.31 }, { -1171.05, -2013.96 }, { -1158.38, -2026.03 }, { -1139.17, -2007.18 }, { -1144.73, -1992.89 } } },
    { id = 'la_mesa', label = 'Taller de personalización · La Mesa', z = 22.15,
      points = { { 724.93, -1092.04 }, { 738.52, -1094.83 }, { 737.36, -1064.56 }, { 724.14, -1063.71 } } },
    -- Taller de jugadores (trabajo «mechanic» de qbx_core). Añade aquí los polígonos de tus talleres.
    -- { id = 'taller_central', label = 'Taller Central', z = 30.0, job = 'mechanic', account = 'mechanic',
    --   points = { { x1, y1 }, { x2, y2 }, { x3, y3 }, { x4, y4 } } },
}
Config.zoneHeight = 6.0          -- tolerancia vertical (m) alrededor de `z`
Config.zoneMargin = 3.0          -- margen (m) que admite el servidor fuera del polígono
Config.blip = { sprite = 72, colour = 3, scale = 0.75 }
Config.key = 38                  -- E (INPUT_PICKUP) para entrar con el vehículo dentro de la zona

-- ── Quién puede personalizar ──────────────────────────────────────────────
Config.requireOwned = true       -- solo vehículos registrados en qbx_vehicles (player_vehicles)
Config.paymentMethods = { cash = true, bank = true }
Config.cooldown = 1.0            -- segundos entre peticiones del mismo jugador
Config.sessionTimeout = 900      -- segundos que dura abierta una sesión de taller

-- ── Precios ───────────────────────────────────────────────────────────────
-- «base» = precio del modelo en qbx_core (shared/vehicles.lua), acotado. Cada cambio cuesta
-- flat + pct × base. Volver a «de serie» es gratis. El servidor recalcula siempre el total.
Config.pricing = {
    fallbackBase = 40000,        -- modelos sin precio conocido
    minBase = 15000,
    maxBase = 600000,
    round = 10,                  -- los importes se redondean a múltiplos de 10
    groups = {
        body      = { flat = 300, pct = 0.006 },   -- carrocería
        interior  = { flat = 200, pct = 0.004 },
        engine    = { flat = 250, pct = 0.004 },   -- piezas visibles del motor
        paint     = { flat = 450, pct = 0.007 },
        wheels    = { flat = 500, pct = 0.010 },
        lights    = { flat = 350, pct = 0.004 },
        details   = { flat = 200, pct = 0.003 },
    },
    -- Rendimiento: fracción de «base» acumulada por nivel (índice 1 = nivel 0 del juego).
    -- Se cobra la diferencia entre el nivel nuevo y el que ya tenía.
    performance = {
        modEngine       = { 0.04, 0.09, 0.15, 0.22, 0.30 },
        modBrakes       = { 0.02, 0.045, 0.075, 0.11 },
        modTransmission = { 0.03, 0.065, 0.105, 0.15 },
        modSuspension   = { 0.015, 0.03, 0.05, 0.075, 0.10 },
        modArmor        = { 0.05, 0.11, 0.18, 0.26, 0.35 },
        modTurbo        = { 0.12 },                 -- interruptor
    },
    mechanicFactor = 0.85,       -- en un taller de jugadores las piezas salen un 15 % más baratas
}

-- ── Tuning de rendimiento: quién puede montar cada nivel ───────────────────
-- npcMax: nivel máximo en autoservicio (-1 = no disponible; para el turbo, true/false).
-- mechLevel[nivel + 1]: nivel de mecánico necesario en un taller de jugadores.
Config.performance = {
    modEngine       = { label = 'Motor',       npcMax = 1,  mechLevel = { 1, 1, 2, 3, 4 } },
    modBrakes       = { label = 'Frenos',      npcMax = 1,  mechLevel = { 1, 1, 2, 3 } },
    modTransmission = { label = 'Transmisión', npcMax = 1,  mechLevel = { 1, 1, 2, 3 } },
    modSuspension   = { label = 'Suspensión',  npcMax = 2,  mechLevel = { 1, 1, 1, 2, 3 } },
    modArmor        = { label = 'Blindaje',    npcMax = -1, mechLevel = { 3, 4, 5, 5, 6 } },
    modTurbo        = { label = 'Turbo',       npcMax = false, mechLevel = { 3 } },
}

-- ── Mecánicos por nivel ───────────────────────────────────────────────────
Config.mechanic = {
    jobs = { mechanic = true },            -- trabajos de qbx_core que cuentan como mecánico
    -- Experiencia necesaria para cada nivel (el nivel 1 se tiene desde el principio).
    levels = {
        { xp = 0,    name = 'Aprendiz' },
        { xp = 150,  name = 'Ayudante' },
        { xp = 500,  name = 'Mecánico' },
        { xp = 1200, name = 'Oficial' },
        { xp = 2600, name = 'Especialista' },
        { xp = 5000, name = 'Maestro' },
    },
    xp = {
        repairPart = 12,        -- reparar una pieza en el banco de trabajo (qbx_mechanicjob)
        repairCooldown = 600,   -- segundos antes de volver a contar la misma pieza del mismo vehículo
        tuningBase = 15,        -- por trabajo de personalización cobrado
        tuningPer1000 = 2,      -- extra por cada $1000 del trabajo
        tuningMax = 80,         -- tope por trabajo
        dailyCap = 600,         -- tope diario de experiencia
    },
    homeServiceLevel = 4,       -- futuro: asistencia a domicilio (aún no implementada)
}

-- Escalas de las barras de estadísticas (valores de los natives de GTA).
Config.stats = {
    speed = 70.0,        -- m/s (GetVehicleEstimatedMaxSpeed)
    acceleration = 0.6,  -- GetVehicleAcceleration
    braking = 1.6,       -- GetVehicleMaxBraking
    traction = 3.5,      -- GetVehicleMaxTraction
}

-- Límites de validación del servidor (el cliente cuenta las opciones reales del modelo).
Config.limits = { mod = 120, wheels = 300, colour = 160, plateIndex = 12, windowTint = 6, xenon = 12, livery = 60, wheelType = 12, paintType = 6 }

Config.ace = { manage = 'pxd.garage.manage' }   -- consultar y corregir la experiencia de mecánicos
