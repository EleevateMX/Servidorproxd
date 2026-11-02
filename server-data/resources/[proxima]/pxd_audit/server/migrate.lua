-- Migración idempotente de los registros antiguos a pxd_audit. NUNCA borra ni modifica los
-- originales: solo los lee. Cada registro lleva un legacy_ref único ('compat:<id>',
-- 'fine_event:<id>', 'audit_json:<archivo>:<id>'); si ya está, se omite.
local Cfg = Config
local Lib, Store = PXDAuditLib, PXDAuditStore

PXDAuditMigrate = {}

local function counter() return { read = 0, imported = 0, skipped = 0, invalid = 0 } end

--- Ejecuta la migración. `insertLegacy(entry, ref)` devuelve 'imported', 'skipped' o 'invalid'.
--- `backend` es 'sql' o 'json'. Devuelve el informe por origen.
function PXDAuditMigrate.run(backend, insertLegacy)
    local report = { compat = counter(), fine_events = counter(), audit_json = counter() }
    local M = Cfg.migration

    local function add(c, entry, ref)
        c.read = c.read + 1
        if not entry then c.invalid = c.invalid + 1 return end
        local r = insertLegacy(entry, ref)
        c[r] = c[r] + 1
    end

    -- 1) pxd_compat/data/audit.json (solo lectura).
    local raw = M.compat and LoadResourceFile(M.compat.resource, M.compat.file)
    if not raw or raw == '' then
        report.compat.note = 'sin archivo'
    else
        local data = json.decode(raw)
        local entries = type(data) == 'table' and type(data.entries) == 'table' and data.entries
        if not entries then
            report.compat.note = 'archivo ilegible: no se ha tocado'
        else
            for _, e in ipairs(entries) do add(report.compat, Lib.fromCompat(e)) end
        end
    end

    -- 2) Tabla pxd_fine_events (solo SELECT).
    if not M.fineEvents then
        report.fine_events.note = 'desactivado'
    elseif backend ~= 'sql' then
        report.fine_events.note = 'requiere oxmysql'
    elseif not Store.sqlTableExists('pxd_fine_events') then
        report.fine_events.note = 'la tabla no existe'
    else
        local withFines = Store.sqlTableExists('pxd_fines')
        local last, batch = 0, math.max(1, M.batch or 500)
        while true do
            local rows = Store.sqlFineEvents(last, batch, withFines)
            for _, r in ipairs(rows) do
                add(report.fine_events, Lib.fromFineEvent(r))
                last = math.max(last, math.tointeger(tonumber(r.id)) or last)
            end
            if #rows < batch then break end
        end
    end

    -- 3) Respaldo JSON de pxd_audit (lo escrito mientras no había base de datos).
    if backend ~= 'sql' then
        report.audit_json.note = 'es el almacén actual'
    else
        for _, item in ipairs(Store.jsonAllForMigration()) do
            add(report.audit_json, Lib.fromJsonFallback(item.e, item.fileId, json.decode))
        end
    end
    return report
end

local LABEL = { compat = 'pxd_compat/data/audit.json', fine_events = 'pxd_fine_events', audit_json = 'respaldo JSON de pxd_audit' }

--- Líneas para la consola.
function PXDAuditMigrate.describe(report)
    local lines = {}
    for _, k in ipairs({ 'compat', 'fine_events', 'audit_json' }) do
        local c = report[k]
        local line = ('%s: %d importadas, %d omitidas (ya estaban), %d no válidas'):format(LABEL[k], c.imported, c.skipped, c.invalid)
        if c.note then line = ('%s: %s'):format(LABEL[k], c.note) .. (c.read > 0 and (' · ' .. line) or '') end
        lines[#lines + 1] = line
    end
    return lines
end

return PXDAuditMigrate
