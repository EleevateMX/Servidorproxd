-- Almacén de layouts (conjuntos de props + puntos). Lógica pura y validada:
-- el servidor la usa para todo cambio, venga del juego o del dashboard web.
PXDProps = PXDProps or {}
local L = {}
PXDProps.Layouts = L

L.POINT_KINDS = { spawn = true, team1 = true, team2 = true, grid = true, checkpoint = true, zone = true }
L.LIMITS = {
    maxLayouts = 200,
    maxPropsPerLayout = 1500,
    maxPointsPerLayout = 200,
    xy = 10000.0,          -- |x|,|y| máximos (el mapa de GTA V cabe holgado)
    zMin = -500.0, zMax = 3000.0,
}

local function finite(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

local function round(v, decimals)
    local m = 10 ^ (decimals or 3)
    return math.floor(v * m + 0.5) / m
end

--- Normaliza un ángulo a (-180, 180].
function L.normAngle(a)
    a = a % 360.0
    if a > 180.0 then a = a - 360.0 end
    return round(a, 2)
end

function L.validId(id)
    return type(id) == 'string' and #id >= 2 and #id <= 40 and id:match('^[a-z0-9_%-]+$') ~= nil
end

function L.validModel(model)
    return type(model) == 'string' and #model >= 3 and #model <= 64 and model:match('^[%w_]+$') ~= nil
end

local function validCoords(t)
    if not (finite(t.x) and finite(t.y) and finite(t.z)) then return false, 'coordenadas no numéricas' end
    local lim = L.LIMITS
    if math.abs(t.x) > lim.xy or math.abs(t.y) > lim.xy or t.z < lim.zMin or t.z > lim.zMax then
        return false, 'coordenadas fuera del mapa'
    end
    return true
end

local function cleanName(name, fallback)
    if type(name) ~= 'string' then return fallback end
    name = name:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #name == 0 then return fallback end
    return name:sub(1, 60)
end

-- ── Store ──────────────────────────────────────────────────────────────────

function L.newStore()
    return { layouts = {}, anchors = {}, version = 1 }
end

function L.get(store, id)
    return store.layouts[id]
end

function L.list(store)
    local out = {}
    for id, l in pairs(store.layouts) do
        out[#out + 1] = { id = id, name = l.name, active = l.active, props = #l.props,
            points = #l.points, updatedAt = l.updatedAt }
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

local function touch(layout, now)
    layout.updatedAt = now or layout.updatedAt or 0
end

function L.createLayout(store, id, name, now)
    if not L.validId(id) then return nil, 'id inválido: usa a-z, 0-9, _ o - (2-40)' end
    if store.layouts[id] then return nil, 'ya existe un layout con ese id' end
    local n = 0
    for _ in pairs(store.layouts) do n = n + 1 end
    if n >= L.LIMITS.maxLayouts then return nil, 'límite de layouts alcanzado' end
    local layout = { id = id, name = cleanName(name, id), active = false, props = {}, points = {}, nextId = 1 }
    touch(layout, now)
    store.layouts[id] = layout
    return layout
end

function L.renameLayout(store, id, name, now)
    local l = store.layouts[id]
    if not l then return nil, 'layout no encontrado' end
    l.name = cleanName(name, l.name)
    touch(l, now)
    return l
end

function L.setActive(store, id, active, now)
    local l = store.layouts[id]
    if not l then return nil, 'layout no encontrado' end
    l.active = active == true
    touch(l, now)
    return l
end

function L.deleteLayout(store, id)
    if not store.layouts[id] then return nil, 'layout no encontrado' end
    store.layouts[id] = nil
    return true
end

-- ── Props ──────────────────────────────────────────────────────────────────

local function findIndex(list, itemId)
    for i, it in ipairs(list) do if it.id == itemId then return i end end
    return nil
end

--- Construye un prop validado a partir de `src` (y `base` para actualizaciones parciales).
local function buildProp(src, base)
    local p = {}
    base = base or {}
    p.model = src.model ~= nil and src.model or base.model
    if not L.validModel(p.model) then return nil, 'modelo inválido' end
    for _, k in ipairs({ 'x', 'y', 'z' }) do
        local v = src[k]; if v == nil then v = base[k] end
        p[k] = v
    end
    local ok, err = validCoords(p)
    if not ok then return nil, err end
    p.x, p.y, p.z = round(p.x), round(p.y), round(p.z)
    for _, k in ipairs({ 'rx', 'ry', 'rz' }) do
        local v = src[k]; if v == nil then v = base[k] or 0.0 end
        if not finite(v) then return nil, 'rotación no numérica' end
        p[k] = L.normAngle(v)
    end
    local frozen = src.frozen; if frozen == nil then frozen = base.frozen end
    local collision = src.collision; if collision == nil then collision = base.collision end
    local ground = src.ground; if ground == nil then ground = base.ground end
    p.frozen = frozen ~= false
    p.collision = collision ~= false
    p.ground = ground == true      -- el cliente lo apoya en el suelo al crearlo
    return p
end

function L.addProp(store, layoutId, src, now)
    local l = store.layouts[layoutId]
    if not l then return nil, 'layout no encontrado' end
    if #l.props >= L.LIMITS.maxPropsPerLayout then return nil, 'límite de props del layout alcanzado' end
    local p, err = buildProp(src or {})
    if not p then return nil, err end
    p.id = l.nextId
    l.nextId = l.nextId + 1
    l.props[#l.props + 1] = p
    touch(l, now)
    return p
end

function L.updateProp(store, layoutId, propId, patch, now)
    local l = store.layouts[layoutId]
    if not l then return nil, 'layout no encontrado' end
    local i = findIndex(l.props, propId)
    if not i then return nil, 'prop no encontrado' end
    local p, err = buildProp(patch or {}, l.props[i])
    if not p then return nil, err end
    p.id = propId
    l.props[i] = p
    touch(l, now)
    return p
end

function L.removeProp(store, layoutId, propId, now)
    local l = store.layouts[layoutId]
    if not l then return nil, 'layout no encontrado' end
    local i = findIndex(l.props, propId)
    if not i then return nil, 'prop no encontrado' end
    local removed = table.remove(l.props, i)
    touch(l, now)
    return removed
end

-- ── Puntos (spawns, checkpoints, zona) ─────────────────────────────────────

local function buildPoint(src, base)
    base = base or {}
    local p = {}
    p.kind = src.kind ~= nil and src.kind or base.kind
    if not L.POINT_KINDS[p.kind] then return nil, 'tipo de punto inválido' end
    for _, k in ipairs({ 'x', 'y', 'z' }) do
        local v = src[k]; if v == nil then v = base[k] end
        p[k] = v
    end
    local ok, err = validCoords(p)
    if not ok then return nil, err end
    p.x, p.y, p.z = round(p.x), round(p.y), round(p.z)
    local h = src.h; if h == nil then h = base.h or 0.0 end
    if not finite(h) then return nil, 'rumbo no numérico' end
    p.h = round(h % 360.0, 2)
    if p.kind == 'zone' then
        local r = src.radius; if r == nil then r = base.radius or 20.0 end
        if not finite(r) or r < 1 or r > 300 then return nil, 'radio fuera de rango (1-300)' end
        p.radius = round(r, 2)
    end
    if p.kind == 'checkpoint' then
        local o = src.order; if o == nil then o = base.order end
        if o ~= nil and (not finite(o) or o ~= math.floor(o)) then return nil, 'orden inválido' end
        p.order = o
    end
    return p
end

function L.addPoint(store, layoutId, src, now)
    local l = store.layouts[layoutId]
    if not l then return nil, 'layout no encontrado' end
    if #l.points >= L.LIMITS.maxPointsPerLayout then return nil, 'límite de puntos alcanzado' end
    local p, err = buildPoint(src or {})
    if not p then return nil, err end
    if p.kind == 'zone' then
        -- Solo una zona por layout: la nueva sustituye a la anterior.
        for i = #l.points, 1, -1 do if l.points[i].kind == 'zone' then table.remove(l.points, i) end end
    end
    if p.kind == 'checkpoint' and p.order == nil then
        local maxOrder = 0
        for _, q in ipairs(l.points) do
            if q.kind == 'checkpoint' and (q.order or 0) > maxOrder then maxOrder = q.order end
        end
        p.order = maxOrder + 1
    end
    p.id = l.nextId
    l.nextId = l.nextId + 1
    l.points[#l.points + 1] = p
    touch(l, now)
    return p
end

function L.updatePoint(store, layoutId, pointId, patch, now)
    local l = store.layouts[layoutId]
    if not l then return nil, 'layout no encontrado' end
    local i = findIndex(l.points, pointId)
    if not i then return nil, 'punto no encontrado' end
    local p, err = buildPoint(patch or {}, l.points[i])
    if not p then return nil, err end
    p.id = pointId
    l.points[i] = p
    touch(l, now)
    return p
end

function L.removePoint(store, layoutId, pointId, now)
    local l = store.layouts[layoutId]
    if not l then return nil, 'layout no encontrado' end
    local i = findIndex(l.points, pointId)
    if not i then return nil, 'punto no encontrado' end
    local removed = table.remove(l.points, i)
    touch(l, now)
    return removed
end

-- ── Anclas (posiciones con nombre tomadas en el juego con /ancla) ──────────

function L.setAnchor(store, name, a, now)
    if not L.validId(name) then return nil, 'nombre de ancla inválido: usa a-z, 0-9, _ o - (2-40)' end
    if type(a) ~= 'table' then return nil, 'datos no válidos' end
    local ok, err = validCoords(a)
    if not ok then return nil, err end
    local h = a.h or 0.0
    if not finite(h) then return nil, 'rumbo no numérico' end
    local anchor = { name = name, x = round(a.x), y = round(a.y), z = round(a.z), h = round(h % 360.0, 2), updatedAt = now }
    store.anchors[name] = anchor
    return anchor
end

function L.removeAnchor(store, name)
    if not store.anchors[name] then return nil, 'ancla no encontrada' end
    store.anchors[name] = nil
    return true
end

-- ── Importar / exportar ────────────────────────────────────────────────────

--- Reconstruye un layout desde datos externos, validando cada elemento.
--- Devuelve layout, nº de elementos descartados.
function L.sanitizeLayout(data, idOverride)
    if type(data) ~= 'table' then return nil, 'datos no válidos' end
    local id = idOverride or data.id
    if not L.validId(id) then return nil, 'id inválido' end
    local tmp = L.newStore()
    local l = assert(L.createLayout(tmp, id, data.name, data.updatedAt))
    l.active = data.active == true
    local dropped, used, maxId = 0, {}, 0
    -- Conserva los ids originales si son enteros positivos y no se repiten.
    local function keepId(item, srcId)
        if finite(srcId) and srcId >= 1 and srcId == math.floor(srcId) and not used[srcId] then
            item.id = srcId
        end
        used[item.id] = true
        if item.id > maxId then maxId = item.id end
    end
    for _, p in ipairs(type(data.props) == 'table' and data.props or {}) do
        local item = type(p) == 'table' and L.addProp(tmp, id, p)
        if item then keepId(item, p.id) else dropped = dropped + 1 end
    end
    for _, p in ipairs(type(data.points) == 'table' and data.points or {}) do
        local item = type(p) == 'table' and L.addPoint(tmp, id, p)
        if item then keepId(item, p.id) else dropped = dropped + 1 end
    end
    -- Si algún id nuevo chocara con uno conservado, se renumera.
    local seen = {}
    for _, list in ipairs({ l.props, l.points }) do
        for _, item in ipairs(list) do
            if seen[item.id] then maxId = maxId + 1; item.id = maxId end
            seen[item.id] = true
        end
    end
    l.nextId = maxId + 1
    l.updatedAt = data.updatedAt
    return l, dropped
end

function L.importLayout(store, data, opts, now)
    opts = opts or {}
    local l, droppedOrErr = L.sanitizeLayout(data, opts.id)
    if not l then return nil, droppedOrErr end
    if store.layouts[l.id] and not opts.overwrite then return nil, 'ya existe un layout con ese id' end
    touch(l, now)
    store.layouts[l.id] = l
    return l, droppedOrErr
end

--- Carga un store completo (p. ej. desde data/layouts.json ya decodificado).
function L.loadStore(data)
    local store = L.newStore()
    local dropped = 0
    if type(data) == 'table' and type(data.layouts) == 'table' then
        for id, raw in pairs(data.layouts) do
            local l, d = L.sanitizeLayout(raw, id)
            if l then
                store.layouts[l.id] = l
                dropped = dropped + d
            else
                dropped = dropped + 1
            end
        end
    end
    if type(data) == 'table' and type(data.anchors) == 'table' then
        for name, a in pairs(data.anchors) do
            if not L.setAnchor(store, name, a, type(a) == 'table' and a.updatedAt or nil) then dropped = dropped + 1 end
        end
    end
    return store, dropped
end

return L
