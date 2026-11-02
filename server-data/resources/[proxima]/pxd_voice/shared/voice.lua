-- Lógica pura de pxd_voice: doble pulsación, modo efectivo y rango. Sin natives.
PXDVoice = {}

local LABELS = {
    whisper = { index = 1, mode = 'Whisper' },
    normal  = { index = 2, mode = 'Normal' },
    shout   = { index = 3, mode = 'Shouting' },
}

--- Detector de doble pulsación.
function PXDVoice.newTap()
    return { last = nil }
end

--- Registra una pulsación en `now` (ms). Devuelve true si es la segunda dentro de la
--- ventana (y la consume, para que una tercera pulsación no cuente como doble otra vez).
function PXDVoice.press(tap, now, windowMs)
    local last = tap.last
    if last and now - last >= 0 and now - last <= (windowMs or 300) then
        tap.last = nil
        return true
    end
    tap.last = now
    return false
end

--- Modo efectivo: gritar manda sobre el modo base (normal o susurro).
function PXDVoice.effective(base, shouting)
    if shouting then return 'shout' end
    return base == 'whisper' and 'whisper' or 'normal'
end

function PXDVoice.toggleWhisper(base)
    return base == 'whisper' and 'normal' or 'whisper'
end

--- Tabla de rangos según el tipo de audio de pma-voice.
function PXDVoice.ranges(useNativeAudio, cfg)
    cfg = cfg or {}
    local r = useNativeAudio and cfg.native or cfg.standard
    return r or { whisper = 2.0, normal = 8.0, shout = 20.0 }
end

--- Estado con la misma forma que el state bag `proximity` de pma-voice
--- ({index, distance, mode}) para que el HUD lo lea igual.
function PXDVoice.state(mode, ranges)
    local l = LABELS[mode] or LABELS.normal
    return { index = l.index, mode = l.mode, distance = (ranges[mode] or ranges.normal) + 0.0, pxd = mode }
end

--- ¿Hay que volver a aplicar? (pma-voice reescribe la proximidad al reconectar a mumble).
function PXDVoice.needsReapply(current, wanted)
    if type(current) ~= 'table' or type(current.distance) ~= 'number' then return true end
    return math.abs(current.distance - wanted.distance) > 0.01
end

return PXDVoice
