-- Pantalla de bienvenida: aparece al terminar la carga y deja elegir ciudad o modos.
local open = false

local function setOpen(state)
    open = state
    SetNuiFocus(state, state)
    FreezeEntityPosition(PlayerPedId(), state)
    SendNUIMessage({ type = state and 'open' or 'close' })
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(200) end
    while not DoesEntityExist(PlayerPedId()) do Wait(200) end
    if Config.welcomeScreen then
        TriggerServerEvent('pxd_login:server:ready')
    else
        TriggerEvent('pxd_loadscreen:close')
    end
end)

RegisterNetEvent('pxd_login:client:profile', function(profile)
    SendNUIMessage({ type = 'profile', data = profile })
    setOpen(true)
    Wait(300)
    TriggerEvent('pxd_loadscreen:close')
end)

local function choose(after)
    setOpen(false)
    if after then
        CreateThread(function()
            Wait(250)
            ExecuteCommand(after)
        end)
    end
end

RegisterNUICallback('city', function(_, cb) choose(nil) cb({ ok = true }) end)
RegisterNUICallback('modes', function(_, cb) choose('modos') cb({ ok = true }) end)
RegisterNUICallback('props', function(_, cb) choose('props') cb({ ok = true }) end)

-- /bienvenida vuelve a abrir el panel.
RegisterCommand('bienvenida', function()
    if not open then TriggerServerEvent('pxd_login:server:ready') end
end, false)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and open then
        SetNuiFocus(false, false)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)
