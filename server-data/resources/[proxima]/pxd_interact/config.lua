-- Configuración de pxd_interact.
Config = {}


-- Máximo de opciones que se ven a la vez.
Config.maxOptions = 6

-- ── Identidad ────────────────────────────────────────────────────────────────
Config.idPrefix = 'PROX-'
Config.idLength = 4
Config.metadataId = 'pxd_id'         -- clave de metadata de Qbox con el ID público
Config.metadataKnown = 'pxd_known'   -- clave de metadata con los conocidos
Config.maxKnown = 200                -- conocidos por personaje (se olvida al más antiguo)

-- Etiquetas sobre la cabeza
Config.tags = {
    enabled = true,
    distance = 8.0,       -- metros
    unknown = 'Desconocido',
}

-- Presentarse
Config.introduce = {
    distance = 3.0,       -- metros para ofrecerlo
    acceptDistance = 6.0, -- metros para aceptarlo
    cooldown = 10,        -- segundos entre intentos a la misma persona
    timeout = 20,         -- segundos que dura la invitación
}

-- ── Controles de Próxima (docs/28-controles.md) ──────────────────────────────
-- Teclas por defecto; cada jugador las cambia en Ajustes → Asignación de teclas → FiveM.
Config.keys = {
    interact = 'E',        -- interacción contextual
    pickup = 'B',          -- recoger objetos del suelo (solo a pie)
    crouch = 'LCONTROL',   -- agacharse / levantarse (alternancia)
}

-- E · Abrir maletero: directamente el inventario del maletero (ox_inventory), sin menú.
Config.trunk = {
    enabled = true,
    distance = 1.5,        -- metros desde la parte trasera (la misma que usa ox_inventory)
    scanRadius = 6.0,      -- vehículos que se miran alrededor
}

-- B · Recoger: objetos tirados de ox_inventory, directo al inventario, sin abrirlo.
Config.drops = {
    enabled = true,
    radius = 1.6,          -- alcance en el cliente para mostrar el aviso
    serverMaxDist = 3.0,   -- distancia máxima que acepta el servidor
    lockSeconds = 3,       -- bloqueo por objeto mientras se recoge
    cooldownMs = 400,      -- entre dos pulsaciones de B
}

-- Agacharse: usa el state bag «crouch» de qbx_crouch (misma animación y
-- sincronización); si qbx_smallresources no está, lo aplica pxd_interact.
-- Surtidores de ox_fuel (los de su config.lua por defecto): a menos de 3 m, la E es de ox_fuel.
Config.fuelPumps = {
    'prop_gas_pump_old2', 'prop_gas_pump_1a', 'prop_vintage_pump', 'prop_gas_pump_old3',
    'prop_gas_pump_1c', 'prop_gas_pump_1b', 'prop_gas_pump_1d',
}
Config.crouch = {
    enabled = true,
    disableStealth = true, -- anula el sigilo nativo de GTA (control 36) para que Ctrl no lo active
}
