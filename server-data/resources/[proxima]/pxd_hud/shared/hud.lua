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

--- Límite anti-abuso de los eventos de estrés (son eventos de red: cualquier cliente
--- puede lanzarlos). `rec` guarda el historial del jugador; `lim` = {maxPerCall,
--- cooldown, window, maxPerWindow} en segundos. Devuelve cuánto se permite (0 = nada).
function H.limitStress(rec, amount, now, lim)
    if not lim then return amount end
    rec.list = rec.list or {}
    if lim.cooldown and rec.last and now - rec.last < lim.cooldown then return 0 end
    local kept, used = {}, 0
    for _, e in ipairs(rec.list) do
        if now - e.t < (lim.window or 60) then kept[#kept + 1] = e; used = used + e.n end
    end
    rec.list = kept
    local allowed = math.min(amount, lim.maxPerCall or amount, math.max(0, (lim.maxPerWindow or math.huge) - used))
    if allowed <= 0 then return 0 end
    rec.list[#rec.list + 1] = { t = now, n = allowed }
    rec.last = now
    return allowed
end

-- ── HUD 2.0 ───────────────────────────────────────────────────────────────
--- Rumbo de brújula (0 = norte, 90 = este) a partir del heading de GTA (0 = norte, 90 = oeste).
function H.compass(gtaHeading)
    local h = tonumber(gtaHeading) or 0
    if h ~= h then h = 0 end
    return floor((360 - (h % 360)) % 360 + 0.5) % 360
end

local CARDINALS = { 'N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO' }
--- Punto cardinal en español (O = oeste) de un rumbo de brújula.
function H.cardinal(deg)
    deg = (tonumber(deg) or 0) % 360
    return CARDINALS[floor((deg + 22.5) / 45) % 8 + 1]
end

--- Redondea a pasos (para no mandar a la NUI cada pequeño cambio).
function H.step(value, size)
    value, size = tonumber(value) or 0, size or 1
    return floor(value / size + 0.5) * size
end

--- Cuenta atrás de la paga (state bag pxdPayday, en segundos). nil si no hay dato válido.
--- Por encima del minuto se manda en minutos enteros; por debajo, de 5 en 5 s.
function H.payday(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds ~= seconds or seconds < 0 or seconds > 86400 then return nil end
    if seconds >= 60 then return math.ceil(seconds / 60) * 60 end
    return math.ceil(seconds / 5) * 5
end

--- Marcha que se muestra: P (motor parado), R (marcha atrás) o el número.
function H.gear(gear, engineOn)
    if not engineOn then return 'P' end
    gear = floor(tonumber(gear) or 0)
    if gear <= 0 then return 'R' end
    return tostring(min(gear, 9))
end

--- Salud de motor o carrocería (0..1000 en GTA; puede ser negativa) → 0..100.
function H.partPercent(value)
    return floor(H.clamp((tonumber(value) or 0) / 10, 0, 100) + 0.5)
end

--- Luces: 0 apagadas, 1 cortas, 2 largas (GET_VEHICLE_LIGHTS_STATE).
function H.lights(lightsOn, highbeamsOn)
    if highbeamsOn == true or highbeamsOn == 1 then return 2 end
    if lightsOn == true or lightsOn == 1 then return 1 end
    return 0
end

--- Combustible: el state bag `fuel` de ox_fuel si existe; si no, el nivel del vehículo.
function H.fuel(stateFuel, nativeFuel)
    local v = tonumber(stateFuel)
    if not v or v ~= v then v = tonumber(nativeFuel) or 0 end
    return floor(H.clamp(v, 0, 100) + 0.5)
end

--- Calle y zona en una sola estructura (cadenas ya traducidas por el juego).
function H.location(street, cross, zone)
    local function clean(v) v = type(v) == 'string' and v or '' if v == 'NULL' then v = '' end return v end
    street, cross, zone = clean(street), clean(cross), clean(zone)
    local line = street
    if cross ~= '' and cross ~= street then line = (street ~= '' and (street .. ' · ') or '') .. cross end
    return line, zone
end

-- Ajustes del jugador (se guardan con KVP en su equipo).
H.ELEMENTS = { 'vitals', 'money', 'alerts', 'clock', 'compass', 'location', 'voice', 'vehicle', 'minimap' }
H.SCALE_MIN, H.SCALE_MAX = 0.8, 1.3

function H.defaultSettings()
    local show = {}
    for _, k in ipairs(H.ELEMENTS) do show[k] = true end
    return { scale = 1.0, cinema = false, show = show }
end

--- Devuelve ajustes válidos a partir de cualquier cosa (JSON guardado, datos de la NUI…).
function H.sanitizeSettings(raw)
    local out = H.defaultSettings()
    if type(raw) ~= 'table' then return out end
    local scale = tonumber(raw.scale)
    if scale and scale == scale then out.scale = floor(H.clamp(scale, H.SCALE_MIN, H.SCALE_MAX) * 20 + 0.5) / 20 end
    out.cinema = raw.cinema == true
    if type(raw.show) == 'table' then
        for _, k in ipairs(H.ELEMENTS) do
            if raw.show[k] ~= nil then out.show[k] = raw.show[k] == true end
        end
    end
    return out
end

--- ¿Se dibuja el HUD? Lo apagan otros recursos (SetVisible), el modo cine, la pausa o no haber entrado.
function H.shouldShow(o)
    return o.visible == true and o.cinema ~= true and o.loggedIn == true and o.paused ~= true and o.hudHidden ~= true
end

return H
