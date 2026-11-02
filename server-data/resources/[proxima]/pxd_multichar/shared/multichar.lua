-- Lógica pura de pxd_multichar (sin natives): validación del registro, formato y ranuras.
-- La usan cliente, servidor y las pruebas (tests/lua/test_multichar.lua).
PXDChar = PXDChar or {}

local LOWER_TO_UPPER = {
    ['á'] = 'Á', ['é'] = 'É', ['í'] = 'Í', ['ó'] = 'Ó', ['ú'] = 'Ú', ['ü'] = 'Ü', ['ñ'] = 'Ñ',
    ['à'] = 'À', ['è'] = 'È', ['ì'] = 'Ì', ['ò'] = 'Ò', ['ù'] = 'Ù', ['ç'] = 'Ç', ['ã'] = 'Ã', ['õ'] = 'Õ',
    ['â'] = 'Â', ['ê'] = 'Ê', ['ô'] = 'Ô',
}
local UPPER_TO_LOWER = {}
for lower, upper in pairs(LOWER_TO_UPPER) do UPPER_TO_LOWER[upper] = lower end

local function upperChar(c)
    if #c == 1 then return c:upper() end
    return LOWER_TO_UPPER[c] or c
end

local function lowerChar(c)
    if #c == 1 then return c:lower() end
    return UPPER_TO_LOWER[c] or c
end

local function isLetter(c)
    if #c == 1 then return c:match('%a') ~= nil end
    return LOWER_TO_UPPER[c] ~= nil or UPPER_TO_LOWER[c] ~= nil
end

--- Recorta espacios y colapsa los repetidos.
function PXDChar.clean(str)
    if type(str) ~= 'string' then return nil end
    return (str:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', ''))
end

--- «josé ÁNGEL de-la o'neil» → «José Ángel De-La O'Neil» (UTF-8, español y portugués).
function PXDChar.capitalize(str)
    local out, startWord = {}, true
    for _, cp in utf8.codes(str) do
        local c = utf8.char(cp)
        if isLetter(c) then
            out[#out + 1] = startWord and upperChar(c) or lowerChar(c)
            startWord = false
        else
            out[#out + 1] = c
            startWord = (c == ' ' or c == '-' or c == "'")
        end
    end
    return table.concat(out)
end

local function hasProfanity(str, words)
    if not words then return false end
    local lower = str:lower()
    if words[lower] then return true end
    for word in lower:gmatch('[^%s%-]+') do
        if words[word] then return true end
    end
    return false
end

--- Nombre o apellido: 2–25 letras, hasta 3 palabras (espacio, guion o apóstrofo entre letras).
---@return string? value, string? err
function PXDChar.validateName(str, label, profanity)
    str = PXDChar.clean(str)
    if not str or str == '' then return nil, ('Escribe el %s.'):format(label) end
    if not utf8.len(str) then return nil, ('El %s tiene caracteres no válidos.'):format(label) end
    local len = utf8.len(str)
    if len < 2 then return nil, ('El %s es demasiado corto.'):format(label) end
    if len > 25 then return nil, ('El %s es demasiado largo (máximo 25).'):format(label) end
    local words, prev = 1, nil
    for _, cp in utf8.codes(str) do
        local c = utf8.char(cp)
        if c == ' ' or c == '-' or c == "'" then
            if not prev or not isLetter(prev) then return nil, ('El %s solo puede llevar letras.'):format(label) end
            if c == ' ' then words = words + 1 end
        elseif not isLetter(c) then
            return nil, ('El %s solo puede llevar letras.'):format(label)
        end
        prev = c
    end
    if not isLetter(prev) then return nil, ('El %s solo puede llevar letras.'):format(label) end
    if words > 3 then return nil, ('El %s puede tener como máximo 3 palabras.'):format(label) end
    if hasProfanity(str, profanity) then return nil, ('Ese %s no está permitido.'):format(label) end
    return PXDChar.capitalize(str)
end

local DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

--- Fecha AAAA-MM-DD real y dentro de [min, max] (comparación de cadenas ISO).
function PXDChar.validateBirthdate(str, min, max)
    if type(str) ~= 'string' then return nil, 'Elige la fecha de nacimiento.' end
    local y, m, d = str:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 then return nil, 'La fecha de nacimiento no es válida.' end
    local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
    local maxDay = (m == 2 and leap) and 29 or DAYS[m]
    if d > maxDay then return nil, 'La fecha de nacimiento no es válida.' end
    if (min and str < min) or (max and str > max) then
        return nil, ('La fecha debe estar entre %s y %s.'):format(min or '…', max or '…')
    end
    return str
end

--- Busca la nacionalidad en la lista (sin distinguir mayúsculas) y devuelve la forma oficial.
function PXDChar.validateNationality(str, list, limit, profanity)
    str = PXDChar.clean(str)
    if not str or str == '' then return nil, 'Elige la nacionalidad.' end
    if limit and list and #list > 0 then
        local lower = str:lower()
        for i = 1, #list do
            if list[i]:lower() == lower then return list[i] end
        end
        return nil, 'Elige una nacionalidad de la lista.'
    end
    if utf8.len(str) == nil or utf8.len(str) > 30 then return nil, 'La nacionalidad no es válida.' end
    if hasProfanity(str, profanity) then return nil, 'Esa nacionalidad no está permitida.' end
    return PXDChar.capitalize(str)
end

---@class PXDRegistrationOpts
---@field nationalities string[]?
---@field limitNationalities boolean?
---@field dateMin string?
---@field dateMax string?
---@field profanity table<string, boolean>?

--- Valida y normaliza el formulario. Devuelve los datos listos para qbx_core:server:createCharacter.
---@return table? data, string? err, string? field
function PXDChar.validateRegistration(input, opts)
    if type(input) ~= 'table' then return nil, 'Datos no válidos.', nil end
    opts = opts or {}
    local firstname, err = PXDChar.validateName(input.firstname, 'nombre', opts.profanity)
    if not firstname then return nil, err, 'firstname' end
    local lastname
    lastname, err = PXDChar.validateName(input.lastname, 'apellido', opts.profanity)
    if not lastname then return nil, err, 'lastname' end
    local nationality
    nationality, err = PXDChar.validateNationality(input.nationality, opts.nationalities, opts.limitNationalities, opts.profanity)
    if not nationality then return nil, err, 'nationality' end
    local gender = tonumber(input.gender)
    if gender ~= 0 and gender ~= 1 then return nil, 'Elige el sexo del personaje.', 'gender' end
    local birthdate
    birthdate, err = PXDChar.validateBirthdate(input.birthdate, opts.dateMin, opts.dateMax)
    if not birthdate then return nil, err, 'birthdate' end
    return {
        firstname = firstname,
        lastname = lastname,
        nationality = nationality,
        gender = gender,
        birthdate = birthdate,
    }
end

--- 95846 → «$95,846».
function PXDChar.formatMoney(n)
    n = math.floor(tonumber(n) or 0)
    local neg = n < 0
    local s = tostring(math.abs(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (neg and '-$' or '$') .. s
end

--- Segundos → «29 días y 8 horas», «3 h 12 min», «45 min», «Recién llegado».
function PXDChar.formatPlaytime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 60 then return 'Recién llegado' end
    local days = seconds // 86400
    local hours = (seconds % 86400) // 3600
    local mins = (seconds % 3600) // 60
    if days > 0 then
        local d = days == 1 and '1 día' or (days .. ' días')
        if hours == 0 then return d end
        return d .. ' y ' .. (hours == 1 and '1 hora' or (hours .. ' horas'))
    end
    if hours > 0 then return ('%d h %d min'):format(hours, mins) end
    return ('%d min'):format(mins)
end

local function num(v) return tonumber(v) or 0 end
local function str(v, max)
    if type(v) ~= 'string' then return nil end
    return #v > (max or 80) and v:sub(1, max or 80) or v
end

--- Convierte una entidad de qbx_core (getCharacters) y su resumen de progreso
--- en lo que necesita la interfaz. Nunca pasa campos que no conocemos.
function PXDChar.toCard(entity, summary)
    if type(entity) ~= 'table' or type(entity.charinfo) ~= 'table' then return nil end
    local ci, money, job = entity.charinfo, entity.money or {}, entity.job or {}
    local grade = type(job.grade) == 'table' and job.grade or {}
    local card = {
        citizenid = str(entity.citizenid, 16),
        firstname = str(ci.firstname, 50) or '',
        lastname = str(ci.lastname, 50) or '',
        gender = num(ci.gender) == 1 and 1 or 0,
        birthdate = str(ci.birthdate, 20),
        nationality = str(ci.nationality, 50),
        job = str(job.label, 50),
        grade = str(grade.name, 50),
        onduty = job.onduty == true,
        cash = num(money.cash),
        bank = num(money.bank),
    }
    if type(summary) == 'table' then
        card.level = tonumber(summary.level)
        card.xp = tonumber(summary.xp)
        card.xpNext = tonumber(summary.xpNext)
        card.playtime = tonumber(summary.playtime)
    end
    return card
end

--- Ranuras de la columna izquierda: personajes, libres hasta `allowed` y bloqueadas extra.
function PXDChar.buildSlots(cards, allowed, lockedShown)
    local slots = {}
    allowed = math.max(num(allowed), #cards)
    for i = 1, #cards do slots[#slots + 1] = { kind = 'character', index = i, citizenid = cards[i].citizenid } end
    for i = #cards + 1, allowed do slots[#slots + 1] = { kind = 'free', index = i } end
    for i = 1, math.max(0, num(lockedShown)) do slots[#slots + 1] = { kind = 'locked', index = allowed + i } end
    return slots
end

--- ¿Sigue qbx_core gestionando los personajes? (texto de qbx_core/config/client.lua)
function PXDChar.qbxManagesCharacters(configText)
    if type(configText) ~= 'string' then return true end
    return configText:match('useExternalCharacters%s*=%s*true') == nil
end

--- ¿qbx_core da apartamento inicial? (config/client.lua → characters.startingApartment).
--- Si no se puede leer, se asume el valor por defecto de qbx_core (true).
function PXDChar.qbxStartingApartment(configText)
    if type(configText) ~= 'string' then return true end
    return configText:match('startingApartment%s*=%s*false') == nil
end

local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end

--- Lista de opciones de aparición para la interfaz: valida coordenadas y da a cada
--- opción un id estable. kinds: 'last' (última ubicación), 'property' (casa propia)
--- y 'point' (puntos de la ciudad de Config.spawnPoints).
--- Devuelve la lista para la NUI y un índice id → opción (con coords) para el cliente.
function PXDChar.buildSpawnOptions(last, properties, points)
    local list, byId = {}, {}
    local function add(opt)
        local c = opt.coords
        if type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' then return end
        if not (finite(c.x) and finite(c.y) and finite(c.z)) then return end
        byId[opt.id] = opt
        list[#list + 1] = { id = opt.id, kind = opt.kind, label = opt.label, detail = opt.detail, image = opt.image }
    end
    if type(last) == 'table' and last.coords then
        add({ id = 'last', kind = 'last', label = 'Última ubicación', detail = 'Donde lo dejaste', coords = last.coords, propertyId = last.propertyId, image = last.image })
    end
    for i, p in ipairs(type(properties) == 'table' and properties or {}) do
        if type(p) == 'table' and type(p.label) == 'string' then
            add({ id = 'property:' .. tostring(p.propertyId or i), kind = 'property', label = p.label, detail = 'Tu casa', coords = p.coords, propertyId = p.propertyId, image = p.image })
        end
    end
    for i, p in ipairs(type(points) == 'table' and points or {}) do
        if type(p) == 'table' and type(p.label) == 'string' then
            add({ id = 'point:' .. i, kind = 'point', label = p.label, detail = p.detail, coords = p.coords, image = p.image })
        end
    end
    return list, byId
end

--- ¿El nombre escrito para confirmar el borrado coincide con el del personaje?
function PXDChar.confirmName(card, typed)
    if type(card) ~= 'table' or type(typed) ~= 'string' then return false end
    local want = PXDChar.capitalize(PXDChar.clean((card.firstname or '') .. ' ' .. (card.lastname or '')) or '')
    return want ~= '' and PXDChar.capitalize(PXDChar.clean(typed) or '') == want
end

return PXDChar
