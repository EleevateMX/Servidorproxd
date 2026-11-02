-- Deathmatch por equipos: las bajas suman al equipo; matar a un compañero resta.
PXD.Modes.register({
    id = 'tdm',
    label = 'Deathmatch por equipos',
    description = 'Dos equipos. Las bajas suman al marcador del equipo.',
    kind = 'combat',
    teams = 2,
    minPlayers = 2,
    maxPlayers = 20,
    durationSec = 600,
    scoreLimit = 40,
    respawnDelaySec = 5,
    scoring = { kill = 1, teamkill = -1, suicide = -1 },
    armour = 100,
    loadout = {
        { weapon = 'WEAPON_PISTOL', ammo = 250 },
        { weapon = 'WEAPON_CARBINERIFLE', ammo = 500 },
    },
})
