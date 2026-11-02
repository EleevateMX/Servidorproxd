-- Interacciones de serie: «Presentarse» con otros jugadores e invitaciones.
local API = PXDInteractAPI

-- Presentarse ----------------------------------------------------------------
API.addGlobalPlayer({
    {
        label = 'Presentarse', icon = 'handshake', distance = Config.introduce.distance,
        canInteract = function(ctx) return Player(ctx.serverId).state.pxdId ~= nil end,
        onSelect = function(ctx) TriggerServerEvent('pxd_interact:introduce', ctx.serverId) end,
    },
})

local invites = {}
RegisterNetEvent('pxd_interact:invite', function(from, fromId, seconds)
    if invites[from] then API.removeTemporary(invites[from]) end
    local function answer(accept)
        return function()
            if invites[from] then API.removeTemporary(invites[from]) invites[from] = nil end
            TriggerServerEvent('pxd_interact:answer', from, accept)
        end
    end
    invites[from] = API.addTemporary({
        { label = ('Aceptar presentación de %s'):format(tostring(fromId)), icon = 'handshake', onSelect = answer(true) },
        { label = 'Ignorar', icon = 'close', onSelect = answer(false) },
    }, seconds or 20, 100)
    SendNUIMessage({ action = 'notify', text = ('%s quiere presentarse.'):format(tostring(fromId)) })
end)

-- Los objetos tirados (ox_inventory) se recogen con B: client/pickup.lua.

-- Al cargar el personaje (o al iniciar el recurso) pide su ID y sus conocidos.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('pxd_interact:ready') end)
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(2000)
    TriggerServerEvent('pxd_interact:ready')
end)
