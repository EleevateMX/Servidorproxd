-- Lógica pura de pxd_interact (sin natives; recibe `now` y funciones de azar).
-- Se carga en cliente y servidor.
PXDInteract = PXDInteract or {}

-- Sin caracteres ambiguos: ni 0/O ni 1/I.
PXDInteract.ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

--- ID público tipo «PROX-7KQ2». `rand(n)` devuelve un entero 1..n.
function PXDInteract.generateId(rand, prefix, len)
    prefix, len = prefix or 'PROX-', len or 4
    local a, out = PXDInteract.ALPHABET, {}
    for i = 1, len do
        local k = rand(#a)
        out[i] = a:sub(k, k)
    end
    return prefix .. table.concat(out)
end

function PXDInteract.isValidId(id, prefix, len)
    prefix, len = prefix or 'PROX-', len or 4
    if type(id) ~= 'string' or #id ~= #prefix + len or id:sub(1, #prefix) ~= prefix then return false end
    local body = id:sub(#prefix + 1)
    for i = 1, #body do
        if not PXDInteract.ALPHABET:find(body:sub(i, i), 1, true) then return false end
    end
    return true
end

--- Genera un ID que no esté ocupado (`isTaken(id)`), con un máximo de intentos.
function PXDInteract.uniqueId(isTaken, rand, prefix, len, tries)
    for _ = 1, tries or 50 do
        local id = PXDInteract.generateId(rand, prefix, len)
        if not isTaken(id) then return id end
    end
    return nil
end

--- Aplana candidatos cercanos en la lista de opciones que se muestra.
--- candidates: { { key, dist, priority?, options = { {label, icon, name?, hidden?}... } } }
--- Devuelve { {key, index, label, icon, dist} } ordenada: prioridad ↓, distancia ↑, orden original.
function PXDInteract.flatten(candidates, max)
    local sorted = {}
    for i, c in ipairs(candidates or {}) do
        if type(c.options) == 'table' and #c.options > 0 then
            sorted[#sorted + 1] = { c = c, i = i }
        end
    end
    table.sort(sorted, function(a, b)
        local pa, pb = a.c.priority or 0, b.c.priority or 0
        if pa ~= pb then return pa > pb end
        if a.c.dist ~= b.c.dist then return (a.c.dist or 0) < (b.c.dist or 0) end
        return a.i < b.i
    end)
    local out = {}
    for _, s in ipairs(sorted) do
        for idx, o in ipairs(s.c.options) do
            if not o.hidden and type(o.label) == 'string' and o.label ~= '' then
                out[#out + 1] = { key = s.c.key, index = idx, label = o.label, icon = o.icon or 'hand', dist = s.c.dist }
                if #out >= (max or 6) then return out end
            end
        end
    end
    return out
end

--- Firma para saber si la lista cambió (y no reenviarla a la NUI en cada vuelta).
function PXDInteract.signature(list)
    local parts = {}
    for i, o in ipairs(list or {}) do parts[i] = tostring(o.key) .. '#' .. o.index .. '#' .. o.label .. '#' .. o.icon end
    return table.concat(parts, '|')
end

--- Índice circular 1..n.
function PXDInteract.wrap(i, n)
    if n <= 0 then return 1 end
    return (i - 1) % n + 1
end

--- Conocidos: { [id] = { name, t } }. Añade o actualiza; si se pasa del límite,
--- olvida al más antiguo. Devuelve la tabla (modificada).
function PXDInteract.addKnown(known, id, name, now, max)
    known = type(known) == 'table' and known or {}
    known[id] = { name = name, t = now }
    local count, oldestId, oldestT = 0, nil, math.huge
    for k, v in pairs(known) do
        count = count + 1
        if type(v) == 'table' and (v.t or 0) < oldestT then oldestId, oldestT = k, v.t or 0 end
    end
    if count > (max or 200) and oldestId and oldestId ~= id then known[oldestId] = nil end
    return known
end

--- Texto de la etiqueta sobre la cabeza.
function PXDInteract.tagLabel(known, id, unknown)
    local k = type(known) == 'table' and known[id]
    local name = type(k) == 'table' and k.name or nil
    if name and name ~= '' then return name .. ' · ' .. id end
    return (unknown or 'Desconocido') .. ' · ' .. id
end

--- Enfriamiento: true si `key` puede repetirse (y lo registra).
function PXDInteract.cooldown(store, key, now, seconds)
    local last = store[key]
    if last and now - last < seconds then return false end
    store[key] = now
    return true
end

--- Nombre visible de un personaje a partir de su charinfo (recortado).
function PXDInteract.charName(charinfo)
    if type(charinfo) ~= 'table' then return nil end
    local function trim(v) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
    local first, last = trim(charinfo.firstname), trim(charinfo.lastname)
    local name = first ~= '' and last ~= '' and (first .. ' ' .. last) or (first .. last)
    if name == '' then return nil end
    return name:sub(1, 40)
end

return PXDInteract
