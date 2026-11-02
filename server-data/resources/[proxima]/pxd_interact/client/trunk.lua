-- «E · Abrir maletero»: abre directamente el inventario del maletero de ox_inventory.
-- Replica la comprobación de ox_inventory 2.48.1 (modules/inventory/client.lua,
-- Inventory.CanAccessTrunk / OpenTrunk, que no se exportan) con sus mismos datos
-- (data/vehicles.lua). El servidor de ox_inventory vuelve a validar la distancia (16 m)
-- y el cierre del vehículo (GetVehicleDoorLockStatus) antes de abrir.
if not Config.trunk.enabled then return end

local backDoorIds = { 2, 3 }
local Vehicles

-- Datos de vehículos de ox_inventory (qué modelos no tienen maletero o lo llevan delante).
local function vehiclesData()
    if Vehicles ~= nil then return Vehicles end
    Vehicles = false
    if GetResourceState('ox_inventory') ~= 'started' then return Vehicles end
    local src = LoadResourceFile('ox_inventory', 'data/vehicles.lua')
    if src then
        local chunk = load(src, '@ox_inventory/data/vehicles.lua', 't', {})
        local ok, data = pcall(chunk or error)
        if ok and type(data) == 'table' then Vehicles = data end
    end
    return Vehicles
end

--- Devuelve la puerta (id o lista de ids) si el maletero está al alcance; nil si no.
local function canAccessTrunk(ped, entity)
    if not NetworkGetEntityIsNetworked(entity) or IsEntityDead(entity) then return end
    local V = vehiclesData()
    local hash, class = GetEntityModel(entity), GetVehicleClass(entity)
    local check = V and V.Storage and V.Storage[hash]
    if check == 0 or check == 1 then return end
    if V and V.trunk and not V.trunk[class] and not (V.trunk.models and V.trunk.models[hash]) then return end

    local doorId = check and 4 or 5
    if not (V and V.trunk and V.trunk.boneIndex and V.trunk.boneIndex[hash]) and not GetIsDoorValid(entity, doorId) then
        if class ~= 11 and (doorId ~= 5 or GetEntityBoneIndexByName(entity, 'boot') ~= -1 or not GetIsDoorValid(entity, 2)) then
            return
        end
        if class ~= 11 then doorId = backDoorIds end
    end

    local min, max = GetModelDimensions(hash)
    local f = check and vector3(0.5, 1.0, 0.5) or vector3(0.5, 0.0, 0.5)
    local off = (max - min) * f + min
    local point = GetOffsetFromEntityInWorldCoords(entity, off.x, off.y, off.z)
    local d = #(GetEntityCoords(ped) - point)
    if d < Config.trunk.distance then return doorId, d end
end

local function openTrunk(entity, door)
    local c = GetEntityCoords(entity)
    TaskTurnPedToFaceCoord(PlayerPedId(), c.x, c.y, c.z, 0)
    local ok, opened = pcall(function()
        return exports.ox_inventory:openInventory('trunk', {
            netid = NetworkGetNetworkIdFromEntity(entity), entityid = entity, door = door,
        })
    end)
    if not ok or not opened then return end
    -- Como ox_inventory: abre la puerta; al cerrar, ox_inventory la cierra (closeTrunk).
    for _, id in ipairs(type(door) == 'table' and door or { door }) do
        SetVehicleDoorOpen(entity, id, false, false)
    end
end

--- Bloqueado según el juego: 0 sin cierre, 1 abierto, 8 maletero abierto (como ox_inventory).
local function isLocked(entity)
    local s = GetVehicleDoorLockStatus(entity)
    return s > 1 and s ~= 8
end

PXDInteractAddProvider(function(ped, pos, inVehicle)
    if inVehicle or GetResourceState('ox_inventory') ~= 'started' then return end
    local best, bestD, bestDoor
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(pos - GetEntityCoords(veh)) <= Config.trunk.scanRadius then
            local door, d = canAccessTrunk(ped, veh)
            if door and (not bestD or d < bestD) then best, bestD, bestDoor = veh, d, door end
        end
    end
    if not best then return end
    local ctx = { entity = best, coords = GetEntityCoords(best), dist = bestD }
    if isLocked(best) then
        return { key = 'trunk' .. best, dist = bestD, ctx = ctx, priority = PXDInteract.PRIORITY.trunk,
            options = { { label = 'Maletero cerrado', icon = 'lock', onSelect = function()
                SendNUIMessage({ action = 'notify', text = 'El vehículo está cerrado.' })
            end } } }
    end
    return { key = 'trunk' .. best, dist = bestD, ctx = ctx, priority = PXDInteract.PRIORITY.trunk,
        options = { { label = 'Abrir maletero', icon = 'box', onSelect = function() openTrunk(best, bestDoor) end } } }
end)
