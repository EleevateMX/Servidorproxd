-- Configuración de pxd_ui (interfaz común de Próxima RP). docs/43-interfaz-y-hud.md
Config = {}

-- Avisos
Config.notify = {
    position = 'top-right',   -- esquina por defecto si el emisor no indica otra
    duration = 3000,          -- ms por defecto
    minDuration = 1000,
    maxDuration = 30000,
}

-- Indicación contextual (Text UI)
Config.textUi = { position = 'right-center' }

-- Progreso propio (cuando ox_lib no está arrancado). Tecla para cancelar si canCancel = true.
Config.progress = { cancelKey = 'x' }
