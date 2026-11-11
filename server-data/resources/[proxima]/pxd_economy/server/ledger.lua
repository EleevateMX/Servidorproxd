-- Registro del flujo de dinero (A-8): escucha cada cambio de dinero de qbx_core
-- (QBCore:Server:OnMoneyChange), lo agrupa por hora, motivo, tipo y sentido, y lo guarda
-- cada minuto en pxd_money_flow. Los movimientos grandes van además a pxd_money_large.
local E, Store = PXDEconomy, PXDEconomyStore
local L = Config.ledger
local flow = E.newFlow()
local known = {}        -- [src] = { cash = n, bank = n }: saldo conocido para calcular los «set»
local lastNil = {}      -- [src] = { amount, hour }: último ingreso al banco sin motivo (posible nómina)

local function now() return os.time() end

local function citizenOf(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p and p.PlayerData or nil
end

local function remember(src, data)
    if not data or not data.money then return end
    known[src] = { cash = tonumber(data.money.cash), bank = tonumber(data.money.bank), crypto = tonumber(data.money.crypto) }
end

local function large(src, reason, moneyType, direction, amount)
    if amount < (L.largeAmount or math.huge) then return end
    local data = citizenOf(src)
    local cid = data and data.citizenid or nil
    print(('[pxd_economy] ^3Movimiento grande: %s %s $%d (%s) · %s^7'):format(direction == 'in' and '+' or '-',
        moneyType, amount, reason ~= '' and reason or 'sin motivo', cid or ('jugador ' .. tostring(src))))
    pcall(Store.largeInsert, now(), cid, reason, moneyType, direction, amount)
end

--- Guarda un ingreso sin motivo pendiente (si no llegó a ser nómina).
local function settleNil(src, asReason)
    local p = lastNil[src]
    if not p then return end
    lastNil[src] = nil
    E.record(flow, p.hour, asReason or '', 'bank', 'in', p.amount)
    large(src, asReason or '', 'bank', 'in', p.amount)
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, action, reason)
    if not L.enabled then return end
    src = tonumber(src)
    if not src or type(moneyType) ~= 'string' then return end
    local direction, value
    local k = known[src]
    if k then
        local newCache
        direction, value, newCache = E.movement(action, amount, k[moneyType])
        k[moneyType] = newCache
    else
        -- Primera vez que se ve a este jugador (p. ej. tras reiniciar el recurso): el saldo
        -- leído ya incluye este cambio. Un «set» no se puede medir; add/remove sí.
        remember(src, citizenOf(src))
        if action == 'set' then return end
        direction, value = E.movement(action, amount, nil)
    end
    if not direction or value <= 0 then return end
    local r = E.normalizeReason(reason, L.maxReasonLength)
    -- qbx_core paga la nómina con AddMoney('bank', n) sin motivo y justo después lanza
    -- qbx_core:server:onPaycheck: se aparta para reclasificarla.
    if r == '' and moneyType == 'bank' and direction == 'in' then
        settleNil(src)
        lastNil[src] = { amount = value, hour = E.hourKey(now()) }
        return
    end
    E.record(flow, E.hourKey(now()), r, moneyType, direction, value)
    large(src, r, moneyType, direction, value)
end)

AddEventHandler('qbx_core:server:onPaycheck', function(src, payment)
    src = tonumber(src)
    local p = src and lastNil[src]
    if p and p.amount == tonumber(payment) then settleNil(src, '#nomina') else if src then settleNil(src) end end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if type(player) == 'table' and player.PlayerData then remember(player.PlayerData.source, player.PlayerData) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    settleNil(src)
    known[src] = nil
end)

local function flush()
    for src in pairs(lastNil) do settleNil(src) end
    if flow.size == 0 then return end
    local rows = E.drain(flow)
    local ok, err = pcall(Store.flowUpsert, rows)
    if not ok then
        print('[pxd_economy] ^1No se pudo guardar el flujo de dinero; se reintenta: ' .. tostring(err) .. '^7')
        for _, r in ipairs(rows) do E.merge(flow, r) end
    end
end

CreateThread(function()
    while true do
        Wait((L.flushSeconds or 60) * 1000)
        if PXDEconomyServer.isReady() then flush() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and PXDEconomyServer.isReady() then flush() end
end)

-- ── Resumen para el staff (/economia [horas]) ──────────────
local function summary(hours)
    hours = math.max(1, math.min(24 * 30, math.floor(tonumber(hours) or L.summaryHours or 24)))
    flush()
    local since = E.hourKey(now()) - (hours - 1) * 3600
    local s = E.summarizeFlow(Store.flowSince(since), Config.categories, Config.otherCategory)
    s.hours = hours
    s.large = Store.largeSince(now() - hours * 3600, 10)
    local ok, c = pcall(Store.circulation)
    if ok and c then s.circulation = { cash = tonumber(c.cash) or 0, bank = tonumber(c.bank) or 0 } end
    -- Indicadores de la economía viva (docs/41): impuestos recaudados e índice del mercado.
    if PXDTax and PXDTax.isReady() then
        local okTax, taxes = pcall(PXDTax.summary, hours)
        if okTax then s.taxes = taxes end
    end
    if PXDMarketServer and PXDMarketServer.isReady() then
        s.marketIndex = PXDMarket.index(PXDMarketServer.state(), Config.market)
    end
    return s
end

RegisterCommand('economia', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, Config.ace.view) then return end
    if not PXDEconomyServer.isReady() then return end
    local s = summary(args[1])
    if src == 0 then
        print(('[pxd_economy] Últimas %dh · entra $%d · sale $%d · neto %s$%d'):format(s.hours, s.totalIn, s.totalOut,
            s.net >= 0 and '+' or '-', math.abs(s.net)))
        for _, c in ipairs(s.categories) do print(('  %-40s +$%d  -$%d  (%d mov.)'):format(c.label, c['in'], c.out, c.count)) end
        if s.circulation then print(('  En circulación (último guardado): efectivo $%d · banco $%d'):format(s.circulation.cash, s.circulation.bank)) end
        return
    end
    TriggerClientEvent('pxd_economy:client:summary', src, s)
end, false)

exports('GetFlowSummary', summary)
PXDLedger = { flush = flush, summary = summary, flow = flow, known = known }   -- para pruebas
