-- Lógica pura de pxd_inventory (sin natives): ropa y datos para la interfaz.
PXDInv = {}

local MALE, FEMALE = 'male', 'female'

--- Busca la definición de una ranura de ropa.
function PXDInv.slot(clothing, id)
    for _, s in ipairs(clothing) do if s.id == id then return s end end
end

--- ¿Está «quitada»? Una prenda está puesta si el valor actual no es el de «sin prenda».
--- current = { drawable, texture } (para props, drawable -1 = sin nada).
function PXDInv.isOn(slot, current, sex)
    if not current then return false end
    if slot.kind == 'prop' then return (current[1] or -1) >= 0 end
    local off = slot.off and slot.off[sex or MALE]
    return not off or current[1] ~= off[1]
end

--- Operaciones para alternar una prenda.
--- saved: tabla por id con lo que llevaba antes de quitársela (nil si no se la quitó).
--- current: { [index] = { drawable, texture } } con los valores actuales de los componentes/props implicados.
--- Devuelve ops = { { kind, index, drawable, texture } , ...}, nuevo saved[id] y si queda puesta.
function PXDInv.toggle(slot, saved, current, sex)
    sex = sex == FEMALE and FEMALE or MALE
    local ops = {}
    if saved then
        -- volver a ponerla
        for _, s in ipairs(saved) do ops[#ops + 1] = { s.kind, s.index, s.drawable, s.texture } end
        return ops, nil, true
    end
    local main = current[slot.index]
    if not PXDInv.isOn(slot, main, sex) then return ops, nil, false end -- no lleva nada: no hay qué quitar
    local keep = { { kind = slot.kind, index = slot.index, drawable = main[1], texture = main[2] } }
    if slot.kind == 'prop' then
        ops[#ops + 1] = { 'prop', slot.index, -1, -1 }
    else
        local off = slot.off[sex]
        ops[#ops + 1] = { 'comp', slot.index, off[1], off[2] }
        for _, extra in ipairs(slot.also or {}) do
            local cur = current[extra.index] or { 0, 0 }
            keep[#keep + 1] = { kind = 'comp', index = extra.index, drawable = cur[1], texture = cur[2] }
            ops[#ops + 1] = { 'comp', extra.index, extra[sex][1], extra[sex][2] }
        end
    end
    return ops, keep, false
end

local function clamp(v, lo, hi) v = tonumber(v) or lo; return v < lo and lo or (v > hi and hi or v) end

--- Salud en % a partir de la vida de GTA (100 = muerto, max = llena).
function PXDInv.healthPercent(health, maxHealth)
    health, maxHealth = tonumber(health) or 0, tonumber(maxHealth) or 200
    if maxHealth <= 100 then return 0 end
    return math.floor(clamp((health - 100) / (maxHealth - 100) * 100, 0, 100) + 0.5)
end

--- Guarda una notificación (la más reciente primero). n = { title, text, kind }.
function PXDInv.pushNotice(list, n, now, max)
    if type(n) ~= 'table' then return list end
    local title = type(n.title) == 'string' and n.title:sub(1, 80) or nil
    local text = type(n.text) == 'string' and n.text:sub(1, 240) or nil
    if not title and not text then return list end
    table.insert(list, 1, { title = title, text = text, kind = type(n.kind) == 'string' and n.kind or 'inform', at = now })
    while #list > (max or 20) do table.remove(list) end
    return list
end

-- Versión del contrato con la interfaz (web/pxd-inventory, docs/36-inventario.md).
PXDInv.CONTRACT = 2

local function pct(v)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return math.floor(clamp(v, 0, 100) + 0.5)
end

--- Datos que pinta la interfaz. pd = PlayerData de Qbox (o nil), extra = { health, maxHealth, armour, state, preview }.
--- Nunca se inventan valores: si un dato no llega (sin Qbox, sin state bag ni metadata), se omite
--- y la interfaz no muestra esa barra.
function PXDInv.view(pd, extra, clothing, wearing)
    extra = extra or {}
    local hasPd = type(pd) == 'table'
    pd = hasPd and pd or {}
    local ci = type(pd.charinfo) == 'table' and pd.charinfo or {}
    local money = type(pd.money) == 'table' and pd.money or nil
    local meta = type(pd.metadata) == 'table' and pd.metadata or {}
    local st = extra.state or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    local slots = {}
    for _, s in ipairs(clothing) do
        slots[#slots + 1] = { id = s.id, label = s.label, icon = s.icon, side = s.side, on = wearing[s.id] == true }
    end
    local stateOr = function(k) local v = st[k]; if v == nil then v = meta[k] end; return pct(v) end
    local vitals = {
        hunger = stateOr('hunger'),
        thirst = stateOr('thirst'),
        stress = stateOr('stress'),
        health = extra.health ~= nil and PXDInv.healthPercent(extra.health, extra.maxHealth) or nil,
        armour = pct(extra.armour),
    }
    return {
        contract = PXDInv.CONTRACT,
        name = name ~= '' and name or nil,
        id = type(meta.pxd_id) == 'string' and meta.pxd_id or nil,
        -- Misma fuente que pxd_hud: el dinero de qbx_core (GetPlayerData().money).
        cash = money and tonumber(money.cash) and math.floor(tonumber(money.cash)) or nil,
        bank = money and tonumber(money.bank) and math.floor(tonumber(money.bank)) or nil,
        vitals = vitals,
        clothing = slots,
        preview = extra.preview,
        notices = extra.notices or {},
        now = extra.now,
    }
end

return PXDInv
