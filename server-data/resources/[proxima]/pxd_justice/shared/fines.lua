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

return PXDFines
