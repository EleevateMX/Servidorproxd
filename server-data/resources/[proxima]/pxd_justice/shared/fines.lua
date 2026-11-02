-- Lógica pura de multas (sin natives ni base de datos). La usan el servidor y las pruebas.
PXDFines = {}

local OPEN = { pending = true, partial = true }
PXDFines.OPEN = OPEN

local function isInt(n) return type(n) == 'number' and n == math.floor(n) end

function PXDFines.outstanding(row)
    if type(row) ~= 'table' or not OPEN[row.status] then return 0 end
    return math.max(0, (tonumber(row.amount) or 0) - (tonumber(row.paid) or 0))
end

function PXDFines.statusAfter(amount, paid)
    if paid >= amount then return 'paid' end
    if paid > 0 then return 'partial' end
    return 'pending'
end

--- Valida los datos de una multa nueva. Devuelve true o false, motivo.
function PXDFines.validateIssue(amount, reason, notes, maxFine)
    if not isInt(amount) or amount < 1 or amount > (maxFine or 100000) then return false, 'importe' end
    if type(reason) ~= 'string' or not reason:find('%S') or #reason > 200 then return false, 'motivo' end
    if notes ~= nil and (type(notes) ~= 'string' or #notes > 1000) then return false, 'notas' end
    return true
end

--- Valida un pago. Devuelve el importe a cobrar (limitado a lo que falta) o nil, motivo.
function PXDFines.validatePayment(row, citizenid, amount, method, cfg)
    if type(row) ~= 'table' then return nil, 'no_existe' end
    if row.citizenid ~= citizenid then return nil, 'no_es_tuya' end
    if not OPEN[row.status] then return nil, 'cerrada' end
    if type(method) ~= 'string' or not (cfg.paymentMethods or {})[method] then return nil, 'metodo' end
    if not isInt(amount) or amount < 1 then return nil, 'importe' end
    local left = PXDFines.outstanding(row)
    if left <= 0 then return nil, 'cerrada' end
    local pay = math.min(amount, left)
    if pay < (cfg.minPartialPayment or 1) and pay < left then return nil, 'minimo' end
    return pay
end

--- Datos que puede ver la interfaz (sin notas internas si no es autoridad).
function PXDFines.publicRow(row, withNotes)
    return {
        id = tonumber(row.id),
        reason = row.reason,
        notes = withNotes and row.notes or nil,
        amount = tonumber(row.amount) or 0,
        paid = tonumber(row.paid) or 0,
        outstanding = PXDFines.outstanding(row),
        status = row.status,
        officer = row.officer_name,
        issuedAt = tonumber(row.issued_at) or 0,
        updatedAt = tonumber(row.updated_at) or 0,
    }
end

--- Separa pendientes e historial y suma lo que se debe.
function PXDFines.summarize(rows, withNotes)
    local pending, history, total = {}, {}, 0
    for _, r in ipairs(rows or {}) do
        local p = PXDFines.publicRow(r, withNotes)
        if OPEN[r.status] then
            pending[#pending + 1] = p
            total = total + p.outstanding
        else
            history[#history + 1] = p
        end
    end
    return { outstanding = total, pending = pending, history = history }
end

--- Clasifica lo que escribe una autoridad para buscar: ID de servidor, PROX-XXXX o citizenid.
function PXDFines.parseQuery(q)
    if type(q) ~= 'string' then return nil end
    q = q:gsub('^%s+', ''):gsub('%s+$', '')
    if #q == 0 or #q > 32 then return nil end
    if q:match('^%d+$') then return 'server', tonumber(q) end
    local up = q:upper()
    if up:match('^PROX%-[%w]+$') then return 'public', up end
    if q:match('^[%w]+$') then return 'citizenid', up end
    return nil
end

PXDFines.MESSAGES = {
    importe = 'Importe no válido.',
    motivo = 'Escribe un motivo (máximo 200 caracteres).',
    notas = 'Las notas son demasiado largas.',
    no_existe = 'Esa multa no existe.',
    no_es_tuya = 'Esa multa no es tuya.',
    cerrada = 'Esa multa ya está pagada o cancelada.',
    metodo = 'Forma de pago no válida.',
    minimo = 'El pago es demasiado pequeño.',
    fondos = 'No tienes dinero suficiente.',
    en_curso = 'Ya hay una operación en curso con esa multa.',
    cambio = 'La multa cambió mientras pagabas. Inténtalo otra vez.',
    banco = 'El banco no pudo registrar el pago. No se te ha cobrado.',
    sin_servicio = 'El sistema de multas no está disponible.',
    espera = 'Espera un momento.',
}

-- ── Auditoría común (pxd_audit) ──────────────────────────

--- Entrada para exports.pxd_audit:Log. Mismo formato que la migración de pxd_fine_events
--- (PXDAuditLib.fineEntry): target 'fine:<id>', actor = citizenid del autor o 'system'.
function PXDFines.auditEntry(fineId, action, actorCid, actorName, amount, detail, citizenid, extra)
    local data = { fine_id = tonumber(fineId), actor_name = actorName, amount = tonumber(amount),
        detail = detail, citizenid = citizenid }
    if type(extra) == 'table' then for k, v in pairs(extra) do if data[k] == nil then data[k] = v end end end
    return { category = 'fines', action = action, actor = actorCid or 'system', target = 'fine:' .. tostring(fineId),
        data = data, source = 'pxd_justice' }
end

--- Origen de una multa del sistema ('radar', 'peaje'…): letras, números, _ y -; 'system' si no se indica.
function PXDFines.systemOrigin(v)
    if v == nil then return 'system' end
    if type(v) ~= 'string' or #v > 32 or not v:find('^[%w_%-]+$') then return nil end
    return v
end

--- Fila de pxd_audit → evento con la forma de pxd_fine_events (lo que devolvía GetFineEvents).
function PXDFines.eventFromAudit(r)
    local d = type(r.data) == 'table' and r.data or {}
    return {
        audit_id = tonumber(r.id), legacy_ref = r.legacy_ref,
        fine_id = tonumber(d.fine_id) or tonumber(tostring(r.target or ''):match('^fine:(%d+)$')),
        action = r.action,
        actor_citizenid = (r.actor ~= 'system') and r.actor or nil,
        actor_name = d.actor_name, amount = tonumber(d.amount), detail = d.detail,
        created_at = tonumber(r.created_at),
    }
end

--- Une los eventos antiguos (pxd_fine_events) con los de pxd_audit sin duplicados: si una fila
--- antigua ya se migró (legacy_ref 'fine_event:<id>'), cuenta una sola vez y conserva su id.
--- Orden cronológico; a igual fecha, primero los antiguos (por id) y luego los nuevos (por id).
function PXDFines.mergeEvents(legacy, audits)
    local out, migrated = {}, {}
    for _, r in ipairs(audits or {}) do
        local e = PXDFines.eventFromAudit(r)
        local lid = math.tointeger(tonumber(tostring(r.legacy_ref or ''):match('^fine_event:(%d+)$')))
        if lid then migrated[lid] = true; e.id = lid; e._k = { 0, lid }
        else e._k = { 1, e.audit_id or 0 } end
        out[#out + 1] = e
    end
    for _, r in ipairs(legacy or {}) do
        local id = math.tointeger(tonumber(r.id))
        if not (id and migrated[id]) then
            local e = {}
            for k, v in pairs(r) do e[k] = v end
            e._k = { 0, id or 0 }
            out[#out + 1] = e
        end
    end
    table.sort(out, function(a, b)
        local ta, tb = tonumber(a.created_at) or 0, tonumber(b.created_at) or 0
        if ta ~= tb then return ta < tb end
        if a._k[1] ~= b._k[1] then return a._k[1] < b._k[1] end
        return a._k[2] < b._k[2]
    end)
    for _, e in ipairs(out) do e._k = nil end
    return out
end

return PXDFines
