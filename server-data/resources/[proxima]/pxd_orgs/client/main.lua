-- pxd_orgs (cliente): abre la interfaz y hace de puente entre la NUI y el servidor.
-- Aquí no se decide nada: cada acción viaja al servidor, que la valida y devuelve el estado nuevo.
local open = false
local pending = {}     -- [id de petición] = respuesta pendiente de la NUI
local nextId = 0

local function notify(text, kind)
    if GetResourceState('qbx_core') ~= 'started' then return end
    pcall(function() exports.qbx_core:Notify(text, kind or 'inform') end)
end

--- Petición al servidor con respuesta (o error si no contesta en 8 s).
local function rpc(action, payload, cb)
    nextId = nextId + 1
    local id = nextId
    pending[id] = cb
    TriggerServerEvent('pxd_orgs:server:rpc', id, action, payload or {})
    SetTimeout(8000, function()
        if pending[id] then
            pending[id] = nil
            cb({ ok = false, error = 'El servidor no respondió. Inténtalo de nuevo.' })
        end
    end)
end

RegisterNetEvent('pxd_orgs:client:rpc', function(id, res)
    local cb = pending[id]
    if not cb then return end
    pending[id] = nil
    cb(type(res) == 'table' and res or { ok = false, error = 'Respuesta no válida.' })
end)

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    TriggerScreenblurFadeOut(200.0)
    SendNUIMessage({ action = 'close' })
end

local function show()
    if open or IsPauseMenuActive() then return end
    rpc('view', nil, function(res)
        if not res.ok or not res.state then return notify(res.error or 'Las organizaciones no están disponibles ahora mismo.', 'error') end
        open = true
        SetNuiFocus(true, true)
        TriggerScreenblurFadeIn(200.0)
        SendNUIMessage({ action = 'open', state = res.state })
    end)
end

RegisterNUICallback('rpc', function(data, cb)
    if type(data) ~= 'table' or type(data.action) ~= 'string' then return cb({ ok = false, error = 'Petición no válida.' }) end
    rpc(data.action, type(data.payload) == 'table' and data.payload or {}, cb)
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb({ ok = true })
end)

-- El servidor avisa cuando cambia algo que afecta a lo que se ve (invitación, rango, expulsión…).
RegisterNetEvent('pxd_orgs:client:refresh', function()
    if not open then return end
    rpc('view', nil, function(res)
        if res.ok and res.state then SendNUIMessage({ action = 'state', state = res.state }) end
    end)
end)

RegisterCommand(Config.command, show, false)
exports('Open', show)      -- para el panel TAB u otros menús
exports('Close', close)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then
        SetNuiFocus(false, false)
        TriggerScreenblurFadeOut(0.0)
    end
end)

TriggerEvent('chat:addSuggestion', '/' .. Config.command, 'Tu organización: miembros, fondos, identidad e invitaciones')
