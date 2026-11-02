-- pxd_voice: N habla (pma-voice), doble N y mantener grita, J alterna susurro.
-- Usa los exports de pma-voice overrideProximityRange / clearProximityOverride /
-- setAllowProximityCycleState (client/commands.lua de pma-voice) y publica el modo en
-- el state bag local `pxdVoice` (misma forma que `proximity`) para el HUD.
local V = PXDVoice
local ranges = V.ranges(GetConvar('voice_useNativeAudio', 'false') == 'true', Config.ranges)
local base, shouting = 'normal', false
local tap = V.newTap()
local wanted = V.state('normal', ranges)

local function pma() return GetResourceState('pma-voice') == 'started' end

local function apply()
    wanted = V.state(V.effective(base, shouting), ranges)
    LocalPlayer.state:set('pxdVoice', wanted, false)
    if pma() then
        exports['pma-voice']:overrideProximityRange(wanted.distance, Config.disablePmaCycle)
    end
end

-- Susurro: pulsar para activar/desactivar.
RegisterCommand(Config.whisperCommand, function()
    base = V.toggleWhisper(base)
    apply()
end, false)
RegisterKeyMapping(Config.whisperCommand, 'Susurrar (activar/desactivar)', 'keyboard', Config.whisperKey)

-- Doble N y mantener: gritar mientras se mantiene.
CreateThread(function()
    local ptt = Config.pushToTalkControl
    while true do
        Wait(0)
        -- En la radio pma-voice mantiene pulsado el control 249: no cuenta como voz local.
        if not LocalPlayer.state.radioActive then
            if IsControlJustPressed(0, ptt) or IsDisabledControlJustPressed(0, ptt) then
                if V.press(tap, GetGameTimer(), Config.doubleTapMs) and not shouting then
                    shouting = true
                    apply()
                end
            elseif shouting and (IsControlJustReleased(0, ptt) or IsDisabledControlJustReleased(0, ptt)) then
                shouting = false
                apply()
            end
        end
    end
end)

-- pma-voice vuelve a su modo al (re)conectar a mumble o al ciclar: lo reaplicamos.
CreateThread(function()
    Wait(2000)
    apply()
    while true do
        Wait(1000)
        if pma() and V.needsReapply(LocalPlayer.state.proximity, wanted) then apply() end
    end
end)

AddEventHandler('mumbleConnected', function()
    SetTimeout(1000, apply)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == 'pma-voice' then SetTimeout(1000, apply) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    LocalPlayer.state:set('pxdVoice', nil, false)
    if pma() then exports['pma-voice']:clearProximityOverride() end
end)

exports('getMode', function() return wanted.pxd end)
