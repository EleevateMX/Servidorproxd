-- Pruebas de la lógica pura de pxd_progress (niveles, días, pista diaria, logros).
local T = _G.T
local DIR = RES .. 'pxd_progress/'

local function fresh()
    Config = nil; PXDProgress = nil
    dofile(DIR .. 'config.lua')
    dofile(DIR .. 'shared/progress.lua')
    -- Temporada y evento fijos para que las pruebas no dependan de la fecha real.
    Config.daily.season = { id = 'test', name = 'Prueba', startsAt = '2026-11-01T06:00:00Z', endsAt = '2026-12-01T06:00:00Z' }
    Config.daily.missions = { { label = 'Juega 60 min', any = { { key = 'playtime_min', goal = 60 } } } }
    return PXDProgress, Config
end

local function at(s) return PXDProgress.parseUtc(s) end

T.describe('pxd_progress (lógica)', function()
    T.it('fechas UTC y día natural con desfase', function()
        local P = fresh()
        T.eq(P.parseUtc('1970-01-02'), 86400)
        T.eq(P.parseUtc('2026-11-01T06:00:00Z'), 1793512800)
        T.eq(P.dayKey(at('2026-11-02T05:59:00Z'), -6), '2026-11-01', 'antes de las 6:00 UTC sigue siendo el día anterior en CDMX')
        T.eq(P.dayKey(at('2026-11-02T06:00:00Z'), -6), '2026-11-02')
        T.eq(P.dayKey(at('2024-02-29T12:00:00Z'), 0), '2024-02-29')
        T.falsy(P.parseUtc('ayer'))
    end)

    T.it('niveles: curva base + step', function()
        local P, C = fresh()
        T.eq((P.levelFromXp(0, C.levels)), 1)
        local l, inLevel, need = P.levelFromXp(99, C.levels)
        T.eq(l, 1); T.eq(inLevel, 99); T.eq(need, 100)
        l, inLevel, need = P.levelFromXp(100 + 125 + 10, C.levels)
        T.eq(l, 3); T.eq(inLevel, 10); T.eq(need, 150)
        T.eq(P.summaryFromMetadata({ pxd_progress = { xp = 100, playtime = 7200 } }, C).level, 2)
        T.eq(P.summaryFromMetadata({ xp = 0, playtime = 60 }, C).playtime, 60)
        T.eq(P.summaryFromMetadata(nil, C).level, 1)
    end)

    T.it('track: valida claves, limita cantidades y da XP', function()
        local P, C = fresh()
        local d = P.normalize(nil)
        local t = at('2026-11-05T18:00:00Z')
        T.eq(P.track(d, 'hackear', 5, t, C), nil)
        T.eq(P.track(d, 'gm_win', -3, t, C), nil)
        T.eq(P.track(d, 'gm_win', 1, t, C), 25)
        P.track(d, 'job_task', 99999, t, C)
        T.eq(d.counters.job_task, C.maxTrackAmount)
        T.eq(d.today.counters.gm_win, 1)
    end)

    T.it('horas de hoy se reinician al cambiar el día natural', function()
        local P, C = fresh()
        local d = P.normalize(nil)
        P.addPlaytime(d, 600, at('2026-11-05T18:00:00Z'), C)
        P.addPlaytime(d, 600, at('2026-11-06T05:00:00Z'), C) -- aún día 5 en CDMX
        T.eq(d.today.seconds, 1200)
        P.addPlaytime(d, 60, at('2026-11-06T07:00:00Z'), C)
        T.eq(d.today.seconds, 60); T.eq(d.playtime, 1260)
    end)

    T.it('pista diaria: misión, un día por día natural y entrega', function()
        local P, C = fresh()
        local d = P.normalize(nil)
        local t = at('2026-11-05T18:00:00Z')
        local v = P.dailyView(d, t, C, false)
        T.eq(v.day, 1); T.falsy(v.canClaim); T.eq(v.days[1].state, 'locked')
        local def, why = P.checkClaim(d, t, C)
        T.falsy(def); T.truthy(why:find('misión'))
        P.track(d, 'playtime_min', 60, t, C)
        v = P.dailyView(d, t, C, true)
        T.truthy(v.canClaim); T.eq(v.days[1].state, 'available'); T.truthy(v.plus)
        def = P.checkClaim(d, t, C)
        T.eq(def, C.daily.days[1])
        P.markClaimed(d, t, C)
        def, why = P.checkClaim(d, t + 3600, C)
        T.falsy(def); T.truthy(why:find('mañana'))
        v = P.dailyView(d, t + 3600, C, false)
        T.eq(v.days[1].state, 'claimed'); T.eq(v.day, 1); T.truthy(v.claimedToday)
        -- Día siguiente: la misión empieza de cero.
        local t2 = at('2026-11-06T18:00:00Z')
        T.falsy(P.checkClaim(d, t2, C))
        P.track(d, 'playtime_min', 60, t2, C)
        T.eq(P.checkClaim(d, t2, C), C.daily.days[2])
    end)

    T.it('pista diaria: retrocede un día por cada día sin reclamar', function()
        local P, C = fresh()
        local d = P.normalize(nil)
        for i = 0, 2 do
            local t = at(('2026-11-%02dT18:00:00Z'):format(5 + i))
            P.track(d, 'playtime_min', 60, t, C)
            T.truthy(P.checkClaim(d, t, C)); P.markClaimed(d, t, C)
        end
        T.eq(d.daily.claimed, 3)
        local v = P.dailyView(d, at('2026-11-10T18:00:00Z'), C, false) -- 8 y 9 sin reclamar
        T.eq(v.claimed, 1); T.eq(v.lost, 2)
        v = P.dailyView(d, at('2026-11-10T20:00:00Z'), C, false)
        T.eq(v.claimed, 1, 'no se vuelve a penalizar el mismo día')
        C.missedDayPenalty = false
        C.daily.missedDayPenalty = false
        v = P.dailyView(d, at('2026-11-15T18:00:00Z'), C, false)
        T.eq(v.claimed, 1, 'sin penalización no retrocede')
    end)

    T.it('pista diaria: fuera de temporada no se reclama y otra temporada empieza de cero', function()
        local P, C = fresh()
        local d = P.normalize(nil)
        local v = P.dailyView(d, at('2026-12-02T18:00:00Z'), C, false)
        T.falsy(v.season.active); T.eq(v.days[1].state, 'missed')
        T.falsy(P.checkClaim(d, at('2026-12-02T18:00:00Z'), C))
        d.daily = { season = 'vieja', claimed = 9, total = 9 }
        v = P.dailyView(d, at('2026-11-05T18:00:00Z'), C, false)
        T.eq(v.claimed, 0); T.eq(d.daily.total, 9, 'el total histórico se conserva')
    end)

    T.it('describe recompensas', function()
        local P = fresh()
        T.eq(P.describeReward({ type = 'money', account = 'bank', amount = 1500 }).label, '$1,500 en el banco')
        T.eq(P.describeReward({ type = 'item', name = 'water', count = 3 }).icon, 'item:water')
        T.eq(P.describeReward({ type = 'xp', amount = 50 }).label, '50 XP')
    end)

    T.it('logros: progreso, derivados y reclamo único', function()
        local P, C = fresh()
        local d = P.normalize(nil)
        local t = at('2026-11-05T18:00:00Z')
        d.playtime = 3600
        local cats = P.achievementsView(d, t, C)
        T.eq(cats[1].id, 'bienvenida')
        T.truthy(cats[1].items[1].done, '1 hora jugada')
        T.falsy(cats[1].items[2].done, 'nivel 2 aún no')
        local it = P.checkAchievement(d, 'b_hora', t, C)
        T.eq(it.id, 'b_hora')
        d.achievements.b_hora = true
        local ok, why = P.checkAchievement(d, 'b_hora', t, C)
        T.falsy(ok); T.truthy(why:find('Ya'))
        T.falsy(P.checkAchievement(d, 'no_existe', t, C))
        T.falsy(P.checkAchievement(d, 'g_ganar1', t, C))
    end)

    T.it('logros limitados: solo cuentan y se ven dentro de sus fechas', function()
        local P, C = fresh()
        local _, ev = P.findAchievement('l_evento', C)
        ev.disabled = nil   -- se activa aquí para probar las fechas
        local d = P.normalize(nil)
        local before = at('2026-10-20T18:00:00Z')
        P.track(d, 'event_join', 1, before, C)
        local function find(cats, id) for _, c in ipairs(cats) do if c.id == id then return c end end end
        T.falsy(find(P.achievementsView(d, before, C), 'lanzamiento'))
        local during = at('2026-11-05T18:00:00Z')
        local cat = find(P.achievementsView(d, during, C), 'lanzamiento')
        T.truthy(cat and cat.limited)
        T.falsy(cat.items[1].done, 'lo de antes del evento no cuenta')
        P.track(d, 'event_join', 1, during, C)
        T.truthy(P.checkAchievement(d, 'l_evento', during, C))
        local after = at('2026-12-05T18:00:00Z')
        T.truthy(find(P.achievementsView(d, after, C), 'lanzamiento'), 'sigue visible si participaste')
        local ok, why = P.checkAchievement(d, 'l_evento', after, C)
        T.falsy(ok); T.truthy(why:find('ya no'))
    end)

    T.it('logro desactivado: no se ve ni se reclama; «Temporada completa» = días de la pista', function()
        local P, C = fresh()
        local d = P.normalize(nil)
        local during = at('2026-11-05T18:00:00Z')
        P.track(d, 'event_join', 1, during, C)
        local ok, why = P.checkAchievement(d, 'l_evento', during, C)
        T.falsy(ok); T.truthy(why:find('no existe'))
        local seen = false
        for _, c in ipairs(P.achievementsView(d, during, C)) do
            for _, it in ipairs(c.items) do if it.id == 'l_evento' then seen = true end end
            if c.id == 'constancia' then
                for _, it in ipairs(c.items) do if it.id == 'c_28' then T.eq(it.goal, #C.daily.days) end end
            end
        end
        T.falsy(seen, 'no aparece en la vista')
        d.daily.total = #C.daily.days
        T.truthy(P.checkAchievement(d, 'c_28', during, C), 'se completa con los días de la temporada')
    end)

    T.it('Plus: extiende desde el vencimiento o desde ahora', function()
        local P = fresh()
        local plus, t = {}, 1000000
        P.extendPlus(plus, 'license:a', 30, t)
        T.eq(plus['license:a'], t + 30 * 86400)
        P.extendPlus(plus, 'license:a', 1, t)
        T.eq(plus['license:a'], t + 31 * 86400)
        T.truthy((P.plusActive(plus, 'license:a', t)))
        T.falsy((P.plusActive(plus, 'license:a', t + 40 * 86400)))
        T.falsy((P.plusActive(plus, nil, t)))
    end)
end)
