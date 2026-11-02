-- Pruebas de pxd_jobs: lógica pura (shared/jobs.lua) y servidor con el simulador.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_jobs/'

local function loadPure()
    PXDJobs, Config = nil, nil
    dofile(DIR .. 'config.lua')
    dofile(DIR .. 'shared/jobs.lua')
end

local function fixed(v) return function() return v end end

T.describe('pxd_jobs (lógica)', function()
    loadPure()

    T.it('la configuración incluida es válida', function()
        for name, job in pairs(Config.jobs) do
            local errs = PXDJobs.validateJob(name, job)
            T.eq(#errs, 0, table.concat(errs, '; '))
        end
    end)

    T.it('detecta configuraciones rotas', function()
        local errs = PXDJobs.validateJob('Mal Nombre', { label = '', kind = 'otro' })
        T.truthy(#errs >= 3)
        local job = Config.jobs.miner
        local broken = { label = 'x', kind = 'gather', signOn = job.signOn, grades = job.grades, maxCarry = 5,
            work = { points = { { x = 1 } }, seconds = 0, radius = 1, cooldown = 0, yield = { 2, 1 }, scenario = 'X' },
            sell = { point = job.sell.point, price = 0 } }
        local text = table.concat(PXDJobs.validateJob('roto', broken), '\n')
        T.truthy(text:find('work.points%[1%]'))
        T.truthy(text:find('work.seconds'))
        T.truthy(text:find('work.yield'))
        T.truthy(text:find('sell.price'))
    end)

    T.it('genera los trabajos en formato Qbox', function()
        local q = PXDJobs.qbxJobs(Config.jobs)
        T.eq(q.miner.label, 'Minero')
        T.eq(q.courier.grades[0].payment, 0)
        T.eq(q.fisher.defaultDuty, true)
    end)

    T.it('recolección: lejos, demasiado rápido, bien, agotado y lleno', function()
        local job, st = Config.jobs.miner, PXDJobs.newState()
        local pt = job.work.points[1]
        local far = { x = pt.x + 50, y = pt.y, z = pt.z }
        T.falsy(PXDJobs.startWork(st, 'miner', job, 1, far, 0))
        T.falsy(PXDJobs.startWork(st, 'miner', job, 99, pt, 0), 'punto inexistente')
        T.truthy(PXDJobs.startWork(st, 'miner', job, 1, pt, 0))
        T.falsy(PXDJobs.startWork(st, 'miner', job, 2, job.work.points[2], 0), 'no dos a la vez')
        local ok, err = PXDJobs.finishWork(st, 'miner', job, pt, 2, fixed(2))
        T.falsy(ok); T.truthy(err:find('rápido'))
        T.truthy(PXDJobs.startWork(st, 'miner', job, 1, pt, 3))
        local ok2, units = PXDJobs.finishWork(st, 'miner', job, pt, 3 + job.work.seconds, fixed(2))
        T.truthy(ok2); T.eq(units, 2); T.eq(st.carry, 2)
        local ok3, msg = PXDJobs.startWork(st, 'miner', job, 1, pt, 20)
        T.falsy(ok3); T.truthy(msg:find('agotado'))
        T.truthy(PXDJobs.startWork(st, 'miner', job, 1, pt, 3 + job.work.seconds + job.work.cooldown + 1))
        PXDJobs.cancel(st)
        st.carry = job.maxCarry
        local ok4, full = PXDJobs.startWork(st, 'miner', job, 2, job.work.points[2], 500)
        T.falsy(ok4); T.truthy(full:find('lleno'))
    end)

    T.it('al terminar no supera la carga máxima', function()
        local job, st = Config.jobs.miner, PXDJobs.newState()
        st.carry = job.maxCarry - 1
        local pt = job.work.points[1]
        PXDJobs.startWork(st, 'miner', job, 1, pt, 0)
        local _, units = PXDJobs.finishWork(st, 'miner', job, pt, 100, fixed(2))
        T.eq(units, 1); T.eq(st.carry, job.maxCarry)
    end)

    T.it('venta: paga por unidad y respeta el tope por hora', function()
        local job, st = Config.jobs.miner, PXDJobs.newState()
        st.carry = 10
        T.falsy(PXDJobs.sell(st, job, { x = 0, y = 0, z = 0 }, 0, 1000), 'lejos del punto de venta')
        local ok, pay, sold = PXDJobs.sell(st, job, job.sell.point, 0, 1000)
        T.truthy(ok); T.eq(sold, 10); T.eq(pay, 10 * job.sell.price); T.eq(st.carry, 0)
        st.carry = 100
        local _, pay2 = PXDJobs.sell(st, job, job.sell.point, 10, 1000)
        T.eq(pay2, 1000 - 10 * job.sell.price, 'solo hasta el tope')
        st.carry = 5
        local ok3, msg = PXDJobs.sell(st, job, job.sell.point, 20, 1000)
        T.falsy(ok3); T.truthy(msg:find('tope'))
        T.eq(st.carry, 5, 'si no se paga, no se pierde la carga')
        local ok4 = PXDJobs.sell(st, job, job.sell.point, 3700, 1000)
        T.truthy(ok4, 'pasada una hora vuelve a cobrar')
    end)

    T.it('repartidor: recoge, no repite destino y rechaza teletransportes', function()
        local job, st = Config.jobs.courier, PXDJobs.newState()
        T.falsy(PXDJobs.pickup(st, job, { x = 0, y = 0, z = 0 }, 0, fixed(1)))
        local ok, idx = PXDJobs.pickup(st, job, job.depot.point, 0, fixed(3))
        T.truthy(ok); T.eq(idx, 3)
        T.falsy(PXDJobs.pickup(st, job, job.depot.point, 1, fixed(1)), 'ya lleva uno')
        local drop = job.deliver.drops[3]
        T.falsy(PXDJobs.deliver(st, job, job.deliver.drops[1], 999, nil), 'destino equivocado')
        local okFast, msg = PXDJobs.deliver(st, job, drop, 1, nil)
        T.falsy(okFast); T.truthy(msg:find('rápido'))
        PXDJobs.pickup(st, job, job.depot.point, 100, fixed(3))
        T.eq(st.delivery.idx, 4, 'no repite el último destino')
        local meters = PXDJobs.dist(job.depot.point, job.deliver.drops[4])
        local okPay, pay = PXDJobs.deliver(st, job, job.deliver.drops[4], 100 + meters / job.deliver.maxSpeed + 30, nil)
        T.truthy(okPay)
        T.eq(pay, math.floor(job.deliver.base + job.deliver.perKm * meters / 1000))
    end)

    T.it('aplica puntos añadidos en el juego', function()
        local jobs = json and nil
        loadPure()
        jobs = Config.jobs
        local before = #jobs.miner.work.points
        local n = PXDJobs.applyExtra(jobs, {
            miner = { work = { { x = 1, y = 2, z = 3 } }, sell = { { x = 4, y = 5, z = 6 } }, raro = { { x = 0, y = 0, z = 0 } } },
            courier = { drop = { { x = 7, y = 8, z = 9 }, { x = 'mal' } } },
            nadie = { work = { { x = 1, y = 1, z = 1 } } },
        })
        T.eq(n, 3)
        T.eq(#jobs.miner.work.points, before + 1)
        T.eq(jobs.miner.sell.point.x, 4)
    end)
end)

-- ── Servidor ────────────────────────────────────────────────────────────────

local qbxCalls
local realRandom = math.random
local function boot(withQbx)
    qbxCalls = { money = {}, jobs = {}, notes = {}, created = nil, tracked = 0 }
    local players = {}
    local exportsTbl = {
        qbx_core = {
            CreateJobs = function(tbl, commit) qbxCalls.created = tbl; qbxCalls.commit = commit; return true end,
            GetPlayer = function(src) return players[src] end,
            SetJob = function(src, name) players[src] = { PlayerData = { job = { name = name } } }; qbxCalls.jobs[#qbxCalls.jobs + 1] = name; return true end,
            AddMoney = function(src, kind, amount) qbxCalls.money[#qbxCalls.money + 1] = { src = src, kind = kind, amount = amount }; return true end,
            Notify = function(src, text) qbxCalls.notes[#qbxCalls.notes + 1] = text end,
        },
        pxd_progress = { Track = function(_, key) if key == 'job_task' then qbxCalls.tracked = qbxCalls.tracked + 1 end end },
    }
    Fx.reset({
        resourceName = 'pxd_jobs',
        resourceStates = withQbx and { qbx_core = 'started', pxd_progress = 'started' } or {},
        exports = exportsTbl,
    })
    PXDJobs, Config = nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/jobs.lua', 'server/main.lua' })
    math.random = function(a) return a end
end

local function lastNote() return qbxCalls.notes[#qbxCalls.notes] or '' end

T.describe('pxd_jobs (servidor)', function()
    T.it('registra los trabajos en Qbox sin escribir en sus archivos', function()
        boot(true)
        T.truthy(qbxCalls.created and qbxCalls.created.miner)
        T.eq(qbxCalls.commit, false)
    end)

    T.it('minero completo: alta, picar, vender, cobrar y avisar a pxd_progress', function()
        boot(true)
        local job = Config.jobs.miner
        local pt = job.work.points[1]
        Fx.addPlayer(1, 'Ana', job.signOn)
        Fx.emit('pxd_jobs:start', 1, 'miner', 1)
        T.truthy(lastNote():find('alta'), 'sin el trabajo no puede')
        Fx.emit('pxd_jobs:signOn', 1, 'miner')
        T.eq(qbxCalls.jobs[1], 'miner')
        Fx.movePlayer(1, pt)
        Fx.emit('pxd_jobs:start', 1, 'miner', 1)
        T.eq(Fx.lastTo(1, 'pxd_jobs:started').args[2], job.work.seconds)
        Fx.emit('pxd_jobs:finish', 1, 'miner')
        T.truthy(lastNote():find('rápido'), 'el servidor mide el tiempo')
        Fx.emit('pxd_jobs:start', 1, 'miner', 2)
        Fx.movePlayer(1, job.work.points[2])
        Fx.emit('pxd_jobs:start', 1, 'miner', 2)
        Fx.advance(job.work.seconds)
        Fx.emit('pxd_jobs:finish', 1, 'miner')
        T.eq(qbxCalls.tracked, 1)
        Fx.movePlayer(1, job.sell.point)
        Fx.emit('pxd_jobs:sell', 1, 'miner')
        T.eq(#qbxCalls.money, 1)
        T.eq(qbxCalls.money[1].kind, 'cash')
        T.eq(qbxCalls.money[1].amount, job.work.yield[1] * job.sell.price)
    end)

    T.it('el tope por hora va por cuenta: reconectar no lo reinicia', function()
        boot(true)
        local job = Config.jobs.miner
        local amount = job.work.yield[1] * job.sell.price
        Config.maxEarningsPerHour = amount   -- una venta llena el tope
        local function mineAndSell(src)
            Fx.emit('pxd_jobs:signOn', src, 'miner')
            Fx.movePlayer(src, job.work.points[1])
            Fx.emit('pxd_jobs:start', src, 'miner', 1)
            Fx.advance(job.work.seconds)
            Fx.emit('pxd_jobs:finish', src, 'miner')
            Fx.movePlayer(src, job.sell.point)
            Fx.emit('pxd_jobs:sell', src, 'miner')
        end
        Fx.addPlayer(8, 'Fede', job.signOn, nil, { license = 'license:fede' })
        mineAndSell(8)
        T.eq(#qbxCalls.money, 1, 'primera venta pagada')
        Fx.emit('playerDropped', 8)
        Fx.addPlayer(9, 'Fede', job.signOn, nil, { license = 'license:fede' })
        Fx.advance(job.work.cooldown or 0)
        mineAndSell(9)
        T.eq(#qbxCalls.money, 1, 'tras reconectar sigue en el tope')
        T.truthy(lastNote():find('tope'))
        Fx.addPlayer(10, 'Otra', job.signOn, nil, { license = 'license:otra' })
        Fx.advance(job.work.cooldown or 0)
        mineAndSell(10)
        T.eq(#qbxCalls.money, 2, 'otra cuenta tiene su propio tope')
    end)

    T.it('ignora datos raros del cliente', function()
        boot(true)
        Fx.addPlayer(2, 'Beto', Config.jobs.miner.signOn)
        Fx.emit('pxd_jobs:signOn', 2, 'admin')
        Fx.emit('pxd_jobs:signOn', 2, { 'miner' })
        Fx.emit('pxd_jobs:start', 2, 'miner', 'uno')
        Fx.emit('pxd_jobs:sell', 2, 'courier')
        T.eq(#qbxCalls.jobs, 0)
        T.eq(#qbxCalls.money, 0)
    end)

    T.it('alta solo cerca del punto', function()
        boot(true)
        Fx.addPlayer(3, 'Caro', { x = 0, y = 0, z = 0 })
        Fx.emit('pxd_jobs:signOn', 3, 'fisher')
        T.eq(#qbxCalls.jobs, 0)
        T.truthy(lastNote():find('Acércate'))
    end)

    T.it('repartidor: ruta al cliente y pago al entregar', function()
        boot(true)
        local job = Config.jobs.courier
        Fx.addPlayer(4, 'Dani', job.signOn)
        Fx.emit('pxd_jobs:signOn', 4, 'courier')
        Fx.movePlayer(4, job.depot.point)
        Fx.emit('pxd_jobs:pickup', 4, 'courier')
        local r = Fx.lastTo(4, 'pxd_jobs:route')
        T.eq(r.args[1], 'courier')
        local drop = r.args[2]
        Fx.advance(600)
        Fx.movePlayer(4, drop)
        Fx.emit('pxd_jobs:deliver', 4, 'courier')
        T.eq(#qbxCalls.money, 1)
        T.truthy(qbxCalls.money[1].amount >= job.deliver.base)
        T.eq(qbxCalls.tracked, 1)
    end)

    T.it('sin Qbox funciona con alta local y sin pagar dinero real', function()
        boot(false)
        local job = Config.jobs.fisher
        Fx.addPlayer(5, 'Eva', job.signOn)
        Fx.emit('pxd_jobs:signOn', 5, 'fisher')
        Fx.movePlayer(5, job.work.points[1])
        Fx.emit('pxd_jobs:start', 5, 'fisher', 1)
        T.truthy(Fx.lastTo(5, 'pxd_jobs:started'))
    end)

    T.it('staff añade puntos y se guardan', function()
        boot(true)
        Fx.addPlayer(6, 'Staff', { x = 10.123, y = 20.456, z = 30.789 }, { ['pxd.jobs.edit'] = true })
        Fx.addPlayer(7, 'Nadie', { x = 0, y = 0, z = 0 })
        local before = #Config.jobs.miner.work.points
        Fx.commands['pxd_jobpunto'](7, { 'miner', 'work' })
        T.eq(#Config.jobs.miner.work.points, before)
        Fx.commands['pxd_jobpunto'](6, { 'miner', 'nada' })
        T.eq(#Config.jobs.miner.work.points, before)
        Fx.commands['pxd_jobpunto'](6, { 'miner', 'work' })
        T.eq(#Config.jobs.miner.work.points, before + 1)
        local saved = Fx.json.decode(Fx.files['data/points.json'])
        T.eq(saved.miner.work[1].x, 10.12)
        T.truthy(Fx.lastTo(-1, 'pxd_jobs:points'))
    end)
end)
math.random = realRandom
