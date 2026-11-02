-- Registro de modos de juego. Un modo es una tabla de datos + ganchos opcionales.
-- Para añadir uno nuevo: crea shared/modes/<id>.lua que llame a PXD.Modes.register{...}
-- y añádelo a fxmanifest.lua (shared_scripts). Ver docs/03-modos-de-juego.md.
PXD = PXD or {}
local Modes = { registry = {}, order = {} }
PXD.Modes = Modes

local KINDS = { combat = true, zone = true, race = true }

local DEFAULTS = {
    teams = 0,                 -- 0 = individual; 2+ = equipos
    minPlayers = 1,
    maxPlayers = 16,
    durationSec = 600,         -- 0 = sin límite de tiempo
    scoreLimit = 0,            -- 0 = sin límite de puntos
    countdownSec = 10,
    resultsSec = 12,
    respawnDelaySec = 5,
    allowJoinInProgress = true,
    scoring = { kill = 1, teamkill = -1, suicide = -1 },
    loadout = {},
    armour = 0,
}

--- Valida y registra un modo. Lanza error con un mensaje claro si falta algo.
function Modes.register(def)
    assert(type(def) == 'table', 'modo: se esperaba una tabla')
    assert(type(def.id) == 'string' and def.id:match('^[a-z0-9_]+$'), 'modo: id inválido (a-z, 0-9, _)')
    assert(not Modes.registry[def.id], ('modo: id duplicado "%s"'):format(def.id))
    assert(type(def.label) == 'string' and #def.label > 0, ('modo %s: falta label'):format(def.id))
    assert(KINDS[def.kind], ('modo %s: kind debe ser combat, zone o race'):format(def.id))

    for k, v in pairs(DEFAULTS) do
        if def[k] == nil then def[k] = PXD.Util.deepCopy(v) end
    end

    assert(def.minPlayers >= 1 and def.maxPlayers >= def.minPlayers,
        ('modo %s: minPlayers/maxPlayers incoherentes'):format(def.id))
    assert(def.teams == 0 or def.teams >= 2, ('modo %s: teams debe ser 0 o >= 2'):format(def.id))
    if def.kind == 'zone' then
        assert(def.teams >= 2, ('modo %s: los modos de zona requieren equipos'):format(def.id))
    end
    if def.kind == 'race' then
        assert(type(def.laps) == 'number' and def.laps >= 1, ('modo %s: laps >= 1'):format(def.id))
    end
    assert(def.durationSec > 0 or def.scoreLimit > 0 or def.kind == 'race',
        ('modo %s: necesita durationSec o scoreLimit para poder terminar'):format(def.id))

    Modes.registry[def.id] = def
    Modes.order[#Modes.order + 1] = def.id
    return def
end

function Modes.get(id)
    return Modes.registry[id]
end

--- Lista resumida (segura para enviar al cliente).
function Modes.list()
    local out = {}
    for _, id in ipairs(Modes.order) do
        local m = Modes.registry[id]
        out[#out + 1] = {
            id = m.id, label = m.label, description = m.description, kind = m.kind,
            teams = m.teams, minPlayers = m.minPlayers, maxPlayers = m.maxPlayers,
            durationSec = m.durationSec, scoreLimit = m.scoreLimit,
        }
    end
    return out
end

--- Comprueba que una arena tiene lo que el modo necesita.
function Modes.validateArena(mode, arena)
    if type(arena) ~= 'table' then return false, 'arena inexistente' end
    if mode.kind == 'race' then
        if type(arena.checkpoints) ~= 'table' or #arena.checkpoints < 2 then
            return false, 'la arena necesita al menos 2 checkpoints'
        end
        if type(arena.grid) ~= 'table' or #arena.grid < 1 then
            return false, 'la arena necesita posiciones de salida (grid)'
        end
        return true
    end
    if mode.teams >= 2 then
        for t = 1, mode.teams do
            local s = arena.teamSpawns and arena.teamSpawns[t]
            if type(s) ~= 'table' or #s < 1 then
                return false, ('faltan spawns del equipo %d'):format(t)
            end
        end
    elseif type(arena.spawns) ~= 'table' or #arena.spawns < 1 then
        return false, 'la arena necesita spawns'
    end
    if mode.kind == 'zone' then
        local z = arena.zone
        if type(z) ~= 'table' or not z.radius then return false, 'la arena necesita zone {x,y,z,radius}' end
    end
    return true
end

return Modes
