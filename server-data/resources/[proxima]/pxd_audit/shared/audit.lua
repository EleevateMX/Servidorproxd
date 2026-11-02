-- Lógica pura de la auditoría común (sin natives ni base de datos). La usan el servidor y las pruebas.
-- Una entrada normalizada («fila») tiene siempre esta forma:
--   { created_at = segundos UNIX (UTC), category, action, actor, target?, data? (texto JSON),
--     source (módulo que la escribe), legacy_ref? ('compat:<id>', 'fine_event:<id>'…) }
PXDAuditLib = {}

local NAME = '^[%w_%.:%-]+$'      -- category, action y source: sin espacios ni comillas
local DEFAULT_LIMITS = {
    category = 32, action = 32, actor = 64, target = 64, source = 64, legacyRef = 64,
    data = 4096,                  -- bytes del JSON de `data`
    queryMax = 500, queryDefault = 100, offsetMax = 100000,
}
PXDAuditLib.DEFAULT_LIMITS = DEFAULT_LIMITS

local function lim(limits, k) return (limits and limits[k]) or DEFAULT_LIMITS[k] end

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

--- Texto corto: número o cadena, sin espacios a los lados ni caracteres de control, de 1 a `max` bytes.
local function shortText(v, max)
    if type(v) == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        v = math.tointeger(v) and tostring(math.tointeger(v)) or tostring(v)
    end
    if type(v) ~= 'string' then return nil end
    v = trim(v)
    if v == '' or #v > max or v:find('%c') then return nil end
    return v
end
PXDAuditLib.shortText = shortText

local function name(v, max)
    v = shortText(v, max)
    if v and v:find(NAME) then return v end
    return nil
end

--- Convierte una entrada de `Log` en fila. ctx = { now, source, limits, encode, legacyRef? }.
--- Devuelve la fila o nil, motivo ('category', 'action', 'actor', 'target', 'data', 'source'…).
function PXDAuditLib.normalize(entry, ctx)
    if type(entry) ~= 'table' then return nil, 'entry' end
    local L = ctx.limits
    local row = {}
    row.category = name(entry.category, lim(L, 'category'))
    if not row.category then return nil, 'category' end
    row.action = name(entry.action, lim(L, 'action'))
    if not row.action then return nil, 'action' end

    if entry.actor == nil then row.actor = 'system'
    else
        row.actor = shortText(entry.actor, lim(L, 'actor'))
        if not row.actor then return nil, 'actor' end
    end

    if entry.target ~= nil then
        row.target = shortText(entry.target, lim(L, 'target'))
        if not row.target then return nil, 'target' end
    end

    local src = entry.source
    if src == nil then src = ctx.source end
    row.source = name(src, lim(L, 'source'))
    if not row.source then return nil, 'source' end

    if entry.data ~= nil then
        if type(entry.data) ~= 'table' then return nil, 'data' end
        local ok, encoded = pcall(ctx.encode, entry.data)
        if not ok or type(encoded) ~= 'string' then return nil, 'data' end
        -- Un registro nunca se pierde por ser grande: se guarda la marca del recorte.
        if #encoded > lim(L, 'data') then encoded = ctx.encode({ truncated = true, bytes = #encoded }) end
        row.data = encoded
    end

    local at = tonumber(entry.created_at) or ctx.now
    row.created_at = math.floor(at)
    if ctx.legacyRef ~= nil then
        row.legacy_ref = shortText(ctx.legacyRef, lim(L, 'legacyRef'))
        if not row.legacy_ref then return nil, 'legacy_ref' end
    end
    return row
end

--- Valida y acota un filtro de `Query`. Devuelve el filtro limpio o nil, motivo.
function PXDAuditLib.normalizeFilter(f, limits)
    if f == nil then f = {} end
    if type(f) ~= 'table' then return nil, 'filter' end
    local out = {}
    for _, k in ipairs({ 'category', 'action', 'source' }) do
        if f[k] ~= nil then
            out[k] = name(f[k], lim(limits, k))
            if not out[k] then return nil, k end
        end
    end
    for _, k in ipairs({ 'target', 'actor' }) do
        if f[k] ~= nil then
            out[k] = shortText(f[k], lim(limits, k))
            if not out[k] then return nil, k end
        end
    end
    if f.since ~= nil then
        out.since = tonumber(f.since)
        if not out.since or out.since ~= out.since then return nil, 'since' end
        out.since = math.floor(out.since)
    end
    local limit = f.limit == nil and lim(limits, 'queryDefault') or tonumber(f.limit)
    if not limit or limit ~= limit then return nil, 'limit' end
    out.limit = math.max(1, math.min(math.floor(limit), lim(limits, 'queryMax')))
    local offset = f.offset == nil and 0 or tonumber(f.offset)
    if not offset or offset ~= offset then return nil, 'offset' end
    out.offset = math.max(0, math.min(math.floor(offset), lim(limits, 'offsetMax')))
    return out
end

--- ¿Cumple la fila el filtro? (para el respaldo en JSON; en SQL lo hace el WHERE).
function PXDAuditLib.matches(row, f)
    for _, k in ipairs({ 'category', 'action', 'source', 'target', 'actor' }) do
        if f[k] and row[k] ~= f[k] then return false end
    end
    if f.since and (tonumber(row.created_at) or 0) < f.since then return false end
    return true
end

--- Orden de las consultas: más reciente primero; a igual fecha, el id mayor primero.
function PXDAuditLib.newerFirst(a, b)
    local ta, tb = tonumber(a.created_at) or 0, tonumber(b.created_at) or 0
    if ta ~= tb then return ta > tb end
    return (tonumber(a.id) or 0) > (tonumber(b.id) or 0)
end

-- ── Formato común de las multas ─────────────────────────────────────────────

--- Entrada de multa. La usan pxd_justice (por el export) y la migración de pxd_fine_events.
---   target = 'fine:<id>' · actor = citizenid del autor o 'system' · data = el resto.
function PXDAuditLib.fineEntry(fineId, action, actorCid, actorName, amount, detail, citizenid, at)
    return {
        created_at = at,
        category = 'fines', action = action,
        actor = actorCid or 'system',
        target = 'fine:' .. tostring(fineId),
        data = { fine_id = tonumber(fineId), actor_name = actorName, amount = tonumber(amount),
            detail = detail, citizenid = citizenid },
        source = 'pxd_justice',
    }
end

-- ── Migración de los registros antiguos ─────────────────────────────────────

local function intId(v) return math.tointeger(tonumber(v)) end

--- Entrada de pxd_compat/data/audit.json → entrada de Log y legacy_ref 'compat:<id>'.
function PXDAuditLib.fromCompat(e)
    if type(e) ~= 'table' or not intId(e.id) then return nil end
    return {
        created_at = tonumber(e.at),
        category = e.category, action = e.action,
        actor = e.actor, target = e.target,
        data = type(e.data) == 'table' and e.data or nil,
        source = e.resource or 'pxd_compat',
    }, 'compat:' .. intId(e.id)
end

--- Fila de pxd_fine_events → entrada de Log (categoría 'fines') y legacy_ref 'fine_event:<id>'.
--- r.fine_citizenid es el citizenid de la persona multada (LEFT JOIN con pxd_fines; puede faltar).
function PXDAuditLib.fromFineEvent(r)
    if type(r) ~= 'table' or not intId(r.id) then return nil end
    return PXDAuditLib.fineEntry(r.fine_id, r.action, r.actor_citizenid, r.actor_name, r.amount, r.detail,
        r.fine_citizenid, tonumber(r.created_at)), 'fine_event:' .. intId(r.id)
end

--- Fila del respaldo JSON de pxd_audit → entrada de Log y legacy_ref 'audit_json:<archivo>:<id>'.
--- `fileId` identifica el archivo (si alguien lo borra, los ids nuevos no chocan con los ya migrados).
--- Si la fila ya venía de una migración (p. ej. 'compat:5'), conserva ese legacy_ref para no duplicarla.
--- `decode` convierte el texto JSON de `data` en tabla (json.decode).
function PXDAuditLib.fromJsonFallback(e, fileId, decode)
    if type(e) ~= 'table' or not intId(e.id) then return nil end
    local data = nil
    if type(e.data) == 'string' and decode then
        local ok, t = pcall(decode, e.data)
        data = ok and type(t) == 'table' and t or nil
    end
    return {
        created_at = tonumber(e.created_at), category = e.category, action = e.action,
        actor = e.actor, target = e.target, data = data, source = e.source,
    }, e.legacy_ref or ('audit_json:' .. tostring(fileId) .. ':' .. intId(e.id))
end

return PXDAuditLib
