-- Pruebas de pxd_garage: catálogo y precios, cobro y reembolso, eventos manipulados y niveles de mecánico.
-- MariaDB, qbx_core, qbx_vehicles, pxd_economy y Renewed-Banking simulados.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_garage/'

local db, players, notes, vehicles, accounts, invoices, saves, audited, failSave, economyOn
local VEH = 7001   -- entidad del vehículo de la clienta

local function fakeMySQL(Q)
    db = { stats = {}, log = {}, created = 0 }
    local M = {}
    M.query = { await = function(q, p)
        if q == Q.createStats or q == Q.createLog then db.created = db.created + 1 return {} end
        if q == Q.recent then return {} end
        error('consulta no simulada: ' .. q)
    end }
    M.single = { await = function(q, p)
        if q == Q.get then
            local r = db.stats[p[1]]
            return r and { citizenid = p[1], xp = r.xp, jobs = r.jobs, day = r.day, day_xp = r.day_xp } or nil
        end
        error('single no simulado: ' .. q)
    end }
    M.update = { await = function(q, p)
        if q == Q.add then
            local r = db.stats[p[1]]
            if not r then db.stats[p[1]] = { xp = p[2], jobs = 1, day = p[3], day_xp = p[4] } return 1 end
            r.xp = r.xp + p[2]; r.jobs = r.jobs + 1
            r.day_xp = (r.day == p[3]) and (r.day_xp + p[4]) or p[4]; r.day = p[3]
            return 1
        end
        if q == Q.set then
            local r = db.stats[p[1]]
            if r then r.xp = p[2] else db.stats[p[1]] = { xp = p[2], jobs = 0, day = 0, day_xp = 0 } end
            return 1
        end
        error('update no simulado: ' .. q)
    end }
    M.insert = { await = function(q, p)
        if q == Q.log then db.log[#db.log + 1] = { citizenid = p[1], kind = p[2], plate = p[3], xp = p[4], amount = p[5], detail = p[6] } return #db.log end
        error('insert no simulado: ' .. q)
    end }
    return M
end

local function mkPlayer(src, cid, name, job, cash, bank)
    local first, last = name:match('^(%S+)%s+(.+)$')
    local p = { PlayerData = { source = src, citizenid = cid, charinfo = { firstname = first, lastname = last },
        job = job or { name = 'unemployed', onduty = false, grade = { level = 0 } }, money = { cash = cash or 0, bank = bank or 0 } } }
    p.Functions = {
        RemoveMoney = function(t, n) if p.PlayerData.money[t] - n < 0 then return false end p.PlayerData.money[t] = p.PlayerData.money[t] - n return true end,
        AddMoney = function(t, n) p.PlayerData.money[t] = p.PlayerData.money[t] + n return true end,
        GetMoney = function(t) return p.PlayerData.money[t] end,
    }
    players[src] = p
    return p
end

-- Pone a un jugador al volante (o lo baja) del vehículo de pruebas.
local function seat(src, veh)
    for _, v in pairs(Fx.entities) do if v.driver == Fx.players[src].ped then v.driver = nil end end
    Fx.players[src].veh = veh
    if veh then Fx.entities[veh].driver = Fx.players[src].ped end
end

local function boot(opts)
    opts = opts or {}
    players, notes, invoices, saves, audited, failSave = {}, {}, {}, {}, {}, false
    accounts = { mechanic = 0 }
    economyOn = opts.noEconomy ~= true
    vehicles = { [55] = { id = 55, citizenid = opts.owner or 'CLI2', modelName = 'sultan', props = opts.props or { plate = 'PXD 042', modEngine = -1, color1 = 5 } } }
    local qbx = {
        GetPlayer = function(src) return players[tonumber(src)] end,
        GetPlayerByCitizenId = function(cid) for _, p in pairs(players) do if p.PlayerData.citizenid == cid then return p end end end,
        Notify = function(src, text, kind) notes[#notes + 1] = { src = src, text = text, kind = kind } end,
        GetVehiclesByName = function(name) return name == 'sultan' and { price = 50000 } or nil end,
    }
    local qv = {
        GetVehicleIdByPlate = function(plate) for id, v in pairs(vehicles) do if v.props.plate == plate then return id end end end,
        GetPlayerVehicle = function(id) local v = vehicles[id]; if not v then return nil end
            local props = {} for k, x in pairs(v.props) do props[k] = x end
            return { id = id, citizenid = v.citizenid, modelName = v.modelName, props = props } end,
        SaveVehicle = function(veh, options)
            if failSave then return false end
            vehicles[55].props = options.props; saves[#saves + 1] = options.props
            return true
        end,
    }
    local eco = {
        ChargeToAccount = function(src, method, amount, account)
            local p = players[src]
            if p.PlayerData.money[method] < amount then return false, 'fondos' end
            if accounts[account] == nil then return false, 'banco' end
            p.PlayerData.money[method] = p.PlayerData.money[method] - amount
            accounts[account] = accounts[account] + amount
            return true
        end,
        IssueInvoice = function(issuer, target, amount, concept)
            if opts.invoiceFails then return nil, 'Esa persona está demasiado lejos.' end
            invoices[#invoices + 1] = { issuer = issuer, target = target, amount = amount, concept = concept, status = 'pending' }
            return #invoices
        end,
        CancelInvoice = function(_, id) invoices[id].status = 'cancelled' return true end,
    }
    local rb = { removeAccountMoney = function(acc, n) accounts[acc] = accounts[acc] - n return true end }
    Fx.reset({ resourceName = 'pxd_garage',
        resourceStates = { qbx_core = 'started', qbx_vehicles = 'started', pxd_audit = 'started', ['Renewed-Banking'] = 'started',
            pxd_economy = economyOn and 'started' or 'missing' },
        exports = { qbx_core = qbx, qbx_vehicles = qv, pxd_economy = eco, ['Renewed-Banking'] = rb,
            pxd_audit = { Log = function(e) audited[#audited + 1] = e return 1 end } } })
    -- Natives de servidor que usa pxd_garage y no trae el simulador común.
    _G.GetVehiclePedIsIn = function(ped) for _, p in pairs(Fx.players) do if p.ped == ped then return p.veh or 0 end end return 0 end
    _G.GetPedInVehicleSeat = function(veh, s) local v = Fx.entities[veh] return (v and s == -1 and v.driver) or 0 end
    _G.GetVehicleNumberPlateText = function(veh) local v = Fx.entities[veh] return v and v.plate or '' end
    _G.GetVehicleEngineHealth = function() return 870.4 end
    _G.GetVehicleBodyHealth = function() return 990.0 end
    local states = {}
    _G.Entity = function(ent) states[ent] = states[ent] or { fuel = 63.6 } return { state = states[ent] } end

    Config, PXDGarage, PXDGarageStore, PXDGarageServer = nil, nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/garage.lua', 'server/store.lua' })
    -- Taller de jugadores de prueba junto al de autoservicio.
    Config.zones = {
        { id = 'auto', label = 'Autoservicio', z = 30.0, account = opts.account, points = { { 0, 0 }, { 10, 0 }, { 10, 10 }, { 0, 10 } } },
        { id = 'taller', label = 'Taller Central', z = 30.0, job = 'mechanic', account = 'mechanic', points = { { 100, 0 }, { 110, 0 }, { 110, 10 }, { 100, 10 } } },
    }
    MySQL = fakeMySQL(PXDGarageStore.Q)
    Fx.load(DIR, { 'server/main.lua' })

    Fx.addPlayer(1, 'mecanica', { x = 105, y = 5, z = 30 })
    Fx.addPlayer(2, 'clienta', { x = 5, y = 5, z = 30 })
    Fx.addPlayer(3, 'otro', { x = 5, y = 6, z = 30 })
    mkPlayer(1, 'MEC1', 'Marta Llave', { name = 'mechanic', onduty = true, grade = { level = 1 } }, 0, 0)
    mkPlayer(2, 'CLI2', 'Lía Ríos', nil, opts.cash or 500, opts.bank or 60000)
    mkPlayer(3, 'OTR3', 'Leo Lejos', nil, 0, 90000)
    Fx.entities[VEH] = { type = 'vehicle', x = 5, y = 5, z = 30, plate = 'PXD 042 ' }
    seat(2, VEH)
end

local function run(fn) local out = {} CreateThread(function() local r = table.pack(fn()) for i = 1, r.n do out[i] = r[i] end end) return out end
local function open(src, zone) return run(function() return PXDGarageServer.open(src, zone) end) end
local function apply(src, changes, method) return run(function() return PXDGarageServer.apply(src, changes, method) end) end
local function r10(n) return math.floor(n / 10 + 0.5) * 10 end   -- los importes van en múltiplos de 10
local function toTaller()   -- la mecánica conduce el coche de la clienta dentro del taller
    Fx.movePlayer(1, { x = 105, y = 5, z = 30 })
    seat(2, nil); seat(1, VEH)
end

T.describe('pxd_garage · lógica pura', function()
    T.it('valida cada tipo de valor del catálogo y rechaza claves desconocidas', function()
        dofile(RES .. 'pxd_garage/config.lua'); dofile(RES .. 'pxd_garage/shared/garage.lua')
        local G = PXDGarage
        T.truthy(G.sanitize({ modEngine = 3, modTurbo = true, color1 = { 10, 200, 255 }, neonEnabled = { true, true, false, false },
            windowTint = 2, modSpoilers = -1, extras = { ['1'] = 0, [3] = 1 } }, Config))
        T.eq(select(2, G.sanitize({ modEngine = 9 }, Config)), 'modEngine')
        T.eq(select(2, G.sanitize({ modEngine = 1.5 }, Config)), 'modEngine')
        T.eq(select(2, G.sanitize({ color1 = { 10, 300, 0 } }, Config)), 'color1')
        T.eq(select(2, G.sanitize({ modTurbo = 1 }, Config)), 'modTurbo')
        T.eq(select(2, G.sanitize({ plate = 'GRATIS' }, Config)), 'plate', 'la matrícula no es personalizable')
        T.eq(select(2, G.sanitize({ bodyHealth = 1000 }, Config)), 'bodyHealth', 'no se repara por aquí')
        T.eq(select(2, G.sanitize({ extras = { [20] = 0 } }, Config)), 'extras')
        T.eq(select(2, G.sanitize({ modFrontWheels = 9999 }, Config)), 'modFrontWheels')
    end)

    T.it('el precio sale de lo guardado: se cobra la diferencia de nivel y quitar piezas es gratis', function()
        local G = PXDGarage
        local base = G.base(50000, Config)
        local items = G.diff({ modEngine = 1, modSpoilers = 2 }, { modEngine = 3, modSpoilers = -1, modBrakes = 0 })
        local q = G.quote(items, base, Config, 1)
        local byKey = {}
        for _, l in ipairs(q.lines) do byKey[l.key] = l.price end
        T.eq(byKey.modEngine, (0.22 - 0.09) * 50000)
        T.eq(byKey.modBrakes, 0.02 * 50000)
        T.eq(byKey.modSpoilers, 0, 'volver a de serie no cuesta')
        T.eq(#G.diff({ modEngine = 3 }, { modEngine = 3 }), 0, 'lo que ya tiene no se cobra')
        T.eq(#G.diff({}, { modSpoilers = -1, modTurbo = false }), 0, 'de serie sobre un coche sin mods no es un cambio')
        T.eq(G.base(nil, Config), Config.pricing.fallbackBase)
        T.eq(G.base(5000000, Config), Config.pricing.maxBase)
        local full, cheap = G.quote(items, base, Config, 1), G.quote(items, base, Config, 0.85)
        T.truthy(cheap.total < full.total and cheap.total % 10 == 0, 'descuento de taller, en múltiplos de 10')
    end)

    T.it('rendimiento alto: no en autoservicio y según el nivel del mecánico', function()
        local G = PXDGarage
        local items = G.diff({ modEngine = -1 }, { modEngine = 3 })
        T.falsy(G.capCheck(items, 'self', 1, Config))
        T.falsy(G.capCheck(items, 'mechanic', 2, Config))
        T.truthy(G.capCheck(items, 'mechanic', 3, Config))
        T.truthy(G.capCheck(G.diff({ modEngine = 3 }, { modEngine = 0 }), 'self', 1, Config), 'bajar de nivel siempre se puede')
        T.falsy(G.capCheck(G.diff({}, { modTurbo = true }), 'self', 1, Config))
        T.truthy(G.capCheck(G.diff({}, { modTurbo = true }), 'mechanic', 3, Config))
    end)

    T.it('zonas: dentro, margen y altura', function()
        local G = PXDGarage
        local z = { z = 30.0, points = { { 0, 0 }, { 10, 0 }, { 10, 10 }, { 0, 10 } } }
        T.truthy(G.inZone(z, 5, 5, 30, 3, 6))
        T.truthy(G.inZone(z, 12, 5, 30, 3, 6), 'dentro del margen')
        T.falsy(G.inZone(z, 20, 5, 30, 3, 6))
        T.falsy(G.inZone(z, 5, 5, 60, 3, 6), 'otra planta')
    end)

    T.it('niveles de mecánico, experiencia por trabajo y tope diario', function()
        local G = PXDGarage
        T.eq((G.levelFor(0, Config)), 1); T.eq((G.levelFor(499, Config)), 2); T.eq((G.levelFor(500, Config)), 3)
        T.eq(select(3, G.levelFor(99999, Config)), nil, 'último nivel')
        T.eq(G.tuningXp(10000, Config), 15 + 10 * 2); T.eq(G.tuningXp(900000, Config), Config.mechanic.xp.tuningMax)
        T.eq(G.grantable(50, 580, Config), 20); T.eq(G.grantable(50, 600, Config), 0)
    end)
end)

T.describe('pxd_garage · taller (servidor)', function()
    T.it('crea sus tablas y abre sesión solo al dueño, al volante y dentro de la zona', function()
        boot()
        T.eq(db.created, 2)
        local d = open(2, 'auto')[1]
        T.eq(d.mode, 'self'); T.eq(d.base, 50000); T.eq(d.plate, 'PXD 042'); T.eq(d.props.color1, 5)
        T.eq(open(3, 'auto')[2], PXDGarage.MESSAGES.vehiculo, 'a pie')
        seat(2, nil); seat(3, VEH)
        T.eq(open(3, 'auto')[2], PXDGarage.MESSAGES.no_es_tuyo)
        seat(3, nil); seat(2, VEH)
        Fx.movePlayer(2, { x = 300, y = 300, z = 30 })
        T.eq(open(2, 'auto')[2], PXDGarage.MESSAGES.zona)
        T.eq(open(2, 'no-existe')[2], PXDGarage.MESSAGES.zona)
    end)

    T.it('vehículo sin registrar: no se personaliza', function()
        boot()
        Fx.entities[VEH].plate = 'ROBADO'
        T.eq(open(2, 'auto')[2], PXDGarage.MESSAGES.sin_dueno)
    end)

    T.it('autoservicio: cobra lo que calcula el servidor, guarda en qbx_vehicles y audita', function()
        boot()
        open(2, 'auto')
        local r = apply(2, { modEngine = 1, color1 = 27 }, 'bank')[1]
        local expected = 0.09 * 50000 + (450 + 0.007 * 50000)
        T.eq(r.total, expected)
        T.eq(players[2].PlayerData.money.bank, 60000 - expected)
        T.eq(vehicles[55].props.modEngine, 1); T.eq(vehicles[55].props.color1, 27)
        T.eq(vehicles[55].props.plate, 'PXD 042', 'la matrícula no cambia')
        T.eq(vehicles[55].props.engineHealth, 870); T.eq(vehicles[55].props.fuelLevel, 64, 'salud y gasolina reales, no las del cliente')
        T.eq(audited[1].category, 'taller'); T.eq(audited[1].data.total, expected)
        T.eq(db.stats.CLI2, nil, 'el autoservicio no da experiencia')
    end)

    T.it('eventos manipulados: sin sesión, propiedades prohibidas o fuera de zona no aplican nada gratis', function()
        boot()
        T.eq(apply(2, { modEngine = 1 }, 'bank')[2], PXDGarage.MESSAGES.sesion, 'sin abrir el taller')
        open(2, 'auto')
        T.eq(apply(2, { plate = 'ADMIN', modEngine = 1 }, 'bank')[2], PXDGarage.MESSAGES.cambios)
        T.eq(apply(2, { modEngine = 1, price = 0 }, 'bank')[2], PXDGarage.MESSAGES.cambios)
        T.eq(apply(2, { modEngine = 4 }, 'bank')[2]:find('solo lo monta un mecánico', 1, true) ~= nil, true)
        T.eq(apply(2, { modEngine = 1 }, 'crypto')[2], PXDGarage.MESSAGES.metodo)
        Fx.movePlayer(2, { x = 300, y = 300, z = 30 })
        T.eq(apply(2, { modEngine = 1 }, 'bank')[2], PXDGarage.MESSAGES.zona)
        T.eq(#saves, 0); T.eq(players[2].PlayerData.money.bank, 60000)
        -- Por la red, con datos basura
        Fx.movePlayer(2, { x = 5, y = 5, z = 30 })
        Fx.emit('pxd_garage:server:apply', 2, 'DROP TABLE', 'bank')
        T.eq(Fx.lastTo(2, 'pxd_garage:client:applied').args[1].ok, false)
        T.eq(#saves, 0)
    end)

    T.it('otro coche o cambio de vehículo tras abrir: la sesión deja de valer', function()
        boot()
        open(2, 'auto')
        Fx.entities[7002] = { type = 'vehicle', x = 5, y = 5, z = 30, plate = 'OTRO 001' }
        seat(2, 7002)
        T.eq(apply(2, { modEngine = 1 }, 'bank')[2], PXDGarage.MESSAGES.sesion)
    end)

    T.it('sin fondos no se guarda nada ni queda saldo negativo', function()
        boot({ bank = 100, cash = 0 })
        open(2, 'auto')
        T.eq(apply(2, { modEngine = 1 }, 'bank')[2], PXDGarage.MESSAGES.fondos)
        T.eq(#saves, 0); T.eq(players[2].PlayerData.money.bank, 100)
    end)

    T.it('si falla el guardado, devuelve el dinero (sumidero y cuenta de taller)', function()
        boot()
        open(2, 'auto')
        failSave = true
        T.eq(apply(2, { modEngine = 1 }, 'bank')[2], PXDGarage.MESSAGES.guardar)
        T.eq(players[2].PlayerData.money.bank, 60000)
        boot({ account = 'mechanic' })
        open(2, 'auto')
        failSave = true
        T.eq(apply(2, { modEngine = 1 }, 'cash')[2], PXDGarage.MESSAGES.fondos, 'efectivo insuficiente')
        T.eq(apply(2, { modEngine = 1 }, 'bank')[2], PXDGarage.MESSAGES.guardar)
        T.eq(players[2].PlayerData.money.bank, 60000); T.eq(accounts.mechanic, 0, 'también se retira de la cuenta')
    end)

    T.it('autoservicio con cuenta: el cobro entra en la cuenta del taller', function()
        boot({ account = 'mechanic' })
        open(2, 'auto')
        local r = apply(2, { modBrakes = 0 }, 'bank')[1]
        T.eq(r.pay, 'account'); T.eq(accounts.mechanic, 0.02 * 50000)
    end)

    T.it('taller de jugadores: solo mecánicos de servicio; factura al dueño con descuento y experiencia', function()
        boot()
        toTaller()
        players[1].PlayerData.job.onduty = false
        T.eq(open(1, 'taller')[2], PXDGarage.MESSAGES.trabajo)
        players[1].PlayerData.job.onduty = true
        T.eq(open(1, 'taller')[1].mode, 'mechanic')
        T.eq(apply(1, { modEngine = 3 }, nil)[2]:find('nivel 3 de mecánico', 1, true) ~= nil, true, 'nivel insuficiente')
        local r = apply(1, { modEngine = 1 }, nil)[1]
        local total = r10(0.09 * 50000 * 0.85)
        T.eq(r.total, total); T.eq(r.pay, 'invoice')
        T.eq(invoices[1].target, 2); T.eq(invoices[1].amount, total)
        T.eq(players[1].PlayerData.money.bank, 0, 'la mecánica no paga')
        T.eq(vehicles[55].props.modEngine, 1)
        T.eq(db.stats.MEC1.xp, PXDGarage.tuningXp(total, Config))
        T.eq(db.log[1].kind, 'tuning')
    end)

    T.it('taller de jugadores: si la factura no se puede emitir, no se aplica; si falla el guardado, se cancela', function()
        boot({ invoiceFails = true })
        toTaller(); open(1, 'taller')
        T.falsy(apply(1, { modEngine = 1 }, nil)[1]); T.eq(#saves, 0)
        boot()
        toTaller(); open(1, 'taller')
        failSave = true
        T.eq(apply(1, { modEngine = 1 }, nil)[2], PXDGarage.MESSAGES.guardar)
        T.eq(invoices[1].status, 'cancelled')
    end)

    T.it('con nivel suficiente la mecánica monta el motor alto y el turbo', function()
        boot()
        db.stats.MEC1 = { xp = 600, jobs = 3, day = 0, day_xp = 0 }   -- nivel 3
        toTaller(); open(1, 'taller')
        local r = apply(1, { modEngine = 2, modTurbo = true }, nil)[1]
        T.truthy(r); T.eq(vehicles[55].props.modTurbo, true)
    end)
end)

T.describe('pxd_garage · mecánicos', function()
    T.it('reparar una pieza dañada en el banco da experiencia una vez; conducir o repetir no', function()
        boot()
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 042', 'radiator', 40)
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 042', 'radiator', 100)
        T.eq(db.stats.MEC1.xp, Config.mechanic.xp.repairPart)
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 042', 'radiator', 30)
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 042', 'radiator', 100)
        T.eq(db.stats.MEC1.xp, Config.mechanic.xp.repairPart, 'misma pieza dentro del enfriamiento')
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 042', 'engine', 1000)
        T.eq(db.stats.MEC1.xp, Config.mechanic.xp.repairPart, 'sin daño previo no cuenta')
        Fx.emit('vehiclemod:server:updatePart', 2, 'ABC 123', 'axle', 10)
        Fx.emit('vehiclemod:server:updatePart', 2, 'ABC 123', 'axle', 100)
        T.falsy(db.stats.CLI2, 'quien no es mecánico de servicio no gana experiencia')
        Fx.emit('vehiclemod:server:updatePart', 1, { 'x' }, 'axle', 100)
        Fx.emit('vehiclemod:server:updatePart', 1, 'ABC 123', 'nitro', 100)
    end)

    T.it('tope diario, subida de nivel con aviso y export GetMechanicLevel', function()
        boot()
        local p = players[1]
        T.eq(run(function() return PXDGarageServer.addXp(p, 140, 'tuning', 'X', 0) end)[1], 140)
        T.eq(run(function() return PXDGarageServer.addXp(p, 20, 'tuning', 'X', 0) end)[1], 20)
        T.eq(db.stats.MEC1.xp, 160)
        local found = false
        for _, n in ipairs(notes) do if n.src == 1 and n.text:find('nivel 2 de mecánico', 1, true) then found = true end end
        T.truthy(found, 'aviso al subir de nivel')
        db.stats.MEC1.day_xp = Config.mechanic.xp.dailyCap
        db.stats.MEC1.day = PXDGarage.dayKey(os.time())
        T.eq(run(function() return PXDGarageServer.addXp(p, 50, 'tuning', 'X', 0) end)[1], 0, 'tope diario')
        local level, xp, name = Fx.exports.pxd_garage.GetMechanicLevel(1)
        T.eq(level, 2); T.eq(xp, 160); T.eq(name, 'Ayudante')
        T.eq((Fx.exports.pxd_garage.GetMechanicLevel('NADIE')), 1)
    end)

    T.it('pxd_garage_xp: solo consola o staff con permiso', function()
        boot()
        run(function() Fx.commands.pxd_garage_xp(2, { 'MEC1', '5000' }) end)
        T.falsy(db.stats.MEC1)
        run(function() Fx.commands.pxd_garage_xp(0, { 'MEC1', '5000' }) end)
        T.eq(db.stats.MEC1.xp, 5000)
        run(function() Fx.commands.pxd_garage_xp(0, { "x'; DROP", '1' }) end)
        T.eq(db.stats["x'; DROP"], nil)
    end)
end)
