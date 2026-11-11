-- Lógica pura del taller (sin natives ni base de datos). La usan el cliente, el servidor y las pruebas.
-- Cada pieza del catálogo es una propiedad de lib.getVehicleProperties (ox_lib): así lo que se guarda
-- en qbx_vehicles (player_vehicles.mods) es exactamente lo que ox_lib y qbx_garages vuelven a aplicar.
PXDGarage = {}
local G = PXDGarage

G.MESSAGES = {
    sin_servicio = 'El taller no está disponible ahora mismo.',
    zona = 'Tienes que estar dentro del taller.',
    vehiculo = 'Súbete al asiento del conductor de tu vehículo.',
    sin_dueno = 'Este vehículo no está registrado: no se puede personalizar.',
    no_es_tuyo = 'Solo el dueño puede personalizar este vehículo aquí.',
    trabajo = 'Este taller es solo para sus mecánicos de servicio.',
    sesion = 'Vuelve a entrar al taller.',
    cambios = 'Hay un cambio que no es válido.',
    nada = 'No hay cambios que aplicar.',
    metodo = 'Forma de pago no válida.',
    fondos = 'No tienes fondos suficientes.',
    banco = 'La cuenta del taller no está disponible. No se cobró nada.',
    guardar = 'No se pudo guardar el vehículo. No se cobró nada.',
    dueno_lejos = 'El dueño del vehículo tiene que estar a tu lado para recibir la factura.',
    en_curso = 'Ya hay una operación en curso.',
}

-- ── Catálogo ───────────────────────────────────────────────────────────────
-- kind: 'level' (rendimiento por niveles), 'toggle', 'mod' (pieza: -1 = de serie), 'index',
--       'paint' (índice de color o RGB), 'rgb', 'neon' (4 lados), 'extras'.
-- mod = tipo de SET_VEHICLE_MOD (para contar opciones con GetNumVehicleMods y enfocar la cámara).
G.SECTIONS = {
    { id = 'performance', label = 'Rendimiento', camera = 'side' },
    { id = 'body', label = 'Carrocería', camera = 'front' },
    { id = 'paint', label = 'Pintura', camera = 'front' },
    { id = 'wheels', label = 'Ruedas', camera = 'wheel' },
    { id = 'lights', label = 'Luces', camera = 'front' },
    { id = 'interior', label = 'Interior', camera = 'interior' },
    { id = 'engine', label = 'Motor a la vista', camera = 'engine' },
    { id = 'details', label = 'Detalles', camera = 'rear' },
}

G.CATALOG = {
    -- Rendimiento (mods 11, 12, 13, 15, 16 y 18)
    { key = 'modEngine', kind = 'level', section = 'performance', mod = 11, label = 'Motor' },
    { key = 'modBrakes', kind = 'level', section = 'performance', mod = 12, label = 'Frenos' },
    { key = 'modTransmission', kind = 'level', section = 'performance', mod = 13, label = 'Transmisión' },
    { key = 'modSuspension', kind = 'level', section = 'performance', mod = 15, label = 'Suspensión' },
    { key = 'modArmor', kind = 'level', section = 'performance', mod = 16, label = 'Blindaje' },
    { key = 'modTurbo', kind = 'toggle', section = 'performance', mod = 18, label = 'Turbo' },
    -- Carrocería
    { key = 'modSpoilers', kind = 'mod', section = 'body', mod = 0, label = 'Alerón', camera = 'rear' },
    { key = 'modFrontBumper', kind = 'mod', section = 'body', mod = 1, label = 'Parachoques delantero' },
    { key = 'modRearBumper', kind = 'mod', section = 'body', mod = 2, label = 'Parachoques trasero', camera = 'rear' },
    { key = 'modSideSkirt', kind = 'mod', section = 'body', mod = 3, label = 'Faldones', camera = 'side' },
    { key = 'modExhaust', kind = 'mod', section = 'body', mod = 4, label = 'Escape', camera = 'rear' },
    { key = 'modFrame', kind = 'mod', section = 'body', mod = 5, label = 'Jaula antivuelco', camera = 'side' },
    { key = 'modGrille', kind = 'mod', section = 'body', mod = 6, label = 'Parrilla' },
    { key = 'modHood', kind = 'mod', section = 'body', mod = 7, label = 'Capó' },
    { key = 'modFender', kind = 'mod', section = 'body', mod = 8, label = 'Aleta izquierda', camera = 'side' },
    { key = 'modRightFender', kind = 'mod', section = 'body', mod = 9, label = 'Aleta derecha', camera = 'side' },
    { key = 'modRoof', kind = 'mod', section = 'body', mod = 10, label = 'Techo', camera = 'top' },
    { key = 'modArchCover', kind = 'mod', section = 'body', mod = 42, label = 'Pasos de rueda', camera = 'side' },
    { key = 'modAerials', kind = 'mod', section = 'body', mod = 43, label = 'Antenas', camera = 'top' },
    { key = 'modTrimB', kind = 'mod', section = 'body', mod = 44, label = 'Molduras', camera = 'side' },
    { key = 'modTank', kind = 'mod', section = 'body', mod = 45, label = 'Depósito', camera = 'rear' },
    { key = 'modWindows', kind = 'mod', section = 'body', mod = 46, label = 'Ventanas', camera = 'side' },
    { key = 'modLightbar', kind = 'mod', section = 'body', mod = 49, label = 'Barra de luces', camera = 'top' },
    -- Pintura
    { key = 'color1', kind = 'paint', section = 'paint', label = 'Color principal' },
    { key = 'color2', kind = 'paint', section = 'paint', label = 'Color secundario' },
    { key = 'paintType1', kind = 'index', section = 'paint', label = 'Acabado principal', min = 0, limit = 'paintType' },
    { key = 'paintType2', kind = 'index', section = 'paint', label = 'Acabado secundario', min = 0, limit = 'paintType' },
    { key = 'pearlescentColor', kind = 'index', section = 'paint', label = 'Perlado', min = 0, limit = 'colour' },
    { key = 'interiorColor', kind = 'index', section = 'paint', label = 'Color del interior', min = 0, limit = 'colour', camera = 'interior' },
    { key = 'dashboardColor', kind = 'index', section = 'paint', label = 'Color del salpicadero', min = 0, limit = 'colour', camera = 'interior' },
    { key = 'modLivery', kind = 'mod', section = 'paint', mod = 48, label = 'Vinilo', camera = 'side' },
    { key = 'livery', kind = 'index', section = 'paint', label = 'Librea', min = -1, limit = 'livery', camera = 'side' },
    -- Ruedas
    { key = 'wheels', kind = 'index', section = 'wheels', label = 'Tipo de llanta', min = 0, limit = 'wheelType' },
    { key = 'modFrontWheels', kind = 'mod', section = 'wheels', mod = 23, label = 'Llantas', limit = 'wheels' },
    { key = 'modBackWheels', kind = 'mod', section = 'wheels', mod = 24, label = 'Llanta trasera (motos)', limit = 'wheels' },
    { key = 'modCustomTiresF', kind = 'toggle', section = 'wheels', label = 'Neumáticos personalizados' },
    { key = 'wheelColor', kind = 'index', section = 'wheels', label = 'Color de llanta', min = 0, limit = 'colour' },
    { key = 'modSmokeEnabled', kind = 'toggle', section = 'wheels', mod = 20, label = 'Humo de neumáticos' },
    { key = 'tyreSmokeColor', kind = 'rgb', section = 'wheels', label = 'Color del humo' },
    -- Luces
    { key = 'modXenon', kind = 'toggle', section = 'lights', mod = 22, label = 'Faros de xenón' },
    { key = 'xenonColor', kind = 'index', section = 'lights', label = 'Color del xenón', min = -1, limit = 'xenon' },
    { key = 'neonEnabled', kind = 'neon', section = 'lights', label = 'Neones', camera = 'side' },
    { key = 'neonColor', kind = 'rgb', section = 'lights', label = 'Color del neón', camera = 'side' },
    -- Interior
    { key = 'modOrnaments', kind = 'mod', section = 'interior', mod = 28, label = 'Adornos' },
    { key = 'modDashboard', kind = 'mod', section = 'interior', mod = 29, label = 'Salpicadero' },
    { key = 'modDial', kind = 'mod', section = 'interior', mod = 30, label = 'Relojes' },
    { key = 'modDoorSpeaker', kind = 'mod', section = 'interior', mod = 31, label = 'Altavoces de puerta' },
    { key = 'modSeats', kind = 'mod', section = 'interior', mod = 32, label = 'Asientos' },
    { key = 'modSteeringWheel', kind = 'mod', section = 'interior', mod = 33, label = 'Volante' },
    { key = 'modShifterLeavers', kind = 'mod', section = 'interior', mod = 34, label = 'Palanca de cambios' },
    { key = 'modAPlate', kind = 'mod', section = 'interior', mod = 35, label = 'Placas' },
    { key = 'modSpeakers', kind = 'mod', section = 'interior', mod = 36, label = 'Altavoces' },
    { key = 'modTrunk', kind = 'mod', section = 'interior', mod = 37, label = 'Maletero', camera = 'rear' },
    -- Motor a la vista
    { key = 'modHydrolic', kind = 'mod', section = 'engine', mod = 38, label = 'Hidráulicos' },
    { key = 'modEngineBlock', kind = 'mod', section = 'engine', mod = 39, label = 'Bloque del motor' },
    { key = 'modAirFilter', kind = 'mod', section = 'engine', mod = 40, label = 'Filtro de aire' },
    { key = 'modStruts', kind = 'mod', section = 'engine', mod = 41, label = 'Barras de refuerzo' },
    -- Detalles
    { key = 'windowTint', kind = 'index', section = 'details', label = 'Tintado de lunas', min = 0, limit = 'windowTint', camera = 'side' },
    { key = 'plateIndex', kind = 'index', section = 'details', label = 'Estilo de matrícula', min = 0, limit = 'plateIndex' },
    { key = 'modPlateHolder', kind = 'mod', section = 'details', mod = 25, label = 'Portamatrículas' },
    { key = 'modVanityPlate', kind = 'mod', section = 'details', mod = 26, label = 'Matrícula decorativa', camera = 'front' },
    { key = 'modTrimA', kind = 'mod', section = 'details', mod = 27, label = 'Embellecedores', camera = 'side' },
    { key = 'modHorns', kind = 'mod', section = 'details', mod = 14, label = 'Bocina', camera = 'front' },
    { key = 'extras', kind = 'extras', section = 'details', label = 'Extras del modelo', camera = 'side' },
}

-- Grupo de precio de cada sección (Config.pricing.groups).
G.PRICE_GROUP = { body = 'body', paint = 'paint', wheels = 'wheels', lights = 'lights', interior = 'interior', engine = 'engine', details = 'details' }

local byKey = {}
for _, e in ipairs(G.CATALOG) do byKey[e.key] = e end
G.byKey = byKey

local function int(v)
    if type(v) ~= 'number' or v ~= v then return nil end
    return math.tointeger(v)
end

local function rgb(v)
    if type(v) ~= 'table' then return nil end
    local r, g, b = int(v[1] or v.r), int(v[2] or v.g), int(v[3] or v.b)
    if not r or not g or not b then return nil end
    for _, c in ipairs({ r, g, b }) do if c < 0 or c > 255 then return nil end end
    return { r, g, b }
end

--- Valida un valor del catálogo. Devuelve el valor limpio o nil.
function G.clean(entry, value, cfg)
    local limits = cfg.limits
    if entry.kind == 'level' then
        local tiers = cfg.pricing.performance[entry.key]
        local v = int(value)
        if not v or not tiers or v < -1 or v > #tiers - 1 then return nil end
        return v
    elseif entry.kind == 'toggle' then
        if type(value) ~= 'boolean' then return nil end
        return value
    elseif entry.kind == 'mod' then
        local v = int(value)
        if not v or v < -1 or v > (limits[entry.limit or 'mod'] or limits.mod) then return nil end
        return v
    elseif entry.kind == 'index' then
        local v = int(value)
        if not v or v < (entry.min or 0) or v > (limits[entry.limit] or 0) then return nil end
        return v
    elseif entry.kind == 'paint' then
        if type(value) == 'table' then return rgb(value) end
        local v = int(value)
        if not v or v < 0 or v > limits.colour then return nil end
        return v
    elseif entry.kind == 'rgb' then
        return rgb(value)
    elseif entry.kind == 'neon' then
        if type(value) ~= 'table' then return nil end
        local out = {}
        for i = 1, 4 do
            if type(value[i]) ~= 'boolean' then return nil end
            out[i] = value[i]
        end
        return out
    elseif entry.kind == 'extras' then
        if type(value) ~= 'table' then return nil end
        local out, n = {}, 0
        for k, v in pairs(value) do
            local id = int(tonumber(k))
            if not id or id < 1 or id > 15 or (v ~= 0 and v ~= 1) then return nil end
            out[id] = v; n = n + 1
        end
        if n == 0 then return nil end
        return out
    end
    return nil
end

--- Valida todo el carrito { [clave] = valor }. Devuelve la tabla limpia o nil, clave que falla.
function G.sanitize(changes, cfg)
    if type(changes) ~= 'table' then return nil, 'formato' end
    local out, n = {}, 0
    for key, value in pairs(changes) do
        local entry = type(key) == 'string' and byKey[key] or nil
        if not entry then return nil, tostring(key) end
        local v = G.clean(entry, value, cfg)
        if v == nil then return nil, key end
        out[key] = v; n = n + 1
        if n > #G.CATALOG then return nil, 'demasiados' end
    end
    return out
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
G.same = same

--- ¿Es el valor «de serie» (quitar la pieza)? Quitarla no cuesta nada.
function G.isStock(entry, value)
    if entry.kind == 'level' or entry.kind == 'mod' then return value == -1 end
    if entry.kind == 'toggle' then return value == false end
    if entry.kind == 'neon' then
        for i = 1, 4 do if value[i] then return false end end
        return true
    end
    if entry.key == 'livery' or entry.key == 'xenonColor' then return value == -1 end
    if entry.key == 'windowTint' or entry.key == 'plateIndex' then return false end
    return false
end

--- Extras guardados por ox_lib: claves numéricas o de texto (tras pasar por JSON).
local function normalizeExtras(t)
    if type(t) ~= 'table' then return nil end
    local out = {}
    for k, v in pairs(t) do out[math.tointeger(tonumber(k)) or k] = v end
    return out
end

--- Cambios reales respecto a lo guardado: lista ordenada { entry, key, value, old }.
function G.diff(current, changes)
    current = type(current) == 'table' and current or {}
    local items = {}
    for _, entry in ipairs(G.CATALOG) do
        local new = changes[entry.key]
        if new ~= nil then
            local old = current[entry.key]
            if entry.kind == 'extras' then
                old = normalizeExtras(old) or {}
                local merged, changed = {}, false
                for k, v in pairs(old) do merged[k] = v end
                for k, v in pairs(new) do if merged[k] ~= v then merged[k] = v; changed = true end end
                if changed then items[#items + 1] = { entry = entry, key = entry.key, value = merged, old = old } end
            elseif not same(old, new) and not (old == nil and G.isStock(entry, new)) then
                items[#items + 1] = { entry = entry, key = entry.key, value = new, old = old }
            end
        end
    end
    return items
end

--- Precio base del vehículo, acotado.
function G.base(modelPrice, cfg)
    local p = cfg.pricing
    local base = tonumber(modelPrice)
    if not base or base <= 0 then base = p.fallbackBase end
    return math.max(p.minBase, math.min(p.maxBase, base))
end

local function round(n, step)
    step = step or 10
    return math.floor(n / step + 0.5) * step
end

--- Precio de un cambio. `factor` = descuento del taller de jugadores.
function G.itemPrice(item, base, cfg, factor)
    local p, entry = cfg.pricing, item.entry
    local cost = 0
    if entry.section == 'performance' then
        local tiers = p.performance[entry.key]
        if entry.kind == 'toggle' then
            if item.value == true and item.old ~= true then cost = tiers[1] * base end
        else
            local function cum(level) level = tonumber(level) or -1; return level < 0 and 0 or (tiers[level + 1] or tiers[#tiers]) * base end
            cost = math.max(0, cum(item.value) - cum(item.old))
        end
    elseif not G.isStock(entry, item.value) then
        local g = p.groups[G.PRICE_GROUP[entry.section]]
        cost = g.flat + g.pct * base
    end
    return round(cost * (factor or 1), p.round)
end

--- Presupuesto: líneas y total. Siempre lo recalcula el servidor con lo guardado en la base de datos.
function G.quote(items, base, cfg, factor)
    local lines, total = {}, 0
    for _, item in ipairs(items) do
        local price = G.itemPrice(item, base, cfg, factor)
        lines[#lines + 1] = { key = item.key, label = item.entry.label, price = price }
        total = total + price
    end
    return { lines = lines, total = total }
end

--- ¿Puede montar estas mejoras de rendimiento? mode = 'self' (autoservicio) | 'mechanic'.
function G.capCheck(items, mode, mechLevel, cfg)
    for _, item in ipairs(items) do
        local perf = cfg.performance[item.key]
        if perf then
            if item.entry.kind == 'toggle' then
                if item.value == true and item.old ~= true then
                    if mode == 'self' and perf.npcMax ~= true then return false, ('%s solo lo monta un mecánico en su taller.'):format(perf.label) end
                    if mode == 'mechanic' and mechLevel < (perf.mechLevel[1] or 1) then
                        return false, ('%s necesita nivel %d de mecánico.'):format(perf.label, perf.mechLevel[1])
                    end
                end
            elseif item.value > (tonumber(item.old) or -1) then
                if mode == 'self' then
                    if item.value > (tonumber(perf.npcMax) or -1) then
                        return false, ('%s nivel %d solo lo monta un mecánico en su taller.'):format(perf.label, item.value + 1)
                    end
                else
                    local need = perf.mechLevel[item.value + 1] or perf.mechLevel[#perf.mechLevel]
                    if mechLevel < need then return false, ('%s nivel %d necesita nivel %d de mecánico.'):format(perf.label, item.value + 1, need) end
                end
            end
        end
    end
    return true
end

--- Props nuevas = las guardadas + los cambios validados (nunca lo que mande el cliente tal cual).
function G.merge(current, items)
    local out = {}
    for k, v in pairs(type(current) == 'table' and current or {}) do out[k] = v end
    for _, item in ipairs(items) do out[item.key] = item.value end
    return out
end

-- ── Zonas ──────────────────────────────────────────────────────────────────
local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len = dx * dx + dy * dy
    local t = len > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len)) or 0
    local cx, cy = ax + t * dx, ay + t * dy
    return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

--- ¿Está el punto dentro del polígono de la zona (con margen) y a su altura?
function G.inZone(zone, x, y, z, margin, height)
    if not zone or not x or not y then return false end
    if z and zone.z and math.abs(z - zone.z) > (height or 6.0) then return false end
    local pts, inside = zone.points, false
    local j = #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then inside = not inside end
        j = i
    end
    if inside then return true end
    j = #pts
    for i = 1, #pts do
        if segDist(x, y, pts[i][1], pts[i][2], pts[j][1], pts[j][2]) <= (margin or 0) then return true end
        j = i
    end
    return false
end

function G.zoneById(id, cfg)
    for _, z in ipairs(cfg.zones) do if z.id == id then return z end end
end

function G.zoneCenter(zone)
    local x, y = 0, 0
    for _, p in ipairs(zone.points) do x, y = x + p[1], y + p[2] end
    return x / #zone.points, y / #zone.points, zone.z
end

function G.plate(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    return text ~= '' and text or nil
end

-- ── Mecánicos ──────────────────────────────────────────────────────────────
--- Nivel a partir de la experiencia. Devuelve nivel (1…), nombre, xp del siguiente nivel (o nil).
function G.levelFor(xp, cfg)
    xp = tonumber(xp) or 0
    local levels = cfg.mechanic.levels
    local level = 1
    for i, l in ipairs(levels) do if xp >= l.xp then level = i end end
    local nxt = levels[level + 1]
    return level, levels[level].name, nxt and nxt.xp or nil
end

--- Experiencia por un trabajo de personalización cobrado.
function G.tuningXp(total, cfg)
    local x = cfg.mechanic.xp
    return math.min(x.tuningMax, x.tuningBase + math.floor((tonumber(total) or 0) / 1000) * x.tuningPer1000)
end

--- Aplica el tope diario. Devuelve la experiencia que se concede de verdad.
function G.grantable(amount, earnedToday, cfg)
    local left = cfg.mechanic.xp.dailyCap - (tonumber(earnedToday) or 0)
    return math.max(0, math.min(amount, left))
end

function G.dayKey(now) return math.floor(now / 86400) end

return G
