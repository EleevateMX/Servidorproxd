-- Lógica pura del hospital: qué objetos se retiran al reaparecer.
PXDMedical = {}

local ALWAYS_PROTECTED = { money = true }   -- el efectivo es un ítem de ox_inventory

local function toSet(list)
    local s = {}
    for _, v in ipairs(list or {}) do s[v] = true end
    return s
end

--- 'protected' | 'confiscate' | nil (se conserva)
function PXDMedical.classify(name, cfg)
    if type(name) ~= 'string' then return nil end
    if ALWAYS_PROTECTED[name] then return 'protected' end
    cfg = cfg or {}
    cfg._protected = cfg._protected or toSet(cfg.protected)
    cfg._confiscate = cfg._confiscate or toSet(cfg.confiscate)
    if cfg._protected[name] then return 'protected' end
    if cfg._confiscate[name] then return 'confiscate' end
    for _, p in ipairs(cfg.confiscatePrefixes or {}) do
        if name:sub(1, #p) == p then return 'confiscate' end
    end
    return nil
end

--- Objetos a retirar de un inventario (tabla por slot de ox_inventory).
--- Devuelve una lista ordenada por slot: { slot, name, count, label, serial }.
function PXDMedical.plan(items, cfg)
    local out = {}
    for slot, it in pairs(items or {}) do
        if type(it) == 'table' and type(it.count) == 'number' and it.count > 0
            and PXDMedical.classify(it.name, cfg) == 'confiscate' then
            local meta = type(it.metadata) == 'table' and it.metadata or {}
            out[#out + 1] = {
                slot = tonumber(it.slot) or tonumber(slot),
                name = it.name,
                count = it.count,
                label = it.label or it.name,
                serial = meta.serial,
            }
        end
    end
    table.sort(out, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return out
end

--- Texto breve para avisar al jugador.
function PXDMedical.summary(removed)
    if #removed == 0 then return nil end
    local names = {}
    for i = 1, math.min(#removed, 3) do names[#names + 1] = removed[i].label end
    local more = #removed > 3 and (' y %d más'):format(#removed - 3) or ''
    return ('En el hospital te han retirado: %s%s.'):format(table.concat(names, ', '), more)
end

return PXDMedical
