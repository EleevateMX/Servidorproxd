-- Lógica pura de pxd_restart: qué mostrar según los segundos que faltan.
PXDRestart = {}

--- @return 'screen'|'toast'|nil
function PXDRestart.view(secondsRemaining, toastMinutes, screenSeconds)
    local s = tonumber(secondsRemaining)
    if not s or s < 0 then return nil end
    if s <= (screenSeconds or 60) then return 'screen' end
    local minutes = math.floor(s / 60 + 0.5)
    for _, m in ipairs(toastMinutes or {}) do
        if m == minutes then return 'toast' end
    end
    return nil
end

function PXDRestart.toastText(secondsRemaining)
    local minutes = math.floor((tonumber(secondsRemaining) or 0) / 60 + 0.5)
    if minutes <= 1 then return 'La ciudad se reinicia en 1 minuto.' end
    return ('La ciudad se reinicia en %d minutos.'):format(minutes)
end

return PXDRestart
