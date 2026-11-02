-- Servidor de pxd_gamemodes: única autoridad sobre partidas, puntos y buckets.
-- Los clientes solo piden cosas (crear, unirse, checkpoint) y el servidor valida.
local Lobby = PXD.Lobby.new({ bucketBase = Config.bucketBase, maxMatches = Config.maxMatches })
local returnInfo = {}   -- [src] = { x, y, z, h, bucket } para devolver al jugador a su sitio
local vehicles = {}     -- [src] = vehículo de carrera
local lastRespawnAt = {}
local lastDeathAt = {}  -- evita contar dos veces la misma muerte (baseevents + Qbox)
local awaitingRespawn = {} -- [src] = true mientras está muerto/caído en una partida

local function now()
    return GetGameTimer() / 1000.0
end

local function hasAce(src, ace)
    return ace == nil or IsPlayerAceAllowed(src, ace)
end

local function notify(src, msg, kind)
    TriggerClientEvent('pxd_gm:client:notify', src, msg, kind or 'info')
end

-- ── Arenas ─────────────────────────────────────────────────────────────────

local function propsRunning()
    return GetResourceState('pxd_props') == 'started'
end

local function resolveArena(arenaId)
    if type(arenaId) ~= 'string' then return nil end
    local layoutId = arenaId:match('^layout:(.+)$')
    if layoutId then
        if not propsRunning() then return nil end
        return PXD.Arena.fromLayout(exports.pxd_props:GetLayout(layoutId))
    end
    return PXD.Arena.fromConfig(arenaId, Config.arenas[arenaId])
end

local function arenaList()
    local out = {}
    for id, def in pairs(Config.arenas) do
        out[#out + 1] = { id = id, label = def.label or id }
    end
    if propsRunning() then
        for _, l in ipairs(exports.pxd_props:ListLayouts() or {}) do
            if (l.points or 0) > 0 then
                out[#out + 1] = { id = 'layout:' .. l.id, label = l.name .. ' (layout)' }
            end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- ── Envíos a clientes ──────────────────────────────────────────────────────

local function lobbyPayload()
    return { modes = PXD.Modes.list(), matches = Lobby:list(), arenas = arenaList(),
        defaultArena = Config.defaultArena }
end

local function broadcastLobby()
    TriggerClientEvent('pxd_gm:client:lobby', -1, lobbyPayload())
end

local function pushMatch(match)
    local snap = match:snapshot(now())
    for pid in pairs(match.players) do
        TriggerClientEvent('pxd_gm:client:match', pid, snap)
    end
end

--- Lo que el cliente necesita para jugar: datos de la arena y del modo.
local function clientMatchInfo(match)
    local m, a = match.mode, match.arena
    return {
        id = match.id, mode = m.id, kind = m.kind, label = m.label, teams = m.teams,
        respawnDelaySec = m.respawnDelaySec, loadout = m.loadout, armour = m.armour,
        checkpointRadius = m.checkpointRadius, laps = m.laps,
        arena = { id = a.id, label = a.label, layout = a.layout, spawns = a.spawns,
            teamSpawns = a.teamSpawns, grid = a.grid, checkpoints = a.checkpoints, zone = a.zone },
    }
end

-- ── Vehículos de carrera ───────────────────────────────────────────────────

local function deleteVehicle(src)
    local veh = vehicles[src]
    vehicles[src] = nil
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
end

local function spawnRaceVehicle(src, match, point)
    deleteVehicle(src)
    local p = point or PXD.Arena.pickSpawn(match.arena, nil, 1)
    if not p then return end
    local veh = CreateVehicle(GetHashKey(match.mode.vehicle), p.x, p.y, p.z, p.h or 0.0, true, true)
    local tries = 0
    while not DoesEntityExist(veh) and tries < 100 do
        Wait(10)
        tries = tries + 1
    end
    if not DoesEntityExist(veh) then
        notify(src, 'No se pudo crear el vehículo de carrera.', 'error')
        return
    end
    SetEntityRoutingBucket(veh, match.bucket)
    vehicles[src] = veh
    TriggerClientEvent('pxd_gm:client:vehicle', src, NetworkGetNetworkIdFromEntity(veh))
end

-- ── Entrar / salir ─────────────────────────────────────────────────────────

local function sendSpawn(src, match)
    local p = match.players[src]
    if not p then return end
    local list = match.mode.kind == 'race' and match.arena.grid or nil
    local spawn = list and list[(p.joinedSeq - 1) % #list + 1] or PXD.Arena.pickSpawn(match.arena, p.team, p.joinedSeq)
    TriggerClientEvent('pxd_gm:client:spawn', src, spawn, p.team)
    if match.mode.kind == 'race' then
        CreateThread(function() spawnRaceVehicle(src, match, spawn) end)
    end
end

--- Reaparición decidida por el servidor (con o sin Qbox).
local function respawnPlayer(src, match)
    local p = match.players[src]
    if not p then return end
    local spawn
    if match.mode.kind == 'race' then
        local cps = match.arena.checkpoints
        local last = p.checkpoint > 1 and cps[p.checkpoint - 1] or match.arena.grid[1]
        spawn = { x = last.x, y = last.y, z = last.z + 1.0, h = last.h or 0.0 }
    else
        spawn = PXD.Arena.pickSpawn(match.arena, p.team, math.random(1, 64))
    end
    awaitingRespawn[src] = nil
    local revived = Bridge.isDowned(src) and Bridge.revive(src)
    CreateThread(function()
        if revived then Wait(500) end -- deja que Qbox termine de revivir antes de mover al jugador
        TriggerClientEvent('pxd_gm:client:spawn', src, spawn, p.team)
        if match.mode.kind == 'race' then spawnRaceVehicle(src, match, spawn) end
    end)
end

local function restorePlayer(src)
    local info = returnInfo[src]
    returnInfo[src] = nil
    deleteVehicle(src)
    awaitingRespawn[src] = nil
    if Bridge.isDowned(src) then Bridge.revive(src) end
    Bridge.setBucket(src, info and info.bucket or 0)
    TriggerClientEvent('pxd_gm:client:left', src, info)
end

local function removeMatch(match)
    for _, pid in ipairs(Lobby:remove(match.id)) do
        restorePlayer(pid)
    end
    broadcastLobby()
end

local function leavePlayer(src, dropped)
    local match = Lobby:leave(src)
    if not match then return end
    if dropped then
        returnInfo[src] = nil
        deleteVehicle(src)
    else
        restorePlayer(src)
    end
    if match:playerCount() == 0 and match.state ~= PXD.Match.STATE.LOBBY then
        removeMatch(match)
        return
    end
    pushMatch(match)
    broadcastLobby()
end

local function joinPlayer(src, match)
    local allowed, why = Bridge.canJoin(src)
    if not allowed then
        notify(src, why, 'error')
        return false
    end
    local ok, res, previous = Lobby:join(match.id, src, GetPlayerName(src), now())
    if not ok then
        notify(src, res, 'error')
        return false
    end
    if previous then
        deleteVehicle(src)
        if previous:playerCount() == 0 and previous.state ~= PXD.Match.STATE.LOBBY then
            removeMatch(previous)
        else
            pushMatch(previous)
        end
    end
    if not returnInfo[src] then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        returnInfo[src] = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped),
            bucket = GetPlayerRoutingBucket(src) }
    end
    Bridge.setBucket(src, match.bucket)
    TriggerClientEvent('pxd_gm:client:joined', src, clientMatchInfo(match))
    if match.state == PXD.Match.STATE.RUNNING then sendSpawn(src, match) end
    pushMatch(match)
    broadcastLobby()
    return true
end

-- Reacciona a los eventos que devuelve Match (inicio y fin) estén donde estén.
local function handleEvents(match, events, t)
    for _, ev in ipairs(events) do
        if ev.type == 'started' then
            for pid in pairs(match.players) do sendSpawn(pid, match) end
            broadcastLobby()
        elseif ev.type == 'ended' then
            match.removeAt = t + match.mode.resultsSec
            local snap = match:snapshot(t)
            for pid in pairs(match.players) do
                TriggerClientEvent('pxd_gm:client:ended', pid, snap)
            end
            broadcastLobby()
        end
    end
end

-- ── Eventos de red ─────────────────────────────────────────────────────────

RegisterNetEvent('pxd_gm:server:requestLobby', function()
    TriggerClientEvent('pxd_gm:client:lobby', source, lobbyPayload())
end)

RegisterNetEvent('pxd_gm:server:create', function(modeId, arenaId)
    local src = source
    if type(modeId) ~= 'string' or (arenaId ~= nil and type(arenaId) ~= 'string') then return end
    if not hasAce(src, Config.createAce) then
        return notify(src, 'No tienes permiso para crear partidas.', 'error')
    end
    local arena = resolveArena(arenaId or Config.defaultArena[modeId])
    if not arena then return notify(src, 'Arena no encontrada.', 'error') end
    local match, err = Lobby:create(modeId, arena, src, now())
    if not match then return notify(src, err, 'error') end
    SetRoutingBucketPopulationEnabled(match.bucket, false)
    SetRoutingBucketEntityLockdownMode(match.bucket, Config.bucketLockdown)
    if not joinPlayer(src, match) then removeMatch(match) end
end)

RegisterNetEvent('pxd_gm:server:join', function(matchId)
    local src = source
    local match = type(matchId) == 'number' and Lobby:get(matchId)
    if not match then return notify(src, 'Esa partida ya no existe.', 'error') end
    joinPlayer(src, match)
end)

RegisterNetEvent('pxd_gm:server:leave', function()
    leavePlayer(source, false)
end)

RegisterNetEvent('pxd_gm:server:start', function()
    local src = source
    local match = Lobby:findByPlayer(src)
    if not match then return end
    if match.host ~= src and not hasAce(src, Config.adminAce) then
        return notify(src, 'Solo el anfitrión puede iniciar la partida.', 'error')
    end
    local ok, err = match:start(now())
    if not ok then return notify(src, err, 'error') end
    pushMatch(match)
    broadcastLobby()
end)

RegisterNetEvent('pxd_gm:server:checkpoint', function(idx)
    local src = source
    local match = Lobby:findByPlayer(src)
    if not match or type(idx) ~= 'number' then return end
    local cp = match.arena.checkpoints and match.arena.checkpoints[idx]
    if not cp then return end
    -- Validación en servidor: el jugador debe estar realmente cerca del checkpoint.
    local pos = GetEntityCoords(GetPlayerPed(src))
    local radius = (match.mode.checkpointRadius or 10.0) + Config.checkpointTolerance
    if PXD.Util.dist({ x = pos.x, y = pos.y, z = pos.z }, cp) > radius then
        print(('[pxd_gamemodes] checkpoint rechazado: jugador %d a más de %.1f m'):format(src, radius))
        return
    end
    local events, t = {}, now()
    local ok, info = match:reachCheckpoint(src, idx, t, events)
    if not ok then return end
    TriggerClientEvent('pxd_gm:client:checkpointOk', src, info)
    if info.finished then
        for pid in pairs(match.players) do
            notify(pid, ('%s termina en posición %d (%s)'):format(GetPlayerName(src), info.position,
                PXD.Util.formatTime(info.time)), 'success')
        end
    end
    pushMatch(match)
    handleEvents(match, events, t)
end)

-- El cliente pide reaparecer tras su tiempo de espera; el servidor decide dónde.
RegisterNetEvent('pxd_gm:server:respawnMe', function()
    local src = source
    local match = Lobby:findByPlayer(src)
    if not match or match.state ~= PXD.Match.STATE.RUNNING then return end
    -- Solo quien está muerto/caído: muerte registrada, estado de Qbox o vida 0 según el servidor.
    local dead = awaitingRespawn[src] or Bridge.isDowned(src) or GetEntityHealth(GetPlayerPed(src)) <= 0
    if not dead then return end
    local t = now()
    local wait = math.max(1, (match.mode.respawnDelaySec or 3) - 1)
    if lastDeathAt[src] and t - lastDeathAt[src] < wait then return end
    if lastRespawnAt[src] and t - lastRespawnAt[src] < 2 then return end
    lastRespawnAt[src] = t
    respawnPlayer(src, match)
end)

-- Muertes: baseevents (cfx-server-data) las envía desde el cliente de la víctima.
local function onDeath(victim, killerId)
    local match = Lobby:findByPlayer(victim)
    if not match then return end
    -- La misma muerte puede llegar dos veces (baseevents y Qbox): se cuenta una.
    local t0 = now()
    if lastDeathAt[victim] and t0 - lastDeathAt[victim] < 3 then return end
    lastDeathAt[victim] = t0
    if match.state == PXD.Match.STATE.RUNNING then awaitingRespawn[victim] = true end
    local killer = (type(killerId) == 'number' and killerId > 0) and killerId or nil
    if killer and match.players[killer] then
        -- Comprobación básica contra eventos falsos: ambos cerca y en la misma partida.
        local a, b = GetEntityCoords(GetPlayerPed(victim)), GetEntityCoords(GetPlayerPed(killer))
        if PXD.Util.dist({ x = a.x, y = a.y, z = a.z }, { x = b.x, y = b.y, z = b.z }) > 600.0 then
            killer = nil
        end
    elseif killer then
        killer = nil
    end
    local events, t = {}, now()
    local kind = match:registerDeath(victim, killer, t, events)
    if not kind then return end
    local feed = { victim = GetPlayerName(victim), killer = killer and GetPlayerName(killer) or nil, kind = kind }
    for pid in pairs(match.players) do TriggerClientEvent('pxd_gm:client:feed', pid, feed) end
    pushMatch(match)
    handleEvents(match, events, t)
end

AddEventHandler('baseevents:onPlayerKilled', function(killerId)
    onDeath(source, killerId)
end)

AddEventHandler('baseevents:onPlayerDied', function()
    onDeath(source, nil)
end)

-- Con Qbox el jugador queda «caído» en vez de muerto; el cliente lo avisa aquí.
RegisterNetEvent('pxd_gm:server:died', function(killerId)
    if killerId ~= nil and type(killerId) ~= 'number' then return end
    onDeath(source, killerId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    leavePlayer(src, true)
    lastRespawnAt[src], lastDeathAt[src], awaitingRespawn[src] = nil, nil, nil
end)

-- ── Bucle principal (1 Hz) ─────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(1000)
        local t = now()
        for _, match in pairs(Lobby.matches) do
            if match.state == PXD.Match.STATE.LOBBY then
                if match:playerCount() == 0 and t - match.createdAt > Config.emptyLobbyTimeoutSec then
                    removeMatch(match)
                end
            elseif match.state == PXD.Match.STATE.ENDED then
                if match.removeAt and t >= match.removeAt then removeMatch(match) end
            else
                local ctx
                if match.mode.kind == 'zone' then
                    ctx = { positions = {} }
                    for pid in pairs(match.players) do
                        local c = GetEntityCoords(GetPlayerPed(pid))
                        ctx.positions[pid] = { x = c.x, y = c.y, z = c.z }
                    end
                end
                handleEvents(match, match:tick(t, ctx), t)
                pushMatch(match)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, match in pairs(Lobby.matches) do
        for pid in pairs(match.players) do restorePlayer(pid) end
    end
end)

-- ── Consola / admin: gm list | gm terminar <id> ────────────────────────────

RegisterCommand('gm', function(src, args)
    if src ~= 0 and not hasAce(src, Config.adminAce) then return end
    local sub = args[1]
    local function out(msg)
        if src == 0 then print(msg) else notify(src, msg) end
    end
    if sub == 'list' or sub == nil then
        local list = Lobby:list()
        if #list == 0 then return out('No hay partidas.') end
        for _, m in ipairs(list) do
            out(('#%d %s @ %s [%s] %d/%d'):format(m.id, m.modeLabel, m.arenaLabel, m.state, m.players, m.maxPlayers))
        end
    elseif sub == 'terminar' then
        local match = Lobby:get(tonumber(args[2]) or -1)
        if not match then return out('No existe esa partida.') end
        local events, t = {}, now()
        match:finish('admin', t, events)
        handleEvents(match, events, t)
        out(('Partida #%d terminada.'):format(match.id))
    else
        out('Uso: gm list | gm terminar <id>')
    end
end, false)

-- API para otros recursos (p. ej. un futuro menú RP).
exports('GetPlayerMatch', function(src)
    local m = Lobby:findByPlayer(src)
    return m and m:summary() or nil
end)
exports('ListMatches', function() return Lobby:list() end)
