-- Mercado fluctuante (docs/41-economia-viva.md): precios de referencia que se mueven con las
-- operaciones reales, vuelven a su base y reaccionan a noticias. Motor puro en shared/market.lua.
local M, Store = PXDMarket, PXDLiveStore
local cfg = Config.market

local state, ready = nil, false
local byItem = {}       -- nombre de ítem de ox_inventory → id del bien

local function clock() return (PXDEconomyClock and PXDEconomyClock()) or os.time() end
local function started(res) return GetResourceState(res) == 'started' end
local function rng() return (PXDEconomyRandom and PXDEconomyRandom()) or math.random() end

--- Admite el id del bien o el nombre de su ítem.
local function resolve(id)
    if type(id) ~= 'string' then return nil end
    if cfg.goods[id] then return id end
    return byItem[id]
end

local function record(id, side, qty)
    if not ready then return false end
    id = resolve(id)
    qty = tonumber(qty)
    if not id or not qty or qty <= 0 or qty > 1000000 then return false end
    return M.record(state, id, side, qty)
end

local function persistNews(n)
    local ok, id = pcall(Store.newsInsert, n)
    if not ok then print('[pxd_economy] no se pudo guardar la noticia de mercado: ' .. tostring(id)) end
    TriggerEvent('pxd_economy:marketNews', { headline = n.headline, good = n.good, category = n.category, pct = n.pct, kind = n.kind, at = n.at })
end

--- Un tick: mueve los precios, guarda precios, historial y noticias.
local function tick()
    if not ready then return nil end
    local at = clock()
    local changes, news = M.step(state, cfg, rng, at)
    local ok, err = pcall(function()
        Store.newsTick()
        for _, c in ipairs(changes) do
            Store.priceUpsert(c.id, c.new, 0, 0, at)
            Store.historyInsert(c.id, at, c.new, c.bought, c.sold)
        end
        if (cfg.historyKeepDays or 0) > 0 then Store.historyPrune(at - cfg.historyKeepDays * 86400) end
    end)
    if not ok then print('[pxd_economy] ^1No se pudo guardar el mercado: ' .. tostring(err) .. '^7') end
    for _, n in ipairs(news) do persistNews(n) end
    TriggerEvent('pxd_economy:marketTick', M.index(state, cfg))
    return changes, news
end

local function getNews(limit, sinceId)
    if not ready then return {} end
    limit = math.max(1, math.min(math.floor(tonumber(limit) or 20), cfg.newsKeep or 200))
    local out = {}
    for _, r in ipairs(Store.newsLatest(math.max(0, math.floor(tonumber(sinceId) or 0)), limit)) do
        out[#out + 1] = { id = tonumber(r.id), at = tonumber(r.at), headline = r.headline, kind = r.kind,
            good = r.good, category = r.category, pct = tonumber(r.pct) or 0 }
    end
    return out
end

--- Noticia con efecto en los precios. ev = { headline, good | category, pct (fracción), minutes | ticks }.
local function addEvent(ev)
    if not ready then return false, 'sin_servicio' end
    if type(ev) ~= 'table' then return false, 'evento' end
    local ticks = ev.ticks or (tonumber(ev.minutes) and math.ceil(ev.minutes / (cfg.tickMinutes or 15))) or 4
    local item, err = M.addEvent(state, cfg, { id = ev.id, headline = ev.headline, good = resolve(ev.good), category = ev.category,
        pct = ev.pct, ticks = ticks, kind = 'evento' }, clock())
    if not item then return false, err end
    persistNews(item)
    return true
end

-- ── Exports ───────────────────────────────────────────────
--- Precio actual de un bien (id o ítem). Entero ≥ 1 listo para cobrar; exact = true → con decimales.
exports('GetPrice', function(id, exact)
    if not ready then return nil end
    id = resolve(id)
    return id and M.price(state, id, exact == true) or nil
end)
--- Todos los bienes: { id, label, category, categoryLabel, item, price, exact, base, vsBase }.
exports('GetPrices', function() return ready and M.snapshot(state, cfg) or {} end)
--- Anota una operación real: side 'buy' (un jugador compra) o 'sell' (un jugador vende).
exports('RecordTrade', function(id, side, qty) return record(id, side, qty) end)
--- Historial de un bien en las últimas `hours` horas (máx. 30 días): { at, price, bought, sold }.
exports('GetHistory', function(id, hours)
    id = resolve(id)
    if not ready or not id then return {} end
    hours = math.max(1, math.min(24 * 30, math.floor(tonumber(hours) or 24)))
    local out = {}
    for _, r in ipairs(Store.historySince(id, clock() - hours * 3600)) do
        out[#out + 1] = { at = tonumber(r.at), price = tonumber(r.price), bought = tonumber(r.bought) or 0, sold = tonumber(r.sold) or 0 }
    end
    return out
end)
--- Titulares recientes (los más nuevos primero) para la app de noticias y la bolsa.
exports('GetNews', getNews)
exports('AddMarketEvent', addEvent)
--- Índice general: 100 = todo en su precio base.
exports('GetMarketIndex', function() return ready and M.index(state, cfg) or 100 end)

-- ── Integraciones reales ──────────────────────────────────
-- Tiendas de ox_inventory: cada compra cuenta como demanda del bien (hook «buyItem»).
local function hookShops()
    if not cfg.integrations.shops or not started('ox_inventory') then return end
    CreateThread(function()
        for _ = 1, 120 do   -- ox_inventory publica sus exports al terminar de cargar la base de datos
            local ok = pcall(function()
                exports.ox_inventory:registerHook('buyItem', function(payload)
                    if type(payload) == 'table' then record(payload.itemName, 'buy', payload.count) end
                end, {})
            end)
            if ok then return end
            Wait(500)
        end
        print('[pxd_economy] ^3No se pudo enganchar a las tiendas de ox_inventory: sus compras no moverán el mercado.^7')
    end)
end

-- ox_fuel: se sustituye su cobro por uno idéntico (ítem «money») que además anota la demanda.
local function fuelPayment(playerId, price)
    local success = exports.ox_inventory:RemoveItem(playerId, 'money', price)
    if success then
        if type(price) == 'number' and price > 0 then record('fuel', 'buy', price / cfg.goods.fuel.base) end
        return true
    end
    local money = exports.ox_inventory:GetItemCount(playerId, 'money') or 0
    TriggerClientEvent('ox_lib:notify', playerId, { type = 'error',
        description = ('No tienes suficiente dinero (faltan $%d).'):format(math.max(0, math.floor((tonumber(price) or 0) - money))) })
end

local function hookFuel(on)
    if not cfg.integrations.fuel or not cfg.goods.fuel or not started('ox_fuel') then return end
    pcall(function() exports.ox_fuel:setPaymentMethod(on and fuelPayment or nil) end)
end

AddEventHandler('onServerResourceStart', function(res)
    if not ready then return end
    if res == 'ox_inventory' then hookShops() elseif res == 'ox_fuel' then hookFuel(true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hookFuel(false)   -- ox_fuel vuelve a su cobro original
    if not ready then return end
    local at = clock()
    for id, g in pairs(state.goods) do pcall(Store.priceUpsert, id, g.price, g.bought, g.sold, at) end
end)

-- ── Comandos ──────────────────────────────────────────────
RegisterCommand('mercado', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.ace.view) then return end
    if not ready then return end
    local view = { goods = M.snapshot(state, cfg), news = getNews(8), index = M.index(state, cfg), tickMinutes = cfg.tickMinutes }
    if src == 0 then
        print(('[pxd_economy] Mercado · índice %.1f (100 = precios base)'):format(view.index))
        for _, g in ipairs(view.goods) do
            print(('  %-18s %-28s $%-8.2f base $%-6d %+.1f %%'):format(g.categoryLabel, g.label, g.exact, g.base, g.vsBase * 100))
        end
        for _, n in ipairs(view.news) do print('  · ' .. n.headline) end
        return
    end
    TriggerClientEvent('pxd_economy:client:market', src, view)
end, false)

-- /mercado_evento <bien o categoría> <porcentaje> <minutos> <titular…>   (staff con pxd.economy.manage o consola)
RegisterCommand('mercado_evento', function(src, args)
    local function say(text)
        if src == 0 then print('[pxd_economy] ' .. text)
        else pcall(function() exports.qbx_core:Notify(src, text, 'inform') end) end
    end
    if src > 0 and not IsPlayerAceAllowed(src, Config.ace.manage) then return end
    local target, pct, minutes = args[1], tonumber(args[2]), tonumber(args[3])
    local headline = table.concat(args, ' ', 4)
    if not target or not pct or not minutes or headline == '' then
        return say('Uso: mercado_evento <bien o categoría> <porcentaje, p. ej. 3 o -2> <minutos> <titular con {pct}>')
    end
    local ev = { headline = headline, pct = pct / 100, minutes = minutes }
    if cfg.categories[target] then ev.category = target else ev.good = target end
    local ok, err = addEvent(ev)
    say(ok and 'Noticia de mercado publicada.' or ('No se pudo publicar (%s).'):format(tostring(err)))
end, false)

-- ── Arranque ──────────────────────────────────────────────
CreateThread(function()
    if not cfg.enabled then return end
    local errors = M.validate(cfg)
    if #errors > 0 then
        for _, e in ipairs(errors) do print('[pxd_economy] ^1Mercado mal configurado: ' .. e .. '^7') end
        return
    end
    for id, g in pairs(cfg.goods) do if g.item then byItem[g.item] = id end end
    local ok, err = pcall(function()
        Store.initMarket()
        local saved = {}
        for _, r in ipairs(Store.pricesAll()) do saved[r.good] = { price = r.price, bought = r.bought, sold = r.sold } end
        state = M.new(cfg, saved)
        local at = clock()
        for id, g in pairs(state.goods) do
            if not saved[id] then Store.priceUpsert(id, g.price, 0, 0, at) end
        end
        -- Noticias que seguían activas antes del reinicio.
        for _, r in ipairs(Store.newsActive()) do
            state.events[#state.events + 1] = { id = r.event_id, good = r.good, category = r.category,
                pct = tonumber(r.pct) or 0, left = tonumber(r.ticks_left) or 0, headline = r.headline, at = tonumber(r.at), kind = r.kind }
        end
    end)
    if not ok then return print('[pxd_economy] ^1No se pudo preparar el mercado: ' .. tostring(err) .. '^7') end
    ready = true
    hookShops()
    hookFuel(true)
    while true do
        Wait((cfg.tickMinutes or 15) * 60000)
        local okTick, e = pcall(tick)
        if not okTick then print('[pxd_economy] error en el tick del mercado: ' .. tostring(e)) end
    end
end)

PXDMarketServer = { tick = tick, record = record, addEvent = addEvent, news = getNews,
    state = function() return state end, isReady = function() return ready end, fuelPayment = fuelPayment }   -- para pruebas
