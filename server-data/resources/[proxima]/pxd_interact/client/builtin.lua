-- Interacciones de serie: «Presentarse» con otros jugadores, invitaciones y
-- objetos tirados de ox_inventory («Recoger»).
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

-- Objetos tirados (ox_inventory) -------------------------------------------------
-- ox_inventory avisa con los eventos createDrop/removeDrop/setPlayerInventory y abre
-- un drop con exports.ox_inventory:openInventory('drop', id) (client.lua de ox_inventory).
if Config.drops.enabled then
    local dropZones = {}

    local function addDrop(dropId, data)
        if type(data) ~= 'table' or not data.coords or dropZones[dropId] then return end
        dropZones[dropId] = API.addZone({
            coords = data.coords, radius = Config.drops.radius,
            options = { { label = 'Recoger', icon = 'hand', onSelect = function()
                if GetResourceState('ox_inventory') == 'started' then
                    exports.ox_inventory:openInventory('drop', dropId)
                end
            end } },
        })
    end

    local function removeDrop(dropId)
        if dropZones[dropId] then API.removeZone(dropZones[dropId]) dropZones[dropId] = nil end
    end

    RegisterNetEvent('ox_inventory:createDrop', function(dropId, data) addDrop(dropId, data) end)
    RegisterNetEvent('ox_inventory:removeDrop', function(dropId) removeDrop(dropId) end)
    RegisterNetEvent('ox_inventory:setPlayerInventory', function(currentDrops)
        for id in pairs(dropZones) do removeDrop(id) end
        for id, data in pairs(type(currentDrops) == 'table' and currentDrops or {}) do addDrop(id, data) end
    end)
end

-- Al cargar el personaje (o al iniciar el recurso) pide su ID y sus conocidos.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('pxd_interact:ready') end)
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(2000)
    TriggerServerEvent('pxd_interact:ready')
end)
