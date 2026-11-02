-- «B · Recoger …»: recoge directamente el objeto tirado más cercano (ox_inventory),
-- sin abrir el inventario. El servidor valida y mueve el objeto (server/pickup.lua).
-- Los drops llegan con los eventos createDrop/removeDrop/setPlayerInventory de
-- ox_inventory 2.48.1 (client.lua). Como ox_inventory, solo se muestran los de tu
-- instancia (LocalPlayer.state.instance).
if not Config.drops.enabled then return end

local drops = {}          -- [dropId] = { x, y, z, instance }
local peek = {}           -- [dropId] = { slot, label, t }
local current             -- drop elegido ahora mismo
local lastPress = 0

local function add(dropId, data)
    if type(dropId) ~= 'string' or type(data) ~= 'table' or not data.coords then return end
    local c = data.coords
    drops[dropId] = { id = dropId, x = c.x, y = c.y, z = c.z, instance = data.instance }
end

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data) add(dropId, data) end)
RegisterNetEvent('ox_inventory:removeDrop', function(dropId) drops[dropId] = nil peek[dropId] = nil end)
RegisterNetEvent('ox_inventory:setPlayerInventory', function(currentDrops)
    drops, peek = {}, {}
    for id, data in pairs(type(currentDrops) == 'table' and currentDrops or {}) do add(id, data) end
end)

-- El servidor dice qué hay en el drop (primer hueco y su nombre).
RegisterNetEvent('pxd_interact:dropPeek', function(dropId, slot, label)
    if type(dropId) ~= 'string' or not drops[dropId] then return end
    local p = peek[dropId] or {}
    p.t, p.slot, p.label, p.empty = GetGameTimer(), slot, label, slot == nil
    peek[dropId] = p
end)

--- ¿Hay que (volver a) preguntar al servidor qué hay en el drop?
--- Respuestas válidas 3 s; como mucho una pregunta cada 1,5 s.
local function needPeekImpl(id)
    local p, now = peek[id], GetGameTimer()
    if p and p.t and now - p.t < 3000 then return false end
    if p and p.asked and now - p.asked < 1500 then return false end
    return true
end

RegisterNetEvent('pxd_interact:pickupResult', function(ok, text, dropId)
    if dropId then peek[dropId] = nil end
    if text then SendNUIMessage({ action = 'notify', text = tostring(text) }) end
end)

local function visibleDrops()
    local inst = LocalPlayer.state.instance
    local list = {}
    for _, d in pairs(drops) do
        if d.instance == nil or d.instance == inst then list[#list + 1] = d end
    end
    return list
end

local function blocked(ped)
    return IsPauseMenuActive() or IsNuiFocused() or IsPedInAnyVehicle(ped, false) or IsPedDeadOrDying(ped, true)
        or LocalPlayer.state.invOpen or LocalPlayer.state.invBusy
end

-- Bucle: busca el drop más cercano (empate → el de enfrente) y muestra el aviso.
CreateThread(function()
    local shownId, shownLabel
    while true do
        local sleep = 300
        local ped = PlayerPedId()
        local target
        if next(drops) and not blocked(ped) then
            local pos = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            target = PXDInteract.pickDrop(visibleDrops(), pos, fwd, Config.drops.radius)
            if target then
                if needPeekImpl(target.id) then
                    peek[target.id] = peek[target.id] or {}
                    peek[target.id].asked = GetGameTimer()
                    TriggerServerEvent('pxd_interact:dropPeek', target.id)
                end
                if peek[target.id] and peek[target.id].empty then target = nil end
            end
            sleep = 200
        end
        current = target
        local label = target and peek[target.id] and peek[target.id].slot and peek[target.id].label
        if target and label then
            if shownId ~= target.id or shownLabel ~= label then
                SendNUIMessage({ action = 'pickup', key = Config.keys.pickup, label = label })
                shownId, shownLabel = target.id, label
            end
        elseif shownId then
            SendNUIMessage({ action = 'pickup' })
            shownId, shownLabel = nil, nil
        end
        Wait(sleep)
    end
end)

RegisterCommand('+pxd_recoger', function()
    local ped = PlayerPedId()
    if not current or blocked(ped) then return end   -- sin objetos: B no hace nada
    if GetGameTimer() - lastPress < Config.drops.cooldownMs then return end
    lastPress = GetGameTimer()
    local p = peek[current.id]
    if not p or not p.slot then return end
    TriggerServerEvent('pxd_interact:pickup', current.id, p.slot)
end, false)
RegisterCommand('-pxd_recoger', function() end, false)
RegisterKeyMapping('+pxd_recoger', 'Recoger objeto del suelo (Próxima RP)', 'keyboard', Config.keys.pickup)
