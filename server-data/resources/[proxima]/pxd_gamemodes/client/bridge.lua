-- Puente con Qbox en el cliente. Sin Qbox/ox_inventory no hace nada.
-- APIs verificadas en el código fuente (octubre 2026):
--   exports.ox_inventory:weaponWheel(true|false)  «para minijuegos»: permite armas nativas
--     sin que el inventario las quite (comprobación weaponmismatch).
--   TriggerEvent('ox_inventory:disarm', noAnim)   guarda el arma del inventario.
--   LocalPlayer.state.invBusy                     bloquea abrir el inventario.
--   exports.qbx_medical:DisableBleeding / EnableBleeding / DisableDamageEffects / EnableDamageEffects
--   eventos qbx_medical:client:onPlayerLaststand / onPlayerDied (attacker = ped)
QboxBridge = { inMatch = false, downed = false }

local function started(name)
    return GetResourceState(name) == 'started'
end

function QboxBridge.active()
    return started('qbx_core')
end

--- Al entrar en una partida: el inventario RP queda guardado y bloqueado.
function QboxBridge.enter()
    QboxBridge.inMatch = true
    QboxBridge.downed = false
    if started('ox_inventory') then
        TriggerEvent('ox_inventory:disarm', true)
        exports.ox_inventory:weaponWheel(true)
        LocalPlayer.state.invBusy = true
    end
    if started('qbx_medical') then
        exports.qbx_medical:DisableBleeding()
        exports.qbx_medical:DisableDamageEffects()
    end
end

--- Tras reaparecer: Qbox desbloquea el inventario al revivir; lo volvemos a bloquear.
function QboxBridge.reapply()
    QboxBridge.downed = false
    if QboxBridge.inMatch and started('ox_inventory') then
        exports.ox_inventory:weaponWheel(true)
        LocalPlayer.state.invBusy = true
    end
end

function QboxBridge.leave()
    if not QboxBridge.inMatch then return end
    QboxBridge.inMatch = false
    QboxBridge.downed = false
    if started('ox_inventory') then
        exports.ox_inventory:weaponWheel(false)
        LocalPlayer.state.invBusy = false
    end
    if started('qbx_medical') then
        exports.qbx_medical:EnableBleeding()
        exports.qbx_medical:EnableDamageEffects()
    end
end

-- Qbox no deja morir: pasa a «caído». Dentro de una partida lo contamos como muerte.
local function onDowned(attacker)
    if not QboxBridge.inMatch or QboxBridge.downed then return end
    QboxBridge.downed = true
    local killer = nil
    if attacker and attacker ~= 0 and DoesEntityExist(attacker) and IsEntityAPed(attacker) then
        local idx = NetworkGetPlayerIndexFromPed(attacker)
        if idx ~= -1 and idx ~= PlayerId() then killer = GetPlayerServerId(idx) end
    end
    TriggerServerEvent('pxd_gm:server:died', killer)
end

AddEventHandler('qbx_medical:client:onPlayerLaststand', function(attacker) onDowned(attacker) end)
AddEventHandler('qbx_medical:client:onPlayerDied', function(attacker) onDowned(attacker) end)
