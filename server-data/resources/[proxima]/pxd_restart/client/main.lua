local function send(msg) SendNUIMessage(msg) end

RegisterNetEvent('pxd_restart:show', function(view, seconds)
    if GetInvokingResource() then return end
    seconds = tonumber(seconds) or 0
    if view == 'toast' then
        send({ action = 'toast', text = PXDRestart.toastText(seconds) })
    elseif view == 'screen' then
        send({ action = 'screen', seconds = seconds, serverName = Config.serverName, steps = Config.steps })
    end
end)

RegisterNetEvent('pxd_restart:cancel', function()
    if GetInvokingResource() then return end
    send({ action = 'cancel' })
end)
