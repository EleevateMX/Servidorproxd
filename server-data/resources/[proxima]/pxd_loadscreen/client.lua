-- Cierre controlado de la pantalla de carga (loadscreen_manual_shutdown 'yes').
local closed = false

local function close()
    if closed then return end
    closed = true
    SendLoadingScreenMessage(json.encode({ eventName = 'pxd:closing' }))
    Wait(600) -- deja terminar el fundido de la página
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

-- pxd_login lo pide cuando su pantalla de bienvenida está lista.
AddEventHandler('pxd_loadscreen:close', function()
    CreateThread(close)
end)

-- Mensajes de estado opcionales desde otros recursos del cliente.
AddEventHandler('pxd_loadscreen:status', function(text)
    if not closed then
        SendLoadingScreenMessage(json.encode({ eventName = 'pxd:status', text = tostring(text) }))
    end
end)

-- Si pxd_login no está en marcha, se cierra sola cuando el jugador está activo.
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    SendLoadingScreenMessage(json.encode({ eventName = 'pxd:status', text = 'Entrando en la ciudad…' }))
    Wait(2500)
    if GetResourceState('pxd_login') ~= 'started' then close() end
    -- Red de seguridad: nunca dejar a nadie atrapado en la carga.
    Wait(20000)
    close()
end)
