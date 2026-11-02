-- Rey de la colina: el equipo que controla la zona en solitario suma puntos cada segundo.
-- Si hay jugadores de dos equipos dentro, la zona queda disputada y nadie puntúa.
local Util = PXD.Util

local function inZone(zone, pos)
    if not pos then return false end
    if Util.dist2d(zone, pos) > zone.radius then return false end
    return math.abs((pos.z or 0) - (zone.z or 0)) <= (zone.height or 10.0)
end

PXD.Modes.register({
    id = 'koth',
    label = 'Rey de la colina',
    description = 'Controla la zona con tu equipo para sumar puntos.',
    kind = 'zone',
    teams = 2,
    minPlayers = 2,
    maxPlayers = 20,
    durationSec = 480,
    scoreLimit = 150,
    respawnDelaySec = 5,
    pointsPerSecond = 1,
    scoring = { kill = 0, teamkill = 0, suicide = 0 },
    armour = 100,
    loadout = {
        { weapon = 'WEAPON_PISTOL', ammo = 250 },
        { weapon = 'WEAPON_ASSAULTRIFLE', ammo = 500 },
    },
    onTick = function(match, ctx, now, events)
        local zone = match.arena.zone
        local present = {}
        for pid, p in pairs(match.players) do
            if p.team and inZone(zone, ctx.positions and ctx.positions[pid]) then
                present[p.team] = true
            end
        end
        local owner, teamsInside = 0, 0
        for t in pairs(present) do teamsInside = teamsInside + 1; owner = t end
        if teamsInside > 1 then owner = -1 end
        match.zoneOwner = owner
        if owner > 0 then
            local dt = now - (match.lastTickAt or now)
            if dt > 0 then
                match:addTeamScore(owner, dt * match.mode.pointsPerSecond, now, events)
            end
        end
    end,
})
