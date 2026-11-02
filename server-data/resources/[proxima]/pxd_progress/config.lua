-- Configuración de pxd_progress (progreso de cada personaje).
-- Las fechas van en UTC con formato 'AAAA-MM-DDTHH:MM:SSZ' (o solo 'AAAA-MM-DD').
Config = {}

-- Zona horaria del «día natural» (cuándo empieza un día nuevo para las recompensas
-- y el «tiempo jugado hoy»), en horas respecto a UTC. -6 = Ciudad de México.
-- Cámbialo si tu comunidad vive en otra zona.
Config.utcOffsetHours = -6

-- Clave de metadata de Qbox donde se guarda el progreso de cada personaje.
Config.metadataKey = 'pxd_progress'
-- Sin Qbox (pruebas): se guarda aquí, por licencia.
Config.dataFile = 'data/progress.json'
-- Plus es por cuenta (licencia), no por personaje: { [licencia] = vence (epoch UTC) }.
Config.plusFile = 'data/plus.json'

-- Niveles: para pasar del nivel N al N+1 hacen falta base + step * (N - 1) XP.
Config.levels = { base = 100, step = 25, max = 100 }

-- XP que da cada acción registrada con Track(src, clave, cantidad), por unidad.
Config.xp = {
    playtime_min = 1,   -- cada minuto jugado
    duty_min = 1,       -- cada minuto de servicio en un trabajo (además del anterior)
    job_task = 10,      -- cada tarea de trabajo (scripts de trabajos)
    gm_play = 5,        -- cada partida jugada en Modos de juego
    gm_win = 25,        -- cada partida ganada
    event_join = 50,    -- cada evento al que te unes
}

-- Claves que acepta Track. Otras se ignoran.
Config.trackKeys = { playtime_min = true, duty_min = true, job_task = true, gm_play = true, gm_win = true, event_join = true }
-- Máximo por llamada a Track (evita errores de otros scripts).
Config.maxTrackAmount = 100

-- Trabajos que no cuentan como «de servicio» aunque tengan onduty.
Config.dutyIgnoredJobs = { unemployed = true }

-- ── Recompensas diarias (pista Gratis + pista Plus) ──────────────────────
-- Una temporada global. Cada día natural se puede reclamar UN día de la pista,
-- y solo si se cumplió la misión del día.
Config.daily = {
    season = {
        id = 't1',
        name = 'Temporada 1 · Primeras luces',
        startsAt = '2026-11-01T06:00:00Z',
        endsAt = '2026-12-01T06:00:00Z',
    },
    -- Por cada día natural que pasa sin reclamar, se retrocede un día en la pista.
    missedDayPenalty = true,

    -- Misión del día: rota según el día. «any» = basta con cumplir una de las opciones.
    missions = {
        { label = 'Juega 60 minutos en la ciudad', any = { { key = 'playtime_min', goal = 60 } } },
        { label = 'Juega 45 minutos o haz 20 minutos de servicio', any = { { key = 'playtime_min', goal = 45 }, { key = 'duty_min', goal = 20 } } },
        { label = 'Haz 30 minutos de servicio o juega 90 minutos', any = { { key = 'duty_min', goal = 30 }, { key = 'playtime_min', goal = 90 } } },
        { label = 'Juega una partida en Modos de juego o juega 60 minutos', any = { { key = 'gm_play', goal = 1 }, { key = 'playtime_min', goal = 60 } } },
    },

    -- Recompensas. Tipos: money (account 'cash' | 'bank'), item (nombre de ox_inventory), xp.
    -- La pista Plus la decide el dueño del servidor. Reglas de Tebex/Cfx: nada que dé una
    -- ventaja fuerte pagando; por eso los valores son modestos (comida, poco dinero, XP).
    days = {
        { free = { type = 'money', account = 'cash', amount = 500 },  plus = { type = 'money', account = 'cash', amount = 1000 } },
        { free = { type = 'item', name = 'water', count = 3 },        plus = { type = 'item', name = 'sprunk', count = 3 } },
        { free = { type = 'xp', amount = 50 },                        plus = { type = 'xp', amount = 100 } },
        { free = { type = 'item', name = 'burger', count = 3 },       plus = { type = 'item', name = 'burger', count = 5 } },
        { free = { type = 'money', account = 'bank', amount = 1000 }, plus = { type = 'money', account = 'bank', amount = 2000 } },
        { free = { type = 'item', name = 'bandage', count = 2 },      plus = { type = 'item', name = 'bandage', count = 4 } },
        { free = { type = 'xp', amount = 150 },                       plus = { type = 'xp', amount = 250 } },
        { free = { type = 'money', account = 'cash', amount = 750 },  plus = { type = 'money', account = 'cash', amount = 1500 } },
        { free = { type = 'item', name = 'water', count = 5 },        plus = { type = 'item', name = 'sprunk', count = 5 } },
        { free = { type = 'xp', amount = 75 },                        plus = { type = 'xp', amount = 150 } },
        { free = { type = 'money', account = 'bank', amount = 1500 }, plus = { type = 'money', account = 'bank', amount = 3000 } },
        { free = { type = 'item', name = 'burger', count = 4 },       plus = { type = 'item', name = 'burger', count = 6 } },
        { free = { type = 'xp', amount = 100 },                       plus = { type = 'xp', amount = 200 } },
        { free = { type = 'money', account = 'cash', amount = 2000 }, plus = { type = 'money', account = 'cash', amount = 3000 } },
    },
}

-- ── Logros ──────────────────────────────────────────────────────────────
-- key: contador de Track (de toda la vida del personaje) o uno derivado:
--   level (nivel), playtime_h (horas jugadas), days_claimed (días de la pista reclamados).
-- Categoría «limited»: solo cuenta lo que hagas entre startsAt y endsAt (y solo se ve en
-- esas fechas). Recompensa: rewardXp (y opcionalmente rewardMoney = { account, amount }).
Config.achievements = {
    {
        id = 'bienvenida', label = 'Bienvenida', icon = 'star',
        description = 'Tus primeros pasos en Próxima RP.',
        items = {
            { id = 'b_hora', label = 'Recién llegado', description = 'Juega tu primera hora.', key = 'playtime_h', goal = 1, rewardXp = 50 },
            { id = 'b_nivel2', label = 'Subiendo', description = 'Llega al nivel 2.', key = 'level', goal = 2, rewardXp = 50 },
            { id = 'b_diaria', label = 'Constante', description = 'Reclama tu primera recompensa diaria.', key = 'days_claimed', goal = 1, rewardXp = 50 },
            { id = 'b_servicio', label = 'A trabajar', description = 'Haz 10 minutos de servicio en un trabajo.', key = 'duty_min', goal = 10, rewardXp = 75 },
        },
    },
    {
        id = 'trabajo', label = 'Trabajo', icon = 'briefcase',
        description = 'Hazte un nombre en tu oficio.',
        items = {
            { id = 't_1h', label = 'Turno completo', description = '1 hora de servicio.', key = 'duty_min', goal = 60, rewardXp = 100 },
            { id = 't_10h', label = 'Veterano', description = '10 horas de servicio.', key = 'duty_min', goal = 600, rewardXp = 300 },
            { id = 't_tareas10', label = 'Manos a la obra', description = 'Completa 10 tareas de trabajo.', key = 'job_task', goal = 10, rewardXp = 100 },
            { id = 't_tareas100', label = 'Imparable', description = 'Completa 100 tareas de trabajo.', key = 'job_task', goal = 100, rewardXp = 400 },
        },
    },
    {
        id = 'modos', label = 'Modos de juego', icon = 'gamepad',
        description = 'Compite en las partidas de la ciudad.',
        items = {
            { id = 'g_jugar1', label = 'Primera partida', description = 'Juega una partida.', key = 'gm_play', goal = 1, rewardXp = 50 },
            { id = 'g_jugar25', label = 'Habitual', description = 'Juega 25 partidas.', key = 'gm_play', goal = 25, rewardXp = 200 },
            { id = 'g_ganar1', label = 'Primera victoria', description = 'Gana una partida.', key = 'gm_win', goal = 1, rewardXp = 100 },
            { id = 'g_ganar10', label = 'Campeón', description = 'Gana 10 partidas.', key = 'gm_win', goal = 10, rewardXp = 300 },
        },
    },
    {
        id = 'constancia', label = 'Constancia', icon = 'calendar',
        description = 'Vuelve a la ciudad día tras día.',
        items = {
            { id = 'c_7', label = 'Una semana', description = 'Reclama 7 días de la pista.', key = 'days_claimed', goal = 7, rewardXp = 150 },
            { id = 'c_28', label = 'Temporada completa', description = 'Reclama 28 días de la pista.', key = 'days_claimed', goal = 28, rewardXp = 500 },
            { id = 'c_24h', label = 'Un día entero', description = 'Juega 24 horas.', key = 'playtime_h', goal = 24, rewardXp = 300 },
            { id = 'c_100h', label = 'Vecino de siempre', description = 'Juega 100 horas.', key = 'playtime_h', goal = 100, rewardXp = 1000 },
        },
    },
    -- Ejemplo de categoría limitada (evento). Cambia las fechas y el contenido para cada evento.
    {
        id = 'lanzamiento', label = 'Noche de lanzamiento', icon = 'sparkles', limited = true,
        startsAt = '2026-11-01T06:00:00Z', endsAt = '2026-11-30T06:00:00Z',
        description = 'Logros especiales del primer mes de Próxima RP.',
        image = nil, -- URL opcional de una imagen (https)
        items = {
            { id = 'l_evento', label = 'Estuve ahí', description = 'Únete a un evento de la ciudad.', key = 'event_join', goal = 1, rewardXp = 150 },
            { id = 'l_horas', label = 'Noches largas', description = 'Juega 10 horas durante el evento.', key = 'playtime_min', goal = 600, rewardXp = 300 },
        },
    },
}
