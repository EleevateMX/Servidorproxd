-- Pruebas de pxd_progress con FXServer simulado y Qbox / ox_inventory falsos.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_progress/'

local function copy(v) return v == nil and nil or Fx.json.decode(Fx.json.encode(v)) end

local q -- estado de los falsos
local function boot(opts)
    opts = opts or {}
    q = { meta = {}, money = {}, items = {}, canCarry = true, players = {} }
    local states = { pxd_progress = 'started' }
    local exports = {}
    if opts.qbox ~= false then
        states.qbx_core, states.ox_inventory = 'started', 'started'
        exports.qbx_core = {
            GetPlayer = function(src) return q.players[src] end,
            -- Como en FXServer, lo que cruza un export se copia.
            GetMetadata = function(src, key) return copy((q.meta[src] or {})[key]) end,
            SetMetadata = function(src, key, val) q.meta[src] = q.meta[src] or {}; q.meta[src][key] = copy(val) end,
            AddMoney = function(src, acc, amount, reason) q.money[#q.money + 1] = { src, acc, amount, reason } return true end,
        }
        exports.ox_inventory = {
            CanCarryItem = function() return q.canCarry end,
            AddItem = function(src, name, count) q.items[#q.items + 1] = { src, name, count } return true end,
        }
    end
    Fx.reset({ resourceName = 'pxd_progress', resourceStates = states, exports = exports })
    Config = nil; PXDProgress = nil; PXDProgressServer = nil
    Fx.load(DIR, { 'config.lua', 'shared/progress.lua', 'server/main.lua' })
    Config.daily.season = { id = 'test', name = 'Prueba', startsAt = '2026-11-01T06:00:00Z', endsAt = '2026-12-01T06:00:00Z' }
    Config.daily.missions = { { label = 'Juega 60 min', any = { { key = 'playtime_min', goal = 60 } } } }
    q.t = PXDProgress.parseUtc('2026-11-05T18:00:00Z')
    PXDProgressServer.setClock(function() return q.t end)
    return PXDProgressServer
end

local function join(src, job)
    Fx.addPlayer(src, 'P' .. src, { x = 0, y = 0, z = 0 })
    q.players[src] = { PlayerData = { source = src, job = job or { name = 'unemployed', onduty = false } } }
end

local function minutes(n) for _ = 1, n do q.t = q.t + 60; Fx.advance(60) end end

T.describe('pxd_progress (servidor)', function()
    T.it('sin personaje cargado no hay perfil ni progreso', function()
        local S = boot()
        Fx.addPlayer(1, 'Sin personaje', { x = 0, y = 0, z = 0 })
        T.eq(S.GetProfile(1), nil)
        T.falsy(S.Track(1, 'gm_win', 1))
        minutes(1)
        T.eq(q.meta[1], nil)
    end)

    T.it('cada minuto suma horas y XP; el servicio cuenta aparte', function()
        local S = boot()
        join(1); join(2, { name = 'police', onduty = true })
        minutes(3)
        local p1, p2 = S.GetProfile(1), S.GetProfile(2)
        T.eq(p1.playtime, 180); T.eq(p1.playtimeToday, 180); T.eq(p1.xp, 3)
        T.eq(q.meta[1].pxd_progress.counters.duty_min, nil)
        T.eq(q.meta[2].pxd_progress.counters.duty_min, 3)
        T.eq(p2.xp, 6)
    end)

    T.it('subir de nivel avisa al jugador y emite el evento', function()
        local S = boot()
        join(1)
        local leveled
        AddEventHandler('pxd_progress:levelUp', function(src, level) leveled = { src, level } end)
        T.eq(S.AddXP(1, 120, 'prueba'), 2)
        T.eq(leveled[1], 1); T.eq(leveled[2], 2)
        local n = Fx.lastTo(1, 'pxd_progress:notify')
        T.truthy(n and n.args[1].title:find('nivel'))
        T.eq(S.GetProfile(1).level, 2)
    end)

    T.it('reclamar: exige misión, entrega Gratis (+ Plus si lo tiene) y solo una vez al día', function()
        local S = boot()
        join(1)
        local ok, msg = S.ClaimDaily(1)
        T.falsy(ok); T.truthy(msg:find('misión'))
        minutes(60)
        ok = S.ClaimDaily(1)
        T.truthy(ok)
        T.eq(#q.money, 1); T.eq(q.money[1][2], 'cash'); T.eq(q.money[1][3], 500)
        ok, msg = S.ClaimDaily(1)
        T.falsy(ok); T.truthy(msg:find('mañana'))
        T.eq(S.GetDaily(1).days[1].state, 'claimed')
        -- Al día siguiente, con Plus: día 2 = agua (gratis) + sprunk (Plus).
        Fx.commands['pxd_plus'](0, { '1', '30' })
        q.t = q.t + 86400
        minutes(60)
        T.truthy(S.GetDaily(1).plus)
        T.truthy((S.ClaimDaily(1)))
        T.eq(#q.items, 2); T.eq(q.items[1][2], 'water'); T.eq(q.items[2][2], 'sprunk')
    end)

    T.it('sin espacio en el inventario no entrega nada ni marca el día', function()
        local S = boot()
        join(1)
        local d = PXDProgress.normalize(nil)
        d.daily = { season = 'test', claimed = 1, anchor = PXDProgress.dayIndex(q.t, -6) - 1 }
        q.meta[1] = { pxd_progress = d }
        minutes(60)
        q.canCarry = false
        local ok, msg = S.ClaimDaily(1)
        T.falsy(ok); T.truthy(msg:find('espacio'))
        T.eq(#q.items, 0)
        T.eq(S.GetDaily(1).claimed, 1)
    end)

    T.it('logros: reclama una vez y da XP', function()
        local S = boot()
        join(1)
        minutes(60)
        local cats = S.GetAchievements(1)
        T.truthy(cats[1].items[1].done)
        local xp = S.GetProfile(1).xp
        T.truthy((S.ClaimAchievement(1, 'b_hora')))
        T.eq(S.GetProfile(1).xp, xp + 50)
        T.falsy((S.ClaimAchievement(1, 'b_hora')))
        T.falsy((S.ClaimAchievement(1, {})))
    end)

    T.it('pxd_plus solo desde la consola y con licencias válidas', function()
        boot()
        join(1)
        Fx.commands['pxd_plus'](1, { '1', '30' })
        T.eq(Fx.files['data/plus.json'], nil, 'un jugador no puede darse Plus')
        Fx.commands['pxd_plus'](0, { 'license:abc123', '7' })
        local plus = Fx.json.decode(Fx.files['data/plus.json'])
        T.eq(plus['license:abc123'], q.t + 7 * 86400)
        Fx.commands['pxd_plus'](0, { 'cualquier cosa', '7' })
        Fx.commands['pxd_plus'](0, { '1', '-5' })
        plus = Fx.json.decode(Fx.files['data/plus.json'])
        local n = 0 for _ in pairs(plus) do n = n + 1 end
        T.eq(n, 1)
    end)

    T.it('sin Qbox guarda en JSON por licencia y no entrega dinero', function()
        local S = boot({ qbox = false })
        Fx.addPlayer(1, 'Solo', { x = 0, y = 0, z = 0 })
        minutes(60)
        T.eq(S.GetProfile(1).playtime, 3600)
        local saved = Fx.json.decode(Fx.files['data/progress.json'])
        T.eq(saved['license:1'].playtime, 3600)
        local ok, msg = S.ClaimDaily(1)
        T.falsy(ok); T.truthy(msg:find('Qbox'))
    end)

    T.it('SummaryFromMetadata para la lista de personajes', function()
        local S = boot()
        local s = S.SummaryFromMetadata({ pxd_progress = { xp = 250, playtime = 90000 } })
        T.eq(s.level, 3); T.eq(s.playtime, 90000)
        T.eq(Fx.exports.pxd_progress.SummaryFromMetadata({}).level, 1)
    end)
end)
