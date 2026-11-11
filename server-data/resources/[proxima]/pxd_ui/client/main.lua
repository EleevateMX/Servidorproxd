-- pxd_ui (cliente): interfaz común de Próxima RP.
--  · Exports propios: Notify, ShowTextUI, HideTextUI, IsTextUIOpen, Progress, ProgressCircle,
--    ProgressActive, CancelProgress, Confirm.
--  · Adaptador de ox_lib (docs/43): ox_lib sigue haciendo la lógica (animaciones, props,
--    controles, promesas); sus archivos parcheados llaman a OxNotify, OxTextUI, OxTextUIHide,
--    OxProgress, OxProgressCancel, OxAlert y OxAlertClose en vez de a su propia página.
--    Si este recurso no está arrancado, ox_lib usa su interfaz original.
local U = PXDUi

local ready = false          -- la NUI avisó de que está cargada
local queue = {}             -- mensajes anteriores a `ready`

local function nui(msg)
    if not ready then
        if #queue < 40 then queue[#queue + 1] = msg end
        return
    end
    SendNUIMessage(msg)
end

RegisterNUICallback('ready', function(_, cb)
    ready = true
    for i = 1, #queue do SendNUIMessage(queue[i]) end
    queue = {}
    cb({})
end)

-- ── Avisos ────────────────────────────────────────────────────────────────
local function notify(data)
    local n = U.notify(data, Config.notify)
    if not n then return false end
    nui({ action = 'notify', data = n })
    return true
end

exports('Notify', notify)
exports('OxNotify', notify)

-- Para scripts de servidor de Próxima: TriggerClientEvent('pxd_ui:client:notify', src, { title, description, type })
RegisterNetEvent('pxd_ui:client:notify', function(data) notify(data) end)

-- ── Text UI ───────────────────────────────────────────────────────────────
local textOpen, textCurrent = false, nil

local function showTextUI(text, options)
    local t = U.textUi(text, options, Config.textUi)
    if not t then return false end
    textOpen, textCurrent = true, t.text
    nui({ action = 'textUi', data = t })
    return true
end

local function hideTextUI()
    textOpen, textCurrent = false, nil
    nui({ action = 'textUiHide' })
    return true
end

exports('ShowTextUI', showTextUI)
exports('HideTextUI', hideTextUI)
exports('IsTextUIOpen', function() return textOpen, textCurrent end)
-- ox_lib envía sus opciones con el texto dentro (options.text).
exports('OxTextUI', function(options)
    if type(options) ~= 'table' then return false end
    return showTextUI(options.text, options)
end)
exports('OxTextUIHide', hideTextUI)

-- ── Progreso ──────────────────────────────────────────────────────────────
-- ox_lib mide el progreso con el reloj del juego y espera que la interfaz le avise al
-- terminar la duración. Aquí el aviso lo da Lua (SetTimeout), no la página: aunque la NUI
-- fallara, el progreso termina igual.
local progressToken = 0

local function oxProgress(msg)
    if type(msg) ~= 'table' then return false end
    local data, duration, circle = U.progress(msg.data, msg.action == 'circleProgress')
    if not data then return false end
    progressToken = progressToken + 1
    local token = progressToken
    nui({ action = 'progress', circle = circle, data = data })
    SetTimeout(duration, function()
        if token ~= progressToken then return end   -- cancelado o sustituido
        progressToken = progressToken + 1
        nui({ action = 'progressDone' })
        TriggerEvent('pxd_ui:oxProgressComplete')
    end)
    return true
end

local function oxProgressCancel()
    progressToken = progressToken + 1
    nui({ action = 'progressCancel' })
    return true
end

exports('OxProgress', oxProgress)
exports('OxProgressCancel', oxProgressCancel)

-- Progreso propio. Con ox_lib arrancado se delega en él (mismas animaciones, props, bloqueo de
-- controles y resultado true/false) y la parte visual vuelve aquí por el adaptador.
local ownProgress = nil   -- { cancel = bool, canCancel = bool }

local function runOwn(data, circle)
    if ownProgress then return false end
    local payload, duration = U.progress(data, circle)
    if not payload then return false end
    ownProgress = { cancel = false, canCancel = data.canCancel == true }
    progressToken = progressToken + 1
    nui({ action = 'progress', circle = circle == true, data = payload })
    local finish = GetGameTimer() + duration
    while GetGameTimer() < finish and not ownProgress.cancel do Wait(50) end
    local ok = not ownProgress.cancel
    ownProgress = nil
    progressToken = progressToken + 1
    nui({ action = ok and 'progressDone' or 'progressCancel' })
    return ok
end

local function progress(data, circle)
    if type(data) ~= 'table' then return false end
    if GetResourceState('ox_lib') == 'started' then
        local ok, result = pcall(function()
            if circle then return exports.ox_lib:progressCircle(data) end
            return exports.ox_lib:progressBar(data)
        end)
        if ok then return result == true end
    end
    return runOwn(data, circle)
end

exports('Progress', function(data) return progress(data, false) end)
exports('ProgressCircle', function(data) return progress(data, true) end)
exports('ProgressActive', function()
    if ownProgress then return true end
    if GetResourceState('ox_lib') == 'started' then
        local ok, active = pcall(function() return exports.ox_lib:progressActive() end)
        return ok and active == true
    end
    return false
end)
exports('CancelProgress', function()
    if ownProgress then ownProgress.cancel = true return true end
    if GetResourceState('ox_lib') == 'started' then
        return (pcall(function() exports.ox_lib:cancelProgress() end))
    end
    return false
end)

RegisterCommand('pxd_ui_cancelar', function()
    if ownProgress and ownProgress.canCancel then ownProgress.cancel = true end
end, false)
RegisterKeyMapping('pxd_ui_cancelar', 'Cancelar la acción en curso (Próxima RP)', 'keyboard', Config.progress.cancelKey)

-- ── Diálogo de confirmación ───────────────────────────────────────────────
local alertPromise = nil     -- diálogo propio (export Confirm)
local alertFromOx = false    -- diálogo abierto por ox_lib (lib.alertDialog)

local function openAlert(data)
    local a = U.alert(data)
    if not a then return false end
    SetNuiFocus(true, true)
    nui({ action = 'alert', data = a })
    return true
end

local function closeAlert()
    SetNuiFocus(false, false)
    nui({ action = 'alertClose' })
end

RegisterNUICallback('alertResult', function(body, cb)
    cb({})
    local result = U.alertResult(type(body) == 'table' and body.result or nil)
    SetNuiFocus(false, false)
    if alertFromOx then
        alertFromOx = false
        TriggerEvent('pxd_ui:oxAlertResult', result)
    elseif alertPromise then
        local p = alertPromise
        alertPromise = nil
        p:resolve(result)
    end
end)

--- Diálogo propio: devuelve 'confirm' o 'cancel'. nil si ya hay uno abierto o no hay texto.
exports('Confirm', function(data)
    if alertPromise or alertFromOx then return nil end
    if not openAlert(data) then return nil end
    alertPromise = promise.new()
    return Citizen.Await(alertPromise)
end)

exports('OxAlert', function(data)
    if alertPromise or alertFromOx then return false end
    if not openAlert(data) then return false end
    alertFromOx = true
    return true
end)

-- ox_lib cierra su diálogo (tiempo agotado o lib.closeAlertDialog): él resuelve su promesa.
exports('OxAlertClose', function()
    if not alertFromOx then return false end
    alertFromOx = false
    closeAlert()
    return true
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if alertPromise or alertFromOx then SetNuiFocus(false, false) end
end)
