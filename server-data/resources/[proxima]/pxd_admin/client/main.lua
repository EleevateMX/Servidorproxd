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
    FreezeEntityPosition(ped, LocalPlayer.state.pxd_frozen == true)
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

local tools = { invisible = false, devtools = false }

local function toast(text, kind)
    SendNUIMessage({ action = 'toast', title = 'Administración', text = text, kind = kind or 'success' })
end

-- Noclip: guarda el estado anterior y lo restaura al salir. Natives verificados en
-- runtime.fivem.net/doc/natives.json: GET_ENTITY_COLLISION_DISABLED, GET_PLAYER_INVINCIBLE,
-- SET_ENTITY_COLLISION, FREEZE_ENTITY_POSITION, SET_ENTITY_VISIBLE, SET_LOCAL_PLAYER_VISIBLE_LOCALLY,
-- SET_ENTITY_ALPHA / RESET_ENTITY_ALPHA, SET_ENTITY_COORDS_NO_OFFSET, GET_GAMEPLAY_CAM_ROT.
local nc = { on = false, saved = nil, speeds = { 0.2, 0.5, 1.0, 2.0, 4.0, 8.0 }, idx = 3, invisible = true }

local function ncTargets()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return GetVehiclePedIsIn(ped, false), ped end
    return ped, ped
end

local function noclipStop(tellServer)
    if not nc.on then return end
    nc.on = false
    LocalPlayer.state:set('pxd_noclip', false, false) -- lo lee pxd_interact (no agacharse en vuelo)
    local s = nc.saved or {}
    local ped = PlayerPedId()
    if s.ent and DoesEntityExist(s.ent) then
        SetEntityCollision(s.ent, not s.collisionDisabled, not s.collisionDisabled)
        -- Solo queda congelado si un miembro del staff lo había congelado (state bag del servidor).
        FreezeEntityPosition(s.ent, s.ent == ped and LocalPlayer.state.pxd_frozen == true)
        SetEntityVisible(s.ent, true, false)
        ResetEntityAlpha(s.ent)
    end
    SetEntityVisible(ped, s.visible ~= false and not tools.invisible, false)
    ResetEntityAlpha(ped)
    SetPlayerInvincible(PlayerId(), s.invincible == true)
    nc.saved = nil
    SendNUIMessage({ action = 'noclip', on = false })
    if tellServer then TriggerServerEvent('pxd_admin:server:noclipOff') end
end

local NC_DISABLED = { 14, 15, 16, 17, 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 73, 140, 141, 142 }

local function noclipLoop()
    while nc.on do
        local ent, ped = ncTargets()
        if IsEntityDead(ped) then noclipStop(true) break end
        for _, c in ipairs(NC_DISABLED) do DisableControlAction(0, c, true) end
        if IsDisabledControlJustPressed(0, 15) and nc.idx < #nc.speeds then nc.idx = nc.idx + 1; SendNUIMessage({ action = 'noclip', on = true, speed = nc.speeds[nc.idx] }) end
        if IsDisabledControlJustPressed(0, 14) and nc.idx > 1 then nc.idx = nc.idx - 1; SendNUIMessage({ action = 'noclip', on = true, speed = nc.speeds[nc.idx] }) end
        local rot = GetGameplayCamRot(2)
        local rz, rx = math.rad(rot.z), math.rad(rot.x)
        local fwd = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
        local right = vector3(math.cos(rz), math.sin(rz), 0.0)
        local mul = IsDisabledControlPressed(0, 21) and 3.0 or 1.0          -- Shift: rápido
        local move = vector3(0.0, 0.0, 0.0)
        if IsDisabledControlPressed(0, 32) then move = move + fwd end        -- W
        if IsDisabledControlPressed(0, 33) then move = move - fwd end        -- S
        if IsDisabledControlPressed(0, 34) then move = move - right end      -- A
        if IsDisabledControlPressed(0, 35) then move = move + right end      -- D
        if IsDisabledControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end   -- Espacio: sube
        if IsDisabledControlPressed(0, 73) then move = move - vector3(0.0, 0.0, 1.0) end   -- X: baja
        local pos = GetEntityCoords(ent) + move * (nc.speeds[nc.idx] * mul)
        SetEntityCoordsNoOffset(ent, pos.x, pos.y, pos.z, true, true, true)
        SetEntityHeading(ent, rot.z)
        if nc.invisible then SetLocalPlayerVisibleLocally(true) end
        Wait(0)
    end
end

local function noclipStart(opts)
    if nc.on then return end
    LocalPlayer.state:set('pxd_noclip', true, false)
    if LocalPlayer.state.crouch then LocalPlayer.state:set('crouch', false, false) end
    local ent, ped = ncTargets()
    nc.saved = { ent = ent, collisionDisabled = GetEntityCollisionDisabled(ent), visible = IsEntityVisible(ped),
        invincible = GetPlayerInvincible(PlayerId()) }
    if type(opts.speeds) == 'table' and #opts.speeds > 0 then nc.speeds = opts.speeds end
    nc.idx = math.max(1, math.min(#nc.speeds, tonumber(opts.speed) or 3))
    nc.invisible = opts.invisible ~= false
    nc.on = true
    SetEntityCollision(ent, false, false)
    FreezeEntityPosition(ent, true)
    SetPlayerInvincible(PlayerId(), true)
    if nc.invisible then
        SetEntityVisible(ped, false, false)
        if ent ~= ped then SetEntityVisible(ent, false, false) end
        SetEntityAlpha(ped, 120, false)   -- uno mismo se ve en semitransparente
    end
    SendNUIMessage({ action = 'noclip', on = true, speed = nc.speeds[nc.idx], invisible = nc.invisible })
    CreateThread(noclipLoop)
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

local function closePanel()
    setFocus(false)
    SendNUIMessage({ action = 'hide' })
end

local function here()
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(s1)
    if s2 and s2 ~= 0 then street = street .. ' / ' .. GetStreetNameFromHashKey(s2) end
    return { x = c.x, y = c.y, z = c.z, h = h, street = street, interior = GetInteriorFromEntity(ped) }
end

local TOOLS = {}

function TOOLS.noclip(opts)
    opts = type(opts) == 'table' and opts or {}
    if opts.on then noclipStart(opts); toast('Noclip activado · rueda del ratón: velocidad · Espacio/X: subir/bajar.')
    else noclipStop(false); toast('Noclip desactivado.') end
end

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

function TOOLS.clean()
    local veh = nearestVehicle(6.0)
    if not veh then return toast('No hay vehículo cerca.', 'error') end
    SetVehicleDirtLevel(veh, 0.0)
    toast('Vehículo limpio.')
end

function TOOLS.dv()
    local veh = nearestVehicle(6.0)
    if not veh then return toast('No hay vehículo cerca.', 'error') end
    TriggerServerEvent('pxd_admin:server:deleteVehicle', NetworkGetNetworkIdFromEntity(veh))
end

function TOOLS.vehinfo()
    local veh = nearestVehicle(6.0)
    if not veh then return toast('No hay vehículo cerca.', 'error') end
    SendNUIMessage({ action = 'result', kind = 'vehicleLocal', data = {
        name = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        engine = math.floor(GetVehicleEngineHealth(veh)), body = math.floor(GetVehicleBodyHealth(veh)),
        dirt = math.floor(GetVehicleDirtLevel(veh)),
    } })
    TriggerServerEvent('pxd_admin:server:vehicleInfo', NetworkGetNetworkIdFromEntity(veh))
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

function TOOLS.coords()
    SendNUIMessage({ action = 'result', kind = 'coords', data = here() })
end

-- Herramientas de desarrollo: coordenadas, rumbo y vehículo en pantalla.
local function devText(x, y, text)
    SetTextFont(4)
    SetTextScale(0.0, 0.36)
    SetTextColour(92, 225, 255, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

function TOOLS.devtools()
    tools.devtools = not tools.devtools
    toast(tools.devtools and 'Herramientas de desarrollo en pantalla.' or 'Herramientas de desarrollo ocultas.')
    if not tools.devtools then return end
    CreateThread(function()
        while tools.devtools do
            local h = here()
            devText(0.012, 0.30, ('X %.2f  Y %.2f  Z %.2f  H %.1f'):format(h.x, h.y, h.z, h.h))
            devText(0.012, 0.325, ('%s · interior %d'):format(h.street or '', h.interior or 0))
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                devText(0.012, 0.35, ('Vehículo %s · %s · motor %d'):format(GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
                    GetVehicleNumberPlateText(veh), math.floor(GetVehicleEngineHealth(veh))))
            end
            Wait(0)
        end
    end)
end

-- Editor de props: lo abre su propio comando, que vuelve a pedir permiso a pxd_props.
function TOOLS.props()
    closePanel()
    ExecuteCommand('props')
end

-- Menú avanzado de Qbox (qbx_adminmenu): trabajo, banda, datos, ropa… con sus propios permisos.
function TOOLS.qbxmenu()
    if GetResourceState('qbx_adminmenu') ~= 'started' then return toast('qbx_adminmenu no está en marcha.', 'error') end
    closePanel()
    TriggerEvent('qbx_admin:client:openMenu')
end

RegisterNetEvent('pxd_admin:client:tool', function(name, arg)
    if not fromServer() or not TOOLS[name] then return end
    TOOLS[name](arg)
end)

RegisterNetEvent('pxd_admin:client:result', function(kind, data)
    if not fromServer() then return end
    SendNUIMessage({ action = 'result', kind = kind, data = data })
end)

RegisterNetEvent('pxd_admin:client:warning', function(w)
    if not fromServer() or type(w) ~= 'table' then return end
    SendNUIMessage({ action = 'warning', reason = w.reason, by = w.by })
    setFocus(true)
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

-- Nombre de comando nuevo a propósito: FiveM conserva la tecla que cada jugador tenía
-- guardada para un comando; con un nombre nuevo se aplica la tecla por defecto (F10).
RegisterCommand('pxd_panel_admin', function()
    if spec then return stopSpectate() end   -- la misma tecla sale de espectar
    if uiOpen then return end
    TriggerServerEvent('pxd_admin:server:openStaff')
end, false)
RegisterKeyMapping('pxd_panel_admin', 'Próxima: panel de administración', 'keyboard', Config.keyStaff)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/admin', 'Abrir el panel de administración')
    TriggerEvent('chat:addSuggestion', '/noclip', 'Vuelo libre de staff')
    TriggerEvent('chat:removeSuggestion', '/pxd_panel_admin')
end)

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
cb('query', function(d) TriggerServerEvent('pxd_admin:server:query', d.kind, d.args) end)
cb('localTool', function(d) if d.tool == 'coords' then TOOLS.coords() end end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if spec then stopSpectate() end
    if nc.on then noclipStop(true) end
    tools.devtools = false
    if tools.invisible then SetEntityVisible(PlayerPedId(), true, false) end
    if duty.on then SetPlayerInvincible(PlayerId(), false); SetEntityInvincible(PlayerPedId(), false) end
    if uiOpen then SetNuiFocus(false, false) end
end)

-- ── /checkas: rango y permisos dentro del juego (menú de ox_lib con el tema de Próxima) ──
local function ago(at)
    if not at then return '' end
    local d = math.max(0, GetCloudTimeAsInt() - at)
    if d < 3600 then return ('hace %d min'):format(d // 60) end
    if d < 86400 then return ('hace %d h'):format(d // 3600) end
    return ('hace %d días'):format(d // 86400)
end

RegisterNetEvent('pxd_admin:client:checkas', function(d)
    if type(d) ~= 'table' then return end
    local granted, total = 0, 0
    for _, p in ipairs(d.perms or {}) do total = total + 1; if p.ok then granted = granted + 1 end end
    local options = {
        { title = d.role, icon = 'shield-halved', readOnly = true,
          description = ('%s (#%s)%s · %d de %d permisos'):format(d.name or '?', tostring(d.id), d.publicId and (' · ' .. d.publicId) or '', granted, total),
          metadata = { d.origin and ('Origen: ' .. d.origin) or 'Sin rango de staff', d.license and ('Licencia: ' .. d.license) or nil } },
        { title = 'Permisos', icon = 'list-check', menu = 'pxd_checkas_perms', description = 'Qué puede y qué no puede hacer' },
    }
    local perms = {}
    for _, p in ipairs(d.perms or {}) do
        perms[#perms + 1] = { title = (p.ok and '✔ ' or '✖ ') .. p.label, description = 'pxd.admin.' .. p.id,
            icon = p.ok and 'circle-check' or 'circle-xmark', iconColor = p.ok and '#4dd9a3' or '#6b7699', readOnly = true }
    end
    lib.registerContext({ id = 'pxd_checkas_perms', title = 'Permisos · ' .. (d.name or ''), menu = 'pxd_checkas', options = perms })
    if d.staff then
        local list = {}
        if #d.staff == 0 then list[1] = { title = 'Nadie tiene rango dado con /darrango', readOnly = true } end
        for _, s in ipairs(d.staff) do
            list[#list + 1] = { title = ('%s · %s'):format(s.name or '?', s.role or '?'), readOnly = true,
                icon = s.online and 'circle' or 'circle-dot', iconColor = s.online and '#4dd9a3' or '#6b7699',
                description = ('Por %s %s%s'):format(s.by or '?', ago(s.at), s.online and ' · conectado' or '') }
        end
        lib.registerContext({ id = 'pxd_checkas_staff', title = 'Staff', menu = 'pxd_checkas', options = list })
        options[#options + 1] = { title = 'Staff con rango', icon = 'users', menu = 'pxd_checkas_staff',
            description = ('%d personas · /darrango <id> <rol> · /quitarrango <id>'):format(#d.staff) }
    end
    lib.registerContext({ id = 'pxd_checkas', title = '/checkas', options = options })
    lib.showContext('pxd_checkas')
end)

TriggerEvent('chat:addSuggestion', '/checkas', 'Ver tu rango y permisos (staff: de otro jugador)', { { name = 'id', help = 'ID del jugador (opcional)' } })
TriggerEvent('chat:addSuggestion', '/darrango', 'Dar rango de staff', {
    { name = 'id', help = 'ID del jugador' }, { name = 'rol', help = 'soporte, moderador, administrador o desarrollador' }, { name = 'motivo', help = 'Opcional' } })
TriggerEvent('chat:addSuggestion', '/quitarrango', 'Quitar rango de staff', { { name = 'id', help = 'ID o license:…' }, { name = 'motivo', help = 'Opcional' } })
