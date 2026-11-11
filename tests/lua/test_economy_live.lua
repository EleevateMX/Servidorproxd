-- Pruebas de la economía viva de pxd_economy: paga cada 30 min, impuestos y mercado fluctuante.
-- MariaDB, qbx_core, Renewed-Banking, ox_inventory y ox_fuel simulados con la semántica de las consultas reales.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_economy/'

local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.011) end

-- ── MariaDB simulada: interpreta las consultas de server/store_live.lua ──
local db
local function fakeMySQL(Q, keep)
    db = keep or { payroll = {}, taxes = {}, prices = {}, history = {}, news = {}, created = 0, nextNews = 1 }
    local M = {}
    M.query = { await = function(q, p)
        if q == Q.createPayroll or q == Q.createTaxes or q == Q.createPrices or q == Q.createHistory or q == Q.createNews then
            db.created = db.created + 1 return {}
        end
        if q == Q.taxSince then
            local agg, out = {}, {}
            for _, r in ipairs(db.taxes) do
                if r.created_at >= p[1] then
                    if not agg[r.kind] then agg[r.kind] = { kind = r.kind, amount = 0, count = 0 }; out[#out + 1] = agg[r.kind] end
                    agg[r.kind].amount = agg[r.kind].amount + r.amount; agg[r.kind].count = agg[r.kind].count + 1
                end
            end
            return out
        end
        if q == Q.pricesAll then
            local out = {}
            for good, r in pairs(db.prices) do out[#out + 1] = { good = good, price = r.price, bought = r.bought, sold = r.sold } end
            return out
        end
        if q == Q.historySince then
            local out = {}
            for _, r in ipairs(db.history) do if r.good == p[1] and r.at >= p[2] then out[#out + 1] = r end end
            return out
        end
        if q == Q.newsLatest then
            local out = {}
            for i = #db.news, 1, -1 do
                if db.news[i].id > p[1] and #out < p[2] then out[#out + 1] = db.news[i] end
            end
            return out
        end
        if q == Q.newsActive then
            local out = {}
            for _, r in ipairs(db.news) do if r.ticks_left > 0 then out[#out + 1] = r end end
            return out
        end
        error('consulta no simulada: ' .. q)
    end }
    M.insert = { await = function(q, p)
        if q == Q.payrollEnsure then
            db.payroll[p[1]] = db.payroll[p[1]] or { progress = 0, last_paid_at = 0, paid_total = 0, paid_count = 0 }
            return 0
        end
        if q == Q.taxInsert then
            db.taxes[#db.taxes + 1] = { created_at = p[1], kind = p[2], citizenid = p[3], base = p[4], amount = p[5], deposited = p[6], detail = p[7] }
            return #db.taxes
        end
        if q == Q.historyInsert then
            db.history[#db.history + 1] = { good = p[1], at = p[2], price = p[3], bought = p[4], sold = p[5] }
            return #db.history
        end
        if q == Q.newsInsert then
            local id = db.nextNews; db.nextNews = id + 1
            db.news[#db.news + 1] = { id = id, at = p[1], headline = p[2], kind = p[3], good = p[4], category = p[5], pct = p[6], ticks_left = p[7], event_id = p[8] }
            return id
        end
        error('insert no simulado: ' .. q)
    end }
    M.single = { await = function(q, p)
        if q == Q.payrollGet then
            local r = db.payroll[p[1]]
            return r and { progress = r.progress, last_paid_at = r.last_paid_at } or nil
        end
        error('single no simulado: ' .. q)
    end }
    M.update = { await = function(q, p)
        if q == Q.payrollSave then
            local r = db.payroll[p[2]]; if not r then return 0 end
            r.progress = p[1]; return 1
        end
        if q == Q.payrollClaim then
            local r = db.payroll[p[3]]
            if not r or r.last_paid_at > p[4] then return 0 end
            r.last_paid_at, r.progress, r.paid_total, r.paid_count = p[1], 0, r.paid_total + p[2], r.paid_count + 1
            return 1
        end
        if q == Q.payrollRevert then
            local r = db.payroll[p[4]]
            if not r or r.last_paid_at ~= p[5] or r.paid_total < p[6] or r.paid_count < 1 then return 0 end
            r.last_paid_at, r.progress, r.paid_total, r.paid_count = p[1], p[2], r.paid_total - p[3], r.paid_count - 1
            return 1
        end
        if q == Q.priceUpsert then
            db.prices[p[1]] = { price = p[2], bought = p[3], sold = p[4], updated_at = p[5] }
            return 1
        end
        if q == Q.newsTick then
            for _, r in ipairs(db.news) do if r.ticks_left > 0 then r.ticks_left = r.ticks_left - 1 end end
            return 1
        end
        if q == Q.historyPrune then return 0 end
        error('update no simulado: ' .. q)
    end }
    return M
end

-- ── qbx_core, Renewed-Banking, ox_inventory, ox_fuel y pxd_audit simulados ──
local players, accounts, audited, shopHook, fuelMethod, items, addMoneyOk
local JOBS = {
    unemployed = { offDutyPay = false, grades = { [0] = { payment = 10 } } },
    mechanic = { offDutyPay = false, grades = { [0] = { payment = 50 }, [1] = { payment = 75 } } },
    judge = { offDutyPay = true, grades = { [0] = { payment = 100 } } },
}
local function mkPlayer(src, cid, job, bank)
    local p = { PlayerData = { source = src, citizenid = cid, job = job, money = { cash = 0, bank = bank or 0 } }, log = {} }
    p.Functions = {
        AddMoney = function(t, n, reason)
            if not addMoneyOk then return false end
            p.PlayerData.money[t] = p.PlayerData.money[t] + n
            p.log[#p.log + 1] = { type = t, amount = n, reason = reason }
            return true
        end,
        RemoveMoney = function(t, n) if p.PlayerData.money[t] < n then return false end p.PlayerData.money[t] = p.PlayerData.money[t] - n return true end,
        GetMoney = function(t) return p.PlayerData.money[t] end,
    }
    players[src] = p
    _G.Player(src).state.isLoggedIn = true
    return p
end

local QBX_PATCHED = "    sendPaycheck = function (player, payment)\n        if GlobalState.pxdPayroll then return end -- Próxima: la nómina la paga pxd_economy cada 30 min\n        player.Functions.AddMoney('bank', payment)\n"

local function boot(opts)
    opts = opts or {}
    players, audited, shopHook, fuelMethod, addMoneyOk = {}, {}, nil, false, true
    accounts = opts.accounts or { mechanic = 1000 }
    items = { [2] = { money = 100 } }
    local qbx = {
        GetPlayer = function(src) return players[tonumber(src)] end,
        GetJob = function(name) return JOBS[name] end,
        Notify = function() end,
    }
    local rb = {
        getAccountMoney = function(a) return accounts[a] ~= nil and accounts[a] or false end,
        addAccountMoney = function(a, n) if accounts[a] == nil then return false end accounts[a] = accounts[a] + n return true end,
        removeAccountMoney = function(a, n) if accounts[a] == nil or accounts[a] < n then return false end accounts[a] = accounts[a] - n return true end,
        handleTransaction = function() return {} end,
        CreateJobAccount = function(job) if opts.createFails then error('fallo de Renewed-Banking') end accounts[job.name] = 0 return {} end,
    }
    local ox = {
        registerHook = function(event, fn) if event == 'buyItem' then shopHook = fn end return 'pxd_economy:buyItem:1' end,
        RemoveItem = function(src, item, n) local inv = items[src] or {}; if (inv[item] or 0) < n then return false end inv[item] = inv[item] - n return true end,
        GetItemCount = function(src, item) return (items[src] or {})[item] or 0 end,
    }
    Fx.reset({ resourceName = 'pxd_economy',
        resourceStates = { qbx_core = 'started', ['Renewed-Banking'] = 'started', pxd_audit = 'started', ox_inventory = 'started',
            ox_fuel = 'started', pxd_justice = 'started' },
        exports = { qbx_core = qbx, ['Renewed-Banking'] = rb, ox_inventory = ox,
            ox_fuel = { setPaymentMethod = function(fn) fuelMethod = fn end },
            pxd_audit = { Log = function(e) audited[#audited + 1] = e return #audited end },
            pxd_justice = { GetOutstanding = function(cid) return cid == 'CIT2' and 500 or 0 end } },
        files = { ['qbx_core/config/server.lua'] = opts.unpatched and "sendPaycheck = function (player, payment)\n        player.Functions.AddMoney('bank', payment)\n" or QBX_PATCHED } })
    _G.GlobalState = {}
    _G.PXDEconomyClock = function() return 1700000000 + math.floor(Fx.time) end
    local seq, i = opts.rng, 0
    _G.PXDEconomyRandom = function() if not seq then return 0.5 end i = i + 1 return seq[((i - 1) % #seq) + 1] end
    Config, PXDEconomy, PXDPayroll, PXDMarket, PXDLiveStore, PXDMoney, PXDTax, PXDPayrollServer, PXDMarketServer, PXDEconomyServer =
        nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/economy.lua', 'shared/payroll.lua', 'shared/market.lua', 'server/store_live.lua' })
    MySQL = fakeMySQL(PXDLiveStore.Q, opts.keepDb and db or nil)
    Config.payroll.startGraceMinutes = 0
    if opts.config then opts.config(Config) end
    Fx.load(DIR, { 'server/money.lua', 'server/taxes.lua', 'server/payroll.lua', 'server/market.lua' })
    Fx.threads = {}   -- los bucles se llaman a mano (el simulador no respeta la duración de Wait)
    Fx.addPlayer(1, 'mecanica', { x = 0, y = 0, z = 0 })
    Fx.addPlayer(2, 'parado', { x = 50, y = 0, z = 0 })
    mkPlayer(1, 'MEC1', { name = 'mechanic', label = 'Taller', onduty = true, grade = { level = 1 }, payment = 75 }, 0)
    mkPlayer(2, 'CIT2', { name = 'unemployed', label = 'Sin empleo', onduty = true, grade = { level = 0 }, payment = 10 }, 0)
    -- Como en el servidor: qbx_core avisa al cargar el personaje y ahí empieza a contar su ciclo.
    for id = 1, 2 do Fx.emit('QBCore:Server:PlayerLoaded', nil, players[id]) end
end

--- Avanza `minutes` de juego con una revisión cada 30 s. moving = ids que se mueven.
local function play(minutes, moving)
    for n = 1, minutes * 2 do
        Fx.time = Fx.time + 30
        for _, id in ipairs(moving or { 1, 2 }) do
            local e = Fx.entities[Fx.players[id].ped]
            Fx.movePlayer(id, { x = e.x + 3, y = e.y, z = e.z })
        end
        PXDPayrollServer.tick()
    end
end
local function bank(src) return players[src].PlayerData.money.bank end
local function payday(src) local s = Fx.lastTo(src, 'pxd_economy:client:payday') return s and s.args[1] end

T.describe('pxd_economy · paga (lógica pura)', function()
    T.it('sueldo según trabajo, rango y servicio; ayuda a quien no tiene trabajo', function()
        dofile(DIR .. 'config.lua'); dofile(DIR .. 'shared/payroll.lua')
        local P, cfg = PXDPayroll, Config.payroll
        T.eq(P.gross({ name = 'unemployed', onduty = true, grade = { level = 0 } }, JOBS.unemployed, cfg), 30)
        T.eq(select(2, P.gross({ name = 'unemployed', onduty = true }, JOBS.unemployed, cfg)), 'ayuda')
        T.eq(P.gross({ name = 'mechanic', onduty = true, grade = { level = 1 }, payment = 75 }, JOBS.mechanic, cfg), 225, '75 × 3')
        T.eq(P.gross({ name = 'mechanic', onduty = false, grade = { level = 1 } }, JOBS.mechanic, cfg), 0, 'fuera de servicio no cobra')
        T.eq(P.gross({ name = 'judge', onduty = false, grade = { level = 0 } }, JOBS.judge, cfg), 300, 'offDutyPay cobra sin servicio')
        T.eq(P.gross({ name = 'raro', onduty = true, grade = { level = 0 }, payment = 40 }, nil, cfg), 120, 'sin definición usa job.payment')
        T.eq(P.gross(nil, nil, cfg), 0)
    end)

    T.it('la paga de Próxima se clasifica como nómina en el libro de flujo', function()
        dofile(DIR .. 'shared/economy.lua')
        T.eq(PXDEconomy.classify('pxd-nomina', Config.categories, Config.otherCategory), 'nominas')
        T.eq(PXDEconomy.classify('pxd-factura-3', Config.categories, Config.otherCategory), 'facturas')
    end)

    T.it('impuesto: redondea hacia abajo y respeta el tope', function()
        local P = PXDPayroll
        T.eq(P.tax(225, 0.1, 0.5), 22); T.eq(P.tax(225, 0, 0.5), 0); T.eq(P.tax(225, 0.9, 0.5), 112); T.eq(P.tax(225, -1, 0.5), 0)
    end)

    T.it('ausente tras 10 minutos sin moverse ni girarse; moverse o girar lo reactiva', function()
        local P, afk = PXDPayroll, Config.payroll.afk
        local st = P.newState(0, 0)
        T.falsy(P.activity(st, { x = 0, y = 0, z = 0 }, 0, 0, afk))
        T.falsy(P.activity(st, { x = 0.5, y = 0, z = 0 }, 0, 599, afk), 'aún no')
        T.truthy(P.activity(st, { x = 0.5, y = 0, z = 0 }, 0, 600, afk), '10 min quieto')
        T.falsy(P.activity(st, { x = 5, y = 0, z = 0 }, 0, 630, afk), 'se movió')
        T.truthy(P.activity(st, { x = 5, y = 0, z = 0 }, 0, 1300, afk))
        T.falsy(P.activity(st, { x = 5, y = 0, z = 0 }, 90, 1330, afk), 'giró')
        T.falsy(P.activity(P.newState(0, 0), nil, nil, 5000, { enabled = false }), 'anti-AFK apagado')
    end)

    T.it('el ciclo solo avanza con derecho a paga y sin estar ausente, y no regala tiempo', function()
        local P, cfg = PXDPayroll, Config.payroll
        local st = P.newState(0, 0)
        T.falsy(P.accumulate(st, 30, true, false, cfg)); T.eq(st.progress, 30)
        P.accumulate(st, 30, true, true, cfg); T.eq(st.progress, 30, 'ausente no suma')
        P.accumulate(st, 30, false, false, cfg); T.eq(st.progress, 30, 'sin derecho no suma')
        P.accumulate(st, 99999, true, false, cfg); T.eq(st.progress, 90, 'un parón del servidor suma como mucho dos revisiones')
        st.progress = 1790
        T.truthy(P.accumulate(st, 30, true, false, cfg)); T.eq(P.remaining(st, cfg), 0)
    end)
end)

T.describe('pxd_economy · paga (servidor)', function()
    T.it('con el parche de qbx_core la nómina es de Próxima; sin él no paga (paga qbx_core)', function()
        boot()
        T.truthy(PXDPayrollServer.isActive()); T.eq(GlobalState.pxdPayroll, true)
        T.truthy(QBX_PATCHED:find(PXDPayroll.PATCH_MARK, 1, true), 'la marca coincide con el parche')
        boot({ unpatched = true })
        T.falsy(PXDPayrollServer.isActive()); T.eq(GlobalState.pxdPayroll, false)
        play(31)
        T.eq(bank(1), 0); T.eq(bank(2), 0)
    end)

    T.it('paga a los 30 minutos activos: sueldo ×3, motivo pxd-nomina, aviso con desglose y auditoría', function()
        boot()
        play(29)
        T.eq(bank(1), 0, 'a los 29 min aún no')
        play(1)
        T.eq(bank(1), 225); T.eq(players[1].log[1].reason, 'pxd-nomina'); T.eq(players[1].log[1].type, 'bank')
        T.eq(bank(2), 30, 'ayuda al desempleado')
        local b = payday(1)
        T.eq(b.gross, 225); T.eq(b.tax, 0); T.eq(b.net, 225); T.eq(b.kind, 'sueldo'); T.eq(b.job, 'Taller')
        T.eq(payday(2).fines, 500, 'recuerda las multas pendientes')
        T.eq(audited[1].action, 'nomina'); T.eq(audited[1].actor, 'system'); T.eq(audited[1].data.source, 'estado')
        T.eq(Fx.playerStates[1].pxdPayday.remaining, 1800, 'cuenta atrás reiniciada')
        T.eq(db.payroll.MEC1.paid_total, 225); T.eq(db.payroll.MEC1.paid_count, 1)
        play(30)
        T.eq(bank(1), 450, 'segunda paga 30 min después')
    end)

    T.it('ausente no cobra y fuera de servicio tampoco; al volver sigue donde lo dejó', function()
        boot()
        play(15)
        play(40, {})            -- nadie se mueve: a los 10 min pasan a ausentes
        T.eq(bank(1), 0); T.truthy(Fx.playerStates[1].pxdPayday.afk)
        local before = PXDPayrollServer.states().MEC1.progress
        T.truthy(before >= 15 * 60 and before < 30 * 60, 'conserva lo acumulado antes de ausentarse')
        players[1].PlayerData.job.onduty = false
        play(30)
        T.eq(bank(1), 0, 'fuera de servicio no acumula')
        T.falsy(Fx.playerStates[1].pxdPayday.eligible)
        players[1].PlayerData.job.onduty = true
        play(6)
        T.eq(bank(1), 225)
    end)

    T.it('reconectar no reinicia el ciclo ni permite cobrar dos veces', function()
        boot()
        play(20)
        Fx.emit('playerDropped', 1)
        T.eq(db.payroll.MEC1.progress, 1200, 'progreso guardado al salir')
        T.falsy(PXDPayrollServer.states().MEC1)
        _G.Player(1).state.isLoggedIn = false          -- desconectado: no hay personaje cargado
        play(5, { 2 })
        T.falsy(PXDPayrollServer.states().MEC1, 'desconectado no acumula')
        _G.Player(1).state.isLoggedIn = true
        Fx.emit('QBCore:Server:PlayerLoaded', nil, players[1])
        T.eq(PXDPayrollServer.states().MEC1.progress, 1200)
        play(10)
        T.eq(bank(1), 225, 'cobra a los 30 min de tiempo activo en total')
        -- Intento de segunda paga dentro del mismo ciclo (p. ej. dos procesos): la base de datos lo impide.
        PXDPayrollServer.states().MEC1.progress = 1800
        play(1)
        T.eq(bank(1), 225); T.eq(db.payroll.MEC1.paid_count, 1)
    end)

    T.it('impuesto configurable: retiene, registra e ingresa en la cuenta del Estado', function()
        boot({ accounts = { mechanic = 1000, estado = 0 }, config = function(c) c.taxes.payroll = 0.1 end })
        play(30)
        T.eq(bank(1), 203); T.eq(payday(1).tax, 22)
        T.eq(accounts.estado, 22 + 3)
        T.eq(db.taxes[1].kind, 'payroll'); T.eq(db.taxes[1].deposited, 1)
        T.eq(PXDTax.summary(1).payroll.amount, 25)
    end)

    T.it('sin cuenta del Estado: la crea; si no puede, lo recaudado queda registrado sin ingresar', function()
        boot({ config = function(c) c.taxes.payroll = 0.1 end })
        play(30)
        T.eq(accounts.estado, 25, 'creada con CreateJobAccount')
        boot({ createFails = true, config = function(c) c.taxes.payroll = 0.1 end })
        play(30)
        T.eq(accounts.estado, nil); T.eq(#db.taxes, 2); T.eq(db.taxes[1].deposited, 0)
        T.eq(bank(1), 203, 'el jugador cobra igual su neto')
    end)

    T.it('nómina con fondos de la empresa: descuenta de su cuenta; sin fondos no paga y reintenta', function()
        boot({ config = function(c) c.payroll.society.mechanic = true end })
        play(30)
        T.eq(bank(1), 225); T.eq(accounts.mechanic, 775); T.eq(audited[1].data.source, 'empresa')
        boot({ accounts = { mechanic = 100 }, config = function(c) c.payroll.society.mechanic = true end })
        play(30)
        T.eq(bank(1), 0); T.eq(accounts.mechanic, 100)
        T.truthy(Fx.lastTo(1, 'pxd_economy:client:paydayFailed'))
        T.eq(PXDPayrollServer.states().MEC1.progress, 1500, 'reintenta en 5 minutos')
        T.eq(bank(2), 30, 'los demás cobran')
    end)

    T.it('si qbx_core rechaza el ingreso, se deshace y no se pierde la paga', function()
        boot()
        play(29)
        addMoneyOk = false
        play(1)
        T.eq(bank(1), 0); T.eq(db.payroll.MEC1.paid_count, 0); T.eq(db.payroll.MEC1.last_paid_at, 0)
        addMoneyOk = true
        play(1)
        T.eq(bank(1), 225)
    end)

    T.it('si qbx_core sigue pagando (parche sin reiniciar), cede la nómina; el margen de arranque evita la doble paga', function()
        boot({ config = function(c) c.payroll.startGraceMinutes = 11 end })
        PXDPayrollServer.states()   -- (cargado)
        play(5)
        local st = PXDPayrollServer.states().MEC1
        st.progress = 1800
        play(1)
        T.eq(bank(1), 0, 'dentro del margen no se paga')
        Fx.emit('qbx_core:server:onPaycheck', nil, 1, 75)
        T.falsy(PXDPayrollServer.isActive()); T.eq(GlobalState.pxdPayroll, false)
        play(20)
        T.eq(bank(1), 0)
    end)
end)

T.describe('pxd_economy · mercado (lógica pura)', function()
    local function load() dofile(DIR .. 'config.lua'); dofile(DIR .. 'shared/market.lua'); return PXDMarket, Config.market end
    local mid = function() return 0.5 end

    T.it('el catálogo es válido y sus ítems existen en la receta de Qbox', function()
        local M, cfg = load()
        T.eq(#M.validate(cfg), 0, table.concat(M.validate(cfg), '; '))
        local known = {}
        for line in io.lines(ROOT .. 'tests/fixtures/qbox-items.txt') do if line:sub(1, 1) ~= '#' then known[line] = true end end
        for id, g in pairs(cfg.goods) do
            if g.item then T.truthy(known[g.item], id .. ': el ítem no existe en ox_inventory: ' .. tostring(g.item)) end
        end
        T.falsy(cfg.goods.fuel.item, 'el combustible aún no es un ítem')
        local bad = { goods = { x = { label = 'X', category = 'nada', base = 5, min = 9, max = 2 } }, categories = {}, events = { { id = 'e', pct = { 2, 1 } } } }
        T.truthy(#M.validate(bad) >= 3)
    end)

    T.it('sube con la demanda, baja con la oferta y vuelve hacia el precio base', function()
        local M, cfg = load()
        cfg.eventChance = 0
        local st = M.new(cfg)
        M.record(st, 'steel', 'buy', 200)
        M.step(st, cfg, mid, 0)
        T.truthy(near(st.goods.steel.price, 61.8), 'presión máxima: +3 % → ' .. st.goods.steel.price)
        T.eq(st.goods.iron.price, 45, 'sin operaciones ni ruido no se mueve')
        for _ = 1, 3 do M.record(st, 'steel', 'sell', 500); M.step(st, cfg, mid, 0) end
        T.truthy(st.goods.steel.price < 60, 'la oferta lo baja: ' .. st.goods.steel.price)
        local low = st.goods.steel.price
        for _ = 1, 60 do M.step(st, cfg, mid, 0) end
        T.truthy(st.goods.steel.price > low and near(st.goods.steel.price, 60, 0.6), 'vuelve a su base: ' .. st.goods.steel.price)
        T.falsy(M.record(st, 'nada', 'buy', 1)); T.falsy(M.record(st, 'steel', 'buy', -5)); T.falsy(M.record(st, 'steel', 'regalar', 5))
    end)

    T.it('nunca sale de [mín, máx] ni cambia más del 5 % por tick, pase lo que pase', function()
        local M, cfg = load()
        local seed = 12345
        local rnd = function() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end
        local st = M.new(cfg)
        for n = 1, 600 do
            for id in pairs(cfg.goods) do M.record(st, id, n % 7 < 4 and 'buy' or 'sell', 100000) end
            for _, c in ipairs((M.step(st, cfg, rnd, n))) do
                local g = cfg.goods[c.id]
                T.truthy(c.new >= g.min and c.new <= g.max, c.id .. ' fuera de rango: ' .. c.new)
                T.truthy(math.abs(c.new - c.old) <= c.old * 0.05 + 0.011, c.id .. ' salto mayor del 5 %')
            end
        end
    end)

    T.it('una noticia mueve el precio de su categoría mientras dura, con titular en español', function()
        local M, cfg = load()
        cfg.eventChance = 0
        local st = M.new(cfg)
        local ev = M.addEvent(st, cfg, { headline = 'Aumentan las reparaciones: las piezas suben un {pct}', category = 'taller', pct = 0.025, ticks = 3 }, 100)
        T.eq(ev.headline, 'Aumentan las reparaciones: las piezas suben un 2,5 %')
        T.eq(M.pctText(-0.01), '1 %')
        T.truthy(near(M.eventEffect(st, cfg, 'repairkit'), 0.025)); T.eq(M.eventEffect(st, cfg, 'water'), 0)
        M.step(st, cfg, mid, 0); M.step(st, cfg, mid, 0)
        T.truthy(st.goods.repairkit.price > 250 and st.goods.water.price == 10)
        M.step(st, cfg, mid, 0)
        T.eq(#st.events, 0, 'caduca a los 3 ticks')
        T.falsy(M.addEvent(st, cfg, { headline = 'x', category = 'nada', pct = 0.1 }, 0))
        T.falsy(M.addEvent(st, cfg, { headline = 'x', good = 'steel', pct = 2 }, 0), 'efecto máximo ±50 %')
        T.falsy(M.addEvent(st, cfg, { headline = '', good = 'steel', pct = 0.1 }, 0))
    end)

    T.it('noticias automáticas: se sortean según la probabilidad y no se repite una activa', function()
        local M, cfg = load()
        local st = M.new(cfg)
        cfg.eventChance = 1
        local seq, i = { 0.0, 0.0, 0.5 }, 0
        local rnd = function() i = i + 1 return seq[((i - 1) % #seq) + 1] end
        local ev = M.rollEvent(st, cfg, rnd, 5)
        T.eq(ev.id, 'reparaciones'); T.truthy(ev.pct >= 0.01 and ev.pct <= 0.04)
        T.truthy(ev.headline:find('suben un', 1, true) and not ev.headline:find('{pct}', 1, true))
        i = 0
        T.truthy(M.rollEvent(st, cfg, rnd, 6).id ~= 'reparaciones', 'la activa no se repite')
        cfg.eventChance = 0
        T.falsy(M.rollEvent(st, cfg, rnd, 7))
    end)

    T.it('las operaciones reales generan titular e índice general', function()
        local M, cfg = load()
        cfg.eventChance = 0
        local st = M.new(cfg)
        T.eq(M.index(st, cfg), 100)
        M.record(st, 'water', 'buy', 500)
        local _, news = M.step(st, cfg, mid, 9)
        T.eq(#news, 1); T.eq(news[1].kind, 'operaciones'); T.eq(news[1].good, 'water')
        T.truthy(news[1].headline:find('Sube la demanda de agua', 1, true))
        M.record(st, 'water', 'buy', 500)
        local _, again = M.step(st, cfg, mid, 10)
        T.eq(#again, 0, 'no repite el titular en cada tick')
        T.truthy(M.index(st, cfg) > 100)
        T.eq(M.price(st, 'water'), 11); T.truthy(M.price(st, 'water', true) > 10.5)
    end)
end)

T.describe('pxd_economy · mercado (servidor)', function()
    local ex = function(name, ...) return Fx.exports.pxd_economy[name](...) end

    T.it('crea sus tablas, arranca en los precios base y guarda precio, historial y demanda', function()
        boot()
        T.eq(db.created, 5); T.truthy(PXDMarketServer.isReady())
        T.eq(ex('GetPrice', 'steel'), 60); T.eq(ex('GetPrice', 'water', true), 10); T.falsy(ex('GetPrice', 'nada'))
        T.eq(db.prices.steel.price, 60)
        T.truthy(ex('RecordTrade', 'steel', 'buy', 200)); T.falsy(ex('RecordTrade', 'steel', 'buy', 0)); T.falsy(ex('RecordTrade', 'x', 'buy', 5))
        Fx.time = Fx.time + 900
        PXDMarketServer.tick()
        T.truthy(near(ex('GetPrice', 'steel', true), 61.8)); T.eq(ex('GetPrice', 'steel'), 62)
        T.truthy(near(db.prices.steel.price, 61.8))
        local h = ex('GetHistory', 'steel', 1)
        T.eq(#h, 1); T.eq(h[1].bought, 200); T.truthy(near(h[1].price, 61.8))
        T.truthy(ex('GetMarketIndex') > 100)
        T.eq(#ex('GetPrices'), (function() local n = 0 for _ in pairs(Config.market.goods) do n = n + 1 end return n end)())
    end)

    T.it('AddMarketEvent publica la noticia, mueve el precio y sobrevive a un reinicio', function()
        boot()
        local seen
        AddEventHandler('pxd_economy:marketNews', function(n) seen = n end)
        T.truthy(ex('AddMarketEvent', { headline = 'Avería en la refinería: el combustible sube un {pct}', good = 'fuel', pct = 0.08, minutes = 45 }))
        T.falsy(ex('AddMarketEvent', { headline = 'x', good = 'nada', pct = 0.1 }))
        T.eq(seen.headline, 'Avería en la refinería: el combustible sube un 8 %')
        local news = ex('GetNews', 5)
        T.eq(#news, 1); T.eq(news[1].good, 'fuel'); T.eq(db.news[1].ticks_left, 3, '45 min = 3 ticks de 15')
        PXDMarketServer.tick()
        T.truthy(ex('GetPrice', 'fuel', true) > 5)
        local price = ex('GetPrice', 'fuel', true)
        ex('RecordTrade', 'water', 'sell', 30)
        Fx.emit('onResourceStop', nil, 'pxd_economy')
        T.eq(db.prices.water.sold, 30, 'la oferta pendiente se guarda al parar')
        boot({ keepDb = true })
        T.eq(ex('GetPrice', 'fuel', true), price, 'precio restaurado')
        T.eq(#PXDMarketServer.state().events, 1, 'la noticia sigue activa'); T.eq(PXDMarketServer.state().events[1].left, 2)
        T.eq(PXDMarketServer.state().goods.water.sold, 30)
        T.eq(#ex('GetNews', 5, news[1].id), 0, 'sinceId devuelve solo las nuevas')
    end)

    T.it('integraciones: las compras en tiendas y el repostaje cuentan como demanda', function()
        boot()
        T.truthy(shopHook, 'hook buyItem registrado en ox_inventory')
        T.eq(shopHook({ source = 2, itemName = 'water', count = 3, price = 10 }), nil, 'no cancela la compra')
        shopHook({ source = 2, itemName = 'un_item_que_no_cotiza', count = 3 })
        T.eq(PXDMarketServer.state().goods.water.bought, 3)
        T.eq(type(fuelMethod), 'function', 'cobro de ox_fuel sustituido')
        T.truthy(fuelMethod(2, 40)); T.eq(items[2].money, 60, 'cobra lo mismo que ox_fuel')
        T.eq(PXDMarketServer.state().goods.fuel.bought, 8, '40 $ / 5 $ base')
        T.falsy(fuelMethod(2, 500)); T.eq(items[2].money, 60)
        T.truthy(Fx.lastTo(2, 'ox_lib:notify').args[1].description:find('faltan $440', 1, true))
        Fx.emit('onResourceStop', nil, 'pxd_economy')
        T.eq(fuelMethod, nil, 'al parar, ox_fuel recupera su cobro')
    end)

    T.it('/mercado exige permiso; /mercado_evento exige gestionar', function()
        boot()
        Fx.clearSent()
        Fx.commands.mercado(2, {})
        T.falsy(Fx.lastTo(2, 'pxd_economy:client:market'))
        Fx.players[1].aces['pxd.economy.view'] = true
        Fx.commands.mercado(1, {})
        local v = Fx.lastTo(1, 'pxd_economy:client:market').args[1]
        T.truthy(#v.goods > 20); T.eq(v.index, 100)
        Fx.commands.mercado_evento(1, { 'taller', '3', '30', 'Las', 'piezas', 'suben', 'un', '{pct}' })
        T.eq(#db.news, 0, 'sin pxd.economy.manage no publica')
        Fx.commands.mercado_evento(0, { 'taller', '3', '30', 'Las', 'piezas', 'suben', 'un', '{pct}' })
        T.eq(db.news[1].headline, 'Las piezas suben un 3 %'); T.eq(db.news[1].category, 'taller')
    end)
end)

T.describe('pxd_economy · impuestos y cobro seguro', function()
    T.it('impuesto de facturas: el negocio recibe el resto y el cliente paga lo mismo', function()
        boot({ accounts = { mechanic = 0, estado = 0 }, config = function(c) c.taxes.invoices = 0.1 end })
        players[2].PlayerData.money.bank = 1000
        local tax = PXDTax.amount('invoices', 450)
        T.eq(tax, 45)
        local ok = PXDMoney.chargeToAccount(players[2], 'bank', 450, 'mechanic', { reason = 'pxd-factura-1', depositAmount = 450 - tax })
        T.truthy(ok); T.eq(bank(2), 550); T.eq(accounts.mechanic, 405)
        T.truthy(PXDTax.collect('invoices', 'CIT2', 450, tax, 'Factura #1'))
        T.eq(accounts.estado, 45); T.eq(db.taxes[1].base, 450)
        T.eq(PXDTax.rate('payroll'), 0); T.eq(Fx.exports.pxd_economy.GetTaxRate('invoices'), 0.1)
    end)

    T.it('con impuestos a 0 (por defecto) no se crea ninguna cuenta ni registro', function()
        boot()
        play(30)
        T.eq(accounts.estado, nil); T.eq(#db.taxes, 0)
        T.eq(PXDTax.amount('payroll', 1000), 0)
    end)
end)
