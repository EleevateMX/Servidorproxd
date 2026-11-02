-- Lógica pura de pxd_phone (sin natives): textos, límites de frecuencia, propiedades y
-- cola de taxis. Recibe `now` (segundos) para poder probarla.
PXDPhone = {}

--- Limpia texto de usuario: sin caracteres de control ni etiquetas, espacios normalizados.
function PXDPhone.cleanText(s, max)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('[%c]', ' '):gsub('[<>]', ''):gsub('%s+', ' ')
    s = s:match('^%s*(.-)%s*$') or ''
    if max and #s > max then
        -- corta sin partir un carácter UTF-8
        local cut = max
        while cut > 0 and (s:byte(cut + 1) or 0) >= 0x80 and (s:byte(cut + 1) or 0) < 0xC0 do cut = cut - 1 end
        s = s:sub(1, cut)
    end
    return s
end

--- Límite de frecuencia por clave. Devuelve true y apunta la hora si está permitido;
--- si no, false y los segundos que faltan.
function PXDPhone.allow(book, key, now, cooldown)
    local last = book[key]
    if last and now - last < cooldown then return false, cooldown - (now - last) end
    book[key] = now
    return true
end

--- Fila de la tabla `properties` de qbx_properties → vista para la app.
function PXDPhone.propertyView(row, citizenid)
    if type(row) ~= 'table' then return nil end
    local keyholders = row.keyholders
    if type(keyholders) == 'string' then keyholders = (json and json.decode(keyholders)) or {} end
    local mine = citizenid ~= nil and row.owner == citizenid
    if not mine and citizenid and type(keyholders) == 'table' then
        for _, k in ipairs(keyholders) do if k == citizenid then mine = true break end end
    end
    return {
        id = tonumber(row.id),
        name = tostring(row.property_name or ('Propiedad ' .. tostring(row.id))),
        price = tonumber(row.price) or 0,
        rentHours = tonumber(row.rent_interval),
        forSale = row.owner == nil,
        mine = mine,
    }
end

--- Separa en «en venta» (ordenadas por precio) y «mías».
function PXDPhone.splitProperties(rows, citizenid, max)
    local sale, mine = {}, {}
    for _, row in ipairs(rows or {}) do
        local v = PXDPhone.propertyView(row, citizenid)
        if v then
            if v.forSale then sale[#sale + 1] = v end
            if v.mine then mine[#mine + 1] = v end
        end
    end
    table.sort(sale, function(a, b) if a.price ~= b.price then return a.price < b.price end return a.id < b.id end)
    if max then
        while #sale > max do table.remove(sale) end
    end
    return { sale = sale, mine = mine }
end

-- ── Cola de taxis ──────────────────────────────────────────────────────────
local Taxi = {}
Taxi.__index = Taxi
PXDPhone.Taxi = Taxi

function Taxi.new(ttl)
    return setmetatable({ seq = 0, items = {}, ttl = ttl or 600 }, Taxi)
end

function Taxi:expire(now)
    for id, r in pairs(self.items) do
        if now - r.at > self.ttl then self.items[id] = nil end
    end
end

--- Petición abierta (pendiente o aceptada) de un cliente, si la hay.
function Taxi:openFor(customer)
    for _, r in pairs(self.items) do
        if r.customer == customer then return r end
    end
end

function Taxi:request(customer, now, text, coords)
    self:expire(now)
    if self:openFor(customer) then return nil, 'Ya tienes una petición de taxi abierta.' end
    self.seq = self.seq + 1
    local r = { id = self.seq, customer = customer, at = now, text = text or '', coords = coords, status = 'pending' }
    self.items[r.id] = r
    return r
end

function Taxi:accept(id, driver, now)
    self:expire(now)
    local r = self.items[id]
    if not r then return nil, 'Esa petición ya no existe.' end
    if r.status ~= 'pending' then return nil, 'Otro taxista ya la aceptó.' end
    if r.customer == driver then return nil, 'No puedes aceptar tu propia petición.' end
    r.status, r.driver = 'accepted', driver
    return r
end

function Taxi:cancel(customer)
    local r = self:openFor(customer)
    if not r then return nil end
    self.items[r.id] = nil
    return r
end

--- Termina las peticiones de un jugador que se va (como cliente o como taxista).
function Taxi:dropPlayer(src)
    local changed = {}
    for id, r in pairs(self.items) do
        if r.customer == src then
            self.items[id] = nil
        elseif r.driver == src then
            r.status, r.driver = 'pending', nil
            changed[#changed + 1] = r
        end
    end
    return changed
end

function Taxi:pending(now)
    self:expire(now)
    local list = {}
    for _, r in pairs(self.items) do
        if r.status == 'pending' then
            list[#list + 1] = { id = r.id, text = r.text, ageSec = now - r.at }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

return PXDPhone
