-- Lógica pura del HUD (sin natives): formateo, niveles de aviso, anclaje del minimapa,
-- estrés y diferencias entre estados. Se prueba con Lua 5.4 (tests/lua/test_hud.lua).
PXDHud = PXDHud or {}
local H = PXDHud

local floor, max, min = math.floor, math.max, math.min

function H.clamp(v, lo, hi)
    v = tonumber(v) or 0
    if v ~= v then return lo end -- NaN
    return max(lo, min(hi, v))
end

--- Dinero con separador de miles: 95846 → "$95,846"; -1200 → "-$1,200".
function H.formatMoney(amount)
    amount = floor(tonumber(amount) or 0)
    local neg = amount < 0
    local s = tostring(neg and -amount or amount)
    s = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (neg and '-$' or '$') .. s
end

--- Salud de 0 a 100. En GTA la salud del ped va de 100 (muerto) al máximo (200 en Qbox).
function H.healthPercent(health, maxHealth)
    health, maxHealth = tonumber(health) or 0, tonumber(maxHealth) or 200
    if maxHealth <= 100 then return 0 end
    return floor(H.clamp((health - 100) / (maxHealth - 100) * 100, 0, 100) + 0.5)
end

--- Nivel de una barra: 'ok', 'low' (≤ warn) o 'critical' (≤ critical).
--- `inverse` para valores donde lo malo es tener mucho (estrés).
function H.level(value, warn, critical, inverse)
    value = H.clamp(value, 0, 100)
    if inverse then value = 100 - value end
    if value <= critical then return 'critical' end
    if value <= warn then return 'low' end
    return 'ok'
end

--- m/s → km/h o mph (entero hacia arriba, como el velocímetro de qbx_hud).
function H.speed(metersPerSecond, unit)
    local mult = unit == 'mph' and 2.23694 or 3.6
    return math.ceil(max(0, tonumber(metersPerSecond) or 0) * mult)
end

--- Nombre del modo de voz de pma-voice (Cfg.voiceModes: "Whisper", "Normal", "Shouting").
local VOICE = { Whisper = 'Susurro', Normal = 'Normal', Shouting = 'Gritando' }
function H.voiceLabel(proximity)
    if type(proximity) ~= 'table' then return 'Normal' end
    return VOICE[proximity.mode] or tostring(proximity.mode or 'Normal')
end

--- Rectángulo del minimapa por defecto, en fracciones de pantalla (0..1).
--- Mismo cálculo que usa la comunidad a partir de GET_SAFE_ZONE_SIZE, GET_ASPECT_RATIO
--- y GET_ACTUAL_SCREEN_RESOLUTION; el minimapa conserva su proporción en pantallas anchas.
function H.minimapAnchor(safezone, aspect, resX, resY)
    safezone = tonumber(safezone) or 1.0
    aspect = tonumber(aspect) or (16 / 9)
    resX, resY = tonumber(resX) or 1920, tonumber(resY) or 1080
    local margin = math.abs(safezone - 1.0) * 10
    local xs, ys = 1.0 / resX, 1.0 / resY
    local a = {}
    a.width = xs * (resX / (4 * aspect))
    a.height = ys * (resY / 5.674)
    a.left = xs * (resX * ((1.0 / 20.0) * margin))
    a.bottom = 1.0 - ys * (resY * ((1.0 / 20.0) * margin))
    a.right = a.left + a.width
    a.top = a.bottom - a.height
    return a
end

--- Estrés: misma validación que qbx_hud (número finito, 0 < n ≤ 100).
function H.validStressAmount(n)
    return type(n) == 'number' and n == n and n > 0 and n <= 100
end

function H.applyStress(current, delta)
    return H.clamp((tonumber(current) or 0) + (tonumber(delta) or 0), 0, 100)
end

--- Busca en una tabla de tramos {min, max, <campo>} el que contiene `value`.
function H.band(bands, value, field, default)
    for _, b in ipairs(bands or {}) do
        if value >= b.min and value <= b.max then return b[field] end
    end
    return default
end

--- Hora del juego "08:05".
function H.clock(hours, minutes)
    return ('%02d:%02d'):format(floor(H.clamp(hours, 0, 23)), floor(H.clamp(minutes, 0, 59)))
end

--- Devuelve solo las claves que cambiaron (o nil si nada cambió), para enviar menos a la NUI.
function H.diff(prev, next)
    local out, changed = {}, false
    for k, v in pairs(next) do
        if prev[k] ~= v then out[k] = v; changed = true end
    end
    return changed and out or nil
end

return H
