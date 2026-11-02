-- Cliente de pxd_panel: abre/cierra la NUI y reenvía acciones al servidor. No decide nada.
local open = false
local gotStatic = false

local function loadSettings()
    local raw = GetResourceKvpString('settings')
    local ok, data = pcall(json.decode, raw or '')
    return PXDPanel.sanitizeSettings(ok and data or nil)
end

local settings = loadSettings()

-- Desenfoque del juego detrás del panel (mismas natives que ox_inventory, Utils.blurIn/blurOut).
local function blur(on)
    if IsScreenblurFadeRunning() then DisableScreenblurFade() end
    if on then TriggerScreenblurFadeIn(150) else TriggerScreenblurFadeOut(200) end
end

local function setOpen(state)
    if state and IsPauseMenuActive() then return end
    if state ~= open then blur(state) end
    open = state
    SetNuiFocus(state, state)
    SendNUIMessage({ type = 'open', data = { open = state, settings = settings } })
    if state then
        TriggerServerEvent('pxd_panel:server:open', not gotStatic)
    end
end

RegisterCommand(Config.command, function() setOpen(not open) end, false)
RegisterKeyMapping(Config.command, 'Abrir el panel de la ciudad (Próxima RP)', 'keyboard', Config.key)

RegisterNetEvent('pxd_panel:client:data', function(data)
    if type(data) ~= 'table' then return end
    if data.static then gotStatic = true end
    SendNUIMessage({ type = 'data', data = data })
end)

RegisterNetEvent('pxd_panel:client:result', function(result)
    SendNUIMessage({ type = 'result', data = result })
end)

-- Avisos de pxd_progress (logro desbloqueado, recompensa lista…): se ven aunque el panel esté cerrado.
RegisterNetEvent('pxd_progress:notify', function(n)
    if type(n) ~= 'table' then return end
    SendNUIMessage({ type = 'notify', data = { title = tostring(n.title or ''), text = tostring(n.text or '') } })
end)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({})
end)

RegisterNUICallback('claimDaily', function(_, cb)
    TriggerServerEvent('pxd_panel:server:claimDaily')
    cb({})
end)

RegisterNUICallback('claimAchievement', function(body, cb)
    if type(body) == 'table' and type(body.id) == 'string' then
        TriggerServerEvent('pxd_panel:server:claimAchievement', body.id)
    end
    cb({})
end)

RegisterNUICallback('logout', function(_, cb)
    setOpen(false)
    TriggerServerEvent('pxd_panel:server:logout')
    cb({})
end)

RegisterNUICallback('saveSettings', function(body, cb)
    settings = PXDPanel.sanitizeSettings(body)
    SetResourceKvp('settings', json.encode(settings))
    cb({ settings = settings })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false); blur(false) end
end)
