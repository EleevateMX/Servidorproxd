-- Carrera de checkpoints: el servidor valida cada checkpoint por distancia.
-- El último checkpoint de la lista es la meta; con laps > 1 el circuito se repite.
PXD.Modes.register({
    id = 'race',
    label = 'Carrera',
    description = 'Checkpoints en orden. El primero en cruzar la meta gana.',
    kind = 'race',
    teams = 0,
    minPlayers = 1,
    maxPlayers = 12,
    durationSec = 900,
    laps = 2,
    finishGraceSec = 45,         -- tiempo que tienen los demás tras el primero
    checkpointRadius = 12.0,     -- radio visual y de validación (m)
    vehicle = 'sultan',
    allowJoinInProgress = false,
    respawnDelaySec = 3,
    scoring = { kill = 0, teamkill = 0, suicide = 0 },
})
