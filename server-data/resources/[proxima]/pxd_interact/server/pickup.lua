-- Recoger objetos del suelo con B (servidor). Usa la API de ox_inventory 2.48.1:
-- GetInventory (drop), CanCarryItem, RemoveItem (del drop, con el hueco exacto),
-- AddItem (al jugador) y RemoveInventory si el drop queda vacío. Si AddItem falla,
-- el objeto vuelve al drop. Un bloqueo por drop impide que dos jugadores lo recojan
-- a la vez. ox_inventory no guarda en el servidor la instancia de cada drop: como el
-- propio ox_inventory, se valida la distancia (el cliente filtra por instancia).
if not Config.drops.enabled then return end

local locks, cooldowns = {}, {}

local function ox() return GetResourceState('ox_inventory') == 'started' end
local function now() return GetGameTimer() / 1000 end

local function getDrop(dropId)
    local ok, inv = pcall(function() return exports.ox_inventory:GetInventory(dropId) end)
    return ok and type(inv) == 'table' and inv or nil
end

local function itemLabel(item)
    if type(item.metadata) == 'table' and type(item.metadata.label) == 'string' then return item.metadata.label end
    if type(item.label) == 'string' then return item.label end
    local ok, def = pcall(function() return exports.ox_inventory:Items(item.name) end)
    return ok and type(def) == 'table' and def.label or item.name
end

local function playerState(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return { pos = GetEntityCoords(ped), inVehicle = GetVehiclePedIsIn(ped, false) ~= 0, dead = GetEntityHealth(ped) <= 0 }
end

-- ¿Qué hay en el drop? (solo si estás cerca). Respuesta: primer hueco y nombre.
RegisterNetEvent('pxd_interact:dropPeek', function(dropId)
    local src = source
    if not ox() or type(dropId) ~= 'string' then return end
    if not PXDInteract.cooldown(cooldowns, 'peek' .. src, now(), 0.25) then return end
    local st, inv = playerState(src), getDrop(dropId)
    if not st or not inv or inv.type ~= 'drop' or not inv.coords then return TriggerClientEvent('pxd_interact:dropPeek', src, dropId) end
    if #(st.pos - vector3(inv.coords.x, inv.coords.y, inv.coords.z)) > Config.drops.serverMaxDist + 2.0 then return end
    local slot = PXDInteract.firstSlot(inv.items)
    if not slot then return TriggerClientEvent('pxd_interact:dropPeek', src, dropId) end
    local item = inv.items[slot]
    TriggerClientEvent('pxd_interact:dropPeek', src, dropId, slot, PXDInteract.pickupLabel(itemLabel(item), item.count))
end)

local MESSAGES = {
    full = 'No te cabe en el inventario.',
    gone = 'Ya no está.',
    far = 'Estás demasiado lejos.',
    busy = 'Alguien lo está recogiendo.',
}

RegisterNetEvent('pxd_interact:pickup', function(dropId, slot)
    local src = source
    if not ox() then return end
    if not PXDInteract.cooldown(cooldowns, 'pick' .. src, now(), (Config.drops.cooldownMs or 400) / 1000) then return end
    if type(dropId) ~= 'string' or type(slot) ~= 'number' then return end

    if not PXDInteract.tryLock(locks, dropId, now(), Config.drops.lockSeconds) then
        return TriggerClientEvent('pxd_interact:pickupResult', src, false, MESSAGES.busy, dropId)
    end

    local result, reason = (function()
        local st, inv = playerState(src), getDrop(dropId)
        if not st then return false, 'gone' end
        local item = inv and type(inv.items) == 'table' and inv.items[slot]
        local canCarry = nil
        if type(item) == 'table' and item.name then
            local okC, can = pcall(function() return exports.ox_inventory:CanCarryItem(src, item.name, item.count, item.metadata) end)
            canCarry = okC and can and true or false
        end
        local ok, why = PXDInteract.validatePickup({
            dropId = dropId, slot = slot, inv = inv, playerPos = st.pos, maxDist = Config.drops.serverMaxDist,
            canCarry = canCarry, inVehicle = st.inVehicle, dead = st.dead,
        })
        if not ok then return false, why end
        -- Copia de los datos antes de tocar el drop (la tabla puede cambiar al quitarlo).
        local name, count, metadata = why.name, why.count, why.metadata

        local removed = exports.ox_inventory:RemoveItem(dropId, name, count, metadata, slot)
        if not removed then return false, 'gone' end
        local added = exports.ox_inventory:AddItem(src, name, count, metadata)
        if not added then
            -- Devolverlo al drop: nunca se pierde un objeto.
            exports.ox_inventory:AddItem(dropId, name, count, metadata, slot)
            return false, 'full'
        end

        -- Drop vacío y nadie mirándolo: se elimina (como hace ox_inventory al cerrarlo).
        local after = getDrop(dropId)
        if after and not PXDInteract.firstSlot(after.items) and not next(after.openedBy or {}) then
            pcall(function() exports.ox_inventory:RemoveInventory(dropId) end)
        end
        return true
    end)()

    PXDInteract.unlock(locks, dropId)
    if result then
        TriggerClientEvent('pxd_interact:pickupResult', src, true, nil, dropId)
    else
        TriggerClientEvent('pxd_interact:pickupResult', src, false, MESSAGES[reason] or MESSAGES.gone, dropId)
    end
end)

AddEventHandler('playerDropped', function()
    cooldowns['peek' .. source], cooldowns['pick' .. source] = nil, nil
end)
