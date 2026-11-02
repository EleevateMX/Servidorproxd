-- Todos contra todos: cada baja suma un punto; gana quien llegue al límite o lidere al acabar el tiempo.
PXD.Modes.register({
    id = 'ffa',
    label = 'Todos contra todos',
    description = 'Cada baja suma. Gana quien llegue primero al límite de puntos.',
    kind = 'combat',
    teams = 0,
    minPlayers = 2,
    maxPlayers = 16,
    durationSec = 600,
    scoreLimit = 20,
    respawnDelaySec = 4,
    scoring = { kill = 1, teamkill = 0, suicide = -1 },
    armour = 50,
    loadout = {
        { weapon = 'WEAPON_PISTOL', ammo = 250 },
        { weapon = 'WEAPON_SMG', ammo = 400 },
        { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 60 },
    },
})
