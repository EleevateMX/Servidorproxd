-- Servidor de pxd_props: guarda los layouts, valida cada cambio y lo reparte.
-- Las mismas operaciones sirven al editor en el juego y al dashboard web.
local L = PXDProps.Layouts
local RES = GetCurrentResourceName()
local store = L.newStore()
local dirty = false
local rate = {}          -- [actor] = { window = segundo, count = n }
local webFails = {}      -- [ip] = { window, count }

local function now()
    return os.time()
end

-- ── Persistencia ───────────────────────────────────────────────────────────

local function loadData()
    local raw = LoadResourceFile(RES, Config.dataFile)
    if not raw or raw == '' then return end
    local data = json.decode(raw)
    local dropped
    store, dropped = L.loadStore(data)
    print(('[pxd_props] %d layouts cargados%s'):format(#L.list(store),
        dropped > 0 and (' (%d elementos inválidos descartados)'):format(dropped) or ''))
end

local function saveData()
    if not dirty then return end
    local data = json.encode(store)
    if SaveResourceFile(RES, Config.dataFile, data, -1) then
        dirty = false
    else
        print('[pxd_props] ERROR: no se pudo guardar ' .. Config.dataFile)
    end
end

loadData()

CreateThread(function()
    while true do
        Wait(Config.saveIntervalSec * 1000)
        saveData()
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == RES then saveData() end
end)

-- ── Operaciones ────────────────────────────────────────────────────────────

local OPS = {
    createLayout = function(p, t) return L.createLayout(store, p.id, p.name, t) end,
    renameLayout = function(p, t) return L.renameLayout(store, p.id, p.name, t) end,
    setActive = function(p, t) return L.setActive(store, p.id, p.active, t) end,
    deleteLayout = function(p) return L.deleteLayout(store, p.id) end,
    addProp = function(p, t) return L.addProp(store, p.layout, p.prop, t) end,
    updateProp = function(p, t) return L.updateProp(store, p.layout, p.id, p.patch, t) end,
    removeProp = function(p, t) return L.removeProp(store, p.layout, p.id, t) end,
    addPoint = function(p, t) return L.addPoint(store, p.layout, p.point, t) end,
    updatePoint = function(p, t) return L.updatePoint(store, p.layout, p.id, p.patch, t) end,
    removePoint = function(p, t) return L.removePoint(store, p.layout, p.id, t) end,
    importLayout = function(p, t)
        return L.importLayout(store, p.data, { overwrite = p.overwrite == true, id = p.id }, t)
    end,
    setAnchor = function(p, t) return L.setAnchor(store, p.name, p.anchor, t) end,
    removeAnchor = function(p) return L.removeAnchor(store, p.name) end,
}
local ANCHOR_OPS = { setAnchor = true, removeAnchor = true }

local function allowRate(actor)
    local t = now()
    local r = rate[actor]
    if not r or r.window ~= t then
        rate[actor] = { window = t, count = 1 }
        return true
    end
    r.count = r.count + 1
    return r.count <= Config.opsPerSecond
end

local function broadcastLayout(layoutId)
    local layout = store.layouts[layoutId]
    TriggerClientEvent('pxd_props:client:layout', -1, layoutId, layout)
end

--- Punto único de entrada para cambios. Devuelve ok, resultado|error.
local function dispatch(actor, op, payload)
    local fn = type(op) == 'string' and OPS[op]
    if not fn then return false, 'operación desconocida' end
    if type(payload) ~= 'table' then return false, 'datos no válidos' end
    if not allowRate(actor) then return false, 'demasiadas operaciones por segundo' end
    local result, err = fn(payload, now())
    if not result then return false, err or 'error' end
    dirty = true
    if ANCHOR_OPS[op] then
        print(('[pxd_props] %s %s %s'):format(actor, op, tostring(payload.name)))
        return true, result
    end
    local layoutId = payload.layout or payload.id
    if op == 'importLayout' then layoutId = result.id end
    print(('[pxd_props] %s %s %s'):format(actor, op, tostring(layoutId)))
    broadcastLayout(layoutId)
    return true, result
end

-- ── Juego ──────────────────────────────────────────────────────────────────

local function canEdit(src)
    return IsPlayerAceAllowed(src, Config.editAce)
end

RegisterNetEvent('pxd_props:server:sync', function()
    local src = source
    TriggerClientEvent('pxd_props:client:sync', src, store.layouts, canEdit(src))
end)

RegisterNetEvent('pxd_props:server:op', function(reqId, op, payload)
    local src = source
    if type(reqId) ~= 'number' then return end
    if not canEdit(src) then
        return TriggerClientEvent('pxd_props:client:opResult', src, reqId, false, 'sin permiso para editar')
    end
    local license = GetPlayerIdentifierByType(src, 'license') or ('player:' .. src)
    local ok, res = dispatch(('%s(%s)'):format(GetPlayerName(src) or '?', license), op, payload)
    TriggerClientEvent('pxd_props:client:opResult', src, reqId, ok, res)
end)

-- /ancla <nombre>: guarda tu posición actual para usarla en blueprints.
-- /ancla (sin nombre): lista las anclas guardadas.
RegisterCommand('ancla', function(src, args)
    if src == 0 or not canEdit(src) then return end
    local name = args[1]
    if not name then
        local names = {}
        for n in pairs(store.anchors) do names[#names + 1] = n end
        table.sort(names)
        local msg = #names > 0 and ('Anclas: ' .. table.concat(names, ', ')) or 'No hay anclas. Usa /ancla <nombre>.'
        return TriggerClientEvent('pxd_props:client:toast', src, msg, 'info')
    end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local license = GetPlayerIdentifierByType(src, 'license') or ('player:' .. src)
    local ok, res = dispatch(('%s(%s)'):format(GetPlayerName(src) or '?', license), 'setAnchor',
        { name = name, anchor = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) } })
    TriggerClientEvent('pxd_props:client:toast', src,
        ok and ('Ancla «%s» guardada en %.2f, %.2f, %.2f'):format(name, res.x, res.y, res.z) or res,
        ok and 'ok' or 'error')
end, false)

-- ── API para otros recursos ────────────────────────────────────────────────

exports('GetLayout', function(id)
    local l = store.layouts[id]
    return l and json.decode(json.encode(l)) or nil   -- copia, para que nadie lo mute
end)
exports('ListLayouts', function() return L.list(store) end)

-- ── Dashboard web (SetHttpHandler) ─────────────────────────────────────────

local STATIC = {
    [''] = { 'html/index.html', 'text/html; charset=utf-8' },
    ['/'] = { 'html/index.html', 'text/html; charset=utf-8' },
    ['/index.html'] = { 'html/index.html', 'text/html; charset=utf-8' },
    ['/app.js'] = { 'html/app.js', 'application/javascript; charset=utf-8' },
    ['/style.css'] = { 'html/style.css', 'text/css; charset=utf-8' },
    ['/catalog.json'] = { 'html/catalog.json', 'application/json; charset=utf-8' },
}

local SECURITY_HEADERS = {
    ['X-Content-Type-Options'] = 'nosniff',
    ['X-Frame-Options'] = 'DENY',
    ['Referrer-Policy'] = 'no-referrer',
    ['Cache-Control'] = 'no-store',
}

local function send(res, code, body, ctype)
    local headers = { ['Content-Type'] = ctype or 'application/json; charset=utf-8' }
    for k, v in pairs(SECURITY_HEADERS) do headers[k] = v end
    res.writeHead(code, headers)
    res.send(body or '')
end

local function sendJson(res, code, tbl)
    send(res, code, json.encode(tbl))
end

-- Comparación en tiempo constante para no filtrar el token por tiempos.
local function safeEquals(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' or #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do diff = diff | (a:byte(i) ~ b:byte(i)) end
    return diff == 0
end

local function webToken()
    local t = GetConvar(Config.webTokenConvar, '')
    if #t < 24 then return nil end   -- tokens cortos = API desactivada
    return t
end

local function authorized(req)
    local token = webToken()
    if not token then return false, 503 end
    local ip = req.address or '?'
    local t = now()
    local f = webFails[ip]
    if f and f.window > t - 60 and f.count >= 10 then return false, 429 end
    local header = req.headers['Authorization'] or req.headers['authorization'] or ''
    local given = header:match('^Bearer%s+(.+)$')
    if safeEquals(given, token) then return true end
    if not f or f.window <= t - 60 then f = { window = t, count = 0 } end
    f.count = f.count + 1
    webFails[ip] = f
    return false, 401
end

-- FXServer entrega el cuerpo completo en una sola llamada al data handler.
local function readBody(req, cb)
    req.setDataHandler(function(data)
        if type(data) ~= 'string' or #data > 2 * 1024 * 1024 then return cb(nil) end   -- 2 MB máx.
        cb(data)
    end)
end

local function handleApi(req, res, path)
    local ok, code = authorized(req)
    if not ok then
        local msg = code == 503 and 'API web desactivada: define ' .. Config.webTokenConvar .. ' (24+ caracteres)'
            or code == 429 and 'demasiados intentos' or 'token no válido'
        return sendJson(res, code, { ok = false, error = msg })
    end
    if req.method == 'GET' and path == '/api/layouts' then
        return sendJson(res, 200, { ok = true, result = L.list(store) })
    end
    if req.method == 'GET' and path == '/api/anchors' then
        return sendJson(res, 200, { ok = true, result = store.anchors })
    end
    local id = path:match('^/api/layouts/([%w_%-]+)$')
    if req.method == 'GET' and id then
        local l = store.layouts[id]
        if not l then return sendJson(res, 404, { ok = false, error = 'layout no encontrado' }) end
        return sendJson(res, 200, { ok = true, result = l })
    end
    if req.method == 'POST' and path == '/api/op' then
        return readBody(req, function(body)
            local data = body and json.decode(body)
            if type(data) ~= 'table' then return sendJson(res, 400, { ok = false, error = 'JSON no válido' }) end
            local okOp, result = dispatch('web(' .. (req.address or '?') .. ')', data.op, data.payload)
            sendJson(res, okOp and 200 or 400, okOp and { ok = true, result = result } or { ok = false, error = result })
        end)
    end
    sendJson(res, 404, { ok = false, error = 'ruta no encontrada' })
end

SetHttpHandler(function(req, res)
    local path = (req.path or '/'):gsub('%?.*$', '')
    if path:sub(1, 5) == '/api/' then return handleApi(req, res, path) end
    local file = req.method == 'GET' and STATIC[path]
    if not file then return send(res, 404, 'No encontrado', 'text/plain; charset=utf-8') end
    send(res, 200, LoadResourceFile(RES, file[1]) or '', file[2])
end)

-- Exportado para pruebas automatizadas.
PXDProps.dispatch = dispatch
PXDProps.store = function() return store end
