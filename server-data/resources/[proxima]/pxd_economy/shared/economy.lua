-- Lógica pura de pxd_economy (sin natives ni base de datos). La usan el servidor y las pruebas.
PXDEconomy = {}
local E = PXDEconomy

E.MESSAGES = {
    sin_servicio = 'La facturación no está disponible ahora mismo.',
    no_existe = 'Esa factura no existe.',
    no_es_tuya = 'Esa factura no es tuya.',
    cerrada = 'Esa factura ya está cerrada.',
    metodo = 'Forma de pago no válida.',
    importe = 'Importe no válido.',
    minimo = 'El pago es menor que el mínimo permitido.',
    fondos = 'No tienes fondos suficientes.',
    en_curso = 'Ya hay una operación en curso con esa factura. Inténtalo de nuevo.',
    cambio = 'La factura cambió mientras pagabas. No se cobró nada.',
    banco = 'La cuenta de la empresa no está disponible. No se cobró nada.',
    concepto = 'Escribe un concepto (máx. 120 caracteres).',
    trabajo = 'Tu trabajo no puede emitir facturas.',
    servicio = 'Debes estar de servicio para facturar.',
    rango = 'Tu rango no permite facturar.',
    lejos = 'Esa persona está demasiado lejos.',
    cliente = 'Cliente no válido.',
    demasiadas = 'Ese cliente ya tiene demasiadas facturas abiertas de tu empresa.',
    permiso = 'Sin permiso.',
}

local OPEN = { pending = true, partial = true }
E.OPEN = OPEN

local function int(n) n = tonumber(n) return n and math.tointeger(n) end

local function cleanText(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s%s+', ' ')
    if s == '' or #s > max then return nil end
    return s
end
E.cleanText = cleanText

-- ── Facturas ──────────────────────────────────────────────
--- Comprueba importe y concepto. Devuelve importe, concepto o nil, código de error.
function E.validateIssue(amount, concept, maxAmount)
    local a = int(amount)
    if not a or a < 1 or a > maxAmount then return nil, 'importe' end
    local c = cleanText(concept, 120)
    if not c then return nil, 'concepto' end
    return a, c
end

--- ¿Puede este puesto (job de qbx_core) emitir facturas? Devuelve la configuración del trabajo o nil, código.
function E.issuerRule(job, cfg)
    if type(job) ~= 'table' or not job.name then return nil, 'trabajo' end
    local rule = cfg.invoiceJobs[job.name]
    if not rule then return nil, 'trabajo' end
    if cfg.invoiceRequireDuty and not job.onduty then return nil, 'servicio' end
    local level = (type(job.grade) == 'table' and tonumber(job.grade.level)) or 0
    if level < (cfg.invoiceMinGrade or 0) then return nil, 'rango' end
    return { job = job.name, account = rule.account or job.name, label = job.label or job.name }
end

function E.outstanding(row)
    if not row or not OPEN[row.status] then return 0 end
    return math.max(0, (tonumber(row.amount) or 0) - (tonumber(row.paid) or 0))
end

--- Igual que las multas: se paga lo pedido limitado a lo que falta. Devuelve importe o nil, código.
function E.validatePayment(row, citizenid, amount, method, cfg)
    if not row then return nil, 'no_existe' end
    if row.citizenid ~= citizenid then return nil, 'no_es_tuya' end
    if not OPEN[row.status] then return nil, 'cerrada' end
    if type(method) ~= 'string' or not cfg.paymentMethods[method] then return nil, 'metodo' end
    local a = int(amount)
    if not a or a < 1 then return nil, 'importe' end
    local left = E.outstanding(row)
    if left <= 0 then return nil, 'cerrada' end
    local pay = math.min(a, left)
    if pay < left and pay < (cfg.minPartialPayment or 1) then return nil, 'minimo' end
    return pay
end

--- ¿Quién puede cancelar? El mismo trabajo con rango de jefe, quien la emitió, o el staff.
function E.canCancel(row, actorCitizenid, actorJob, isStaff)
    if isStaff then return true end
    if not row or not actorJob then return false end
    if actorJob.name ~= row.job then return false end
    if row.issuer_citizenid == actorCitizenid then return true end
    return actorJob.isboss == true
end

local STATUS = { pending = 'Pendiente', partial = 'Pago parcial', paid = 'Pagada', cancelled = 'Cancelada' }
E.STATUS = STATUS

--- Resumen para la interfaz: abiertas primero, con lo que falta.
function E.summarize(rows)
    local open, closed, total = {}, {}, 0
    for _, r in ipairs(rows or {}) do
        local item = {
            id = tonumber(r.id), job = r.job, jobLabel = r.job_label or r.job, concept = r.concept,
            amount = tonumber(r.amount) or 0, paid = tonumber(r.paid) or 0, status = r.status,
            statusLabel = STATUS[r.status] or r.status, issuer = r.issuer_name, client = r.client_name,
            issuedAt = tonumber(r.issued_at), outstanding = E.outstanding(r),
        }
        if OPEN[r.status] then open[#open + 1] = item; total = total + item.outstanding
        else closed[#closed + 1] = item end
    end
    return { open = open, closed = closed, total = total }
end

-- ── Flujo de dinero ───────────────────────────────────────
--- Hora (UTC) en segundos redondeada hacia abajo: clave de agregación.
function E.hourKey(now) return math.floor(now / 3600) * 3600 end

function E.normalizeReason(reason, max)
    if type(reason) ~= 'string' then return '' end
    reason = reason:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #reason > (max or 64) then reason = reason:sub(1, max or 64) end
    return reason
end

--- Categoría de un motivo según Config.categories.
function E.classify(reason, categories, other)
    reason = reason or ''
    local low = reason:lower()
    for _, c in ipairs(categories) do
        if reason:find(c.pattern) or low:find(c.pattern) then return c.id, c.label end
    end
    return other.id, other.label
end

--- Acumulador en memoria: { [clave] = { hour, reason, money_type, direction, total, count } }.
function E.newFlow() return { rows = {}, size = 0 } end

function E.record(flow, hour, reason, moneyType, direction, amount)
    if amount <= 0 then return end
    local key = table.concat({ hour, moneyType, direction, reason }, '|')
    local r = flow.rows[key]
    if not r then
        r = { hour = hour, reason = reason, money_type = moneyType, direction = direction, total = 0, count = 0 }
        flow.rows[key] = r; flow.size = flow.size + 1
    end
    r.total = r.total + amount
    r.count = r.count + 1
end

--- Vuelve a sumar una fila ya agregada (reintento si falló el guardado).
function E.merge(flow, row)
    E.record(flow, row.hour, row.reason, row.money_type, row.direction, row.total)
    local r = flow.rows[table.concat({ row.hour, row.money_type, row.direction, row.reason }, '|')]
    r.count = r.count - 1 + row.count
end

--- Saca lo acumulado (para guardarlo) y deja el acumulador vacío.
function E.drain(flow)
    local out = {}
    for _, r in pairs(flow.rows) do out[#out + 1] = r end
    table.sort(out, function(a, b)
        if a.hour ~= b.hour then return a.hour < b.hour end
        if a.reason ~= b.reason then return a.reason < b.reason end
        if a.money_type ~= b.money_type then return a.money_type < b.money_type end
        return a.direction < b.direction
    end)
    flow.rows, flow.size = {}, 0
    return out
end

--- Convierte un aviso de qbx_core (add/remove/set) en movimiento con signo.
--- cache = saldo conocido de ese tipo (o nil). Devuelve direction ('in'|'out'), importe, nuevo saldo conocido.
function E.movement(action, amount, cache)
    amount = tonumber(amount)
    if not amount or amount ~= amount then return nil end
    if action == 'add' then
        return 'in', amount, cache and (cache + amount) or nil
    elseif action == 'remove' then
        return 'out', amount, cache and (cache - amount) or nil
    elseif action == 'set' then
        if cache == nil then return nil, 0, amount end  -- sin saldo previo no se sabe la diferencia
        local d = amount - cache
        if d > 0 then return 'in', d, amount end
        if d < 0 then return 'out', -d, amount end
        return nil, 0, amount
    end
    return nil
end

--- Resumen por categoría a partir de filas agregadas { reason, money_type, direction, total, count }.
function E.summarizeFlow(rows, categories, other)
    local byCat, order = {}, {}
    local totalIn, totalOut = 0, 0
    for _, r in ipairs(rows or {}) do
        local id, label = E.classify(r.reason, categories, other)
        local c = byCat[id]
        if not c then c = { id = id, label = label, ['in'] = 0, out = 0, count = 0, reasons = {} }; byCat[id] = c; order[#order + 1] = c end
        local t = tonumber(r.total) or 0
        if r.direction == 'in' then c['in'] = c['in'] + t; totalIn = totalIn + t else c.out = c.out + t; totalOut = totalOut + t end
        c.count = c.count + (tonumber(r.count) or 0)
        c.reasons[r.reason] = (c.reasons[r.reason] or 0) + t
    end
    table.sort(order, function(a, b) return (a['in'] + a.out) > (b['in'] + b.out) end)
    for _, c in ipairs(order) do
        local list = {}
        for reason, t in pairs(c.reasons) do list[#list + 1] = { reason = reason, total = t } end
        table.sort(list, function(a, b) return a.total > b.total end)
        while #list > 5 do table.remove(list) end
        c.reasons = list
    end
    -- «Neto» = dinero que entra en los bolsillos menos el que sale. Las transferencias entre
    -- jugadores se compensan; lo que queda es dinero creado (+) o retirado (−) del sistema.
    return { categories = order, totalIn = totalIn, totalOut = totalOut, net = totalIn - totalOut }
end
