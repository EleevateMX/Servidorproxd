-- Lógica pura de pxd_ui (sin natives): normaliza lo que llega de ox_lib, qbx_core o de
-- nuestros exports antes de enviarlo a la NUI. Se prueba con Lua 5.4 (tests/lua/test_ui.lua).
PXDUi = PXDUi or {}
local U = PXDUi

local TONES = { success = 'success', warning = 'warning', warn = 'warning', error = 'error', danger = 'error' }
local CORNERS = {
    top = true, ['top-right'] = true, ['top-left'] = true, bottom = true, ['bottom-right'] = true,
    ['bottom-left'] = true, ['center-right'] = true, ['center-left'] = true,
}
local TEXT_POS = { ['right-center'] = true, ['left-center'] = true, ['top-center'] = true, ['bottom-center'] = true }

local function str(v, max)
    if type(v) == 'number' then v = tostring(v) end
    if type(v) ~= 'string' then return nil end
    v = v:gsub('%z', '')
    if v == '' then return nil end
    if #v > max then v = v:sub(1, max) end
    return v
end
U.str = str

local function num(v, lo, hi, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    return math.max(lo, math.min(hi, v))
end

--- Tono de un aviso: los tipos de ox_lib y los de qbx_core ('inform', 'primary'…) → info/success/warning/error.
function U.tone(kind)
    if type(kind) ~= 'string' then return 'info' end
    return TONES[kind:lower()] or 'info'
end

--- Aviso listo para la NUI a partir de NotifyProps de ox_lib (o de nuestro export Notify).
--- Devuelve nil si no hay nada que mostrar. Solo pasa campos conocidos y acotados.
function U.notify(data, cfg)
    if type(data) ~= 'table' then return nil end
    cfg = cfg or {}
    local title, description = str(data.title, 120), str(data.description, 600)
    if not title and not description then return nil end
    local id = data.id
    if type(id) == 'number' then id = tostring(id) end
    return {
        id = type(id) == 'string' and id:sub(1, 120) or nil,
        title = title,
        description = description,
        type = U.tone(data.type or data.status),
        duration = num(data.duration, cfg.minDuration or 1000, cfg.maxDuration or 30000, cfg.duration or 3000),
        showDuration = data.showDuration ~= false,
        position = CORNERS[data.position] and data.position or (cfg.position or 'top-right'),
        iconColor = str(data.iconColor, 32),
    }
end

--- Text UI: `text` + opciones de ox_lib (position, iconColor). nil si no hay texto.
function U.textUi(text, options, cfg)
    text = str(text, 400)
    if not text then return nil end
    options = type(options) == 'table' and options or {}
    return {
        text = text,
        position = TEXT_POS[options.position] and options.position or ((cfg and cfg.position) or 'right-center'),
        iconColor = str(options.iconColor, 32),
    }
end

--- Progreso a partir del mensaje NUI de ox_lib ({ action = 'progress' | 'circleProgress', data = {...} })
--- o de nuestros datos. Devuelve datos para la NUI y la duración en ms (0 = nada).
function U.progress(data, circle)
    if type(data) ~= 'table' then return nil, 0 end
    local duration = num(data.duration, 0, 600000, 0)
    if duration <= 0 then return nil, 0 end
    return {
        label = str(data.label, 120),
        duration = math.floor(duration),
        position = data.position == 'middle' and 'middle' or 'bottom',
    }, math.floor(duration), circle == true
end

--- Diálogo de confirmación (AlertDialogProps de ox_lib).
function U.alert(data)
    if type(data) ~= 'table' then return nil end
    local header, content = str(data.header, 200), str(data.content, 2000)
    if not header and not content then return nil end
    local labels = type(data.labels) == 'table' and data.labels or {}
    return {
        header = header, content = content, centered = data.centered == true, cancel = data.cancel == true,
        labels = { confirm = str(labels.confirm, 40), cancel = str(labels.cancel, 40) },
    }
end

--- Resultado de un diálogo que llega de la NUI: solo 'confirm' o 'cancel'.
function U.alertResult(v)
    return v == 'confirm' and 'confirm' or 'cancel'
end

return U
