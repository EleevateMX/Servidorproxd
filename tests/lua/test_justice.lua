-- Pruebas de pxd_justice: multas, deudas pendientes y pagos seguros.
-- MariaDB, qbx_core y Renewed-Banking simulados con la MISMA semántica que las consultas reales.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_justice/'

-- ── MariaDB simulada: interpreta solo las consultas de server/store.lua ──
local db
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
local function fakeMySQL(Q)
    db = { fines = {}, events = {}, nextId = 1, created = 0 }
    local M = {}
    M.query = { await = function(q, p)
        if q == Q.createFines or q == Q.createEvents then db.created = db.created + 1 return {} end
        if q == Q.listOpen or q == Q.listClosed then
            local want = q == Q.listOpen and { pending = true, partial = true } or { paid = true, cancelled = true }
            local out = {}
            for _, r in pairs(db.fines) do if r.citizenid == p[1] and want[r.status] then out[#out + 1] = copy(r) end end
            table.sort(out, function(a, b) return a.id > b.id end)
            while p[2] and #out > p[2] do table.remove(out) end
            return out
        end
        if q == Q.events then
            local out = {}
            for _, e in ipairs(db.events) do if e.fine_id == p[1] then out[#out + 1] = copy(e) end end
            return out
        end
        error('consulta no simulada: ' .. q)
    end }
    M.insert = { await = function(q, p)
        if q == Q.insert then
            local id = db.nextId; db.nextId = id + 1
            db.fines[id] = { id = id, citizenid = p[1], officer_citizenid = p[2], officer_name = p[3], reason = p[4], notes = p[5],
                amount = p[6], paid = 0, status = 'pending', society = p[7], record_ref = p[8], issued_at = p[9], updated_at = p[10] }
            return id
        end
        if q == Q.event then
            db.events[#db.events + 1] = { id = #db.events + 1, fine_id = p[1], action = p[2], actor_citizenid = p[3], actor_name = p[4], amount = p[5], detail = p[6], created_at = p[7] }
            return #db.events
        end
        error('insert no simulado: ' .. q)
    end }
    M.single = { await = function(q, p)
        if q == Q.get then local r = db.fines[p[1]] return r and copy(r) or nil end
        error('single no simulado: ' .. q)
    end }
    M.scalar = { await = function(q, p)
        if q == Q.outstanding then
            local s = 0
            for _, r in pairs(db.fines) do
                if r.citizenid == p[1] and (r.status == 'pending' or r.status == 'partial') then s = s + r.amount - r.paid end
            end
            return s
        end
        error('scalar no simulado: ' .. q)
    end }
    M.update = { await = function(q, p)
        local open = function(r) return r and (r.status == 'pending' or r.status == 'partial') end
        if q == Q.pay then
            if db.failPay then error('conexión perdida') end
            local r = db.fines[p[4]]
            if not open(r) or r.amount - r.paid < p[5] then return 0 end
            r.status = (r.paid + p[1] >= r.amount) and 'paid' or 'partial'; r.paid = r.paid + p[2]; r.updated_at = p[3]
            return 1
        end
        if q == Q.unpay then
            local r = db.fines[p[4]]
            if not r or r.paid < p[5] then return 0 end
            r.status = (r.paid - p[1] <= 0) and 'pending' or 'partial'; r.paid = r.paid - p[2]; r.updated_at = p[3]
            return 1
        end
        if q == Q.cancel then
            local r = db.fines[p[2]]
            if not open(r) then return 0 end
            r.status = 'cancelled'; r.updated_at = p[1]
            return 1
        end
        if q == Q.edit then
            local r = db.fines[p[4]]
            if not open(r) or r.paid > p[5] then return 0 end
            r.status = (r.paid >= p[1]) and 'paid' or (r.paid > 0 and 'partial' or 'pending'); r.amount = p[2]; r.updated_at = p[3]
            return 1
        end
        error('update no simulado: ' .. q)
    end }
    return M
end

-- ── pxd_audit simulado (contrato de docs/34: Log y Query) ──
local auditLog, auditFail
local function fakeAudit()
    auditLog, auditFail = {}, false
    return {
        Log = function(e)
            if auditFail then error('pxd_audit caído') end
            local id = #auditLog + 1
            auditLog[id] = { id = id, created_at = e.created_at or (5000 + id), category = e.category, action = e.action,
                actor = e.actor or 'system', target = e.target, data = e.data, source = e.source, legacy_ref = e.legacy_ref }
            return id
        end,
        Query = function(f)
            local out = {}
            for i = #auditLog, 1, -1 do
                local r = auditLog[i]
                if (not f.category or r.category == f.category) and (not f.target or r.target == f.target) then out[#out + 1] = r end
            end
            return out
        end,
    }
end

-- ── qbx_core y Renewed-Banking simulados ──
local players, notes, society, bankOk, bankYield
local function mkPlayer(src, cid, name, job, cash, bank)
    local first, last = name:match('^(%S+)%s+(.+)$')
    local p = { PlayerData = { source = src, citizenid = cid, charinfo = { firstname = first, lastname = last },
        job = job or { type = 'none', onduty = false, grade = { level = 0 } }, money = { cash = cash or 0, bank = bank or 0 } } }
    p.Functions = {
        -- Como qbx_core con dontAllowMinus = { 'cash', 'crypto', 'bank' }.
        RemoveMoney = function(t, n) if p.PlayerData.money[t] - n < 0 then return false end p.PlayerData.money[t] = p.PlayerData.money[t] - n return true end,
        AddMoney = function(t, n) p.PlayerData.money[t] = p.PlayerData.money[t] + n return true end,
        GetMoney = function(t) return p.PlayerData.money[t] end,
    }
    players[src] = p
    return p
end

local function boot(opts)
    opts = opts or {}
    players, notes, society, bankOk, bankYield = {}, {}, {}, true, false
    local qbx = {
        GetPlayer = function(src) return players[tonumber(src)] end,
        GetPlayerByCitizenId = function(cid) for _, p in pairs(players) do if p.PlayerData.citizenid == cid then return p end end end,
        Notify = function(src, text, kind) notes[#notes + 1] = { src = src, text = text, kind = kind } end,
    }
    local rb = {
        addAccountMoney = function(acc, n)
            if bankYield then coroutine.yield(0) end
            if not bankOk then return false end
            society[acc] = (society[acc] or 0) + n
            return true
        end,
        handleTransaction = function() return {} end,
    }
    Fx.reset({ resourceName = 'pxd_justice',
        resourceStates = { qbx_core = 'started', ['Renewed-Banking'] = 'started', qbx_police = 'started', pxd_interact = 'started',
            pxd_audit = opts.audit and 'started' or nil },
        exports = { qbx_core = qbx, ['Renewed-Banking'] = rb, pxd_audit = opts.audit and fakeAudit() or nil,
            pxd_interact = { GetSourceByPublicId = function(id) return id == 'PROX-7KQ2' and 2 or nil end } },
        files = { ['qbx_police/server/main.lua'] = opts.unpatched and '-- sin parche' or
            "RegisterNetEvent('police:server:IssueFine', function()\n    if GetResourceState('pxd_justice') == 'started' then return end -- Próxima\n" } })
    Config, PXDFines, PXDFineStore, PXDJustice = nil, nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/fines.lua', 'server/store.lua' })
    MySQL = fakeMySQL(PXDFineStore.Q)
    if opts.config then for k, v in pairs(opts.config) do Config[k] = v end end
    Fx.load(DIR, { 'server/main.lua' })
    -- Agente (1) y ciudadana (2) cerca; otra persona (3) lejos.
    Fx.addPlayer(1, 'agente', { x = 0, y = 0, z = 0 }, opts.officerAces or {})
    Fx.addPlayer(2, 'ciudadana', { x = 2, y = 0, z = 0 })
    Fx.addPlayer(3, 'lejos', { x = 100, y = 0, z = 0 })
    mkPlayer(1, 'COP1', 'Ana Agente', { type = 'leo', onduty = true, grade = { level = 1 } }, 0, 0)
    mkPlayer(2, 'CIT2', 'Lía Ríos', nil, opts.cash or 100, opts.bank or 1000)
    mkPlayer(3, 'CIT3', 'Leo Lejos', nil, 0, 5000)
end

-- Ejecuta fn en un hilo; el resultado se rellena en la tabla devuelta (también si espera).
local function run(fn) local out = {} CreateThread(function() local r = table.pack(fn()) for i = 1, r.n do out[i] = r[i] end end) return out end
local function logged(pattern) for _, n in ipairs(notes) do if n.text:find(pattern) then return n end end end
local function fine(id) return db.fines[id] end

T.describe('pxd_justice · lógica pura', function()
    T.it('valida multas nuevas como qbx_police', function()
        dofile(RES .. 'pxd_justice/shared/fines.lua')
        T.truthy(PXDFines.validateIssue(500, 'Exceso de velocidad', nil, 100000))
        T.falsy(PXDFines.validateIssue(0, 'x', nil, 100000))
        T.falsy(PXDFines.validateIssue(1.5, 'x', nil, 100000))
        T.falsy(PXDFines.validateIssue(200000, 'x', nil, 100000))
        T.falsy(PXDFines.validateIssue(100, '   ', nil, 100000))
        T.falsy(PXDFines.validateIssue(100, 'x', string.rep('n', 1001), 100000))
    end)

    T.it('el pago se limita a lo que falta y respeta propietario, estado y forma de pago', function()
        local cfg = { paymentMethods = { cash = true, bank = true }, minPartialPayment = 1 }
        local row = { id = 1, citizenid = 'A', amount = 500, paid = 200, status = 'partial' }
        T.eq(PXDFines.validatePayment(row, 'A', 1000, 'bank', cfg), 300)
        T.eq(select(2, PXDFines.validatePayment(row, 'B', 10, 'bank', cfg)), 'no_es_tuya')
        T.eq(select(2, PXDFines.validatePayment(row, 'A', 10, 'crypto', cfg)), 'metodo')
        T.eq(select(2, PXDFines.validatePayment({ citizenid = 'A', amount = 5, paid = 5, status = 'paid' }, 'A', 1, 'bank', cfg)), 'cerrada')
    end)

    T.it('entiende ID de servidor, PROX y citizenid al buscar', function()
        T.eq(select(2, PXDFines.parseQuery('12')), 12)
        T.eq(select(2, PXDFines.parseQuery('prox-7kq2')), 'PROX-7KQ2')
        T.eq((PXDFines.parseQuery('ABC123')), 'citizenid')
        T.falsy(PXDFines.parseQuery("x'; DROP"))
    end)
end)

T.describe('pxd_justice · servidor', function()
    T.it('crea las tablas al arrancar sin borrar nada', function()
        boot()
        T.eq(db.created, 2)
        T.truthy(PXDJustice.isReady())
    end)

    T.it('el /fine de qbx_police queda como multa pendiente: no cobra en el acto', function()
        boot()
        Fx.emit('police:server:IssueFine', 1, 2, 'Exceso de velocidad', 500, 'radar móvil')
        local f = fine(1)
        T.eq(f.status, 'pending'); T.eq(f.amount, 500); T.eq(f.citizenid, 'CIT2'); T.eq(f.officer_name, 'Ana Agente')
        T.eq(players[2].PlayerData.money.bank, 1000, 'no se cobra solo')
        T.eq(Fx.playerStates[2].pxdFines, 500, 'el HUD ve lo pendiente')
        T.eq(db.events[1].action, 'issue')
        T.truthy(logged('Págala desde el panel'))
    end)

    T.it('sin el parche de qbx_police no atiende el evento (evita multar dos veces)', function()
        boot({ unpatched = true })
        Fx.emit('police:server:IssueFine', 1, 2, 'Exceso', 500)
        T.falsy(fine(1))
    end)

    T.it('solo multa la policía de servicio y de cerca', function()
        boot()
        players[1].PlayerData.job.onduty = false
        Fx.emit('police:server:IssueFine', 1, 2, 'Exceso', 500)
        T.falsy(fine(1))
        T.truthy(logged('Solo la policía de servicio'))
        boot()
        Fx.emit('police:server:IssueFine', 1, 3, 'Exceso', 500)
        T.falsy(fine(1)); T.truthy(logged('demasiado lejos'))
        boot()
        Fx.emit('police:server:IssueFine', 1, 2, 'Exceso', 999999)
        T.falsy(fine(1))
    end)

    T.it('pago completo: descuenta, marca pagada, ingresa en la sociedad y audita', function()
        boot()
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        local r = run(function() return PXDJustice.pay(2, id, 500, 'bank') end)
        T.truthy(r[1]); T.eq(fine(id).status, 'paid'); T.eq(fine(id).paid, 500)
        T.eq(players[2].PlayerData.money.bank, 500)
        T.eq(society.police, 500)
        T.eq(Fx.playerStates[2].pxdFines, 0)
        T.eq(db.events[#db.events].action, 'pay')
    end)

    T.it('pagos parciales y el exceso se limita a lo que falta', function()
        boot()
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        run(function() return PXDJustice.pay(2, id, 200, 'cash') end)
        T.eq(fine(id).status, 'pending', 'tenía 100 en efectivo: no paga 200')
        T.eq(fine(id).paid, 0); T.eq(players[2].PlayerData.money.cash, 100)
        local r = run(function() return PXDJustice.pay(2, id, 200, 'bank') end)
        T.truthy(r[1]); T.eq(fine(id).paid, 200); T.eq(fine(id).status, 'partial')
        r = run(function() return PXDJustice.pay(2, id, 5000, 'bank') end)
        T.truthy(r[1]); T.eq(fine(id).paid, 500); T.eq(fine(id).status, 'paid')
        T.eq(players[2].PlayerData.money.bank, 500, 'solo se cobró lo que faltaba')
    end)

    T.it('sin fondos: la multa sigue pendiente y no hay saldo negativo', function()
        boot({ bank = 100, cash = 0 })
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        local r = run(function() return PXDJustice.pay(2, id, 500, 'bank') end)
        T.falsy(r[1]); T.eq(r[2], PXDFines.MESSAGES.fondos)
        T.eq(fine(id).status, 'pending'); T.eq(players[2].PlayerData.money.bank, 100)
    end)

    T.it('si el banco de la sociedad falla, devuelve el dinero y deja la multa como estaba', function()
        boot()
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        bankOk = false
        local r = run(function() return PXDJustice.pay(2, id, 500, 'bank') end)
        T.falsy(r[1]); T.eq(r[2], PXDFines.MESSAGES.banco)
        T.eq(players[2].PlayerData.money.bank, 1000, 'reembolsado')
        T.eq(fine(id).paid, 0); T.eq(fine(id).status, 'pending')
        T.eq(db.events[#db.events].action, 'pay_failed')
    end)

    T.it('si la base de datos falla tras cobrar, devuelve el dinero', function()
        boot()
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        db.failPay = true
        local r = run(function() return PXDJustice.pay(2, id, 500, 'bank') end)
        T.falsy(r[1]); T.eq(players[2].PlayerData.money.bank, 1000, 'reembolsado')
        T.eq(fine(id).paid, 0); T.falsy(society.police)
        db.failPay = false
        T.truthy(run(function() return PXDJustice.pay(2, id, 500, 'bank') end)[1], 'el bloqueo se libera')
    end)

    T.it('nunca deja saldo negativo aunque qbx_core lo permitiera', function()
        boot({ bank = 100 })
        players[2].Functions.RemoveMoney = function(t, n) players[2].PlayerData.money[t] = players[2].PlayerData.money[t] - n return true end
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        local r = run(function() return PXDJustice.pay(2, id, 500, 'bank') end)
        T.falsy(r[1]); T.eq(players[2].PlayerData.money.bank, 100)
    end)

    T.it('dos pagos a la vez de la misma multa: solo uno se aplica', function()
        boot({ bank = 5000 })
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        bankYield = true
        local first = run(function() return PXDJustice.pay(2, id, 500, 'bank') end)   -- se queda esperando al banco
        local second = run(function() return PXDJustice.pay(2, id, 500, 'bank') end)
        T.falsy(second[1]); T.eq(second[2], PXDFines.MESSAGES.en_curso)
        Fx.advance(0)
        T.eq(fine(id).paid, 500); T.eq(players[2].PlayerData.money.bank, 4500, 'cobrado una sola vez')
        T.eq(society.police, 500)
        T.truthy(first[1], 'el primer pago termina bien')
    end)

    T.it('nadie paga multas ajenas', function()
        boot()
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        local r = run(function() return PXDJustice.pay(3, id, 500, 'bank') end)
        T.falsy(r[1]); T.eq(r[2], PXDFines.MESSAGES.no_es_tuya)
    end)

    T.it('cancelar y corregir: solo con permiso, auditado y nunca por debajo de lo pagado', function()
        boot({ officerAces = { ['pxd.justice.manage'] = true } })
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        T.falsy(PXDJustice.cancel(2, id, 'no'), 'la multada no puede')
        run(function() return PXDJustice.pay(2, id, 300, 'bank') end)
        T.falsy(run(function() return PXDJustice.edit(1, id, 200, 'rebaja') end)[1], 'menor que lo pagado')
        T.truthy(run(function() return PXDJustice.edit(1, id, 300, 'rebaja') end)[1])
        T.eq(fine(id).status, 'paid'); T.eq(fine(id).amount, 300)
        local id2 = run(function() return PXDJustice.issue(1, 2, 'Otra', 100) end)[1]
        T.truthy(run(function() return PXDJustice.cancel(1, id2, 'error') end)[1])
        T.eq(fine(id2).status, 'cancelled')
        local actions = {}
        for _, e in ipairs(db.events) do actions[#actions + 1] = e.action end
        T.eq(table.concat(actions, ','), 'issue,pay,edit,issue,cancel')
    end)

    T.it('consultas: el jugador ve lo suyo; la policía busca por ID o PROX y ve notas', function()
        boot()
        run(function() return PXDJustice.issue(1, 2, 'Exceso', 500, 'nota interna') end)
        local mine = run(function() return PXDJustice.view(2) end)[1]
        T.eq(mine.outstanding, 500); T.eq(#mine.pending, 1); T.falsy(mine.pending[1].notes); T.falsy(mine.canSearch)
        local found = run(function() return PXDJustice.search(1, 'PROX-7KQ2') end)[1]
        T.eq(found.citizenid, 'CIT2'); T.eq(found.pending[1].notes, 'nota interna')
        local denied = run(function() return PXDJustice.search(3, '2') end)
        T.falsy(denied[1])
    end)

    T.it('una deuda antigua sigue visible aunque el historial sea largo', function()
        boot({ config = { historyLimit = 2 }, bank = 100000 })
        local old = run(function() return PXDJustice.issue(1, 2, 'Antigua', 50000) end)[1]
        for i = 1, 4 do
            local id = run(function() return PXDJustice.issue(1, 2, 'Pagada ' .. i, 10) end)[1]
            run(function() return PXDJustice.pay(2, id, 10, 'bank') end)
        end
        local v = run(function() return PXDJustice.view(2) end)[1]
        T.eq(#v.pending, 1); T.eq(v.pending[1].id, old); T.eq(v.outstanding, 50000)
        T.eq(#v.history, 2)
    end)

    T.it('cobro automático opcional solo si hay saldo', function()
        boot({ config = { autoChargeIfFunds = true }, bank = 1000 })
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        T.eq(fine(id).status, 'paid'); T.eq(players[2].PlayerData.money.bank, 500)
        local id2 = run(function() return PXDJustice.issue(1, 2, 'Otra', 900) end)[1]
        T.eq(fine(id2).status, 'pending', 'sin saldo queda como deuda')
    end)
end)

-- ── Auditoría común (pxd_audit) y preparación de los radares ──
local function actionsOf(list) local a = {} for _, e in ipairs(list) do a[#a + 1] = e.action end return table.concat(a, ',') end

T.describe('pxd_justice · auditoría en pxd_audit', function()
    T.it('con pxd_audit en marcha, emitir y pagar se auditan allí (categoría fines) y no en pxd_fine_events', function()
        boot({ audit = true })
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        run(function() return PXDJustice.pay(2, id, 200, 'bank') end)
        T.eq(#db.events, 0)
        T.eq(actionsOf(auditLog), 'issue,pay')
        local e = auditLog[1]
        T.eq(e.category, 'fines'); T.eq(e.target, 'fine:' .. id); T.eq(e.actor, 'COP1'); T.eq(e.source, 'pxd_justice')
        T.eq(e.data.citizenid, 'CIT2'); T.eq(e.data.actor_name, 'Ana Agente'); T.eq(e.data.amount, 500); T.eq(e.data.detail, 'Exceso')
        T.eq(auditLog[2].actor, 'CIT2'); T.eq(auditLog[2].data.detail, 'bank')
    end)

    T.it('cancelar desde la consola queda como sistema', function()
        boot({ audit = true })
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        run(function() return PXDJustice.cancel(0, id, 'error') end)
        T.eq(auditLog[2].action, 'cancel'); T.eq(auditLog[2].actor, 'system'); T.eq(auditLog[2].data.actor_name, 'consola')
    end)

    T.it('si pxd_audit falla, no se pierde: va a pxd_fine_events y avisa', function()
        boot({ audit = true })
        auditFail = true
        run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)
        T.eq(db.events[1].action, 'issue')
        local warned = false
        for _, l in ipairs(Fx.logs) do if l:find('pxd_audit no registró issue') then warned = true end end
        T.truthy(warned)
    end)

    T.it('GetFineEvents une pxd_fine_events y pxd_audit sin duplicar lo migrado', function()
        boot({ audit = true })
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]   -- en pxd_audit
        -- Dos eventos antiguos de esa multa; el 1 ya se migró a pxd_audit.
        db.events[1] = { id = 1, fine_id = id, action = 'edit', actor_name = 'consola', amount = 400, created_at = 100 }
        db.events[2] = { id = 2, fine_id = id, action = 'pay', actor_citizenid = 'CIT2', amount = 50, created_at = 200 }
        auditLog[#auditLog + 1] = { id = #auditLog + 1, created_at = 100, category = 'fines', action = 'edit', actor = 'system',
            target = 'fine:' .. id, data = { fine_id = id, actor_name = 'consola', amount = 400 }, source = 'pxd_justice', legacy_ref = 'fine_event:1' }
        local ev = run(function() return Fx.exports.pxd_justice.GetFineEvents(id) end)[1]
        T.eq(actionsOf(ev), 'edit,pay,issue')
        T.eq(ev[1].id, 1); T.eq(ev[1].actor_name, 'consola'); T.eq(ev[1].amount, 400)
        T.eq(ev[2].id, 2); T.eq(ev[3].actor_citizenid, 'COP1'); T.eq(ev[3].fine_id, id)
    end)

    T.it('sin pxd_audit, GetFineEvents devuelve lo de siempre', function()
        boot()
        local id = run(function() return PXDJustice.issue(1, 2, 'Exceso', 500) end)[1]
        local ev = run(function() return Fx.exports.pxd_justice.GetFineEvents(id) end)[1]
        T.eq(actionsOf(ev), 'issue'); T.eq(ev[1].id, 1); T.eq(ev[1].actor_citizenid, 'COP1')
    end)
end)

T.describe('pxd_justice · multas del sistema y radares (preparado, sin cambios)', function()
    T.it('IssueSystemFine deja una multa pendiente, sin cobrar, con autor sistema', function()
        boot({ audit = true })
        local r = run(function() return Fx.exports.pxd_justice.IssueSystemFine('CIT2', 'Radar de velocidad', 250, { source = 'radar', fine = 3 }) end)
        local id = r[1]
        T.eq(fine(id).status, 'pending'); T.eq(fine(id).amount, 250); T.eq(fine(id).citizenid, 'CIT2')
        T.eq(fine(id).officer_name, 'Sistema'); T.falsy(fine(id).officer_citizenid)
        T.eq(r[2], 250, 'devuelve lo pendiente')
        T.eq(players[2].PlayerData.money.bank, 1000, 'no cobra')
        T.eq(Fx.playerStates[2].pxdFines, 250)
        T.truthy(logged('Radar de velocidad'))
        T.eq(auditLog[1].actor, 'system'); T.eq(auditLog[1].data.origin, 'radar'); T.eq(auditLog[1].data.system, true)
        T.eq(auditLog[1].data.citizenid, 'CIT2')
    end)

    T.it('IssueSystemFine valida ciudadano, motivo, importe, notas y origen', function()
        boot()
        local function issue(...) local a = table.pack(...) return run(function() return PXDJustice.issueSystem(table.unpack(a, 1, a.n)) end) end
        T.falsy(issue(nil, 'Radar', 100)[1])
        T.falsy(issue("CIT2'; DROP", 'Radar', 100)[1])
        T.falsy(issue(string.rep('A', 65), 'Radar', 100)[1])
        T.falsy(issue('CIT2', '  ', 100)[1])
        T.falsy(issue('CIT2', 'Radar', 0)[1])
        T.falsy(issue('CIT2', 'Radar', 12.5)[1])
        T.falsy(issue('CIT2', 'Radar', 100001)[1])
        T.falsy(issue('CIT2', 'Radar', 100, { notes = string.rep('n', 1001) })[1])
        T.falsy(issue('CIT2', 'Radar', 100, { source = 'radar móvil' })[1])
        T.eq(db.nextId, 1, 'no se ha creado ninguna')
        T.truthy(issue('OFFLINE9', 'Peaje', 30, { source = 'peaje' })[1], 'también sin estar conectado')
        T.eq(fine(1).citizenid, 'OFFLINE9')
    end)

    T.it('IssueSystemFine no repite la misma multa del mismo origen en el enfriamiento', function()
        boot()
        T.truthy(run(function() return PXDJustice.issueSystem('CIT2', 'Radar', 50, { source = 'radar' }) end)[1])
        local again = run(function() return PXDJustice.issueSystem('CIT2', 'Radar', 50, { source = 'radar' }) end)
        T.falsy(again[1]); T.truthy(again[2]:find('espera'))
        T.truthy(run(function() return PXDJustice.issueSystem('CIT2', 'Peaje', 50, { source = 'peaje' }) end)[1], 'otro origen sí')
        Config.systemFine.cooldownSec = 0
        T.truthy(run(function() return PXDJustice.issueSystem('CIT2', 'Radar', 50, { source = 'radar' }) end)[1])
        T.eq(db.events[1].actor_name, 'Sistema', 'sin pxd_audit, auditado en pxd_fine_events')
        T.falsy(db.events[1].actor_citizenid)
    end)

    T.it('los radares no cambian: modo instant y pxd_justice no atiende police:server:Radar', function()
        boot()
        T.eq(Config.radar.mode, 'instant')
        T.eq(Fx.exports.pxd_justice.GetRadarMode(), 'instant')
        T.falsy(Fx.handlers['police:server:Radar'])
        Config.radar.mode = 'pending'
        T.eq(Fx.exports.pxd_justice.GetRadarMode(), 'pending')
        Config.radar.mode = 'cualquier cosa'
        T.eq(Fx.exports.pxd_justice.GetRadarMode(), 'instant')
    end)
end)

-- ── Pestaña «Multas» de pxd_panel: solo reenvía; pxd_justice decide ──
T.describe('pxd_justice · pestaña Multas del panel', function()
    local calls
    local function bootPanel(withJustice)
        calls = {}
        local player = { PlayerData = { citizenid = 'CIT2', charinfo = { firstname = 'Lía', lastname = 'Ríos' },
            job = { name = 'unemployed', label = 'Paro', onduty = false, grade = { name = 'x', level = 0 } },
            gang = { name = 'none' }, money = { cash = 0, bank = 0 }, jobs = {}, gangs = {} } }
        local exports = { qbx_core = {
            GetPlayer = function(src) return src == 1 and player or nil end,
            GetJobs = function() return {} end, GetGangs = function() return {} end,
            GetDutyCountJob = function() return 0 end,
        } }
        local states = { qbx_core = 'started' }
        if withJustice then
            states.pxd_justice = 'started'
            exports.pxd_justice = {
                GetPlayerView = function(src) return { outstanding = 500, pending = { { id = 7 } }, history = {}, canSearch = false } end,
                PayFine = function(src, id, amount, method) calls[#calls + 1] = { src, id, amount, method } return true, 'Multa #7 pagada.' end,
                SearchFines = function(src, q) return nil, 'No tienes permiso para consultar multas.' end,
            }
        end
        Fx.reset({ resourceName = 'pxd_panel', exports = exports, resourceStates = states, convars = { sv_maxclients = 48 } })
        _G.GetNumPlayerIndices = function() return 1 end
        Config, PXDPanel, PXDRules = nil, nil, nil
        Fx.load(RES .. 'pxd_panel/', { 'config.lua', 'shared/rules.lua', 'shared/panel.lua', 'server/main.lua' })
        Fx.addPlayer(1, 'Lía')
    end

    T.it('la pestaña solo aparece con pxd_justice en marcha', function()
        bootPanel(false)
        Fx.emit('pxd_panel:server:open', 1, false)
        T.falsy(Fx.lastTo(1, 'pxd_panel:client:data').args[1].fines)
        bootPanel(true)
        Fx.emit('pxd_panel:server:open', 1, false)
        T.eq(Fx.lastTo(1, 'pxd_panel:client:data').args[1].fines.outstanding, 500)
    end)

    T.it('pagar reenvía id, importe y forma de pago validados', function()
        bootPanel(true)
        Fx.emit('pxd_panel:server:payFine', 1, 7, 200, 'bank')
        T.eq(#calls, 1); T.eq(calls[1][2], 7); T.eq(calls[1][3], 200); T.eq(calls[1][4], 'bank')
        T.truthy(Fx.lastTo(1, 'pxd_panel:client:result').args[1].ok)
        for _, bad in ipairs({ { 7, -5, 'bank' }, { 7, 1.5, 'bank' }, { 'x', 10, 'bank' }, { 7, 10, 'crypto' } }) do
            Fx.advance(2)
            Fx.emit('pxd_panel:server:payFine', 1, bad[1], bad[2], bad[3])
        end
        T.eq(#calls, 1, 'datos raros no llegan a pxd_justice')
    end)

    T.it('la búsqueda devuelve el motivo del rechazo', function()
        bootPanel(true)
        Fx.emit('pxd_panel:server:searchFines', 1, 'PROX-7KQ2')
        local r = Fx.lastTo(1, 'pxd_panel:client:fineSearch').args[1]
        T.falsy(r.ok); T.eq(r.message, 'No tienes permiso para consultar multas.')
    end)
end)
