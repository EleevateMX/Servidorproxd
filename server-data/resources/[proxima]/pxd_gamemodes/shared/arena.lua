-- Convierte los puntos de un layout de pxd_props en una arena para los modos.
-- Tipos de punto que entiende: spawn, team1, team2, grid, checkpoint, zone.
PXD = PXD or {}
local Arena = {}
PXD.Arena = Arena

local function pt(p)
    return { x = p.x, y = p.y, z = p.z, h = p.h or 0.0 }
end

function Arena.fromLayout(layout)
    if type(layout) ~= 'table' then return nil end
    local arena = {
        id = 'layout:' .. tostring(layout.id),
        label = layout.name or tostring(layout.id),
        layout = layout.id,
        spawns = {}, teamSpawns = { {}, {} }, grid = {}, checkpoints = {},
    }
    local cps = {}
    for _, p in ipairs(layout.points or {}) do
        if p.kind == 'spawn' then
            arena.spawns[#arena.spawns + 1] = pt(p)
        elseif p.kind == 'team1' then
            arena.teamSpawns[1][#arena.teamSpawns[1] + 1] = pt(p)
        elseif p.kind == 'team2' then
            arena.teamSpawns[2][#arena.teamSpawns[2] + 1] = pt(p)
        elseif p.kind == 'grid' then
            arena.grid[#arena.grid + 1] = pt(p)
        elseif p.kind == 'checkpoint' then
            cps[#cps + 1] = p
        elseif p.kind == 'zone' then
            arena.zone = { x = p.x, y = p.y, z = p.z, radius = p.radius or 20.0, height = p.height or 10.0 }
        end
    end
    -- Los checkpoints se ordenan por `order`; en empate, por orden de creación.
    for i, p in ipairs(cps) do p._i = i end
    table.sort(cps, function(a, b)
        local oa, ob = a.order or a._i, b.order or b._i
        if oa ~= ob then return oa < ob end
        return a._i < b._i
    end)
    for _, p in ipairs(cps) do
        arena.checkpoints[#arena.checkpoints + 1] = { x = p.x, y = p.y, z = p.z }
    end
    -- Sin spawns individuales: se usan los de equipo o la parrilla de salida.
    if #arena.spawns == 0 then
        for _, list in ipairs({ arena.teamSpawns[1], arena.teamSpawns[2], arena.grid }) do
            for _, p in ipairs(list) do arena.spawns[#arena.spawns + 1] = p end
        end
    end
    return arena
end

--- Copia una arena de Config añadiéndole id.
function Arena.fromConfig(id, def)
    if type(def) ~= 'table' then return nil end
    local arena = PXD.Util.deepCopy(def)
    arena.id = id
    arena.label = arena.label or id
    return arena
end

--- Elige un spawn para un jugador según su equipo (rotando para repartir).
function Arena.pickSpawn(arena, team, seed)
    local list = (team and arena.teamSpawns and arena.teamSpawns[team]) or arena.spawns
    if not list or #list == 0 then list = arena.grid or {} end
    if #list == 0 then return nil end
    return list[((seed or 1) - 1) % #list + 1]
end

return Arena
