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

-- ── Controles: E cede, B recoge, prioridades ────────────────────────────────

--- Prioridades de las acciones con E (mayor = gana). Una pulsación = una acción.
-- Las zonas (puntos que un recurso registra a propósito, p. ej. «Entregar el paquete»
-- junto a tu furgoneta) van por delante del maletero, que se detecta en cualquier coche.
PXDInteract.PRIORITY = { invite = 100, job = 40, npc = 35, zone = 30, trunk = 25, player = 10 }

--- ¿Debe pxd_interact ceder la E a otro recurso en este momento?
--- s = { textUI, door, sprinting, shift, pump }
--- Cede si otro recurso muestra su aviso (ox_lib textUI: puertas de ox_doorlock,
--- teletransportes…), si hay una puerta de ox_doorlock al alcance, si corres o
--- esprintas (placaje de qbx_tackle), si mantienes Mayús (empujar vehículo) o si
-- estás junto a un surtidor (ox_fuel reposta con E).
function PXDInteract.shouldYield(s)
    if type(s) ~= 'table' then return false end
    return s.textUI == true or s.door == true or s.sprinting == true or s.shift == true or s.pump == true
end

--- Elige el objeto del suelo a recoger: el más cercano dentro de `maxDist`; si hay
--- empate (diferencia ≤ `tie` m), el que está más de frente (producto escalar con
--- la dirección del jugador). cands: { {id, x, y, z} }, pos/fwd: {x, y, z}.
function PXDInteract.pickDrop(cands, pos, fwd, maxDist, tie)
    tie = tie or 0.15
    local best, bestD, bestDot
    for _, c in ipairs(cands or {}) do
        local dx, dy, dz = c.x - pos.x, c.y - pos.y, (c.z or pos.z) - pos.z
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)
        if d <= (maxDist or 1.6) then
            local len = math.sqrt(dx * dx + dy * dy)
            local dot = len > 0 and (dx * fwd.x + dy * fwd.y) / len or 1
            if not best or d < bestD - tie or (math.abs(d - bestD) <= tie and dot > bestDot) then
                best, bestD, bestDot = c, d, dot
            end
        end
    end
    return best, bestD
end

--- Bloqueos con caducidad (para que dos jugadores no recojan lo mismo a la vez).
function PXDInteract.tryLock(store, key, now, ttl)
    local t = store[key]
    if t and now < t then return false end
    store[key] = now + (ttl or 5)
    return true
end
function PXDInteract.unlock(store, key) store[key] = nil end

local DROP_ID = '^[%w_]+%-%d+$'

--- Valida una recogida en el servidor. Devuelve ok, motivo.
--- p = { dropId, slot, inv = {type, coords, items}, playerPos, maxDist, canCarry, inVehicle, dead }
function PXDInteract.validatePickup(p)
    if type(p) ~= 'table' or type(p.dropId) ~= 'string' or not p.dropId:match(DROP_ID) then return false, 'invalid' end
    if type(p.slot) ~= 'number' or p.slot < 1 or p.slot % 1 ~= 0 then return false, 'invalid' end
    if p.dead or p.inVehicle then return false, 'state' end
    local inv = p.inv
    if type(inv) ~= 'table' or inv.type ~= 'drop' or type(inv.items) ~= 'table' then return false, 'gone' end
    local item = inv.items[p.slot]
    if type(item) ~= 'table' or type(item.name) ~= 'string' or (tonumber(item.count) or 0) < 1 then return false, 'gone' end
    local c, pp = inv.coords, p.playerPos
    if type(c) ~= 'table' and type(c) ~= 'vector3' or not pp then return false, 'gone' end
    local dx, dy, dz = c.x - pp.x, c.y - pp.y, c.z - pp.z
    if math.sqrt(dx * dx + dy * dy + dz * dz) > (p.maxDist or 3.0) then return false, 'far' end
    if p.canCarry == false then return false, 'full' end
    return true, item
end

--- Primer hueco ocupado de un drop (el objeto que se ofrece al acercarse).
function PXDInteract.firstSlot(items)
    local best
    for slot, it in pairs(type(items) == 'table' and items or {}) do
        if type(slot) == 'number' and type(it) == 'table' and (tonumber(it.count) or 0) > 0 then
            if not best or slot < best then best = slot end
        end
    end
    return best
end

--- Texto del aviso de recogida: «Recoger botella de agua» (+ « ×3»).
function PXDInteract.pickupLabel(label, count)
    label = type(label) == 'string' and label ~= '' and label or 'objeto'
    count = tonumber(count) or 1
    if count > 1 then return ('Recoger %s ×%d'):format(label, count) end
    return 'Recoger ' .. label
end

return PXDInteract
