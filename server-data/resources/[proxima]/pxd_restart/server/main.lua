-- Escucha los eventos de txAdmin y avisa a todos los jugadores.
-- Eventos documentados en txAdmin (docs/events.md): scheduledRestart {secondsRemaining},
-- scheduledRestartSkipped, serverShuttingDown {delay, author, message}.

AddEventHandler('txAdmin:events:scheduledRestart', function(data)
    local seconds = type(data) == 'table' and tonumber(data.secondsRemaining)
    if not seconds then return end
    local view = PXDRestart.view(seconds, Config.toastMinutes, Config.screenSeconds)
    if view then TriggerClientEvent('pxd_restart:show', -1, view, seconds) end
end)

AddEventHandler('txAdmin:events:scheduledRestartSkipped', function()
    TriggerClientEvent('pxd_restart:cancel', -1)
end)

-- txAdmin expulsa a todos justo después de este evento: es un último intento.
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    TriggerClientEvent('pxd_restart:show', -1, 'screen', 0)
end)
