-- Simulador mínimo de FXServer para probar los server_scripts sin el juego.
-- No pretende ser fiel al 100 %: solo implementa lo que usan nuestros recursos.
local Fx = {}

local vecmt = {}
vecmt.__index = vecmt
vecmt.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vecmt) end
vecmt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
local function vec3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vecmt) end

function Fx.reset(opts)
    opts = opts or {}
    Fx.time = 0
    Fx.handlers = {}
    Fx.commands = {}
    Fx.sent = {}          -- TriggerClientEvent registrados
    Fx.threads = {}
    Fx.players = {}
    Fx.entities = {}
    Fx.nextEntity = 5000
    Fx.buckets = {}
    Fx.files = opts.files or {}
    Fx.resourceStates = opts.resourceStates or {}
    Fx.exports = opts.exports or {}
    Fx.convars = opts.convars or {}
    Fx.httpHandler = nil
    Fx.logs = {}
    Fx.resourceName = opts.resourceName or 'test'

    local G = _G
    G.vector3 = vec3
    G.source = nil
    G.print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        Fx.logs[#Fx.logs + 1] = table.concat(parts, ' ')
    end
    G.json = Fx.json
    G.GetGameTimer = function() return math.floor(Fx.time * 1000) end
    G.GetCurrentResourceName = function() return Fx.resourceName end
    G.GetResourceState = function(name) return Fx.resourceStates[name] or 'missing' end
    G.GetConvar = function(k, d) local v = Fx.convars[k]; if v == nil then return d end return tostring(v) end
    G.GetConvarInt = function(k, d) return tonumber(Fx.convars[k]) or d end
    G.GetHashKey = function(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
    G.RegisterNetEvent = function(name, fn) if fn then G.AddEventHandler(name, fn) end end
    G.AddEventHandler = function(name, fn)
        Fx.handlers[name] = Fx.handlers[name] or {}
        table.insert(Fx.handlers[name], fn)
    end
    G.TriggerEvent = function(name, ...) Fx.emit(name, nil, ...) end
    G.TriggerClientEvent = function(name, target, ...)
        Fx.sent[#Fx.sent + 1] = { name = name, target = target, args = { ... } }
    end
    G.RegisterCommand = function(name, fn) Fx.commands[name] = fn end
    G.CreateThread = function(fn)
        local co = coroutine.create(fn)
        Fx.threads[#Fx.threads + 1] = co
        Fx.resume(co)
    end
    -- Promesas mínimas: Citizen.Await cede el hilo hasta que se resuelven.
    G.promise = {
        new = function()
            local p = { done = false }
            function p:resolve(v) self.done, self.value = true, v end
            return p
        end,
    }
    G.Citizen = {
        CreateThread = G.CreateThread,
        Wait = function(ms) G.Wait(ms) end,
        Await = function(p) while not p.done do coroutine.yield(0) end return p.value end,
    }
    G.SetTimeout = function(_, fn) G.CreateThread(fn) end
    G.Wait = function(ms) coroutine.yield(ms) end
    G.exports = setmetatable({}, {
        __index = function(_, res)
            return setmetatable({}, { __index = function(_, fnName)
                return function(_, ...) return Fx.exports[res][fnName](...) end
            end })
        end,
        __call = function(_, name, fn) Fx.exports[Fx.resourceName] = Fx.exports[Fx.resourceName] or {}; Fx.exports[Fx.resourceName][name] = fn end,
    })

    -- Jugadores y entidades
    G.GetPlayers = function()
        local out = {}
        for id in pairs(Fx.players) do out[#out + 1] = tostring(id) end
        return out
    end
    G.GetPlayerName = function(src) local p = Fx.players[tonumber(src)] return p and p.name end
    G.GetPlayerPed = function(src) local p = Fx.players[tonumber(src)] return p and p.ped or 0 end
    G.GetPlayerIdentifierByType = function(src, t) local p = Fx.players[tonumber(src)] return p and p.ids and p.ids[t] end
    G.GetPlayerIdentifiers = function(src)
        local p, out = Fx.players[tonumber(src)], {}
        for t, v in pairs(p and p.ids or {}) do out[#out + 1] = t .. ':' .. v:gsub('^' .. t .. ':', '') end
        return out
    end
    G.IsPlayerAceAllowed = function(src, ace) local p = Fx.players[tonumber(src)] return p and p.aces[ace] == true or false end
    G.GetPlayerRoutingBucket = function(src) return Fx.players[tonumber(src)].bucket end
    G.SetPlayerRoutingBucket = function(src, b) Fx.players[tonumber(src)].bucket = b end
    G.SetRoutingBucketPopulationEnabled = function(b, on) Fx.buckets[b] = Fx.buckets[b] or {}; Fx.buckets[b].population = on end
    G.SetRoutingBucketEntityLockdownMode = function(b, m) Fx.buckets[b] = Fx.buckets[b] or {}; Fx.buckets[b].lockdown = m end
    G.GetEntityCoords = function(ent)
        local e = Fx.entities[ent]
        if not e then return vec3(0, 0, 0) end
        return vec3(e.x, e.y, e.z)
    end
    G.GetEntityHeading = function(ent) local e = Fx.entities[ent] return e and e.h or 0.0 end
    G.GetEntityHealth = function(ent) local e = Fx.entities[ent] return e and (e.health or 200) or 0 end
    -- State bags de jugador: Player(src).state.x
    Fx.playerStates = {}
    G.Player = function(src)
        src = tonumber(src)
        Fx.playerStates[src] = Fx.playerStates[src] or {}
        local st = Fx.playerStates[src]
        return { state = setmetatable({}, {
            __index = function(_, k) if k == 'set' then return function(_, key, v) st[key] = v end end return st[k] end,
            __newindex = function(_, k, v) st[k] = v end,
        }) }
    end
    G.CreateVehicle = function(model, x, y, z, h)
        Fx.nextEntity = Fx.nextEntity + 1
        Fx.entities[Fx.nextEntity] = { type = 'vehicle', model = model, x = x, y = y, z = z, h = h, bucket = 0 }
        return Fx.nextEntity
    end
    G.DoesEntityExist = function(ent) return Fx.entities[ent] ~= nil end
    G.DeleteEntity = function(ent) Fx.entities[ent] = nil end
    G.SetEntityRoutingBucket = function(ent, b) Fx.entities[ent].bucket = b end
    G.NetworkGetNetworkIdFromEntity = function(ent) return ent + 100000 end
    G.SaveResourceFile = function(_, path, data) Fx.files[path] = data return true end
    G.LoadResourceFile = function(_, path) return Fx.files[path] end
    G.SetHttpHandler = function(fn) Fx.httpHandler = fn end
    G.GetResourcePath = function() return '/tmp' end
end

function Fx.resume(co)
    if coroutine.status(co) == 'dead' then return end
    local ok, err = coroutine.resume(co)
    if not ok then error(err, 0) end
end

--- Avanza el reloj `seconds` y despierta los hilos.
function Fx.advance(seconds)
    Fx.time = Fx.time + seconds
    for _, co in ipairs(Fx.threads) do Fx.resume(co) end
end

function Fx.addPlayer(id, name, pos, aces, ids)
    local ped = 100 + id
    Fx.players[id] = { name = name, ped = ped, bucket = 0, aces = aces or {}, ids = ids or { license = 'license:' .. id } }
    Fx.entities[ped] = { type = 'ped', x = pos and pos.x or 0, y = pos and pos.y or 0, z = pos and pos.z or 0, h = 0 }
end

function Fx.movePlayer(id, pos)
    local e = Fx.entities[Fx.players[id].ped]
    e.x, e.y, e.z = pos.x, pos.y, pos.z
end

--- Emite un evento como si viniera del cliente `src`.
function Fx.emit(name, src, ...)
    local list = Fx.handlers[name]
    if not list then return end
    for _, fn in ipairs(list) do
        _G.source = src
        local args = { ... }
        local co = coroutine.create(function() fn(table.unpack(args)) end)
        Fx.threads[#Fx.threads + 1] = co
        Fx.resume(co)
    end
end

function Fx.sentTo(target, name)
    local out = {}
    for _, s in ipairs(Fx.sent) do
        if (target == nil or s.target == target) and (name == nil or s.name == name) then out[#out + 1] = s end
    end
    return out
end

function Fx.lastTo(target, name)
    local list = Fx.sentTo(target, name)
    return list[#list]
end

function Fx.clearSent() Fx.sent = {} end

--- Carga scripts de un recurso como hace el manifiesto (en orden).
function Fx.load(resourceDir, files)
    for _, f in ipairs(files) do dofile(resourceDir .. f) end
end

-- JSON mínimo (encode/decode) suficiente para pruebas. En FXServer existe `json` nativo.
Fx.json = {}
local function encode(v, out)
    local t = type(v)
    if t == 'nil' then out[#out + 1] = 'null'
    elseif t == 'boolean' then out[#out + 1] = tostring(v)
    elseif t == 'number' then
        if v == math.floor(v) and math.abs(v) < 1e15 then out[#out + 1] = string.format('%d', v)
        else out[#out + 1] = string.format('%.14g', v) end
    elseif t == 'string' then
        out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c)
            local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
            return map[c] or string.format('\\u%04x', c:byte())
        end) .. '"'
    elseif t == 'table' then
        local n = #v
        local isArray = n > 0 or next(v) == nil
        if isArray then for k in pairs(v) do if type(k) ~= 'number' then isArray = false break end end end
        if isArray then
            out[#out + 1] = '['
            for i = 1, n do if i > 1 then out[#out + 1] = ',' end encode(v[i], out) end
            out[#out + 1] = ']'
        else
            out[#out + 1] = '{'
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = ',' end
                encode(k, out); out[#out + 1] = ':'
                local val = v[k]; if val == nil then val = v[tonumber(k)] end
                encode(val, out)
            end
            out[#out + 1] = '}'
        end
    end
end
function Fx.json.encode(v) local out = {} encode(v, out) return table.concat(out) end

function Fx.json.decode(s)
    local pos = 1
    local function ws() pos = s:find('[^ \t\r\n]', pos) or #s + 1 end
    local val
    local function str()
        local out = {}
        pos = pos + 1
        while true do
            local c = s:sub(pos, pos)
            if c == '' then error('json: cadena sin cerrar') end
            if c == '"' then pos = pos + 1 break end
            if c == '\\' then
                local n = s:sub(pos + 1, pos + 1)
                local map = { n = '\n', r = '\r', t = '\t', b = '\b', f = '\f', ['/'] = '/', ['\\'] = '\\', ['"'] = '"' }
                if n == 'u' then
                    out[#out + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16)); pos = pos + 6
                else out[#out + 1] = map[n] or n; pos = pos + 2 end
            else out[#out + 1] = c; pos = pos + 1 end
        end
        return table.concat(out)
    end
    function val()
        ws()
        local c = s:sub(pos, pos)
        if c == '{' then
            local t = {}; pos = pos + 1; ws()
            if s:sub(pos, pos) == '}' then pos = pos + 1 return t end
            while true do
                ws(); local k = str(); ws()
                if s:sub(pos, pos) ~= ':' then error('json: se esperaba :') end
                pos = pos + 1; t[k] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == '}' then return t end
                if d ~= ',' then error('json: se esperaba , o }') end
            end
        elseif c == '[' then
            local t = {}; pos = pos + 1; ws()
            if s:sub(pos, pos) == ']' then pos = pos + 1 return t end
            while true do
                t[#t + 1] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == ']' then return t end
                if d ~= ',' then error('json: se esperaba , o ]') end
            end
        elseif c == '"' then return str()
        elseif s:sub(pos, pos + 3) == 'true' then pos = pos + 4 return true
        elseif s:sub(pos, pos + 4) == 'false' then pos = pos + 5 return false
        elseif s:sub(pos, pos + 3) == 'null' then pos = pos + 4 return nil
        else
            local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
            if not num or num == '' then error('json: valor inesperado en ' .. pos) end
            pos = pos + #num
            return tonumber(num)
        end
    end
    local ok, res = pcall(val)
    if not ok then return nil end
    return res
end

return Fx
