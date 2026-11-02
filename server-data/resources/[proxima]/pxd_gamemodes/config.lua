-- Configuración de pxd_gamemodes. Las arenas reales se diseñan en el juego con el
-- editor de pxd_props (puntos de spawn, checkpoints y zona) y se usan como "layout:<id>".
Config = {}

-- Cada partida vive en su propio routing bucket (mundo aislado). Rango reservado:
-- bucketBase .. bucketBase + maxMatches - 1. El 0 es el mundo RP normal.
Config.bucketBase = 1000
Config.maxMatches = 8

-- Modo de bloqueo de entidades del bucket de cada partida:
-- 'strict' (clientes no crean entidades), 'relaxed', 'inactive'. Ver sv_entityLockdown.
Config.bucketLockdown = 'relaxed'

-- Permisos ACE (ver server-data/permissions.cfg). nil = cualquiera puede.
Config.createAce = nil                   -- crear partidas
Config.adminAce = 'pxd.gamemodes.admin'  -- forzar inicio/fin y borrar partidas de otros

-- Partidas en lobby sin jugadores se borran tras este tiempo (s).
Config.emptyLobbyTimeoutSec = 120

-- Distancia extra (m) que tolera el servidor al validar un checkpoint (latencia).
Config.checkpointTolerance = 8.0

-- Arenas de ejemplo. Las coordenadas salen de los spawnpoints oficiales de
-- cfx-server-data (fivem-map-hipster), así que son puntos válidos sobre el mapa,
-- pero NO están diseñadas como escenario: úsalas solo para probar el flujo.
-- Para arenas jugables crea un layout con /props y usa "layout:<id>".
Config.arenas = {
    prueba = {
        label = 'Arena de prueba (Forum Dr)',
        spawns = {
            { x = -9.96562, y = -1438.54, z = 31.1015, h = 0.0 },
        },
        teamSpawns = {
            { { x = -9.96562, y = -1438.54, z = 31.1015, h = 0.0 } },
            { { x = -9.96562, y = -1438.54, z = 31.1015, h = 180.0 } },
        },
        zone = { x = -9.96562, y = -1438.54, z = 31.1015, radius = 25.0, height = 10.0 },
    },
    colinas = {
        label = 'Colinas de Vinewood (carrera de prueba)',
        grid = {
            { x = 0.916756, y = 528.485, z = 174.628, h = 0.0 },
        },
        checkpoints = {
            { x = -181.615, y = 852.8, z = 232.701 },
            { x = 134.387, y = 1150.31, z = 231.594 },
            { x = 726.14, y = 1196.91, z = 326.262 },
        },
    },
}

-- Arena por defecto de cada modo si al crear no se indica otra.
Config.defaultArena = {
    ffa = 'prueba',
    tdm = 'prueba',
    koth = 'prueba',
    race = 'colinas',
}
