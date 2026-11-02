-- pxd_hud (servidor): estrés compatible con qbx_hud y ocultar el HUD con el inventario abierto.
local H = PXDHud

local function getPlayer(src)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player or nil
end

local function notify(src, text)
    pcall(function() exports.qbx_core:Notify(src, text, 'inform', 2500) end)
end

--- Cambia el estrés del jugador (delta positivo sube, negativo baja). Devuelve el nuevo valor.
local function changeStress(src, delta)
    local player = getPlayer(src)
    if not player then return nil end
    if delta > 0 and Config.stress.disableForLEO and player.PlayerData.job and player.PlayerData.job.type == 'leo' then
        return nil
    end
    local value = H.applyStress(player.PlayerData.metadata.stress, delta)
    -- SetMetadata guarda y sincroniza el state bag 'stress' (qbx_core server/player.lua).
    exports.qbx_core:SetMetadata(src, 'stress', value)
    return value
end

-- Historial por jugador para los límites (se olvida al desconectar).
local limits = {}
local function limited(src, kind, amount)
    limits[src] = limits[src] or { gain = {}, relieve = {} }
    local lim = Config.stress.limits and Config.stress.limits[kind]
    return H.limitStress(limits[src][kind], amount, GetGameTimer() / 1000, lim)
end
AddEventHandler('playerDropped', function() limits[source] = nil end)

-- Nombres de evento de qbx_hud: los usan qbx_vehiclekeys (GainStress) y qbx_medical (RelieveStress).
RegisterNetEvent('hud:server:GainStress', function(amount)
    if not Config.stress.enabled or not H.validStressAmount(amount) then return end
    local src = source
    amount = limited(src, 'gain', amount)
    if amount <= 0 then return end
    if changeStress(src, amount) then notify(src, 'Te sientes más estresado') end
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    if not Config.stress.enabled or not H.validStressAmount(amount) then return end
    local src = source
    amount = limited(src, 'relieve', amount)
    if amount <= 0 then return end
    if changeStress(src, -amount) then notify(src, 'Te sientes más tranquilo') end
end)

-- ox_inventory lanza estos eventos de servidor al abrir/cerrar (modules/inventory/server.lua).
AddEventHandler('ox_inventory:openedInventory', function(playerId)
    TriggerClientEvent('pxd_hud:client:visible', playerId, false)
end)
AddEventHandler('ox_inventory:closedInventory', function(playerId)
    TriggerClientEvent('pxd_hud:client:visible', playerId, true)
end)

exports('ChangeStress', changeStress)
