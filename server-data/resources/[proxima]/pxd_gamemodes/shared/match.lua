-- Máquina de estados de una partida. Lógica pura: no llama natives, recibe `now`
-- (segundos) desde fuera. El servidor es la única autoridad sobre puntos y estados.
--
--   lobby ──start()──▶ countdown ──(tiempo)──▶ running ──(tiempo/puntos/meta)──▶ ended
PXD = PXD or {}
local Util = PXD.Util
local Match = {}
Match.__index = Match
PXD.Match = Match

local STATE = { LOBBY = 'lobby', COUNTDOWN = 'countdown', RUNNING = 'running', ENDED = 'ended' }
Match.STATE = STATE

function Match.new(o)
    assert(o and o.id and o.mode and o.arena, 'Match.new: faltan id, mode o arena')
    local self = setmetatable({
        id = o.id,
        mode = o.mode,
        arena = o.arena,
        bucket = o.bucket,
        host = o.host,
        state = STATE.LOBBY,
        players = {},
        teamScores = {},
        createdAt = o.now or 0,
        seq = 0,
        finishOrder = {},
        zoneOwner = 0,      -- KOTH: 0 libre, -1 disputada, n equipo
    }, Match)
    for t = 1, o.mode.teams do self.teamScores[t] = 0 end
    return self
end

-- ── Jugadores ──────────────────────────────────────────────────────────────

function Match:playerCount()
    return Util.count(self.players)
end

function Match:teamCounts()
    local counts = {}
    for t = 1, self.mode.teams do counts[t] = 0 end
    for _, p in pairs(self.players) do
        if p.team then counts[p.team] = counts[p.team] + 1 end
    end
    return counts
end

--- Equipo con menos jugadores; en empate, el de menor número.
function Match:pickTeam()
    if self.mode.teams < 2 then return nil end
    local counts, best = self:teamCounts(), 1
    for t = 2, self.mode.teams do
        if counts[t] < counts[best] then best = t end
    end
    return best
end

function Match:join(id, name, now)
    if self.state == STATE.ENDED then return false, 'La partida ya terminó.' end
    if self.players[id] then return false, 'Ya estás en esta partida.' end
    if self:playerCount() >= self.mode.maxPlayers then return false, 'La partida está llena.' end
    if self.state == STATE.RUNNING then
        if self.mode.kind == 'race' or not self.mode.allowJoinInProgress then
            return false, 'Este modo no admite entrar con la partida empezada.'
        end
    end
    self.seq = self.seq + 1
    local p = {
        id = id, name = name or ('Jugador ' .. tostring(id)), team = self:pickTeam(),
        score = 0, kills = 0, deaths = 0, joinedSeq = self.seq, joinedAt = now or 0,
        lap = 1, checkpoint = 1, finished = false,
    }
    self.players[id] = p
    if not self.host then self.host = id end
    return true, p
end

function Match:leave(id)
    local p = self.players[id]
    if not p then return false end
    self.players[id] = nil
    if self.host == id then
        -- El anfitrión pasa al jugador más antiguo que quede.
        local nextHost, bestSeq = nil, math.huge
        for pid, other in pairs(self.players) do
            if other.joinedSeq < bestSeq then nextHost, bestSeq = pid, other.joinedSeq end
        end
        self.host = nextHost
    end
    return true, p
end

-- ── Ciclo de vida ──────────────────────────────────────────────────────────

function Match:canStart()
    if self.state ~= STATE.LOBBY then return false, 'La partida ya empezó.' end
    if self:playerCount() < self.mode.minPlayers then
        return false, ('Se necesitan al menos %d jugadores.'):format(self.mode.minPlayers)
    end
    return true
end

function Match:start(now)
    local ok, err = self:canStart()
    if not ok then return false, err end
    self.state = STATE.COUNTDOWN
    self.startsAt = now + self.mode.countdownSec
    return true
end

--- Avanza la partida. `ctx.positions` = { [playerId] = {x,y,z} } (solo para modos de zona).
--- Devuelve una lista de eventos para que el servidor actúe (teletransportes, HUD...).
function Match:tick(now, ctx)
    local events = {}
    if self.state == STATE.COUNTDOWN and now >= self.startsAt then
        self.state = STATE.RUNNING
        self.startedAt = now
        self.lastTickAt = now
        if self.mode.durationSec > 0 then self.endsAt = now + self.mode.durationSec end
        events[#events + 1] = { type = 'started' }
    elseif self.state == STATE.RUNNING then
        if self.mode.onTick then self.mode.onTick(self, ctx or {}, now, events) end
        self.lastTickAt = now
        if self.state == STATE.RUNNING and self.endsAt and now >= self.endsAt then
            self:finish('time', now, events)
        end
        if self.state == STATE.RUNNING and self.firstFinishAt
            and now >= self.firstFinishAt + (self.mode.finishGraceSec or 30) then
            self:finish('grace', now, events)
        end
    end
    return events
end

function Match:finish(reason, now, events)
    if self.state == STATE.ENDED then return end
    self.state = STATE.ENDED
    self.endedAt = now
    self.endReason = reason
    self.winner = self:computeWinner()
    if events then events[#events + 1] = { type = 'ended', reason = reason, winner = self.winner } end
end

-- ── Puntuación ─────────────────────────────────────────────────────────────

function Match:_checkScoreLimit(p, events, now)
    local limit = self.mode.scoreLimit
    if limit <= 0 or self.state ~= STATE.RUNNING then return end
    if self.mode.teams >= 2 then
        for t = 1, self.mode.teams do
            if self.teamScores[t] >= limit then return self:finish('score', now, events) end
        end
    elseif p and p.score >= limit then
        self:finish('score', now, events)
    end
end

function Match:addScore(id, points, now, events)
    local p = self.players[id]
    if not p or points == 0 then return end
    p.score = p.score + points
    if p.team then self.teamScores[p.team] = self.teamScores[p.team] + points end
    self:_checkScoreLimit(p, events, now)
end

function Match:addTeamScore(team, points, now, events)
    if not self.teamScores[team] then return end
    self.teamScores[team] = self.teamScores[team] + points
    self:_checkScoreLimit(nil, events, now)
end

--- Registra una muerte. `killerId` nil = suicidio o entorno.
--- Devuelve 'kill' | 'teamkill' | 'suicide' | nil (ignorado).
function Match:registerDeath(victimId, killerId, now, events)
    if self.state ~= STATE.RUNNING then return nil end
    local victim = self.players[victimId]
    if not victim then return nil end
    victim.deaths = victim.deaths + 1
    local scoring = self.mode.scoring
    local killer = killerId and self.players[killerId]
    if not killer or killerId == victimId then
        self:addScore(victimId, scoring.suicide or 0, now, events)
        return 'suicide'
    end
    if killer.team and killer.team == victim.team then
        self:addScore(killerId, scoring.teamkill or 0, now, events)
        return 'teamkill'
    end
    killer.kills = killer.kills + 1
    self:addScore(killerId, scoring.kill or 0, now, events)
    return 'kill'
end

-- ── Carreras ───────────────────────────────────────────────────────────────

--- El cliente avisa de que cruzó `idx`; el servidor ya validó la distancia.
function Match:reachCheckpoint(id, idx, now, events)
    if self.mode.kind ~= 'race' or self.state ~= STATE.RUNNING then return false, 'no hay carrera en curso' end
    local p = self.players[id]
    if not p or p.finished then return false, 'jugador no válido' end
    if idx ~= p.checkpoint then return false, 'checkpoint fuera de orden' end
    local total = #self.arena.checkpoints
    p.lastCheckpointAt = now
    if idx < total then
        p.checkpoint = idx + 1
        return true, { lap = p.lap, next = p.checkpoint }
    end
    if p.lap < self.mode.laps then
        p.lap = p.lap + 1
        p.checkpoint = 1
        return true, { lap = p.lap, next = 1, lapCompleted = true }
    end
    p.finished = true
    p.finishTime = now - self.startedAt
    self.finishOrder[#self.finishOrder + 1] = id
    p.position = #self.finishOrder
    if not self.firstFinishAt then self.firstFinishAt = now end
    local allDone = true
    for _, other in pairs(self.players) do
        if not other.finished then allDone = false break end
    end
    if allDone then self:finish('all_finished', now, events) end
    return true, { finished = true, position = p.position, time = p.finishTime }
end

-- ── Clasificación ──────────────────────────────────────────────────────────

local function raceCompare(a, b)
    if a.finished ~= b.finished then return a.finished end
    if a.finished then return a.finishTime < b.finishTime end
    if a.lap ~= b.lap then return a.lap > b.lap end
    if a.checkpoint ~= b.checkpoint then return a.checkpoint > b.checkpoint end
    local ta, tb = a.lastCheckpointAt or math.huge, b.lastCheckpointAt or math.huge
    if ta ~= tb then return ta < tb end
    return a.joinedSeq < b.joinedSeq
end

local function scoreCompare(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.kills ~= b.kills then return a.kills > b.kills end
    if a.deaths ~= b.deaths then return a.deaths < b.deaths end
    return a.joinedSeq < b.joinedSeq
end

function Match:standings()
    local list = {}
    for _, p in pairs(self.players) do list[#list + 1] = p end
    table.sort(list, self.mode.kind == 'race' and raceCompare or scoreCompare)
    return list
end

function Match:computeWinner()
    if self.mode.teams >= 2 then
        local best, bestScore, tie = nil, -math.huge, false
        for t = 1, self.mode.teams do
            local s = self.teamScores[t]
            if s > bestScore then best, bestScore, tie = t, s, false
            elseif s == bestScore then tie = true end
        end
        if tie then return { type = 'draw' } end
        return { type = 'team', team = best, score = bestScore }
    end
    local top = self:standings()[1]
    if not top then return nil end
    if self.mode.kind == 'race' and not top.finished then return { type = 'none' } end
    return { type = 'player', id = top.id, name = top.name, score = top.score, time = top.finishTime }
end

-- ── Serialización para clientes ────────────────────────────────────────────

function Match:summary()
    return {
        id = self.id, mode = self.mode.id, modeLabel = self.mode.label,
        arena = self.arena.id, arenaLabel = self.arena.label, state = self.state,
        players = self:playerCount(), maxPlayers = self.mode.maxPlayers,
        minPlayers = self.mode.minPlayers, host = self.host,
    }
end

function Match:snapshot(now)
    local players = {}
    for i, p in ipairs(self:standings()) do
        players[i] = {
            id = p.id, name = p.name, team = p.team, score = p.score, kills = p.kills,
            deaths = p.deaths, lap = p.lap, checkpoint = p.checkpoint, finished = p.finished,
            finishTime = p.finishTime, position = p.position,
        }
    end
    local s = self:summary()
    s.kind = self.mode.kind
    s.teams = self.mode.teams
    s.laps = self.mode.laps
    s.scoreLimit = self.mode.scoreLimit
    s.checkpoints = self.arena.checkpoints and #self.arena.checkpoints or nil
    s.teamScores = self.teamScores
    s.zoneOwner = self.zoneOwner
    s.playersList = players
    s.winner = self.winner
    s.endReason = self.endReason
    if self.state == STATE.COUNTDOWN then s.countdown = math.max(0, math.ceil(self.startsAt - now)) end
    if self.state == STATE.RUNNING and self.endsAt then s.timeLeft = math.max(0, math.ceil(self.endsAt - now)) end
    return s
end

return Match
