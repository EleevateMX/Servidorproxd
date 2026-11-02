-- Agacharse / levantarse con Ctrl izquierdo (alternancia).
-- Reutiliza el state bag local «crouch» de qbx_crouch (qbx_smallresources): su
-- manejador pone y quita la animación «move_Ped_crouched», así no hay dos animaciones.
-- Si qbx_smallresources no está arrancado, pxd_interact aplica la misma animación.
-- Ctrl izquierdo es también el sigilo nativo de GTA (control 36, INPUT_DUCK): se anula
-- a pie para que no se mezclen; apuntar, correr y disparar no se tocan.
if not Config.crouch.enabled then return end

local CLIPSET = 'move_Ped_crouched'

local function ownAnimation(value)
    local ped = PlayerPedId()
    if value then
        RequestAnimSet(CLIPSET)
        local t = GetGameTimer() + 1000
        while not HasAnimSetLoaded(CLIPSET) and GetGameTimer() < t do Wait(10) end
        SetPedMovementClipset(ped, CLIPSET, 1.0)
        SetPedStrafeClipset(ped, 'move_Ped_crouched_strafing')
    else
        ResetPedMovementClipset(ped, 1.0)
        ResetPedWeaponMovementClipset(ped)
        ResetPedStrafeClipset(ped)
    end
    RemoveAnimSet(CLIPSET)
end

local function canCrouch(ped)
    return not IsPedInAnyVehicle(ped, false) and not IsPedDeadOrDying(ped, true) and not IsPedRagdoll(ped)
        and not IsPedSwimming(ped) and not IsPauseMenuActive() and not IsNuiFocused()
        and not LocalPlayer.state.pxd_noclip -- en noclip de staff (pxd_admin) no se agacha
end

-- Mismo estado que qbx_crouch (no replicado, como él: el clipset del ped ya se sincroniza).
local function setCrouch(value)
    LocalPlayer.state:set('crouch', value, false)
    if GetResourceState('qbx_smallresources') ~= 'started' then ownAnimation(value) end
end

RegisterCommand('+pxd_agacharse', function()
    local ped = PlayerPedId()
    if not canCrouch(ped) then return end
    setCrouch(not LocalPlayer.state.crouch)
end, false)
RegisterCommand('-pxd_agacharse', function() end, false)
RegisterKeyMapping('+pxd_agacharse', 'Agacharse / levantarse (Próxima RP)', 'keyboard', Config.keys.crouch)

-- Al subir a un vehículo, morir o caer, se levanta solo.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if LocalPlayer.state.crouch and not canCrouch(ped) and not IsPauseMenuActive() and not IsNuiFocused() then
            setCrouch(false)
        end
        Wait(500)
    end
end)

-- Sin sigilo nativo a pie (Ctrl izquierdo ya es agacharse).
if Config.crouch.disableStealth then
    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                DisableControlAction(0, 36, true)
                if GetPedStealthMovement(ped) then SetPedStealthMovement(ped, false, 'DEFAULT_ACTION') end
                Wait(0)
            else
                Wait(500)
            end
        end
    end)
end
