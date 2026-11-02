-- pxd_audit (servidor): auditoría común de Próxima. docs/34-auditoria-comun.md
--   exports.pxd_audit:Log({ category, action, actor?, target?, data?, source? }) → id | nil, motivo
--   exports.pxd_audit:Query({ category?, action?, source?, target?, actor?, since?, limit?, offset? })
--       → filas (más reciente primero; `data` ya decodificado) | nil, motivo
--   exports.pxd_audit:GetStatus() → { backend = 'sql'|'json'|nil, ready, migrating, lastMigration }
-- Con oxmysql guarda en la tabla `pxd_audit`; sin él, en data/audit.json (con aviso y rotación).
local Cfg = Config
local Lib, Store, Migrate = PXDAuditLib, PXDAuditStore, PXDAuditMigrate
local RES = GetCurrentResourceName()

local backend          -- 'sql' | 'json'
local phase = 'idle'   -- 'idle' → 'starting' → 'ready'
local migrating, lastMigration = false, nil

local function now() return os.time() end

local function warnJson(reason)
    print(('[pxd_audit] ^3%s: la auditoría se guarda en %s (con rotación). Arranca oxmysql para usar la tabla pxd_audit.^7')
        :format(reason, Cfg.json.file))
end

--- Elige el almacén y crea la tabla. Se llama en el arranque y, por si acaso, en la primera escritura.
local function ensureReady()
    if phase == 'ready' then return true end
    if phase == 'starting' then
        local waited = 0
        while phase ~= 'ready' and waited < (Cfg.waitForOxmysqlSec + 5) * 1000 do Wait(100); waited = waited + 100 end
        return phase == 'ready'
    end
    phase = 'starting'
    local state = Store.sqlState()
    local waited = 0
    while state == 'starting' and waited < Cfg.waitForOxmysqlSec * 1000 do
        Wait(250); waited = waited + 250
        state = Store.sqlState()
    end
    if state == 'started' then
        local ok, err = pcall(Store.initSql)
        if ok then
            backend = 'sql'
        else
            backend = 'json'
            warnJson('No se pudo crear la tabla pxd_audit (' .. tostring(err) .. ')')
        end
    else
        backend = 'json'
        warnJson('oxmysql no está disponible')
    end
    phase = 'ready'
    return true
end

local function invoker()
    local ok, res = pcall(function() return GetInvokingResource and GetInvokingResource() end)
    return ok and res or nil
end

local function context(source, legacyRef)
    return { now = now(), source = source, limits = Cfg.limits, encode = json.encode, legacyRef = legacyRef }
end

--- Escribe una fila. Si la base de datos falla, la guarda en el respaldo JSON (nunca se pierde).
local function write(row)
    if backend == 'sql' then
        local ok, id = pcall(Store.sqlInsert, row)
        if ok and id then return id end
        print(('[pxd_audit] ^3No se pudo escribir en la BD (%s): se guarda en el respaldo JSON.^7'):format(tostring(id)))
    end
    return Store.jsonInsert(row)
end

local function log(entry)
    if not ensureReady() then return nil, 'sin_servicio' end
    if type(entry) ~= 'table' then return nil, 'entry' end
    -- La hora la pone el servidor y legacy_ref solo la migración: nadie puede antedatar ni suplantar.
    local clean = {}
    for k, v in pairs(entry) do clean[k] = v end
    clean.created_at, clean.legacy_ref = nil, nil
    local row, err = Lib.normalize(clean, context(invoker() or 'unknown'))
    if not row then return nil, err end
    return write(row)
end

local function decodeRow(r)
    local out = {}
    for k, v in pairs(r) do out[k] = v end
    if type(r.data) == 'string' then
        local ok, t = pcall(json.decode, r.data)
        out.data = ok and t or nil
    end
    out.id = tonumber(r.id)
    out.created_at = tonumber(r.created_at)
    return out
end

local function query(filter)
    if not ensureReady() then return nil, 'sin_servicio' end
    local f, err = Lib.normalizeFilter(filter, Cfg.limits)
    if not f then return nil, err end
    local ok, rows
    if backend == 'sql' then
        ok, rows = pcall(Store.sqlQuery, f)
        if not ok then
            print('[pxd_audit] ^1Error al consultar: ' .. tostring(rows) .. '^7')
            return nil, 'sin_servicio'
        end
    else
        rows = Store.jsonQuery(f)
    end
    local out = {}
    for i, r in ipairs(rows) do out[i] = decodeRow(r) end
    return out
end

--- Inserta un registro migrado. 'imported' | 'skipped' (ya estaba) | 'invalid'.
local function insertLegacy(entry, ref)
    local row = Lib.normalize(entry, context(entry and entry.source or 'legacy', ref))
    if not row or not row.legacy_ref then return 'invalid' end
    if backend == 'sql' then
        return Store.sqlInsertLegacy(row) and 'imported' or 'skipped'
    end
    return Store.jsonInsert(row) and 'imported' or 'skipped'
end

local function migrate()
    if migrating then return nil, 'Ya hay una migración en curso.' end
    if not ensureReady() then return nil, 'Sin servicio.' end
    migrating = true
    local ok, report = pcall(Migrate.run, backend, insertLegacy)
    migrating = false
    if not ok then
        print('[pxd_audit] ^1La migración se detuvo: ' .. tostring(report) .. '^7 (lo ya importado queda; vuelve a lanzarla)')
        return nil, tostring(report)
    end
    lastMigration = report
    return report
end

local function printReport(report, err)
    if not report then print('[pxd_audit] Migración no completada: ' .. tostring(err)) return end
    print(('[pxd_audit] Migración terminada (almacén: %s). Los originales no se han tocado.'):format(backend))
    for _, l in ipairs(Migrate.describe(report)) do print('[pxd_audit]   ' .. l) end
end

-- Solo desde la consola del servidor (src 0).
RegisterCommand('pxd_audit_migrar', function(src)
    if src ~= 0 then return end
    CreateThread(function() printReport(migrate()) end)
end, true)

exports('Log', log)
exports('Query', query)
exports('GetStatus', function()
    return { backend = backend, ready = phase == 'ready', migrating = migrating, lastMigration = lastMigration }
end)

CreateThread(function()
    ensureReady()
    if Cfg.migration.onStart then printReport(migrate()) end
end)

PXDAuditService = { log = log, query = query, migrate = migrate, ensureReady = ensureReady,
    backend = function() return backend end }   -- para pruebas
