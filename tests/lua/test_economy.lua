-- Pruebas de pxd_economy: facturas, cobro seguro y registro del flujo de dinero.
-- MariaDB, qbx_core y Renewed-Banking simulados con la MISMA semántica que las consultas reales.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_economy/'

local db
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
local function isOpen(r) return r and (r.status == 'pending' or r.status == 'partial') end

local function fakeMySQL(Q)
    db = { inv = {}, events = {}, flow = {}, large = {}, nextId = 1, created = 0, upserts = 0 }
    local M = {}
    M.query = { await = function(q, p)
        if q == Q.createInvoices or q == Q.createEvents or q == Q.createFlow or q == Q.createLarge then db.created = db.created + 1 return {} end
        if q == Q.listClient or q == Q.listJob then
            local field = q == Q.listClient and 'citizenid' or 'job'
            local out = {}
            for _, r in pairs(db.inv) do if r[field] == p[1] then out[#out + 1] = copy(r) end end
            table.sort(out, function(a, b)
                if isOpen(a) ~= isOpen(b) then return isOpen(a) end
                return a.id > b.id
            end)
            while #out > p[2] do table.remove(out) end
            return out
        end
        if q == Q.flowSince then
            local agg, out = {}, {}
            for _, r in pairs(db.flow) do
                if r.hour >= p[1] then
                    local k = r.reason .. '|' .. r.money_type .. '|' .. r.direction
                    local a = agg[k]
                    if not a then a = { reason = r.reason, money_type = r.money_type, direction = r.direction, total = 0, count = 0 }; agg[k] = a; out[#out + 1] = a end
                    a.total = a.total + r.total; a.count = a.count + r.count
                end
            end
            return out
        end
        if q == Q.largeSince then
            local out = {}
            for _, r in ipairs(db.large) do if r.created_at >= p[1] then out[#out + 1] = copy(r) end end
            return out
        end
        error('consulta no simulada: ' .. q)
    end }
    M.insert = { await = function(q, p)
        if q == Q.insert then
            local id = db.nextId; db.nextId = id + 1
            db.inv[id] = { id = id, job = p[1], job_label = p[2], account = p[3], issuer_citizenid = p[4], issuer_name = p[5],
                citizenid = p[6], client_name = p[7], concept = p[8], amount = p[9], paid = 0, status = 'pending', issued_at = p[10], updated_at = p[11] }
            return id
        end
        if q == Q.event then db.events[#db.events + 1] = { invoice_id = p[1], action = p[2], actor_citizenid = p[3], amount = p[5] } return #db.events end
        if q == Q.largeInsert then db.large[#db.large + 1] = { created_at = p[1], citizenid = p[2], reason = p[3], money_type = p[4], direction = p[5], amount = p[6] } return #db.large end
        error('insert no simulado: ' .. q)
    end }
    M.single = { await = function(q, p)
        if q == Q.get then local r = db.inv[p[1]] return r and copy(r) or nil end
        if q == Q.circulation then return { cash = 1234, bank = 98765 } end
        error('single no simulado: ' .. q)
    end }
    M.scalar = { await = function(q, p)
        if q == Q.countOpen then
            local n = 0
            for _, r in pairs(db.inv) do if r.citizenid == p[1] and r.job == p[2] and isOpen(r) then n = n + 1 end end
            return n
        end
        if q == Q.outstanding then
            local s = 0
            for _, r in pairs(db.inv) do if r.citizenid == p[1] and isOpen(r) then s = s + r.amount - r.paid end end
            return s
        end
        error('scalar no simulado: ' .. q)
    end }
    M.update = { await = function(q, p)
        if q == Q.pay then
            if db.failPay then return 0 end
            local r = db.inv[p[4]]
            if not isOpen(r) or r.amount - r.paid < p[5] then return 0 end
            r.status = (r.paid + p[1] >= r.amount) and 'paid' or 'partial'; r.paid = r.paid + p[2]; r.updated_at = p[3]
            return 1
        end
        if q == Q.unpay then
            local r = db.inv[p[4]]
            if not r or r.paid < p[5] then return 0 end
            r.status = (r.paid - p[1] <= 0) and 'pending' or 'partial'; r.paid = r.paid - p[2]
            return 1
        end
        if q == Q.cancel then
            local r = db.inv[p[2]]
            if not isOpen(r) then return 0 end
            r.status = 'cancelled'
            return 1
        end
        if q == Q.flowUpsert then
            if db.failFlow then error('conexión perdida') end
            db.upserts = db.upserts + 1
            local k = table.concat({ p[1], p[2], p[3], p[4] }, '|')
            local r = db.flow[k]
            if not r then r = { hour = p[1], reason = p[2], money_type = p[3], direction = p[4], total = 0, count = 0 }; db.flow[k] = r end
            r.total = r.total + p[5]; r.count = r.count + p[6]
            return 1
        end
        error('update no simulado: ' .. q)
    end }
    return M
end

-- ── qbx_core y Renewed-Banking simulados ──
local players, notes, accounts, bankOk
local function mkPlayer(src, cid, name, job, cash, bank)
    local first, last = name:match('^(%S+)%s+(.+)$')
    local p = { PlayerData = { source = src, citizenid = cid, charinfo = { firstname = first, lastname = last },
        job = job or { name = 'unemployed', type = 'none', onduty = false, grade = { level = 0 } }, money = { cash = cash or 0, bank = bank or 0 } } }
    local function emit(t, n, action, reason) TriggerEvent('QBCore:Server:OnMoneyChange', src, t, n, action, reason) end
    p.Functions = {
        RemoveMoney = function(t, n, reason)
            if p.PlayerData.money[t] - n < 0 then return false end
            p.PlayerData.money[t] = p.PlayerData.money[t] - n; emit(t, n, 'remove', reason); return true
        end,
        AddMoney = function(t, n, reason) p.PlayerData.money[t] = p.PlayerData.money[t] + n; emit(t, n, 'add', reason); return true end,
        SetMoney = function(t, n, reason) p.PlayerData.money[t] = n; emit(t, n, 'set', reason); return true end,
        GetMoney = function(t) return p.PlayerData.money[t] end,
    }
    players[src] = p
    return p
end

local function boot(opts)
    opts = opts or {}
    players, notes, accounts, bankOk = {}, {}, { mechanic = 0, taxi = 0 }, true
    local qbx = {
        GetPlayer = function(src) return players[tonumber(src)] end,
        GetPlayerByCitizenId = function(cid) for _, p in pairs(players) do if p.PlayerData.citizenid == cid then return p end end end,
        Notify = function(src, text, kind) notes[#notes + 1] = { src = src, text = text, kind = kind } end,
    }
    local rb = {
        addAccountMoney = function(acc, n)
            if not bankOk or accounts[acc] == nil then return false end
            accounts[acc] = accounts[acc] + n
            return true
        end,
        handleTransaction = function() return {} end,
    }
    local audited = {}
    Fx.reset({ resourceName = 'pxd_economy',
        resourceStates = { qbx_core = 'started', ['Renewed-Banking'] = 'started', pxd_audit = opts.noAudit and 'missing' or 'started' },
        exports = { qbx_core = qbx, ['Renewed-Banking'] = rb, pxd_audit = { Log = function(e) audited[#audited + 1] = e return 1 end } } })
    Config, PXDEconomy, PXDEconomyStore, PXDMoney, PXDEconomyServer, PXDLedger = nil, nil, nil, nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/economy.lua', 'server/store.lua' })
    MySQL = fakeMySQL(PXDEconomyStore.Q)
    Fx.load(DIR, { 'server/money.lua', 'server/main.lua', 'server/ledger.lua' })
    -- Mecánica (1) de servicio, cliente (2) cerca, otra persona (3) lejos, policía (4) cerca.
    Fx.addPlayer(1, 'mecanica', { x = 0, y = 0, z = 0 }, opts.mechAces or {})
    Fx.addPlayer(2, 'cliente', { x = 2, y = 0, z = 0 })
    Fx.addPlayer(3, 'lejos', { x = 100, y = 0, z = 0 })
    Fx.addPlayer(4, 'policia', { x = 1, y = 0, z = 0 })
    mkPlayer(1, 'MEC1', 'Marta Llave', { name = 'mechanic', label = 'Taller', onduty = true, isboss = false, grade = { level = 0 } }, 0, 0)
    mkPlayer(2, 'CLI2', 'Lía Ríos', nil, opts.cash or 100, opts.bank or 1000)
    mkPlayer(3, 'CLI3', 'Leo Lejos', nil, 0, 5000)
    mkPlayer(4, 'COP4', 'Ana Agente', { name = 'police', type = 'leo', onduty = true, grade = { level = 3 } }, 0, 0)
    return audited
end

local function run(fn) local out = {} CreateThread(function() local r = table.pack(fn()) for i = 1, r.n do out[i] = r[i] end end) return out end
local function logged(pattern) for _, n in ipairs(notes) do if n.text:find(pattern) then return n end end end
local function inv(id) return db.inv[id] end
local function issue(src, target, amount, concept) return run(function() return PXDEconomyServer.issue(src, target, amount, concept or 'Cambio de aceite') end) end

T.describe('pxd_economy · lógica pura', function()
    T.it('valida importe y concepto de una factura', function()
        dofile(RES .. 'pxd_economy/shared/economy.lua')
        local E = PXDEconomy
        T.eq(E.validateIssue(500, '  Reparación   de motor ', 50000), 500)
        T.eq(select(2, E.validateIssue(500, '  Reparación   de motor ', 50000)), 'Reparación de motor')
        T.eq(select(2, E.validateIssue(0, 'x', 50000)), 'importe')
        T.eq(select(2, E.validateIssue(1.5, 'x', 50000)), 'importe')
        T.eq(select(2, E.validateIssue(60000, 'x', 50000)), 'importe')
        T.eq(select(2, E.validateIssue(10, '   ', 50000)), 'concepto')
        T.eq(select(2, E.validateIssue(10, string.rep('a', 121), 50000)), 'concepto')
    end)

    T.it('solo factura un trabajo permitido, de servicio y con rango', function()
        local E = PXDEconomy
        local cfg = { invoiceJobs = { mechanic = { account = 'mechanic' } }, invoiceRequireDuty = true, invoiceMinGrade = 1 }
        T.eq(select(2, E.issuerRule({ name = 'police', onduty = true, grade = { level = 4 } }, cfg)), 'trabajo')
        T.eq(select(2, E.issuerRule({ name = 'mechanic', onduty = false, grade = { level = 4 } }, cfg)), 'servicio')
        T.eq(select(2, E.issuerRule({ name = 'mechanic', onduty = true, grade = { level = 0 } }, cfg)), 'rango')
        T.eq(E.issuerRule({ name = 'mechanic', onduty = true, grade = { level = 1 } }, cfg).account, 'mechanic')
    end)

    T.it('un «set» de qbx_core se convierte en entrada o salida con el saldo conocido', function()
        local E = PXDEconomy
        T.eq(table.pack(E.movement('add', 50, 100))[3], 150)
        local d, v, c = E.movement('set', 70, 100)
        T.eq(d, 'out'); T.eq(v, 30); T.eq(c, 70)
        d, v = E.movement('set', 130, 100)
        T.eq(d, 'in'); T.eq(v, 30)
        d, v, c = E.movement('set', 130, nil)
        T.falsy(d); T.eq(c, 130, 'sin saldo previo solo se recuerda el nuevo')
    end)

    T.it('clasifica motivos y calcula el neto (dinero creado o retirado)', function()
        local E = PXDEconomy
        dofile(RES .. 'pxd_economy/config.lua')
        T.eq(E.classify('#nomina', Config.categories, Config.otherCategory), 'nominas')
        T.eq(E.classify('pxd-multa-3', Config.categories, Config.otherCategory), 'multas')
        T.eq(E.classify('Sync cash with inventory', Config.categories, Config.otherCategory), 'efectivo')
        T.eq(E.classify('', Config.categories, Config.otherCategory), 'sin_motivo')
        T.eq(E.classify('algo raro', Config.categories, Config.otherCategory), 'otros')
        local s = E.summarizeFlow({
            { reason = '#nomina', money_type = 'bank', direction = 'in', total = 300, count = 2 },
            { reason = 'pxd-factura-1', money_type = 'bank', direction = 'out', total = 100, count = 1 },
        }, Config.categories, Config.otherCategory)
        T.eq(s.totalIn, 300); T.eq(s.totalOut, 100); T.eq(s.net, 200)
        T.eq(s.categories[1].id, 'nominas')
    end)

    T.it('el acumulador agrupa por hora, motivo, tipo y sentido, y se vacía al guardar', function()
        local E = PXDEconomy
        local f = E.newFlow()
        E.record(f, 3600, 'x', 'bank', 'in', 10); E.record(f, 3600, 'x', 'bank', 'in', 5); E.record(f, 3600, 'x', 'cash', 'in', 1)
        T.eq(f.size, 2)
        local rows = E.drain(f)
        T.eq(#rows, 2); T.eq(f.size, 0)
        T.eq(rows[1].total, 15); T.eq(rows[1].count, 2)
        E.merge(f, rows[1])
        T.eq(f.rows['3600|bank|in|x'].count, 2, 'reintento conserva el número de movimientos')
    end)
end)

T.describe('pxd_economy · facturas', function()
    T.it('crea sus tablas al arrancar sin borrar nada', function()
        boot()
        T.eq(db.created, 4); T.truthy(PXDEconomyServer.isReady())
    end)

    T.it('la mecánica de servicio factura a un cliente cercano: queda pendiente y no cobra', function()
        local audited = boot()
        local id = issue(1, 2, 450)[1]
        T.eq(id, 1)
        local r = inv(1)
        T.eq(r.status, 'pending'); T.eq(r.account, 'mechanic'); T.eq(r.citizenid, 'CLI2'); T.eq(r.issuer_name, 'Marta Llave')
        T.eq(players[2].PlayerData.money.bank, 1000)
        T.eq(Fx.playerStates[2].pxdInvoices, 450)
        T.truthy(logged('Págala con /facturas'))
        T.eq(audited[1].category, 'economia'); T.eq(audited[1].action, 'factura_issue')
    end)

    T.it('rechaza: fuera de servicio, lejos, policía, a uno mismo y demasiadas abiertas', function()
        boot()
        players[1].PlayerData.job.onduty = false
        local M = PXDEconomy.MESSAGES
        T.eq(issue(1, 2, 100)[2], M.servicio)
        boot()
        T.eq(issue(1, 3, 100)[2], PXDEconomy.MESSAGES.lejos)
        boot()
        T.eq(issue(4, 2, 100)[2], PXDEconomy.MESSAGES.trabajo)
        boot()
        T.eq(issue(1, 1, 100)[2], PXDEconomy.MESSAGES.cliente)
        boot()
        for _ = 1, 5 do issue(1, 2, 10) end
        T.eq(issue(1, 2, 10)[2], PXDEconomy.MESSAGES.demasiadas)
        T.eq(db.nextId, 6, 'no se creó la sexta')
        -- Por la red (el evento sí avisa)
        boot()
        Fx.emit('pxd_economy:server:issue', 1, 3, 100, 'x')
        T.truthy(logged('demasiado lejos'))
    end)

    T.it('pago completo: cobra al cliente, ingresa en la cuenta del taller y avisa a la mecánica', function()
        boot()
        issue(1, 2, 450)
        local r = run(function() return PXDEconomyServer.pay(2, 1, 450, 'bank') end)
        T.truthy(r[1]); T.eq(inv(1).status, 'paid')
        T.eq(players[2].PlayerData.money.bank, 550); T.eq(accounts.mechanic, 450)
        T.eq(Fx.playerStates[2].pxdInvoices, 0)
        T.truthy(logged('pagó %$450'))
        T.eq(db.events[#db.events].action, 'pay')
    end)

    T.it('pago parcial y luego el resto; nunca más de lo que falta', function()
        boot()
        issue(1, 2, 500)
        local r = run(function() return PXDEconomyServer.pay(2, 1, 200, 'bank') end)
        T.truthy(r[1]); T.eq(inv(1).status, 'partial'); T.eq(inv(1).paid, 200)
        r = run(function() return PXDEconomyServer.pay(2, 1, 9999, 'bank') end)
        T.truthy(r[1]); T.eq(inv(1).status, 'paid'); T.eq(players[2].PlayerData.money.bank, 500)
        r = run(function() return PXDEconomyServer.pay(2, 1, 1, 'bank') end)
        T.falsy(r[1]); T.eq(r[2], PXDEconomy.MESSAGES.cerrada)
    end)

    T.it('sin fondos no cobra nada ni deja saldo negativo', function()
        boot({ cash = 50 })
        issue(1, 2, 450)
        local r = run(function() return PXDEconomyServer.pay(2, 1, 450, 'cash') end)
        T.falsy(r[1]); T.eq(r[2], PXDEconomy.MESSAGES.fondos)
        T.eq(players[2].PlayerData.money.cash, 50); T.eq(inv(1).status, 'pending')
    end)

    T.it('si la cuenta de la empresa falla, devuelve el dinero y deshace el pago', function()
        boot()
        issue(1, 2, 450)
        bankOk = false
        local r = run(function() return PXDEconomyServer.pay(2, 1, 450, 'bank') end)
        T.falsy(r[1]); T.eq(r[2], PXDEconomy.MESSAGES.banco)
        T.eq(players[2].PlayerData.money.bank, 1000); T.eq(inv(1).paid, 0); T.eq(inv(1).status, 'pending')
        T.eq(db.events[#db.events].action, 'pay_failed')
    end)

    T.it('si la factura cambió a mitad (base de datos), devuelve el dinero', function()
        boot()
        issue(1, 2, 450)
        db.failPay = true
        local r = run(function() return PXDEconomyServer.pay(2, 1, 450, 'bank') end)
        T.falsy(r[1]); T.eq(r[2], PXDEconomy.MESSAGES.cambio)
        T.eq(players[2].PlayerData.money.bank, 1000); T.eq(accounts.mechanic, 0)
    end)

    T.it('nadie paga facturas ajenas ni con formas de pago no permitidas', function()
        boot()
        issue(1, 2, 450)
        T.eq(run(function() return PXDEconomyServer.pay(3, 1, 450, 'bank') end)[2], PXDEconomy.MESSAGES.no_es_tuya)
        T.eq(run(function() return PXDEconomyServer.pay(2, 1, 450, 'crypto') end)[2], PXDEconomy.MESSAGES.metodo)
        T.eq(players[3].PlayerData.money.bank, 5000)
    end)

    T.it('cancela quien la emitió, un jefe del trabajo o el staff; el cliente no', function()
        boot()
        issue(1, 2, 450)
        T.falsy(run(function() return PXDEconomyServer.cancel(2, 1) end)[1])
        T.truthy(run(function() return PXDEconomyServer.cancel(1, 1) end)[1])
        T.eq(inv(1).status, 'cancelled')
        boot({ mechAces = { ['pxd.economy.manage'] = true } })
        issue(1, 2, 450)
        players[1].PlayerData.job = { name = 'taxi', onduty = true, grade = { level = 0 } }
        T.truthy(run(function() return PXDEconomyServer.cancel(1, 1) end)[1], 'staff con ACE')
    end)

    T.it('/facturas envía al cliente sus facturas y a la mecánica las de su taller', function()
        boot()
        issue(1, 2, 450)
        Fx.clearSent()
        run(function() Fx.commands.facturas(2, {}) end)
        local s = Fx.lastTo(2, 'pxd_economy:client:invoices')
        T.eq(#s.args[1].open, 1); T.eq(s.args[1].total, 450); T.falsy(s.args[2])
        run(function() Fx.commands.facturas(1, {}) end)
        s = Fx.lastTo(1, 'pxd_economy:client:invoices')
        T.eq(#s.args[2].open, 1, 'vista del trabajo')
    end)
end)

T.describe('pxd_economy · flujo de dinero', function()
    T.it('registra entradas y salidas, y calcula los «set» del inventario con el saldo conocido', function()
        boot()
        Fx.emit('QBCore:Server:PlayerLoaded', nil, players[2])
        players[2].Functions.AddMoney('bank', 200, 'transfer from CLI3')
        players[2].Functions.SetMoney('cash', 70, 'Sync cash with inventory')   -- tenía 100: gastó 30
        PXDLedger.flush()
        local s = PXDLedger.summary(1)
        local byId = {}
        for _, c in ipairs(s.categories) do byId[c.id] = c end
        T.eq(byId.transferencias['in'], 200)
        T.eq(byId.efectivo.out, 30)
        T.eq(s.circulation.bank, 98765)
    end)

    T.it('la nómina de qbx_core (sin motivo + onPaycheck) se cuenta como nómina', function()
        boot()
        Fx.emit('QBCore:Server:PlayerLoaded', nil, players[2])
        players[2].Functions.AddMoney('bank', 150)
        Fx.emit('qbx_core:server:onPaycheck', nil, 2, 150)
        players[2].Functions.AddMoney('bank', 7)   -- sin motivo y sin nómina
        PXDLedger.flush()
        local byId = {}
        for _, c in ipairs(PXDLedger.summary(1).categories) do byId[c.id] = c end
        T.eq(byId.nominas['in'], 150); T.eq(byId.sin_motivo['in'], 7)
    end)

    T.it('un pago de factura aparece como factura y los movimientos grandes se guardan aparte', function()
        boot({ bank = 100000 })
        Fx.emit('QBCore:Server:PlayerLoaded', nil, players[2])
        issue(1, 2, 30000)
        run(function() return PXDEconomyServer.pay(2, 1, 30000, 'bank') end)
        PXDLedger.flush()
        local s = PXDLedger.summary(1)
        T.eq(s.categories[1].id, 'facturas'); T.eq(s.categories[1].out, 30000)
        T.eq(#db.large, 1); T.eq(db.large[1].citizenid, 'CLI2')
    end)

    T.it('si falla el guardado, no se pierde: se reintenta en el siguiente', function()
        boot()
        Fx.emit('QBCore:Server:PlayerLoaded', nil, players[2])
        players[2].Functions.AddMoney('bank', 40, 'transfer x')
        db.failFlow = true
        PXDLedger.flush()
        T.eq(db.upserts, 0)
        db.failFlow = false
        PXDLedger.flush()
        local total = 0
        for _, r in pairs(db.flow) do total = total + r.total end
        T.eq(total, 40)
    end)

    T.it('/economia exige permiso', function()
        boot()
        Fx.clearSent()
        run(function() Fx.commands.economia(2, {}) end)
        T.falsy(Fx.lastTo(2, 'pxd_economy:client:summary'))
        boot({ mechAces = { ['pxd.economy.view'] = true } })
        run(function() Fx.commands.economia(1, { '6' }) end)
        T.eq(Fx.lastTo(1, 'pxd_economy:client:summary').args[1].hours, 6)
    end)
end)
