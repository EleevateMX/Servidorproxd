-- Auditoría de pxd_compat. Desde la auditoría común (docs/34) es una fachada:
--   exports.pxd_compat:Audit({ category = 'medical'|'fines'|'economy'|…, action = 'confiscate'|…,
--       actor = 'citizenid o sistema', target = 'citizenid', data = { … } }) → id
--   exports.pxd_compat:GetAudit({ category?, target?, limit? }) → lista (más reciente primero)
-- Con pxd_audit en marcha delega en él (tabla pxd_audit). Si no está, o falla, usa como
-- antes Config.audit.file (JSON, solo las Config.audit.maxEntries más recientes); esas
-- entradas se migran a pxd_audit con `pxd_audit_migrar` (legacy_ref 'compat:<id>').
local RES = GetCurrentResourceName()
local entries, nextId

local function delegate() return Config.audit.delegate ~= false and GetResourceState('pxd_audit') == 'started' end

local function load()
    if entries then return end
    local raw = LoadResourceFile(RES, Config.audit.file)
    local data = raw and raw ~= '' and json.decode(raw)
    entries = type(data) == 'table' and type(data.entries) == 'table' and data.entries or {}
    nextId = type(data) == 'table' and tonumber(data.nextId) or (#entries + 1)
end

local function save()
    SaveResourceFile(RES, Config.audit.file, json.encode({ nextId = nextId, entries = entries }), -1)
end

local function audit(entry)
    if type(entry) ~= 'table' or type(entry.category) ~= 'string' or type(entry.action) ~= 'string' then
        return nil
    end
    local origin = GetInvokingResource and GetInvokingResource() or RES
    if delegate() then
        local ok, id = pcall(function()
            return exports.pxd_audit:Log({ category = entry.category, action = entry.action, actor = entry.actor,
                target = entry.target, data = type(entry.data) == 'table' and entry.data or nil, source = origin })
        end)
        if ok and id then return id end
        print(('[pxd_compat] ^3pxd_audit no aceptó la entrada (%s): se guarda en %s.^7'):format(tostring(id), Config.audit.file))
    end
    load()
    local e = {
        id = nextId,
        at = os.time(),
        resource = origin,
        category = entry.category,
        action = entry.action,
        actor = entry.actor and tostring(entry.actor) or nil,
        target = entry.target and tostring(entry.target) or nil,
        data = type(entry.data) == 'table' and entry.data or nil,
    }
    nextId = nextId + 1
    entries[#entries + 1] = e
    local excess = #entries - Config.audit.maxEntries
    if excess > 0 then
        for _ = 1, excess do table.remove(entries, 1) end
    end
    save()
    return e.id
end

local function getAudit(filter)
    filter = type(filter) == 'table' and filter or {}
    local limit = tonumber(filter.limit) or 100
    if delegate() then
        local ok, rows = pcall(function()
            return exports.pxd_audit:Query({ category = filter.category, target = filter.target, limit = limit })
        end)
        if ok and type(rows) == 'table' then
            -- Misma forma que antes: at y resource en vez de created_at y source.
            local out = {}
            for i, r in ipairs(rows) do
                out[i] = { id = r.id, at = r.created_at, resource = r.source, category = r.category, action = r.action,
                    actor = r.actor, target = r.target, data = r.data, legacy_ref = r.legacy_ref }
            end
            return out
        end
    end
    load()
    local out = {}
    for i = #entries, 1, -1 do
        local e = entries[i]
        if (not filter.category or e.category == filter.category)
            and (not filter.target or e.target == tostring(filter.target)) then
            out[#out + 1] = e
            if #out >= limit then break end
        end
    end
    return out
end

exports('Audit', audit)
exports('GetAudit', getAudit)

PXDAudit = { audit = audit, get = getAudit }   -- para otros módulos de pxd_compat y pruebas
