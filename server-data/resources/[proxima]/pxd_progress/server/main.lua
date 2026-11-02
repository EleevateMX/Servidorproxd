-- pxd_progress (servidor): guarda el progreso en la metadata de Qbox (o en JSON sin Qbox),
-- alimenta horas y servicio cada minuto y expone exports para el panel y otros recursos.
local P = PXDProgress
local RES = GetCurrentResourceName()

local clock = os.time
local function now() return clock() end
local function hasQbx() return GetResourceState('qbx_core') == 'started' end
local function hasOx() return GetResourceState('ox_inventory') == 'started' end

local function license(src)
    return GetPlayerIdentifierByType(src, 'license')
end

-- ── Archivos JSON (sin Qbox y Plus) ─────────────────────────────────────

local function readJson(path)
    local raw = LoadResourceFile(RES, path)
    local ok, data = pcall(json.decode, raw or '')
    return (ok and type(data) == 'table') and data or {}
end

local function writeJson(path, data)
    SaveResourceFile(RES, path, json.encode(data), -1)
end

local fileData = readJson(Config.dataFile)
local plusData = readJson(Config.plusFile)

local function isPlus(src)
    return (P.plusActive(plusData, license(src), now()))
end

-- ── Carga y guardado ────────────────────────────────────────────────────

--- Progreso del personaje cargado (nil si no hay personaje).
local function load(src)
    src = tonumber(src)
    if not src then return nil end
    if hasQbx() then
        if not exports.qbx_core:GetPlayer(src) then return nil end
        return P.normalize(exports.qbx_core:GetMetadata(src, Config.metadataKey))
    end
    local lic = license(src)
    if not lic then return nil end
    fileData[lic] = P.normalize(fileData[lic])
    return fileData[lic]
end

local function save(src, data)
    if hasQbx() then
        exports.qbx_core:SetMetadata(tonumber(src), Config.metadataKey, data)
    else
        fileData[license(src)] = data
        writeJson(Config.dataFile, fileData)
    end
end

local function notify(src, title, text)
    TriggerClientEvent('pxd_progress:notify', src, { title = title, text = text })
end

--- Tras sumar XP: avisa si subió de nivel.
local function afterXp(src, before, after)
    if after > before then
        TriggerEvent('pxd_progress:levelUp', src, after)
        notify(src, '¡Subiste de nivel!', ('Ahora eres nivel %d.'):format(after))
    end
end

-- ── Exports ─────────────────────────────────────────────────────────────

local function GetProfile(src)
    local data = load(src)
    if not data then return nil end
    return P.profile(data, now(), Config, isPlus(src))
end

local function AddXP(src, amount, reason)
    local data = load(src)
    if not data then return nil end
    local before, after = P.addXp(data, amount, Config)
    save(src, data)
    afterXp(src, before, after)
    return after
end

local function Track(src, key, amount)
    if type(key) ~= 'string' then return false end
    local data = load(src)
    if not data then return false end
    local before = P.levelFromXp(data.xp, Config.levels)
    local xp = P.track(data, key, amount or 1, now(), Config)
    if xp == nil then return false end
    save(src, data)
    afterXp(src, before, (P.levelFromXp(data.xp, Config.levels)))
    return true
end

local function GetDaily(src)
    local data = load(src)
    if not data then return nil end
    local view = P.dailyView(data, now(), Config, isPlus(src))
    save(src, data) -- guarda la penalización aplicada
    return view
end

--- Comprueba que todas las recompensas se pueden entregar antes de entregar nada.
local function canGrant(src, rewards)
    for _, r in ipairs(rewards) do
        if r.type == 'money' then
            if not hasQbx() then return false, 'El dinero necesita Qbox.' end
        elseif r.type == 'item' then
            if not hasOx() then return false, 'Los objetos necesitan ox_inventory.' end
            if not exports.ox_inventory:CanCarryItem(src, r.name, r.count or 1) then
                return false, 'No tienes espacio en el inventario.'
            end
        end
    end
    return true
end

local function grant(src, data, r, reason)
    if r.type == 'money' then
        return exports.qbx_core:AddMoney(src, r.account == 'bank' and 'bank' or 'cash', r.amount, reason)
    elseif r.type == 'item' then
        return (exports.ox_inventory:AddItem(src, r.name, r.count or 1))
    elseif r.type == 'xp' then
        P.addXp(data, r.amount, Config)
        return true
    end
    return false
end

local function ClaimDaily(src)
    local data = load(src)
    if not data then return false, 'No tienes un personaje cargado.' end
    local t = now()
    local def, why, n = P.checkClaim(data, t, Config)
    if not def then
        save(src, data)
        return false, why
    end
    local rewards = { def.free }
    if def.plus and isPlus(src) then rewards[#rewards + 1] = def.plus end
    local ok, err = canGrant(src, rewards)
    if not ok then return false, err end
    local before = P.levelFromXp(data.xp, Config.levels)
    local reason = ('pxd_progress: día %d de %s'):format(n, Config.daily.season.id)
    for _, r in ipairs(rewards) do grant(src, data, r, reason) end
    P.markClaimed(data, t, Config)
    save(src, data)
    afterXp(src, before, (P.levelFromXp(data.xp, Config.levels)))
    return true, ('Reclamaste el día %d.'):format(n)
end

local function GetAchievements(src)
    local data = load(src)
    if not data then return nil end
    return P.achievementsView(data, now(), Config)
end

local function ClaimAchievement(src, id)
    if type(id) ~= 'string' then return false, 'Logro no válido.' end
    local data = load(src)
    if not data then return false, 'No tienes un personaje cargado.' end
    local it, why = P.checkAchievement(data, id, now(), Config)
    if not it then return false, why end
    if it.rewardMoney then
        local ok, err = canGrant(src, { { type = 'money' } })
        if not ok then return false, err end
    end
    local before = P.levelFromXp(data.xp, Config.levels)
    data.achievements[id] = true
    if it.rewardXp and it.rewardXp > 0 then P.addXp(data, it.rewardXp, Config) end
    if it.rewardMoney then
        exports.qbx_core:AddMoney(src, it.rewardMoney.account == 'bank' and 'bank' or 'cash', it.rewardMoney.amount, 'pxd_progress: logro ' .. id)
    end
    save(src, data)
    afterXp(src, before, (P.levelFromXp(data.xp, Config.levels)))
    return true, ('Logro reclamado: %s.'):format(it.label)
end

local function SummaryFromMetadata(meta)
    return P.summaryFromMetadata(meta, Config)
end

exports('GetProfile', GetProfile)
exports('AddXP', AddXP)
exports('Track', Track)
exports('GetDaily', GetDaily)
exports('ClaimDaily', ClaimDaily)
exports('GetAchievements', GetAchievements)
exports('ClaimAchievement', ClaimAchievement)
exports('SummaryFromMetadata', SummaryFromMetadata)

-- ── Minuto a minuto: horas jugadas y servicio ───────────────────────────

local function onDuty(src)
    if not hasQbx() then return false end
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData and player.PlayerData.job
    return job ~= nil and job.onduty == true and not Config.dutyIgnoredJobs[job.name]
end

local function tick()
    local t = now()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local data = load(src)
        if data then
            local before = P.levelFromXp(data.xp, Config.levels)
            P.addPlaytime(data, 60, t, Config)
            P.track(data, 'playtime_min', 1, t, Config)
            if onDuty(src) then P.track(data, 'duty_min', 1, t, Config) end
            save(src, data)
            afterXp(src, before, (P.levelFromXp(data.xp, Config.levels)))
        end
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        tick()
    end
end)

-- ── Plus (para Tebex: solo desde la consola) ────────────────────────────

RegisterCommand('pxd_plus', function(source, args)
    if source ~= 0 then return end
    local who, days = args[1], tonumber(args[2])
    if not who or not days or days <= 0 or days > 3650 then
        return print('[pxd_progress] Uso: pxd_plus <id-jugador|licencia> <días>')
    end
    local lic
    local id = tonumber(who)
    if id and GetPlayerName(id) then
        lic = license(id)
    elseif who:match('^license:%x+$') then
        lic = who
    elseif who:match('^%x+$') and #who >= 32 then
        lic = 'license:' .. who
    end
    if not lic then return print('[pxd_progress] Jugador o licencia no válidos: ' .. tostring(who)) end
    local exp = P.extendPlus(plusData, lic, days, now())
    writeJson(Config.plusFile, plusData)
    print(('[pxd_progress] Plus para %s hasta %s (UTC).'):format(lic, os.date('!%Y-%m-%d %H:%M', exp)))
    if id and GetPlayerName(id) then notify(id, 'Plus activado', ('Tienes Plus %d días más.'):format(math.floor(days))) end
end, true)

-- Para las pruebas.
PXDProgressServer = { tick = tick, setClock = function(fn) clock = fn end, GetProfile = GetProfile, AddXP = AddXP, Track = Track, GetDaily = GetDaily,
    ClaimDaily = ClaimDaily, GetAchievements = GetAchievements, ClaimAchievement = ClaimAchievement,
    SummaryFromMetadata = SummaryFromMetadata }
