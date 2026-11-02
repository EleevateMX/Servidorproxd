-- Registro de auditoría común de Próxima (pxd_compat).
-- Contrato (docs/29-hospital.md):
--   exports.pxd_compat:Audit({ category = 'medical'|'fines'|'economy'|…, action = 'confiscate'|…,
--       actor = 'citizenid o sistema', target = 'citizenid', data = { … } }) → id
--   exports.pxd_compat:GetAudit({ category?, target?, limit? }) → lista (más reciente primero)
-- Se guarda en Config.audit.file (JSON, solo las Config.audit.maxEntries más recientes).
local RES = GetCurrentResourceName()
local entries, nextId

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
    load()
    local e = {
        id = nextId,
        at = os.time(),
        resource = GetInvokingResource and GetInvokingResource() or RES,
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
    load()
    filter = type(filter) == 'table' and filter or {}
    local limit = tonumber(filter.limit) or 100
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
