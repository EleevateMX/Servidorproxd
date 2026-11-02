-- Lógica pura de pxd_jobs: sin natives, recibe `now` (segundos) y posiciones {x,y,z}.
-- Cada jugador tiene un estado `st` que solo modifica el servidor.
PXDJobs = {}

local HOUR = 3600

function PXDJobs.newState()
    return { carry = 0, cooldowns = {}, earned = {} }
end

function PXDJobs.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Punto más cercano de la lista dentro de `maxDist`.
function PXDJobs.nearest(points, pos, maxDist)
    local best, bestD
    for i, pt in ipairs(points or {}) do
        local d = PXDJobs.dist(pt, pos)
        if d <= maxDist and (not bestD or d < bestD) then best, bestD = i, d end
    end
    return best, bestD
end

local function isPoint(v)
    return type(v) == 'table' and type(v.x) == 'number' and type(v.y) == 'number' and type(v.z) == 'number'
end

--- Comprueba que la configuración de un trabajo es coherente. Devuelve una lista de errores.
function PXDJobs.validateJob(name, job)
    local errs = {}
    local function bad(msg) errs[#errs + 1] = ('%s: %s'):format(name, msg) end
    if type(name) ~= 'string' or not name:match('^[a-z][a-z0-9_]*$') then bad('nombre inválido (minúsculas, sin espacios)') end
    if type(job) ~= 'table' then bad('no es una tabla') return errs end
    if type(job.label) ~= 'string' or job.label == '' then bad('falta label') end
    if not isPoint(job.signOn) then bad('signOn no es un punto') end
    if type(job.grades) ~= 'table' or not job.grades[0] then bad('grades necesita el rango 0') end
    if job.kind == 'gather' then
        local w = job.work
        if type(w) ~= 'table' then bad('falta work') return errs end
        if type(w.points) ~= 'table' or #w.points == 0 then bad('work.points vacío') end
        for i, pt in ipairs(w.points or {}) do if not isPoint(pt) then bad('work.points[' .. i .. '] no es un punto') end end
        if type(w.seconds) ~= 'number' or w.seconds < 1 then bad('work.seconds debe ser >= 1') end
        if type(w.radius) ~= 'number' or w.radius <= 0 then bad('work.radius debe ser > 0') end
        if type(w.cooldown) ~= 'number' or w.cooldown < 0 then bad('work.cooldown inválido') end
        if type(w.yield) ~= 'table' or type(w.yield[1]) ~= 'number' or type(w.yield[2]) ~= 'number'
            or w.yield[1] < 1 or w.yield[2] < w.yield[1] then bad('work.yield debe ser {min, max} con 1 <= min <= max') end
        if type(w.scenario) ~= 'string' then bad('work.scenario falta') end
        local s = job.sell
        if type(s) ~= 'table' or not isPoint(s.point) then bad('sell.point no es un punto')
        elseif type(s.price) ~= 'number' or s.price <= 0 then bad('sell.price debe ser > 0') end
        if type(job.maxCarry) ~= 'number' or job.maxCarry < 1 then bad('maxCarry debe ser >= 1') end
    elseif job.kind == 'delivery' then
        if type(job.depot) ~= 'table' or not isPoint(job.depot.point) then bad('depot.point no es un punto') end
        local d = job.deliver
        if type(d) ~= 'table' then bad('falta deliver') return errs end
        if type(d.drops) ~= 'table' or #d.drops < 2 then bad('deliver.drops necesita al menos 2 destinos') end
        for i, pt in ipairs(d.drops or {}) do if not isPoint(pt) then bad('deliver.drops[' .. i .. '] no es un punto') end end
        if type(d.base) ~= 'number' or d.base < 0 or type(d.perKm) ~= 'number' or d.perKm < 0 then bad('deliver.base/perKm inválidos') end
        if type(d.maxSpeed) ~= 'number' or d.maxSpeed <= 0 then bad('deliver.maxSpeed debe ser > 0') end
    else
        bad('kind debe ser "gather" o "delivery"')
    end
    return errs
end

--- Trabajos en el formato de Qbox (exports.qbx_core:CreateJobs).
function PXDJobs.qbxJobs(jobs)
    local out = {}
    for name, job in pairs(jobs) do
        out[name] = { label = job.label, defaultDuty = true, offDutyPay = false, grades = job.grades }
    end
    return out
end

--- Lo ganado en la última hora y cuánto se puede pagar de `amount` sin pasar el tope.
function PXDJobs.capPay(st, amount, now, cap)
    -- Se modifica la lista en su sitio: el servidor la comparte entre sesiones del
    -- mismo jugador (reconectar no reinicia el tope).
    local list, kept, total = st.earned, {}, 0
    for _, e in ipairs(list) do
        if now - e.t < HOUR then kept[#kept + 1] = e; total = total + e.amount end
    end
    for i = #list, 1, -1 do list[i] = nil end
    for i, e in ipairs(kept) do list[i] = e end
    local allowed = math.max(0, math.min(amount, (cap or math.huge) - total))
    allowed = math.floor(allowed)
    if allowed > 0 then st.earned[#st.earned + 1] = { t = now, amount = allowed } end
    return allowed
end

-- ── Trabajos de recolección (minero, leñador, pescador) ─────────────────────

function PXDJobs.startWork(st, name, job, idx, pos, now)
    if st.action then return false, 'Ya estás trabajando.' end
    local pt = job.work.points[idx]
    if not pt then return false, 'Ese punto no existe.' end
    if PXDJobs.dist(pt, pos) > job.work.radius then return false, 'Acércate más.' end
    if st.carry >= job.maxCarry then return false, ('Vas lleno: vende tu %s primero.'):format(job.unit or 'carga') end
    local key = name .. ':' .. idx
    local untilT = st.cooldowns[key]
    if untilT and now < untilT then
        return false, ('Este sitio está agotado. Vuelve en %d s.'):format(math.ceil(untilT - now))
    end
    st.action = { job = name, idx = idx, startedAt = now, seconds = job.work.seconds }
    return true, job.work.seconds
end

--- `rnd(a, b)` devuelve un entero entre a y b (inyectado para poder probarlo).
function PXDJobs.finishWork(st, name, job, pos, now, rnd)
    local a = st.action
    if not a or a.job ~= name then return false, 'No estabas trabajando.' end
    st.action = nil
    if now - a.startedAt < a.seconds - 0.5 then return false, 'Demasiado rápido.' end
    if PXDJobs.dist(job.work.points[a.idx], pos) > job.work.radius + 1.0 then return false, 'Te alejaste del sitio.' end
    local y = job.work.yield
    local units = math.min(rnd(y[1], y[2]), job.maxCarry - st.carry)
    st.carry = st.carry + units
    st.cooldowns[name .. ':' .. a.idx] = now + job.work.cooldown
    return true, units
end

function PXDJobs.cancel(st)
    st.action = nil
end

function PXDJobs.sell(st, job, pos, now, cap)
    if st.carry <= 0 then return false, ('No llevas %s.'):format(job.unit or 'nada que vender') end
    if PXDJobs.dist(job.sell.point, pos) > job.sell.radius then return false, 'Acércate al punto de venta.' end
    local pay = PXDJobs.capPay(st, st.carry * job.sell.price, now, cap)
    if pay <= 0 then return false, 'Has llegado al tope de ganancias de esta hora. Descansa un poco.' end
    local sold = st.carry
    st.carry = 0
    return true, pay, sold
end

-- ── Repartidor ──────────────────────────────────────────────────────────────

function PXDJobs.pickup(st, job, pos, now, rnd)
    if st.delivery then return false, 'Ya llevas un paquete.' end
    if PXDJobs.dist(job.depot.point, pos) > job.depot.radius then return false, 'Acércate al depósito.' end
    local drops = job.deliver.drops
    local idx = rnd(1, #drops)
    if idx == st.lastDrop then idx = idx % #drops + 1 end
    st.delivery = { idx = idx, pickedAt = now, from = { x = pos.x, y = pos.y, z = pos.z } }
    return true, idx
end

function PXDJobs.deliver(st, job, pos, now, cap)
    local d = st.delivery
    if not d then return false, 'No llevas ningún paquete.' end
    local drop = job.deliver.drops[d.idx]
    if PXDJobs.dist(drop, pos) > job.deliver.radius then return false, 'Este no es el destino.' end
    local meters = PXDJobs.dist(d.from, drop)
    local minTime = math.max(job.deliver.minSeconds or 0, meters / job.deliver.maxSpeed)
    st.delivery = nil
    st.lastDrop = d.idx
    if now - d.pickedAt < minTime then return false, 'Entrega rechazada: llegaste imposiblemente rápido.' end
    local amount = job.deliver.base + job.deliver.perKm * meters / 1000
    local pay = PXDJobs.capPay(st, amount, now, cap)
    if pay <= 0 then return false, 'Has llegado al tope de ganancias de esta hora. Descansa un poco.' end
    return true, pay
end

-- ── Puntos añadidos en el juego ─────────────────────────────────────────────

local KINDS = { work = true, sell = true, drop = true, signon = true, depot = true }

--- Aplica puntos guardados (data/points.json) sobre la configuración. Devuelve cuántos aplicó.
function PXDJobs.applyExtra(jobs, extra)
    local n = 0
    for name, kinds in pairs(extra or {}) do
        local job = jobs[name]
        if job and type(kinds) == 'table' then
            for kind, list in pairs(kinds) do
                if KINDS[kind] and type(list) == 'table' then
                    for _, pt in ipairs(list) do
                        if isPoint(pt) then
                            if kind == 'work' and job.work then job.work.points[#job.work.points + 1] = pt; n = n + 1
                            elseif kind == 'drop' and job.deliver then job.deliver.drops[#job.deliver.drops + 1] = pt; n = n + 1
                            elseif kind == 'sell' and job.sell then job.sell.point = pt; n = n + 1
                            elseif kind == 'depot' and job.depot then job.depot.point = pt; n = n + 1
                            elseif kind == 'signon' then job.signOn = pt; n = n + 1 end
                        end
                    end
                end
            end
        end
    end
    return n
end

function PXDJobs.isKind(kind) return KINDS[kind] == true end
