-- Lógica pura del panel (sin natives): organizaciones, tiempos, fechas UTC, reglas y ajustes.
PXDPanel = {}

-- ── Tiempos ────────────────────────────────────────────────────────────────

--- «29 d 8 h», «3 h 12 min», «45 min», «0 min».
function PXDPanel.formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local d = seconds // 86400
    local h = (seconds % 86400) // 3600
    local m = (seconds % 3600) // 60
    if d > 0 then return ('%d d %d h'):format(d, h) end
    if h > 0 then return ('%d h %d min'):format(h, m) end
    return ('%d min'):format(m)
end

--- Días desde 1970-01-01 de una fecha civil (algoritmo de Howard Hinnant). Sin zonas horarias.
local function daysFromCivil(y, m, d)
    y = (m <= 2) and (y - 1) or y
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = (153 * mp + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end

--- «2026-11-14T02:00:00Z» → segundos epoch (UTC). nil si el formato no es válido.
function PXDPanel.parseUtc(s)
    if type(s) ~= 'string' then return nil end
    local y, mo, d, h, mi, se = s:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$')
    if not y then return nil end
    y, mo, d, h, mi, se = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(se)
    if mo < 1 or mo > 12 or d < 1 or d > 31 or h > 23 or mi > 59 or se > 59 then return nil end
    return daysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60 + se
end

--- Cuenta atrás hasta `target` (epoch). nil si ya pasó.
function PXDPanel.countdown(target, now)
    if not target or target <= now then return nil end
    local s = target - now
    return { d = s // 86400, h = (s % 86400) // 3600, m = (s % 3600) // 60 }
end

-- ── Eventos ────────────────────────────────────────────────────────────────

--- Eventos visibles: los que no tienen fecha y los que empiezan después de now - graceSec.
--- Ordenados: primero los fechados (por fecha), después los permanentes.
function PXDPanel.events(list, now, graceSec)
    graceSec = graceSec or 3 * 3600
    local out = {}
    for _, e in ipairs(list or {}) do
        if type(e) == 'table' and type(e.title) == 'string' then
            local at = e.startsAt and PXDPanel.parseUtc(e.startsAt)
            if e.startsAt and not at then
                -- fecha mal escrita: se ignora el evento para no mostrar datos falsos
            elseif not at or at >= now - graceSec then
                out[#out + 1] = {
                    id = tostring(e.id or #out + 1), title = e.title, description = e.description or '',
                    place = e.place, howTo = e.howTo, image = e.image, steps = e.steps,
                    startsAt = at, live = at ~= nil and at <= now,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.startsAt and b.startsAt then return a.startsAt < b.startsAt end
        if a.startsAt ~= b.startsAt then return a.startsAt ~= nil end
        return a.id < b.id
    end)
    return out
end

-- ── Organizaciones ─────────────────────────────────────────────────────────

local function gradeName(group, level)
    local g = group and group.grades and group.grades[level]
    return g and g.name or tostring(level)
end

--- Agrupa trabajos y bandas de Qbox.
--- jobs/gangs: tablas de GetJobs()/GetGangs(). playerJobs/playerGangs: { nombre = rango } (PlayerData.jobs/gangs).
--- duty: { trabajo = nº de servicio }. primaryJob: { name, onduty }.
function PXDPanel.organizations(jobs, gangs, playerJobs, playerGangs, duty, primaryJob, cfg)
    cfg = cfg or {}
    local gov, companies, groups = {}, {}, {}
    local govTypes = cfg.governmentTypes or {}
    for name, job in pairs(jobs or {}) do
        if not (cfg.hiddenJobs or {})[name] then
            local level = playerJobs and playerJobs[name]
            local entry = {
                name = name, label = job.label or name, type = job.type,
                member = level ~= nil, grade = level ~= nil and gradeName(job, level) or nil,
                primary = primaryJob and primaryJob.name == name or false,
                onduty = primaryJob and primaryJob.name == name and primaryJob.onduty or false,
                dutyCount = (duty or {})[name] or 0,
            }
            if job.type and govTypes[job.type] then gov[#gov + 1] = entry else companies[#companies + 1] = entry end
        end
    end
    for name, gang in pairs(gangs or {}) do
        if not (cfg.hiddenGangs or {})[name] then
            local level = playerGangs and playerGangs[name]
            groups[#groups + 1] = {
                name = name, label = gang.label or name,
                member = level ~= nil, grade = level ~= nil and gradeName(gang, level) or nil,
            }
        end
    end
    local function sort(list)
        table.sort(list, function(a, b)
            if a.member ~= b.member then return a.member end
            return a.label:lower() < b.label:lower()
        end)
        return list
    end
    return { government = sort(gov), companies = sort(companies), groups = sort(groups) }
end

-- ── Reglas ─────────────────────────────────────────────────────────────────

local accents = { ['á'] = 'a', ['é'] = 'e', ['í'] = 'i', ['ó'] = 'o', ['ú'] = 'u', ['ü'] = 'u', ['ñ'] = 'n',
    ['Á'] = 'a', ['É'] = 'e', ['Í'] = 'i', ['Ó'] = 'o', ['Ú'] = 'u', ['Ü'] = 'u', ['Ñ'] = 'n' }

function PXDPanel.normalize(s)
    s = tostring(s or '')
    for k, v in pairs(accents) do s = s:gsub(k, v) end
    return s:lower()
end

--- Reglas que contienen todas las palabras de la búsqueda (sin tildes ni mayúsculas).
function PXDPanel.searchRules(rules, query)
    local words = {}
    for w in PXDPanel.normalize(query):gmatch('%S+') do words[#words + 1] = w end
    if #words == 0 then return rules end
    local out = {}
    for _, r in ipairs(rules or {}) do
        local text = PXDPanel.normalize(r.title .. ' ' .. (r.body or '') .. ' ' .. table.concat(r.points or {}, ' '))
        local all = true
        for _, w in ipairs(words) do
            if not text:find(w, 1, true) then all = false break end
        end
        if all then out[#out + 1] = r end
    end
    return out
end

-- ── Ajustes del jugador ────────────────────────────────────────────────────

PXDPanel.defaultSettings = { textScale = 3, sounds = true, reduceMotion = false }

--- Limpia ajustes que vienen de la NUI o del KVP: solo claves conocidas y valores válidos.
function PXDPanel.sanitizeSettings(input)
    local out = {}
    for k, v in pairs(PXDPanel.defaultSettings) do out[k] = v end
    if type(input) ~= 'table' then return out end
    local scale = math.tointeger(tonumber(input.textScale))
    if scale and scale >= 1 and scale <= 5 then out.textScale = scale end
    if type(input.sounds) == 'boolean' then out.sounds = input.sounds end
    if type(input.reduceMotion) == 'boolean' then out.reduceMotion = input.reduceMotion end
    return out
end

-- ── Perfil ─────────────────────────────────────────────────────────────────

--- Perfil seguro a partir de PlayerData de Qbox y del progreso (opcional).
function PXDPanel.profile(pd, progress)
    if type(pd) ~= 'table' then return nil end
    local ci = pd.charinfo or {}
    local job = pd.job or {}
    local money = pd.money or {}
    local p = {
        name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        citizenid = pd.citizenid,
        job = job.name and job.name ~= 'unemployed' and {
            label = job.label or job.name, grade = job.grade and job.grade.name or nil, onduty = job.onduty == true,
        } or nil,
        gang = pd.gang and pd.gang.name and pd.gang.name ~= 'none' and {
            label = pd.gang.label or pd.gang.name, grade = pd.gang.grade and pd.gang.grade.name or nil,
        } or nil,
        cash = math.floor(tonumber(money.cash) or 0),
        bank = math.floor(tonumber(money.bank) or 0),
    }
    if type(progress) == 'table' then
        p.level = tonumber(progress.level)
        p.xp = tonumber(progress.xp)
        p.xpLevel = tonumber(progress.xpLevel)
        p.xpNext = tonumber(progress.xpNext)
        p.playtime = tonumber(progress.playtime)
        p.playtimeToday = tonumber(progress.playtimeToday)
        p.plus = progress.plus == true
    end
    return p
end

return PXDPanel
