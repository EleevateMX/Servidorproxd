-- Configuración de pxd_interact.
Config = {}

-- Tecla de interacción por defecto (cada jugador la cambia en Ajustes → Asignación de teclas → FiveM).
Config.key = 'E'

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

-- Objetos tirados de ox_inventory: «E · Recoger».
Config.drops = {
    enabled = true,
    radius = 1.6,
}
