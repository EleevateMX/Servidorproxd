-- Guarda en la BD el desgaste de piezas de qbx_mechanicjob (ver config.lua).
if not Config.wear.enabled then return end

local st = PXDWear.new(Config.wear.saveIntervalSec)
local SAVE_EVENT = 'vehiclemod:server:saveStatus'

-- Eventos de qbx_mechanicjob que cambian el estado (server/main.lua de qbx_mechanicjob).
for _, ev in ipairs({
    'vehiclemod:server:setupVehicleStatus',
    'vehiclemod:server:updatePart',
    'qb-vehicletuning:server:SetPartLevel',
    'vehiclemod:server:fixEverything',
}) do
    RegisterNetEvent(ev, function(plate) PXDWear.mark(st, plate) end)
end

local function active()
    return GetResourceState('qbx_mechanicjob') == 'started'
end

local function flush(all)
    if not active() then return end
    local now = GetGameTimer() // 1000
    for _, plate in ipairs(PXDWear.due(st, now, all)) do
        TriggerEvent(SAVE_EVENT, plate)
        PXDWear.saved(st, plate, now)
    end
end

CreateThread(function()
    while true do
        Wait(Config.wear.tickSec * 1000)
        flush(false)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() or res == 'qbx_mechanicjob' then flush(true) end
end)
AddEventHandler('txAdmin:events:serverShuttingDown', function() flush(true) end)

PXDCompat = { flush = flush, state = st }   -- para pruebas
