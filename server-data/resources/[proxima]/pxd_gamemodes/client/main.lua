-- Cliente de pxd_gamemodes: menú (NUI), HUD, spawns, respawn y checkpoints.
-- No decide puntos: solo informa al servidor, que valida.
local current = nil      -- info de la partida (clientMatchInfo del servidor)
local snapshot = nil     -- último estado recibido
local menuOpen = false
local nextCheckpoint = 1
local cpBlip = nil
local waitingCheckpoint = false
local spawnSeed = 0

local function nui(type, data)
    SendNUIMessage({ type = type, data = data })
end

local function setMenu(open)
    menuOpen = open
    SetNuiFocus(open, open)
    nui('menu', { open = open })
    if open then TriggerServerEvent('pxd_gm:server:requestLobby') end
end

-- ── Utilidades de juego ────────────────────────────────────────────────────

local function setAutoSpawn(enabled)
    if GetResourceState('spawnmanager') == 'started' then
        exports.spawnmanager:setAutoSpawn(enabled)
    end
end

local function giveLoadout()
    if not current then return end
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    for i, w in ipairs(current.loadout or {}) do
        GiveWeaponToPed(ped, GetHashKey(w.weapon), w.ammo or 100, false, i == 1)
    end
    SetPedArmour(ped, current.armour or 0)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end

local function teleport(p, resurrect)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ped = PlayerPedId()
    if resurrect then
        NetworkResurrectLocalPlayer(p.x, p.y, p.z, p.h or 0.0, true, false)
        ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
    else
        SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    end
    SetEntityHeading(ped, p.h or 0.0)
    Wait(250)
    DoScreenFadeIn(400)
end

-- ── Checkpoints de carrera ─────────────────────────────────────────────────

local function clearCheckpoint()
    if cpBlip then RemoveBlip(cpBlip) cpBlip = nil end
end

local function showCheckpoint(idx)
    clearCheckpoint()
    if not current or current.kind ~= 'race' then return end
    local cp = current.arena.checkpoints[idx]
    if not cp then return end
    cpBlip = AddBlipForCoord(cp.x, cp.y, cp.z)
    SetBlipRoute(cpBlip, true)
end

-- Marcadores documentados: 1 = MarkerTypeVerticalCylinder, 4 = MarkerTypeCheckeredFlagRect.
local function drawCheckpoint(idx)
    local cps = current.arena.checkpoints
    local cp = cps[idx]
    if not cp then return end
    local r = current.checkpointRadius or 10.0
    DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        r * 2.0, r * 2.0, 6.0, 92, 225, 255, 90, false, false, 2, false, nil, nil, false)
    if idx == #cps then
        DrawMarker(4, cp.x, cp.y, cp.z + 4.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            3.0, 3.0, 3.0, 255, 255, 255, 220, true, true, 2, false, nil, nil, false)
    end
end

-- ── Eventos del servidor ───────────────────────────────────────────────────

RegisterNetEvent('pxd_gm:client:lobby', function(data)
    nui('lobby', data)
end)

RegisterNetEvent('pxd_gm:client:notify', function(msg, kind)
    nui('toast', { message = msg, kind = kind })
end)

RegisterNetEvent('pxd_gm:client:joined', function(info)
    current = info
    nextCheckpoint = 1
    setAutoSpawn(false)
    if info.arena.layout and GetResourceState('pxd_props') == 'started' then
        exports.pxd_props:ShowLayout(info.arena.layout)
    end
    info.me = GetPlayerServerId(PlayerId())
    nui('joined', info)
end)

RegisterNetEvent('pxd_gm:client:match', function(snap)
    snapshot = snap
    nui('match', snap)
end)

RegisterNetEvent('pxd_gm:client:spawn', function(spawn, _team)
    if not current or not spawn then return end
    teleport(spawn, IsEntityDead(PlayerPedId()))
    giveLoadout()
    if current.kind == 'race' then showCheckpoint(nextCheckpoint) end
end)

RegisterNetEvent('pxd_gm:client:vehicle', function(netId)
    CreateThread(function()
        local tries = 0
        while not NetworkDoesEntityExistWithNetworkId(netId) and tries < 200 do
            Wait(25)
            tries = tries + 1
        end
        local veh = NetToVeh(netId)
        if veh ~= 0 then SetPedIntoVehicle(PlayerPedId(), veh, -1) end
    end)
end)

RegisterNetEvent('pxd_gm:client:checkpointOk', function(info)
    waitingCheckpoint = false
    if info.finished then
        clearCheckpoint()
        return
    end
    nextCheckpoint = info.next
    showCheckpoint(nextCheckpoint)
end)

RegisterNetEvent('pxd_gm:client:feed', function(feed)
    nui('feed', feed)
end)

RegisterNetEvent('pxd_gm:client:ended', function(snap)
    snapshot = snap
    clearCheckpoint()
    nui('ended', snap)
end)

RegisterNetEvent('pxd_gm:client:left', function(info)
    local layout = current and current.arena.layout
    current, snapshot = nil, nil
    clearCheckpoint()
    if layout and GetResourceState('pxd_props') == 'started' then
        exports.pxd_props:HideLayout(layout)
    end
    RemoveAllPedWeapons(PlayerPedId(), true)
    if info then teleport(info, IsEntityDead(PlayerPedId())) end
    setAutoSpawn(true)
    nui('left', {})
end)

-- ── Bucles ─────────────────────────────────────────────────────────────────

-- Respawn propio dentro de la partida.
CreateThread(function()
    while true do
        Wait(250)
        if current and snapshot and snapshot.state == 'running' and IsEntityDead(PlayerPedId()) then
            nui('respawn', { seconds = current.respawnDelaySec })
            Wait((current.respawnDelaySec or 5) * 1000)
            if current then
                spawnSeed = spawnSeed + 1
                local spawn
                if current.kind == 'race' then
                    local cps = current.arena.checkpoints
                    spawn = nextCheckpoint > 1 and cps[nextCheckpoint - 1] or current.arena.grid[1]
                else
                    local me = nil
                    for _, p in ipairs(snapshot.playersList or {}) do
                        if p.id == GetPlayerServerId(PlayerId()) then me = p end
                    end
                    spawn = PXD.Arena.pickSpawn(current.arena, me and me.team, math.random(1, 64) + spawnSeed)
                end
                if spawn then
                    teleport(spawn, true)
                    giveLoadout()
                    if current.kind == 'race' then TriggerServerEvent('pxd_gm:server:raceRespawn') end
                end
            end
        end
    end
end)

-- Detección de checkpoints y dibujo de la zona.
CreateThread(function()
    while true do
        local sleep = 500
        if current and snapshot and snapshot.state == 'running' then
            local pos = GetEntityCoords(PlayerPedId())
            if current.kind == 'race' then
                sleep = 0
                drawCheckpoint(nextCheckpoint)
                local cp = not waitingCheckpoint and current.arena.checkpoints[nextCheckpoint]
                if cp and #(pos - vector3(cp.x, cp.y, cp.z)) <= (current.checkpointRadius or 10.0) then
                    waitingCheckpoint = true
                    TriggerServerEvent('pxd_gm:server:checkpoint', nextCheckpoint)
                    -- Si el servidor no responde (rechazo), se reintenta en 2 s.
                    SetTimeout(2000, function() waitingCheckpoint = false end)
                end
            elseif current.kind == 'zone' and current.arena.zone then
                sleep = 0
                local z = current.arena.zone
                local owner = snapshot.zoneOwner or 0
                local r, g, b = 255, 255, 255
                if owner == 1 then r, g, b = 80, 160, 255 elseif owner == 2 then r, g, b = 255, 90, 90
                elseif owner == -1 then r, g, b = 255, 200, 60 end
                DrawMarker(1, z.x, z.y, z.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    z.radius * 2.0, z.radius * 2.0, 2.0, r, g, b, 90, false, false, 2, false, nil, nil, false)
            end
        end
        Wait(sleep)
    end
end)

-- ── Menú NUI ───────────────────────────────────────────────────────────────

RegisterCommand('modos', function() setMenu(not menuOpen) end, false)
RegisterKeyMapping('modos', 'Abrir el menú de modos de juego', 'keyboard', 'F7')

RegisterCommand('salirmodo', function() TriggerServerEvent('pxd_gm:server:leave') end, false)

RegisterNUICallback('close', function(_, cb) setMenu(false) cb({ ok = true }) end)
RegisterNUICallback('create', function(data, cb)
    TriggerServerEvent('pxd_gm:server:create', data.mode, data.arena)
    cb({ ok = true })
end)
RegisterNUICallback('join', function(data, cb)
    TriggerServerEvent('pxd_gm:server:join', tonumber(data.id))
    cb({ ok = true })
end)
RegisterNUICallback('leave', function(_, cb) TriggerServerEvent('pxd_gm:server:leave') cb({ ok = true }) end)
RegisterNUICallback('start', function(_, cb) TriggerServerEvent('pxd_gm:server:start') cb({ ok = true }) end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then
        clearCheckpoint()
        if menuOpen then SetNuiFocus(false, false) end
    end
end)
