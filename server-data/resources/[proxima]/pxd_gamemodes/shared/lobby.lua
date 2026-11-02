-- Gestor de partidas: crea partidas, asigna un routing bucket propio a cada una
-- y lleva qué jugador está en qué partida. Lógica pura y testeable.
PXD = PXD or {}
local Lobby = {}
Lobby.__index = Lobby
PXD.Lobby = Lobby

function Lobby.new(opts)
    opts = opts or {}
    return setmetatable({
        bucketBase = opts.bucketBase or 1000,
        maxMatches = opts.maxMatches or 10,
        nextId = 1,
        matches = {},        -- [id] = Match
        playerMatch = {},    -- [playerId] = matchId
        usedBuckets = {},    -- [bucket] = matchId
    }, Lobby)
end

function Lobby:_allocBucket()
    for i = 0, self.maxMatches - 1 do
        local b = self.bucketBase + i
        if not self.usedBuckets[b] then return b end
    end
    return nil
end

function Lobby:count()
    return PXD.Util.count(self.matches)
end

--- Crea una partida. `arena` ya resuelta (ver server/arenas.lua).
function Lobby:create(modeId, arena, hostId, now)
    local mode = PXD.Modes.get(modeId)
    if not mode then return nil, ('Modo desconocido: %s'):format(tostring(modeId)) end
    local ok, err = PXD.Modes.validateArena(mode, arena)
    if not ok then return nil, ('Arena no válida para %s: %s'):format(mode.label, err) end
    if self:count() >= self.maxMatches then return nil, 'No hay hueco para más partidas.' end
    local bucket = self:_allocBucket()
    if not bucket then return nil, 'No quedan routing buckets libres.' end

    local id = self.nextId
    self.nextId = id + 1
    local match = PXD.Match.new({ id = id, mode = mode, arena = arena, bucket = bucket, now = now })
    self.matches[id] = match
    self.usedBuckets[bucket] = id
    return match
end

function Lobby:get(id)
    return self.matches[id]
end

function Lobby:findByPlayer(playerId)
    local id = self.playerMatch[playerId]
    return id and self.matches[id] or nil
end

--- Une al jugador; si ya estaba en otra partida, la abandona antes.
--- Devuelve ok, err|player, partidaAbandonada
function Lobby:join(matchId, playerId, name, now)
    local match = self.matches[matchId]
    if not match then return false, 'Esa partida no existe.' end
    local previous = self:findByPlayer(playerId)
    if previous == match then return false, 'Ya estás en esta partida.' end
    local ok, res = match:join(playerId, name, now)
    if not ok then return false, res end
    if previous then
        previous:leave(playerId)
    end
    self.playerMatch[playerId] = matchId
    return true, res, previous
end

--- Saca al jugador de su partida. Devuelve la partida (o nil).
function Lobby:leave(playerId)
    local match = self:findByPlayer(playerId)
    self.playerMatch[playerId] = nil
    if not match then return nil end
    match:leave(playerId)
    return match
end

--- Elimina la partida y libera su bucket. Devuelve los ids de sus jugadores.
function Lobby:remove(matchId)
    local match = self.matches[matchId]
    if not match then return {} end
    local ids = {}
    for pid in pairs(match.players) do
        ids[#ids + 1] = pid
        if self.playerMatch[pid] == matchId then self.playerMatch[pid] = nil end
    end
    self.matches[matchId] = nil
    self.usedBuckets[match.bucket] = nil
    return ids
end

function Lobby:list()
    local out = {}
    for _, m in pairs(self.matches) do out[#out + 1] = m:summary() end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

return Lobby
