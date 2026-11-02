-- pxd_admin (cliente): abre la NUI, reenvía al servidor y hace lo que solo puede
-- hacerse en el cliente (espectar, curar sin qbx_medical). No decide nada: el
-- servidor valida permisos y objetivos.
local uiOpen = false
local spec = nil   -- { target = serverId, saved = vector3 }

local function setFocus(on)
    uiOpen = on
    SetNuiFocus(on, on)
end

local function fromServer() return GetInvokingResource() == nil end

-- ── Espectar ────────────────────────────────────────────────────────────────

local function stopSpectate()
    if not spec then return end
    local ped = PlayerPedId()
    local targetPlayer = GetPlayerFromServerId(spec.target)
    NetworkSetInSpectatorMode(false, targetPlayer ~= -1 and GetPlayerPed(targetPlayer) or ped)
    local s = spec.saved
    RequestCollisionAtCoord(s.x, s.y, s.z)
    SetEntityCoords(ped, s.x, s.y, s.z, false, false, false, false)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    spec = nil
    SendNUIMessage({ action = 'spectate', on = false })
    TriggerServerEvent('pxd_admin:server:spectateEnd')
end

RegisterNetEvent('pxd_admin:client:spectate', function(target, coords, name)
    if not fromServer() then return end
    if spec then stopSpectate() end
    local ped = PlayerPedId()
    spec = { target = target, saved = GetEntityCoords(ped) }
    setFocus(false)
    SendNUIMessage({ action = 'hide' })
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    -- Nos acercamos (oculto y quieto) para que el otro jugador entre en nuestro alcance.
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 10.0, false, false, false, false)
    local deadline = GetGameTimer() + 6000
    local player = GetPlayerFromServerId(target)
    while (player == -1 or not DoesEntityExist(GetPlayerPed(player))) and GetGameTimer() < deadline do
        Wait(100)
        player = GetPlayerFromServerId(target)
    end
    if player == -1 then
        stopSpectate()
        return SendNUIMessage({ action = 'toast', title = 'Staff', text = 'No se pudo espectar: el jugador no está cerca.', kind = 'error' })
    end
    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    SendNUIMessage({ action = 'spectate', on = true, name = name })
end)

-- ── Curar sin qbx_medical ───────────────────────────────────────────────────

RegisterNetEvent('pxd_admin:client:revive', function()
    if not fromServer() then return end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('pxd_admin:client:heal', function()
    if not fromServer() then return end
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

-- ── Datos del servidor → NUI ────────────────────────────────────────────────

RegisterNetEvent('pxd_admin:client:support', function(data)
    if not fromServer() then return end
    SendNUIMessage({ action = 'support', data = data })
    setFocus(true)
end)

RegisterNetEvent('pxd_admin:client:staff', function(data)
    if not fromServer() then return end
    SendNUIMessage({ action = 'staff', data = data })
    setFocus(true)
end)

RegisterNetEvent('pxd_admin:client:reports', function(list)
    if not fromServer() then return end
    SendNUIMessage({ action = 'reports', reports = list })
end)

RegisterNetEvent('pxd_admin:client:notify', function(n)
    if not fromServer() or type(n) ~= 'table' then return end
    SendNUIMessage({ action = 'toast', title = n.title, text = n.text, kind = n.kind })
end)

RegisterNetEvent('pxd_admin:client:staffAlert', function(r)
    if not fromServer() then return end
    SendNUIMessage({ action = 'alert', report = r })
end)

-- ── Modo servicio ───────────────────────────────────────────────────────────

local duty = { on = false, saved = nil }

local function applyOutfit(ped)
    local model = GetEntityModel(ped)
    for name, parts in pairs(Config.staffOutfit or {}) do
        if model == GetHashKey(name) then
            for _, c in ipairs(parts) do SetPedComponentVariation(ped, c[1], c[2], c[3], 0) end
            return true
        end
    end
    return false
end

RegisterNetEvent('pxd_admin:client:duty', function(on)
    if not fromServer() then return end
    local ped = PlayerPedId()
    local hasAppearance = GetResourceState('illenium-appearance') == 'started'
    if on then
        if hasAppearance then
            local ok, app = pcall(function() return exports['illenium-appearance']:getPedAppearance(ped) end)
            duty.saved = ok and app or nil
        end
        applyOutfit(ped)
    else
        if duty.saved and hasAppearance then
            pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), duty.saved) end)
        end
        duty.saved = nil
        SetPlayerInvincible(PlayerId(), false)
        SetEntityInvincible(PlayerPedId(), false)
    end
    duty.on = on == true
    SendNUIMessage({ action = 'duty', on = duty.on })
    if duty.on then
        CreateThread(function()
            while duty.on do   -- se repite por si otro recurso lo quita (muerte, cambio de ped…)
                SetPlayerInvincible(PlayerId(), true)
                SetEntityInvincible(PlayerPedId(), true)
                Wait(1000)
            end
        end)
    end
end)

-- Etiqueta «STAFF» sobre quien esté de servicio (state bag pxd_staff que pone el servidor).
local function drawTag(x, y, z, text)
    SetDrawOrigin(x, y, z, false)
    SetTextFont(4)
    SetTextScale(0.0, 0.42)
    SetTextColour(255, 79, 216, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local me = PlayerPedId()
        local myPos = GetEntityCoords(me)
        local tags = {}
        for _, player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            if Player(GetPlayerServerId(player)).state.pxd_staff and DoesEntityExist(ped) and IsEntityVisible(ped) then
                local pos = GetEntityCoords(ped)
                if #(pos - myPos) < 25.0 and (ped == me or HasEntityClearLosToEntity(me, ped, 17)) then
                    tags[#tags + 1] = pos
                end
            end
        end
        if #tags == 0 then
            Wait(500)
        else
            local untilAt = GetGameTimer() + 250
            while GetGameTimer() < untilAt do
                for _, pos in ipairs(tags) do drawTag(pos.x, pos.y, pos.z + 1.15, 'STAFF') end
                Wait(0)
            end
        end
    end
end)

-- ── Herramientas de staff (las autoriza el servidor) ────────────────────────

local tools = { noclip = false, invisible = false }

local function noclipLoop()
    local speed = 1.0
    while tools.noclip do
        local ped = PlayerPedId()
        local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
        for _, c in ipairs({ 21, 22, 32, 33, 34, 35, 36 }) do DisableControlAction(0, c, true) end
        local rot = GetGameplayCamRot(2)
        local rz, rx = math.rad(rot.z), math.rad(rot.x)
        local fwd = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
        local right = vector3(math.cos(rz), math.sin(rz), 0.0)
        local mul = IsDisabledControlPressed(0, 21) and 3.0 or 1.0
        local move = vector3(0.0, 0.0, 0.0)
        if IsDisabledControlPressed(0, 32) then move = move + fwd end
        if IsDisabledControlPressed(0, 33) then move = move - fwd end
        if IsDisabledControlPressed(0, 34) then move = move - right end
        if IsDisabledControlPressed(0, 35) then move = move + right end
        if IsDisabledControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
        if IsDisabledControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end
        local pos = GetEntityCoords(ent) + move * (speed * mul)
        SetEntityCoordsNoOffset(ent, pos.x, pos.y, pos.z, true, true, true)
        SetEntityHeading(ent, rot.z)
        Wait(0)
    end
end

local function setNoclip(on)
    local ped = PlayerPedId()
    local ent = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped
    tools.noclip = on
    SetEntityCollision(ent, not on, not on)
    FreezeEntityPosition(ent, on)
    SetEntityVisible(ped, not on and not tools.invisible, false)
    if on then CreateThread(noclipLoop) end
end

local function toast(text, kind)
    SendNUIMessage({ action = 'toast', title = 'Staff', text = text, kind = kind or 'success' })
end

local function nearestVehicle(maxDist)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return GetVehiclePedIsIn(ped, false) end
    local pos, best, bestDist = GetEntityCoords(ped), nil, maxDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - pos)
        if d < bestDist then best, bestDist = veh, d end
    end
    return best
end

local TOOLS = {}

function TOOLS.noclip() setNoclip(not tools.noclip); toast(tools.noclip and 'Noclip activado.' or 'Noclip desactivado.') end

function TOOLS.invisible()
    tools.invisible = not tools.invisible
    SetEntityVisible(PlayerPedId(), not tools.invisible, false)
    toast(tools.invisible and 'Ahora eres invisible.' or 'Vuelves a ser visible.')
end

function TOOLS.tpm()
    local blip = GetFirstBlipInfoId(8)   -- 8 = marcador del jugador
    if not DoesBlipExist(blip) then return toast('Pon un marcador en el mapa.', 'error') end
    local c = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    for z = 1000.0, 0.0, -25.0 do
        RequestCollisionAtCoord(c.x, c.y, z)
        SetEntityCoordsNoOffset(ped, c.x, c.y, z, false, false, false)
        Wait(20)
        local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, z, false)
        if found then
            SetEntityCoordsNoOffset(ped, c.x, c.y, groundZ + 1.0, false, false, false)
            return toast('Has ido al marcador.')
        end
    end
    toast('No encontré el suelo; quedas en el aire sobre el marcador.', 'error')
end

function TOOLS.repair()
    local veh = nearestVehicle(6.0)
    if not veh then return toast('No hay vehículo cerca.', 'error') end
    SetVehicleFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    toast('Vehículo reparado.')
end

function TOOLS.dv()
    local veh = nearestVehicle(6.0)
    if not veh then return toast('No hay vehículo cerca.', 'error') end
    TriggerServerEvent('pxd_admin:server:deleteVehicle', NetworkGetNetworkIdFromEntity(veh))
end

function TOOLS.car(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return toast(('«%s» no es un vehículo.'):format(model), 'error')
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(hash) then return toast('El modelo tarda demasiado en cargar.', 'error') end
    local ped = PlayerPedId()
    local old = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or nil
    local pos = GetEntityCoords(ped)
    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(hash)
    if old then TriggerServerEvent('pxd_admin:server:deleteVehicle', NetworkGetNetworkIdFromEntity(old)) end
    SetPedIntoVehicle(ped, veh, -1)
    TriggerServerEvent('pxd_admin:server:carSpawned', NetworkGetNetworkIdFromEntity(veh))
    toast(('Vehículo «%s» listo.'):format(model))
end

RegisterNetEvent('pxd_admin:client:tool', function(name, arg)
    if not fromServer() or not TOOLS[name] then return end
    TOOLS[name](arg)
end)

RegisterNetEvent('pxd_admin:client:announce', function(a)
    if not fromServer() or type(a) ~= 'table' then return end
    SendNUIMessage({ action = 'announce', text = a.text })
end)

RegisterNetEvent('pxd_admin:client:wounds', function(w)
    if not fromServer() then return end
    SendNUIMessage({ action = 'wounds', data = w })
end)

-- ── Teclas ──────────────────────────────────────────────────────────────────

RegisterCommand('soporte', function()
    if uiOpen then return end
    TriggerServerEvent('pxd_admin:server:openSupport')
end, false)
RegisterKeyMapping('soporte', 'Soporte y reportes', 'keyboard', Config.keySupport)

RegisterCommand('staff', function()
    if spec then return stopSpectate() end   -- la misma tecla sale de espectar
    if uiOpen then return end
    TriggerServerEvent('pxd_admin:server:openStaff')
end, false)
RegisterKeyMapping('staff', 'Panel de staff', 'keyboard', Config.keyStaff)

-- ── NUI → servidor ──────────────────────────────────────────────────────────

local function cb(name, fn)
    RegisterNUICallback(name, function(data, reply)
        fn(type(data) == 'table' and data or {})
        reply({ ok = true })
    end)
end

cb('close', function() setFocus(false) end)
cb('createReport', function(d)
    TriggerServerEvent('pxd_admin:server:createReport', { kind = d.kind, category = d.category, target = d.target, text = d.text })
end)
cb('playerReply', function(d) TriggerServerEvent('pxd_admin:server:playerReply', d.id, d.text) end)
cb('refreshSupport', function() TriggerServerEvent('pxd_admin:server:openSupport') end)
cb('refreshStaff', function() TriggerServerEvent('pxd_admin:server:refreshStaff') end)
cb('openStaff', function() TriggerServerEvent('pxd_admin:server:openStaff') end)
cb('action', function(d) TriggerServerEvent('pxd_admin:server:action', d.action, d.target, d.payload) end)
cb('reportAction', function(d) TriggerServerEvent('pxd_admin:server:reportAction', d.action, d.id, d.text) end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if spec then stopSpectate() end
    if tools.noclip then setNoclip(false) end
    if tools.invisible then SetEntityVisible(PlayerPedId(), true, false) end
    if duty.on then SetPlayerInvincible(PlayerId(), false); SetEntityInvincible(PlayerPedId(), false) end
    if uiOpen then SetNuiFocus(false, false) end
end)
