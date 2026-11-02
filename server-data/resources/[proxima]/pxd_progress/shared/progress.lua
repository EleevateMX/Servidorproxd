-- Lógica pura del progreso (sin natives). Todo recibe `now` (epoch UTC en segundos)
-- y la configuración, para poder probarlo con Lua 5.4.
PXDProgress = {}
local P = PXDProgress

local DAY = 86400

-- ── Fechas ──────────────────────────────────────────────────────────────

--- Días desde 1970-01-01 para una fecha civil (algoritmo de Howard Hinnant).
local function daysFromCivil(y, m, d)
    y = (m <= 2) and (y - 1) or y
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = (153 * mp + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end

--- 'AAAA-MM-DD' o 'AAAA-MM-DDTHH:MM:SSZ' (UTC) → epoch. nil si no es válida.
function P.parseUtc(s)
    if type(s) ~= 'string' then return nil end
    local y, m, d = s:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)')
    if not y then return nil end
    local hh, mm, ss = s:match('T(%d%d):(%d%d):?(%d?%d?)')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    return daysFromCivil(y, m, d) * DAY + (tonumber(hh) or 0) * 3600 + (tonumber(mm) or 0) * 60 + (tonumber(ss) or 0)
end

--- Índice del día natural en la zona del servidor.
function P.dayIndex(now, offsetHours)
    return (now + math.floor((offsetHours or 0) * 3600)) // DAY
end

--- 'AAAA-MM-DD' del día natural.
function P.dayKey(now, offsetHours)
    local z = P.dayIndex(now, offsetHours)
    -- civil desde días (Hinnant)
    z = z + 719468
    local era = (z >= 0 and z or z - 146096) // 146097
    local doe = z - era * 146097
    local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    local mp = (5 * doy + 2) // 153
    local d = doy - (153 * mp + 2) // 5 + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return string.format('%04d-%02d-%02d', y, m, d)
end

-- ── Datos ───────────────────────────────────────────────────────────────

--- Devuelve una tabla de progreso válida (repara lo que falte o venga mal).
function P.normalize(data)
    if type(data) ~= 'table' then data = {} end
    data.v = 1
    data.xp = math.max(0, math.floor(tonumber(data.xp) or 0))
    data.playtime = math.max(0, math.floor(tonumber(data.playtime) or 0))
    if type(data.today) ~= 'table' then data.today = {} end
    data.today.day = type(data.today.day) == 'string' and data.today.day or ''
    data.today.seconds = math.max(0, math.floor(tonumber(data.today.seconds) or 0))
    if type(data.today.counters) ~= 'table' then data.today.counters = {} end
    if type(data.counters) ~= 'table' then data.counters = {} end
    if type(data.windows) ~= 'table' then data.windows = {} end
    if type(data.daily) ~= 'table' then data.daily = {} end
    if type(data.achievements) ~= 'table' then data.achievements = {} end
    return data
end

--- Si cambió el día natural, reinicia lo «de hoy».
local function rollToday(data, now, cfg)
    local key = P.dayKey(now, cfg.utcOffsetHours)
    if data.today.day ~= key then
        data.today.day = key
        data.today.seconds = 0
        data.today.counters = {}
    end
end

-- ── Niveles ─────────────────────────────────────────────────────────────

--- XP necesaria para pasar de `level` a `level + 1`.
function P.xpToNext(level, levels)
    return levels.base + levels.step * (level - 1)
end

--- Nivel a partir de la XP total → nivel, XP dentro del nivel, XP para el siguiente.
function P.levelFromXp(xp, levels)
    local level, rest = 1, math.max(0, xp or 0)
    while level < levels.max do
        local need = P.xpToNext(level, levels)
        if rest < need then return level, rest, need end
        rest = rest - need
        level = level + 1
    end
    return level, 0, 0
end

--- Suma XP. Devuelve nivel anterior y nuevo.
function P.addXp(data, amount, cfg)
    local before = P.levelFromXp(data.xp, cfg.levels)
    amount = math.floor(tonumber(amount) or 0)
    if amount > 0 then data.xp = data.xp + amount end
    local after = P.levelFromXp(data.xp, cfg.levels)
    return before, after
end

-- ── Contadores ──────────────────────────────────────────────────────────

local function activeWindow(cat, now)
    if not cat.limited then return false end
    local s, e = P.parseUtc(cat.startsAt), P.parseUtc(cat.endsAt)
    return s ~= nil and e ~= nil and now >= s and now < e
end
P.activeWindow = activeWindow

--- Registra una acción: contadores de siempre, de hoy y de categorías limitadas activas.
--- Devuelve la XP ganada (o nil si la clave no es válida).
function P.track(data, key, amount, now, cfg)
    if not cfg.trackKeys[key] then return nil end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return nil end
    amount = math.min(amount, cfg.maxTrackAmount or 100)
    rollToday(data, now, cfg)
    data.counters[key] = (data.counters[key] or 0) + amount
    data.today.counters[key] = (data.today.counters[key] or 0) + amount
    for _, cat in ipairs(cfg.achievements or {}) do
        if activeWindow(cat, now) then
            local w = data.windows[cat.id] or {}
            w[key] = (w[key] or 0) + amount
            data.windows[cat.id] = w
        end
    end
    local xp = (cfg.xp[key] or 0) * amount
    if xp > 0 then P.addXp(data, xp, cfg) end
    return xp
end

--- Suma segundos jugados (total y de hoy).
function P.addPlaytime(data, seconds, now, cfg)
    rollToday(data, now, cfg)
    seconds = math.max(0, math.floor(seconds or 0))
    data.playtime = data.playtime + seconds
    data.today.seconds = data.today.seconds + seconds
end

-- ── Recompensas diarias ─────────────────────────────────────────────────

local function season(cfg, now)
    local s = cfg.daily.season
    local startsAt, endsAt = P.parseUtc(s.startsAt), P.parseUtc(s.endsAt)
    return {
        id = s.id, name = s.name, startsAt = startsAt, endsAt = endsAt,
        active = startsAt ~= nil and endsAt ~= nil and now >= startsAt and now < endsAt,
    }
end

--- Misión del día (rota por el día natural).
function P.missionFor(dayIdx, cfg)
    local list = cfg.daily.missions
    if #list == 0 then return nil end
    return list[(dayIdx % #list) + 1]
end

--- Progreso de la misión del día con los contadores de hoy.
function P.missionProgress(mission, data, now, cfg)
    if not mission then return { label = 'Sin misión', progress = 0, goal = 0, done = true } end
    rollToday(data, now, cfg)
    local best, bestRatio = nil, -1
    for _, opt in ipairs(mission.any or {}) do
        local have = data.today.counters[opt.key] or 0
        local ratio = opt.goal > 0 and have / opt.goal or 1
        if ratio > bestRatio then best, bestRatio = { progress = math.min(have, opt.goal), goal = opt.goal }, ratio end
    end
    best = best or { progress = 0, goal = 0 }
    return { label = mission.label, progress = best.progress, goal = best.goal, done = bestRatio >= 1 }
end

--- Pone al día la pista: nueva temporada y penalización por días sin reclamar.
function P.settleDaily(data, now, cfg)
    local s = season(cfg, now)
    local d = data.daily
    if d.season ~= s.id then
        data.daily = { season = s.id, claimed = 0, total = d.total or 0 }
        d = data.daily
    end
    d.claimed = math.max(0, math.floor(tonumber(d.claimed) or 0))
    local today = P.dayIndex(now, cfg.utcOffsetHours)
    if d.anchor == nil then
        d.anchor = today - 1
    elseif today - d.anchor > 1 then
        local missed = today - d.anchor - 1
        if cfg.daily.missedDayPenalty and s.active then
            d.lost = math.min(missed, d.claimed)
            d.claimed = d.claimed - d.lost
        end
        d.anchor = today - 1
    end
    return s, today
end

--- Etiqueta e icono legibles de una recompensa.
function P.describeReward(r)
    if not r then return nil end
    local label, icon = r.label, r.icon
    if r.type == 'money' then
        label = label or ('$%s %s'):format(P.groupDigits(r.amount), r.account == 'bank' and 'en el banco' or 'en efectivo')
        icon = icon or (r.account == 'bank' and 'bank' or 'cash')
    elseif r.type == 'item' then
        label = label or ('%d× %s'):format(r.count or 1, r.name)
        icon = icon or ('item:' .. tostring(r.name))
    elseif r.type == 'xp' then
        label = label or ('%d XP'):format(r.amount)
        icon = icon or 'xp'
    end
    return { label = label, icon = icon }
end

function P.groupDigits(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (out:gsub('^,', ''))
end

--- Estado de la pista para la interfaz.
function P.dailyView(data, now, cfg, plus)
    local s, today = P.settleDaily(data, now, cfg)
    local d = data.daily
    local claimedToday = d.lastClaimDay == today
    local mission = P.missionProgress(P.missionFor(today, cfg), data, now, cfg)
    local total = #cfg.daily.days
    local canClaim = s.active and not claimedToday and mission.done and d.claimed < total
    local days = {}
    for n, def in ipairs(cfg.daily.days) do
        local state
        if n <= d.claimed then state = 'claimed'
        elseif n == d.claimed + 1 and canClaim then state = 'available'
        else state = 'locked' end
        if not s.active and n > d.claimed then state = 'missed' end
        days[n] = { n = n, free = P.describeReward(def.free), plus = P.describeReward(def.plus), state = state }
    end
    return {
        season = { id = s.id, name = s.name, endsAt = s.endsAt, active = s.active },
        day = math.min(d.claimed + (claimedToday and 0 or 1), total),
        claimed = d.claimed,
        claimedToday = claimedToday,
        lost = d.lost or 0,
        days = days,
        mission = mission,
        canClaim = canClaim,
        plus = plus and true or false,
    }
end

--- Comprueba si se puede reclamar hoy. Devuelve la definición del día o nil + motivo.
function P.checkClaim(data, now, cfg)
    local view = P.dailyView(data, now, cfg, false)
    if not view.season.active then return nil, 'La temporada no está activa.' end
    if view.claimedToday then return nil, 'Ya reclamaste la recompensa de hoy. Vuelve mañana.' end
    if view.claimed >= #cfg.daily.days then return nil, 'Ya completaste la pista de esta temporada.' end
    if not view.mission.done then return nil, 'Primero completa la misión del día: ' .. view.mission.label .. '.' end
    return cfg.daily.days[view.claimed + 1], nil, view.claimed + 1
end

--- Marca el día como reclamado (llamar solo tras entregar las recompensas).
function P.markClaimed(data, now, cfg)
    local today = P.dayIndex(now, cfg.utcOffsetHours)
    local d = data.daily
    d.claimed = d.claimed + 1
    d.lastClaimDay = today
    d.anchor = today
    d.lost = 0
    d.total = (d.total or 0) + 1
end

-- ── Logros ──────────────────────────────────────────────────────────────

local function valueFor(data, cat, key, now, cfg)
    if key == 'level' then return (P.levelFromXp(data.xp, cfg.levels)) end
    if key == 'playtime_h' then return data.playtime // 3600 end
    if key == 'days_claimed' then return data.daily.total or 0 end
    if cat.limited then return (data.windows[cat.id] or {})[key] or 0 end
    return data.counters[key] or 0
end

--- Meta real de un logro: `goal = 'season'` = número de días de la pista configurada
--- (así «Temporada completa» siempre coincide con la temporada).
function P.goalOf(it, cfg)
    if it.goal == 'season' then return #((cfg.daily or {}).days or {}) end
    return tonumber(it.goal) or 0
end

--- Categorías visibles con su progreso. Las limitadas solo mientras están activas
--- (o si ya tienes algo hecho en ellas).
function P.achievementsView(data, now, cfg)
    local out = {}
    for _, cat in ipairs(cfg.achievements or {}) do
        local active = activeWindow(cat, now)
        local visible = not cat.limited or active or data.windows[cat.id] ~= nil
        if visible then
            local items, done = {}, 0
            for _, it in ipairs(cat.items) do
              if not it.disabled then   -- desactivado: no se ve ni se puede reclamar
                local goal = P.goalOf(it, cfg)
                local have = valueFor(data, cat, it.key, now, cfg)
                local isDone = have >= goal
                if isDone then done = done + 1 end
                items[#items + 1] = {
                    id = it.id, label = it.label, description = it.description,
                    progress = math.min(have, goal), goal = goal, done = isDone,
                    claimed = data.achievements[it.id] == true, rewardXp = it.rewardXp or 0,
                }
              end
            end
            out[#out + 1] = {
                id = cat.id, label = cat.label, icon = cat.icon, description = cat.description, image = cat.image,
                limited = cat.limited == true, active = not cat.limited or active,
                endsAt = cat.limited and P.parseUtc(cat.endsAt) or nil,
                items = items, done = done, total = #items,
            }
        end
    end
    return out
end

--- Busca un logro por id → categoría, logro.
function P.findAchievement(id, cfg)
    for _, cat in ipairs(cfg.achievements or {}) do
        for _, it in ipairs(cat.items) do
            if it.id == id then return cat, it end
        end
    end
end

--- Comprueba si un logro se puede reclamar → logro o nil + motivo.
function P.checkAchievement(data, id, now, cfg)
    local cat, it = P.findAchievement(id, cfg)
    if not it or it.disabled then return nil, 'Ese logro no existe.' end
    if data.achievements[id] then return nil, 'Ya reclamaste este logro.' end
    if cat.limited and not activeWindow(cat, now) then return nil, 'Este logro ya no está disponible.' end
    if valueFor(data, cat, it.key, now, cfg) < P.goalOf(it, cfg) then return nil, 'Aún no completas este logro.' end
    return it
end

-- ── Resúmenes ───────────────────────────────────────────────────────────

--- Perfil para la interfaz.
function P.profile(data, now, cfg, plus)
    rollToday(data, now, cfg)
    local level, xpLevel, xpNext = P.levelFromXp(data.xp, cfg.levels)
    return {
        level = level, xp = data.xp, xpLevel = xpLevel, xpNext = xpNext,
        playtime = data.playtime, playtimeToday = data.today.seconds, plus = plus and true or false,
    }
end

--- Resumen desde la metadata de un personaje (acepta la metadata entera o solo el progreso).
function P.summaryFromMetadata(meta, cfg)
    local data = type(meta) == 'table' and (meta[cfg.metadataKey] or meta) or {}
    local xp = math.max(0, math.floor(tonumber(data.xp) or 0))
    local level = P.levelFromXp(xp, cfg.levels)
    return { level = level, playtime = math.max(0, math.floor(tonumber(data.playtime) or 0)) }
end

--- Plus activo para una licencia.
function P.plusActive(plusTable, license, now)
    local exp = license and plusTable[license]
    return exp ~= nil and exp > now, exp
end

--- Extiende Plus `days` días desde ahora o desde el vencimiento actual (lo que sea mayor).
function P.extendPlus(plusTable, license, days, now)
    local cur = plusTable[license] or 0
    local base = cur > now and cur or now
    plusTable[license] = base + math.floor(days * DAY)
    return plusTable[license]
end

return P
