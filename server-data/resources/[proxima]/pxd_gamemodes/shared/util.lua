-- Utilidades puras (sin natives) compartidas por cliente, servidor y pruebas.
PXD = PXD or {}
local Util = {}
PXD.Util = Util

--- Distancia 3D entre dos tablas/vectores con campos x, y, z.
function Util.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Distancia en el plano XY (útil para zonas cilíndricas).
function Util.dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function Util.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Util.copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

function Util.deepCopy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Util.deepCopy(v) end
    return out
end

function Util.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- Número finito (descarta NaN e infinitos).
function Util.isFiniteNumber(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

--- Formatea segundos como m:ss.
function Util.formatTime(sec)
    sec = math.max(0, math.floor(sec))
    return string.format('%d:%02d', sec // 60, sec % 60)
end

return Util
