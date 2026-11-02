-- Pruebas de pxd_panel: lógica pura (shared/panel.lua) y servidor con Qbox/pxd_progress simulados.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_panel/'

local function loadShared()
    Config, PXDPanel, PXDRules = nil, nil, nil
    dofile(DIR .. 'config.lua')
    dofile(DIR .. 'shared/rules.lua')
    dofile(DIR .. 'shared/panel.lua')
end

T.describe('pxd_panel (lógica)', function()
    loadShared()

    T.it('formatea duraciones', function()
        T.eq(PXDPanel.formatDuration(0), '0 min')
        T.eq(PXDPanel.formatDuration(45 * 60), '45 min')
        T.eq(PXDPanel.formatDuration(3 * 3600 + 12 * 60), '3 h 12 min')
        T.eq(PXDPanel.formatDuration(29 * 86400 + 8 * 3600 + 59), '29 d 8 h')
        T.eq(PXDPanel.formatDuration(-5), '0 min')
    end)

    T.it('lee fechas UTC sin depender de la zona del servidor', function()
        T.eq(PXDPanel.parseUtc('1970-01-01T00:00:00Z'), 0)
        T.eq(PXDPanel.parseUtc('2000-03-01T00:00:00Z'), 951868800)
        T.eq(PXDPanel.parseUtc('2026-11-14T02:00:00Z'), 1794621600)
        T.falsy(PXDPanel.parseUtc('2026-11-14 02:00'))
        T.falsy(PXDPanel.parseUtc('2026-13-01T00:00:00Z'))
    end)

    T.it('cuenta atrás', function()
        local c = PXDPanel.countdown(100000, 100000 - (2 * 86400 + 3 * 3600 + 5 * 60))
        T.eq(c.d, 2); T.eq(c.h, 3); T.eq(c.m, 5)
        T.falsy(PXDPanel.countdown(10, 10))
    end)

    T.it('eventos: ordena fechados primero, oculta pasados e ignora fechas mal escritas', function()
        local now = PXDPanel.parseUtc('2026-11-10T00:00:00Z')
        local list = PXDPanel.events({
            { id = 'perm', title = 'Permanente' },
            { id = 'b', title = 'B', startsAt = '2026-11-20T00:00:00Z' },
            { id = 'a', title = 'A', startsAt = '2026-11-12T00:00:00Z' },
            { id = 'old', title = 'Viejo', startsAt = '2026-11-01T00:00:00Z' },
            { id = 'live', title = 'En curso', startsAt = '2026-11-09T23:00:00Z' },
            { id = 'bad', title = 'Mal', startsAt = 'mañana' },
        }, now)
        local ids = {}
        for _, e in ipairs(list) do ids[#ids + 1] = e.id end
        T.eq(table.concat(ids, ','), 'live,a,b,perm')
        T.truthy(list[1].live)
        T.falsy(list[2].live)
    end)

    T.it('organizaciones: gobierno por tipo, oculta desempleo y marca pertenencia', function()
        local jobs = {
            unemployed = { label = 'Civilian', grades = { [0] = { name = 'Freelancer' } } },
            police = { label = 'LSPD', type = 'leo', grades = { [0] = { name = 'Recruit' }, [1] = { name = 'Officer' } } },
            ambulance = { label = 'EMS', type = 'ems', grades = { [0] = { name = 'Recruit' } } },
            mechanic = { label = 'Mechanic', type = 'mechanic', grades = { [0] = { name = 'Recruit' } } },
            taxi = { label = 'Taxi', grades = { [0] = { name = 'Driver' } } },
        }
        local gangs = { none = { label = 'No Gang' }, ballas = { label = 'Ballas', grades = { [2] = { name = 'Boss' } } } }
        local o = PXDPanel.organizations(jobs, gangs, { police = 1, taxi = 0 }, { ballas = 2 },
            { police = 4, ambulance = 1 }, { name = 'police', onduty = true }, Config)
        T.eq(#o.government, 2)
        T.eq(o.government[1].name, 'police', 'primero a los que perteneces')
        T.eq(o.government[1].grade, 'Officer')
        T.truthy(o.government[1].onduty)
        T.eq(o.government[1].dutyCount, 4)
        T.eq(o.government[2].dutyCount, 1)
        T.eq(#o.companies, 2, 'unemployed oculto')
        T.eq(o.companies[1].name, 'taxi')
        T.eq(o.companies[1].grade, 'Driver')
        T.eq(#o.groups, 1, 'none oculto')
        T.eq(o.groups[1].grade, 'Boss')
    end)

    T.it('busca reglas sin tildes y con varias palabras', function()
        local r = PXDPanel.searchRules(PXDRules.list, 'SECUESTRO')
        T.eq(#r, 1); T.eq(r[1].id, 'robos')
        T.eq(#PXDPanel.searchRules(PXDRules.list, 'metagaming streams'), 1)
        T.eq(#PXDPanel.searchRules(PXDRules.list, 'vehiculo'), #PXDPanel.searchRules(PXDRules.list, 'vehículo'))
        T.eq(#PXDPanel.searchRules(PXDRules.list, ''), #PXDRules.list)
        T.eq(#PXDPanel.searchRules(PXDRules.list, 'zzzz'), 0)
    end)

    T.it('el reglamento cubre todos los temas pedidos', function()
        local ids = {}
        for _, r in ipairs(PXDRules.list) do
            T.truthy(type(r.title) == 'string' and #r.title > 0, 'título')
            T.truthy(type(r.body) == 'string' and #r.body > 0, 'texto de ' .. r.id)
            ids[r.id] = true
        end
        for _, id in ipairs({ 'basicos', 'pg', 'mg', 'dm', 'vdm', 'nlr', 'ck', 'vida', 'combatlog', 'seguras', 'robos', 'bugs', 'respeto', 'staff', 'sanciones' }) do
            T.truthy(ids[id], 'falta la regla ' .. id)
        end
    end)

    T.it('limpia ajustes que llegan de la NUI', function()
        local s = PXDPanel.sanitizeSettings({ textScale = 9, sounds = 'sí', reduceMotion = true, evil = 1 })
        T.eq(s.textScale, 3); T.eq(s.sounds, true); T.eq(s.reduceMotion, true); T.falsy(s.evil)
        T.eq(PXDPanel.sanitizeSettings({ textScale = 5 }).textScale, 5)
        T.eq(PXDPanel.sanitizeSettings('basura').textScale, 3)
    end)

    T.it('perfil: solo datos esperados, sin trabajo de desempleado', function()
        local p = PXDPanel.profile({
            citizenid = 'ABC123', charinfo = { firstname = 'Valeria', lastname = 'Ríos' },
            job = { name = 'unemployed', label = 'Civilian' }, gang = { name = 'none' },
            money = { cash = 10.7, bank = 200, crypto = 5 }, metadata = { secret = true },
        }, { level = 3, xp = 900, xpLevel = 40, xpNext = 200, playtime = 3600, playtimeToday = 60, plus = true })
        T.eq(p.name, 'Valeria Ríos'); T.eq(p.cash, 10); T.eq(p.bank, 200)
        T.falsy(p.job); T.falsy(p.gang); T.falsy(p.metadata); T.falsy(p.crypto)
        T.eq(p.level, 3); T.truthy(p.plus)
        T.falsy(PXDPanel.profile(nil))
    end)
end)

-- ── Servidor ────────────────────────────────────────────────────────────────

local logouts, claims
local function boot(withProgress)
    logouts, claims = {}, {}
    local player = { PlayerData = {
        citizenid = 'PXD1', charinfo = { firstname = 'Nova', lastname = 'Estrella' },
        job = { name = 'police', label = 'LSPD', onduty = true, grade = { name = 'Officer', level = 1 } },
        gang = { name = 'none' }, money = { cash = 50, bank = 500 },
        jobs = { police = 1 }, gangs = {},
    } }
    local exports = {
        qbx_core = {
            GetPlayer = function(src) return src == 1 and player or nil end,
            GetJobs = function() return { police = { label = 'LSPD', type = 'leo', grades = { [1] = { name = 'Officer' } } } } end,
            GetGangs = function() return {} end,
            GetDutyCountJob = function(name) return name == 'police' and 2 or 0, {} end,
            Logout = function(src) logouts[#logouts + 1] = src end,
        },
    }
    local states = { qbx_core = 'started' }
    if withProgress then
        states.pxd_progress = 'started'
        exports.pxd_progress = {
            GetProfile = function() return { level = 5, xp = 1000, xpLevel = 10, xpNext = 100, playtime = 7200, playtimeToday = 600, plus = false } end,
            GetDaily = function() return { day = 1, canClaim = true, days = {} } end,
            GetAchievements = function() return {} end,
            ClaimDaily = function(src) claims[#claims + 1] = 'daily:' .. src; return true, 'Recibiste $1,000' end,
            ClaimAchievement = function(src, id) claims[#claims + 1] = id; return false, 'Aún no' end,
        }
    end
    Fx.reset({ resourceName = 'pxd_panel', exports = exports, resourceStates = states, convars = { sv_maxclients = 48 } })
    _G.GetNumPlayerIndices = function() return 2 end
    Config, PXDPanel, PXDRules = nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/rules.lua', 'shared/panel.lua', 'server/main.lua' })
    Fx.addPlayer(1, 'Nova')
    Fx.addPlayer(2, 'SinPersonaje')
end

T.describe('pxd_panel (servidor)', function()
    T.it('abre con datos armados en el servidor (y estáticos solo si se piden)', function()
        boot(true)
        Fx.emit('pxd_panel:server:open', 1, true)
        local d = Fx.lastTo(1, 'pxd_panel:client:data').args[1]
        T.eq(d.profile.name, 'Nova Estrella')
        T.eq(d.profile.level, 5)
        T.eq(d.online, 2); T.eq(d.maxPlayers, 48)
        T.truthy(d.progress); T.truthy(d.framework)
        T.eq(d.orgs.government[1].dutyCount, 2)
        T.truthy(d.static and #d.static.rules > 10)
        T.falsy(d.static.storeUrl, 'sin URL configurada no hay tienda')
        Fx.advance(2)
        Fx.emit('pxd_panel:server:open', 1, false)
        T.falsy(Fx.lastTo(1, 'pxd_panel:client:data').args[1].static)
    end)

    T.it('sin pxd_progress oculta recompensas y logros', function()
        boot(false)
        Fx.emit('pxd_panel:server:open', 1, false)
        local d = Fx.lastTo(1, 'pxd_panel:client:data').args[1]
        T.falsy(d.progress); T.falsy(d.daily); T.falsy(d.profile.level)
        Fx.advance(2)
        Fx.emit('pxd_panel:server:claimDaily', 1)
        T.falsy(Fx.lastTo(1, 'pxd_panel:client:result').args[1].ok)
    end)

    T.it('anti-spam: ignora peticiones demasiado seguidas', function()
        boot(true)
        Fx.emit('pxd_panel:server:open', 1, false)
        Fx.emit('pxd_panel:server:open', 1, false)
        T.eq(#Fx.sentTo(1, 'pxd_panel:client:data'), 1)
    end)

    T.it('reclamar: lo decide pxd_progress y se devuelve el resultado', function()
        boot(true)
        Fx.emit('pxd_panel:server:claimDaily', 1)
        T.eq(claims[1], 'daily:1')
        local r = Fx.lastTo(1, 'pxd_panel:client:result').args[1]
        T.truthy(r.ok); T.eq(r.message, 'Recibiste $1,000')
        Fx.advance(2)
        Fx.emit('pxd_panel:server:claimAchievement', 1, 'first_job')
        T.eq(claims[2], 'first_job')
        T.falsy(Fx.lastTo(1, 'pxd_panel:client:result').args[1].ok)
    end)

    T.it('rechaza ids de logro raros', function()
        boot(true)
        Fx.emit('pxd_panel:server:claimAchievement', 1, string.rep('x', 200))
        Fx.advance(2)
        Fx.emit('pxd_panel:server:claimAchievement', 1, { 'tabla' })
        Fx.advance(2)
        Fx.emit('pxd_panel:server:claimAchievement', 1, 'a b')
        T.eq(#claims, 0)
    end)

    T.it('cambiar personaje: usa Logout de qbx_core, con límite y solo con personaje cargado', function()
        boot(true)
        Fx.emit('pxd_panel:server:logout', 1)
        Fx.emit('pxd_panel:server:logout', 1)
        T.eq(#logouts, 1, 'una vez cada 10 s')
        Fx.emit('pxd_panel:server:logout', 2)
        T.eq(#logouts, 1, 'sin personaje no hace nada')
    end)

    T.it('sin Qbox el panel sigue funcionando con lo básico', function()
        boot(false)
        Fx.resourceStates.qbx_core = nil
        Fx.emit('pxd_panel:server:open', 2, false)
        local d = Fx.lastTo(2, 'pxd_panel:client:data').args[1]
        T.eq(d.profile.name, 'SinPersonaje')
        T.falsy(d.orgs); T.falsy(d.framework)
    end)
end)
