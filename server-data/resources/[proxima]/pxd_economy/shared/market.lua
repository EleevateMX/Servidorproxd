-- Motor puro del mercado fluctuante (sin natives ni base de datos). Lo usan el servidor y las pruebas.
-- Cada bien tiene un precio que:
--   · sube con la demanda neta (compras − ventas registradas) y baja con la oferta neta;
--   · vuelve poco a poco hacia su precio base (corregido por las noticias activas);
--   · tiene un ruido pequeño y un cambio máximo por tick, y nunca sale de [min, max].
PXDMarket = {}
local M = PXDMarket

local function clamp(v, lo, hi) if v < lo then return lo end if v > hi then return hi end return v end
local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

--- Parámetro del bien o, si no lo define, el valor por defecto del mercado.
local function param(good, cfg, key) return tonumber(good[key]) or tonumber(cfg.defaults[key]) or 0 end

--- Comprueba el catálogo. Devuelve la lista de errores (vacía = correcto).
function M.validate(cfg)
    local errors = {}
    for id, g in pairs(cfg.goods or {}) do
        if type(id) ~= 'string' or not id:match('^[%w_]+$') then errors[#errors + 1] = ('id no válido: %s'):format(tostring(id)) end
        if type(g.label) ~= 'string' or g.label == '' then errors[#errors + 1] = id .. ': falta label' end
        if not (tonumber(g.min) and tonumber(g.base) and tonumber(g.max)) or not (g.min > 0 and g.min <= g.base and g.base <= g.max) then
            errors[#errors + 1] = id .. ': debe cumplirse 0 < min ≤ base ≤ max'
        end
        if not cfg.categories[g.category] then errors[#errors + 1] = id .. ': categoría desconocida' end
    end
    for _, e in ipairs(cfg.events or {}) do
        if e.good and not cfg.goods[e.good] then errors[#errors + 1] = ('evento %s: bien desconocido'):format(tostring(e.id)) end
        if e.category and not cfg.categories[e.category] then errors[#errors + 1] = ('evento %s: categoría desconocida'):format(tostring(e.id)) end
        if not e.good and not e.category then errors[#errors + 1] = ('evento %s: falta good o category'):format(tostring(e.id)) end
        if type(e.pct) ~= 'table' or not (tonumber(e.pct[1]) and tonumber(e.pct[2])) or e.pct[1] > e.pct[2] then
            errors[#errors + 1] = ('evento %s: pct debe ser { mínimo, máximo }'):format(tostring(e.id))
        end
    end
    table.sort(errors)
    return errors
end

--- Estado nuevo: cada bien en su precio base (o el guardado, acotado a [min, max]).
--- saved = { [id] = { price, bought, sold } } leído de la base de datos.
function M.new(cfg, saved)
    local st = { goods = {}, events = {}, tick = 0, lastNews = {} }
    for id, g in pairs(cfg.goods) do
        local s = saved and saved[id]
        st.goods[id] = {
            price = round2(clamp(tonumber(s and s.price) or g.base, g.min, g.max)),
            bought = math.max(0, tonumber(s and s.bought) or 0),
            sold = math.max(0, tonumber(s and s.sold) or 0),
        }
    end
    return st
end

--- Anota una operación real. side = 'buy' (alguien compra: demanda) o 'sell' (alguien vende: oferta).
function M.record(st, id, side, qty)
    local g = st.goods[id]
    qty = tonumber(qty)
    if not g or not qty or qty <= 0 or qty ~= qty or qty == math.huge then return false end
    if side == 'buy' then g.bought = g.bought + qty
    elseif side == 'sell' then g.sold = g.sold + qty
    else return false end
    return true
end

local function affects(ev, id, good)
    return ev.good == id or (ev.category ~= nil and ev.category == good.category)
end

--- Variación acumulada (fracción) de las noticias activas sobre un bien.
function M.eventEffect(st, cfg, id)
    local good, total = cfg.goods[id], 0
    if not good then return 0 end
    for _, ev in ipairs(st.events) do
        if affects(ev, id, good) then total = total + ev.pct end
    end
    return total
end

--- «+2,5 %» / «−1 %» con coma decimal y signo tipográfico.
function M.pctText(pct)
    local v = math.floor(math.abs(pct) * 1000 + 0.5) / 10
    local text = (v == math.floor(v)) and ('%d'):format(v) or (('%.1f'):format(v):gsub('%.', ','))
    return text .. ' %'
end

function M.headline(template, pct)
    return (template:gsub('{pct}', function() return M.pctText(pct) end))
end

--- Añade una noticia con efecto. ev = { id?, headline, good | category, pct, ticks }.
--- Devuelve la noticia normalizada o nil, motivo.
function M.addEvent(st, cfg, ev, now)
    if type(ev) ~= 'table' or type(ev.headline) ~= 'string' or ev.headline == '' then return nil, 'titular' end
    local pct = tonumber(ev.pct)
    if not pct or pct ~= pct or math.abs(pct) > 0.5 then return nil, 'pct' end
    if ev.good and not cfg.goods[ev.good] then return nil, 'bien' end
    if ev.category and not cfg.categories[ev.category] then return nil, 'categoria' end
    if not ev.good and not ev.category then return nil, 'objetivo' end
    local ticks = math.max(1, math.min(math.floor(tonumber(ev.ticks) or 4), 96 * 7))
    local item = { id = ev.id, good = ev.good, category = ev.category, pct = pct, left = ticks,
        headline = M.headline(ev.headline:sub(1, 200), pct), at = now, kind = ev.kind or 'evento' }
    st.events[#st.events + 1] = item
    return item
end

--- Sortea una noticia automática (o ninguna). rng() devuelve un número en [0, 1).
function M.rollEvent(st, cfg, rng, now)
    if (cfg.eventChance or 0) <= 0 or rng() >= cfg.eventChance then return nil end
    local active = {}
    for _, ev in ipairs(st.events) do if ev.id then active[ev.id] = true end end
    local pool, total = {}, 0
    for _, e in ipairs(cfg.events or {}) do
        if not active[e.id] then pool[#pool + 1] = e; total = total + (e.weight or 1) end
    end
    if #pool == 0 then return nil end
    local pick, roll = pool[#pool], rng() * total
    for _, e in ipairs(pool) do
        roll = roll - (e.weight or 1)
        if roll < 0 then pick = e break end
    end
    local pct = pick.pct[1] + (pick.pct[2] - pick.pct[1]) * rng()
    pct = math.floor(pct * 1000 + (pct >= 0 and 0.5 or -0.5)) / 1000
    if pct == 0 then pct = pick.pct[2] > 0 and 0.001 or -0.001 end
    return M.addEvent(st, cfg, { id = pick.id, headline = pick.headline, good = pick.good, category = pick.category,
        pct = pct, ticks = pick.ticks, kind = 'evento' }, now)
end

--- Un tick del mercado. Devuelve los cambios { id, old, new, pct, bought, sold } (ordenados por id)
--- y las noticias nuevas { headline, good, category, pct, kind, at }.
function M.step(st, cfg, rng, now)
    st.tick = st.tick + 1
    local news = {}
    local rolled = M.rollEvent(st, cfg, rng, now)
    if rolled then news[#news + 1] = rolled end

    local ids = {}
    for id in pairs(cfg.goods) do ids[#ids + 1] = id end
    table.sort(ids)
    local changes = {}
    for _, id in ipairs(ids) do
        local good, g = cfg.goods[id], st.goods[id]
        local old = g.price
        local target = clamp(good.base * (1 + M.eventEffect(st, cfg, id)), good.min, good.max)
        local pressure = clamp((g.bought - g.sold) / math.max(1, param(good, cfg, 'liquidity')), -1, 1)
        local trade = old * param(good, cfg, 'impact') * pressure
        local noise = old * param(good, cfg, 'volatility') * (rng() * 2 - 1)
        local pull = param(good, cfg, 'reversion') * (target - old)
        local maxStep = old * param(good, cfg, 'maxStep')
        local new = round2(clamp(old + clamp(trade + noise + pull, -maxStep, maxStep), good.min, good.max))
        local pct = (new - old) / old
        changes[#changes + 1] = { id = id, old = old, new = new, pct = pct, bought = g.bought, sold = g.sold }
        -- Noticia por operaciones reales: solo si el movimiento lo causaron ellas y no se repite cada tick.
        local tradePct = trade / old
        if (g.bought > 0 or g.sold > 0) and math.abs(tradePct) >= (cfg.newsThreshold or 1)
            and (st.lastNews[id] or -100) <= st.tick - 4 and pct * tradePct > 0 then
            st.lastNews[id] = st.tick
            local up = tradePct > 0
            news[#news + 1] = { good = id, pct = pct, kind = 'operaciones', at = now,
                headline = (up and 'Sube la demanda de %s: el precio aumenta un %s' or 'Exceso de oferta de %s: el precio baja un %s')
                    :format(good.label:lower(), M.pctText(pct)) }
        end
        g.price, g.bought, g.sold = new, 0, 0
    end
    -- Las noticias caducan después de aplicar su tick.
    for i = #st.events, 1, -1 do
        local ev = st.events[i]
        ev.left = ev.left - 1
        if ev.left <= 0 then table.remove(st.events, i) end
    end
    return changes, news
end

--- Precio para cobrar: entero ≥ 1. exact = true devuelve el precio con dos decimales.
function M.price(st, id, exact)
    local g = st.goods[id]
    if not g then return nil end
    if exact then return g.price end
    return math.max(1, math.floor(g.price + 0.5))
end

--- Índice general: 100 = todos los bienes en su precio base.
function M.index(st, cfg)
    local sum, n = 0, 0
    for id, good in pairs(cfg.goods) do sum = sum + st.goods[id].price / good.base; n = n + 1 end
    if n == 0 then return 100 end
    return math.floor(sum / n * 1000 + 0.5) / 10
end

--- Vista para menús y apps: bienes ordenados por categoría y nombre, con su variación sobre el base.
function M.snapshot(st, cfg)
    local out = {}
    for id, good in pairs(cfg.goods) do
        local g = st.goods[id]
        out[#out + 1] = { id = id, label = good.label, category = good.category, categoryLabel = cfg.categories[good.category],
            item = good.item, price = M.price(st, id), exact = g.price, base = good.base,
            vsBase = (g.price - good.base) / good.base }
    end
    table.sort(out, function(a, b)
        if a.categoryLabel ~= b.categoryLabel then return a.categoryLabel < b.categoryLabel end
        return a.label < b.label
    end)
    return out
end

return PXDMarket
