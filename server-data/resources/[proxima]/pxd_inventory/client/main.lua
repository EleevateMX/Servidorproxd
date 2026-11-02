-- pxd_inventory (cliente): adaptador entre la interfaz propia del inventario y el juego.
-- La interfaz (web/pxd-inventory → copiada a ox_inventory/web/build por pxd_updater) habla con
-- ox_inventory por su contrato NUI y con este recurso por https://pxd_inventory/<acción>:
--   state          → signos vitales, dinero, nombre, PROX-ID, ropa (docs/36-inventario.md)
--   toggleClothing → quitar/poner una prenda del propio personaje
-- Este recurso no tiene ui_page, así que no usa nui_callback_strict_mode (solo devuelve datos
-- del propio jugador y cambia la ropa de su propio personaje).

local MALE, FEMALE = GetHashKey('mp_m_freemode_01'), GetHashKey('mp_f_freemode_01')
local saved = {}          -- id de ranura -> lo que llevaba antes de quitárselo
local savedModel = nil
local cam = nil
local notices = {}

-- Historial de notificaciones para el panel del inventario. Solo las que llegan por
-- eventos de red (ox_lib:notify de ox_lib y QBCore:Notify de qbx_core); las que un
-- recurso muestra con lib.notify en el propio cliente no pasan por aquí.
local function pushNotice(title, text, kind)
    PXDInv.pushNotice(notices, { title = title, text = text, kind = kind }, GetCloudTimeAsInt(), Config.notifyHistory)
end

RegisterNetEvent('ox_lib:notify', function(data)
    if type(data) ~= 'table' then return end
    pushNotice(data.title, data.description, data.type)
end)

RegisterNetEvent('QBCore:Notify', function(text, notifyType)
    if type(text) == 'table' then pushNotice(text.text or text.caption, text.caption and text.text or nil, notifyType)
    else pushNotice(nil, text, notifyType) end
end)

local function sexOf(ped)
    local model = GetEntityModel(ped)
    if model == MALE then return 'male' end
    if model == FEMALE then return 'female' end
    return nil -- no es freemode: la ropa no se toca
end

local function read(ped, kind, index)
    if kind == 'prop' then
        return { GetPedPropIndex(ped, index), GetPedPropTextureIndex(ped, index) }
    end
    return { GetPedDrawableVariation(ped, index), GetPedTextureVariation(ped, index) }
end

local function currentFor(ped, slot)
    local cur = { [slot.index] = read(ped, slot.kind, slot.index) }
    for _, extra in ipairs(slot.also or {}) do cur[extra.index] = read(ped, 'comp', extra.index) end
    return cur
end

local function resetIfModelChanged(ped)
    local model = GetEntityModel(ped)
    if model ~= savedModel then saved, savedModel = {}, model end
end

local function wearing(ped, sex)
    local out = {}
    for _, slot in ipairs(Config.clothing) do
        out[slot.id] = sex ~= nil and not saved[slot.id] and PXDInv.isOn(slot, read(ped, slot.kind, slot.index), sex)
    end
    return out
end

local function playerData()
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    local ok, pd = pcall(function() return exports.qbx_core:GetPlayerData() end)
    return ok and pd or nil
end

local function view()
    local ped = PlayerPedId()
    resetIfModelChanged(ped)
    local sex = sexOf(ped)
    -- hunger/thirst/stress: state bags que qbx_core 1.24.1 replica al jugador (server/player.lua)
    -- y que también lee pxd_hud. Si faltan, se usan los metadata de GetPlayerData().
    local data = PXDInv.view(playerData(), {
        health = GetEntityHealth(ped), maxHealth = GetEntityMaxHealth(ped), armour = GetPedArmour(ped),
        state = { hunger = LocalPlayer.state.hunger, thirst = LocalPlayer.state.thirst, stress = LocalPlayer.state.stress },
        preview = cam ~= nil,
        notices = notices, now = GetCloudTimeAsInt(),
    }, Config.clothing, wearing(ped, sex))
    data.canChange = sex ~= nil
    return data
end

RegisterNUICallback('clearNotices', function(_, cb)
    notices = {}
    cb(view())
end)

RegisterNUICallback('state', function(_, cb)
    cb(view())
end)

RegisterNUICallback('toggleClothing', function(data, cb)
    local ped = PlayerPedId()
    resetIfModelChanged(ped)
    local sex = sexOf(ped)
    local slot = type(data) == 'table' and type(data.id) == 'string' and PXDInv.slot(Config.clothing, data.id)
    if slot and sex and not IsPedInAnyVehicle(ped, false) then
        local ops, keep = PXDInv.toggle(slot, saved[slot.id], currentFor(ped, slot), sex)
        for _, op in ipairs(ops) do
            local kind, index, drawable, texture = op[1], op[2], op[3], op[4]
            if kind == 'prop' then
                if drawable < 0 then ClearPedProp(ped, index)
                else SetPedPropIndex(ped, index, drawable, texture, true) end
            else
                SetPedComponentVariation(ped, index, drawable, texture, 0)
            end
        end
        saved[slot.id] = keep
    end
    cb(view())
end)

-- ── Cámara del personaje mientras el inventario está abierto ─────────────
-- ox_inventory marca el state bag local `invOpen` (ox_lib: client.player:set).
local function openCam()
    local c = Config.camera
    local ped = PlayerPedId()
    if not c.enabled or cam or IsPedInAnyVehicle(ped, false) then return end
    local pos = GetOffsetFromEntityInWorldCoords(ped, c.side, c.distance, c.height)
    local look = GetOffsetFromEntityInWorldCoords(ped, c.side, 0.0, c.lookHeight)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, c.fov, false, 0)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    -- Fondo desenfocado y personaje nítido (como la selección de personaje de qbx_core).
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, 0.4)
    SetCamFarDof(cam, c.distance + 0.8)
    SetCamDofStrength(cam, 0.85)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 400, true, false)
    CreateThread(function()
        while cam and DoesCamExist(cam) do
            SetUseHiDof()
            Wait(0)
        end
    end)
end

local function closeCam()
    if not cam then return end
    RenderScriptCams(false, true, 300, true, false)
    if DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil
end

CreateThread(function()
    while true do
        local open = LocalPlayer.state.invOpen == true
        if open and not cam then openCam()
        elseif not open and cam then closeCam() end
        Wait(open and 150 or 300)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then closeCam() end
end)
