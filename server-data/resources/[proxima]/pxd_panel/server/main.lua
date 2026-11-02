-- Servidor de pxd_panel: arma los datos del jugador (nunca se fía del cliente) y
-- reenvía reclamaciones a pxd_progress, que es quien decide.
local lastRequest = {}
local lastLogout = {}

local function now() return os.time() end

local function started(res) return GetResourceState(res) == 'started' end

--- Llama a un export de pxd_progress de forma segura. nil si falta o falla.
local function progress(fn, ...)
    if not started('pxd_progress') then return nil end
    local ok, a, b = pcall(function(...) return exports.pxd_progress[fn](exports.pxd_progress, ...) end, ...)
    if not ok then
        print(('[pxd_panel] pxd_progress:%s falló: %s'):format(fn, tostring(a)))
        return nil
    end
    return a, b
end

--- Llama a un export de pxd_justice (multas) de forma segura. nil si falta o falla.
local function justice(fn, ...)
    if not started('pxd_justice') then return nil end
    local ok, a, b = pcall(function(...) return exports.pxd_justice[fn](exports.pxd_justice, ...) end, ...)
    if not ok then
        print(('[pxd_panel] pxd_justice:%s falló: %s'):format(fn, tostring(a)))
        return nil
    end
    return a, b
end

local function playerData(src)
    if not started('qbx_core') then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player and player.PlayerData or nil
end

local function allowed(src)
    local t = GetGameTimer() / 1000
    if lastRequest[src] and t - lastRequest[src] < Config.requestCooldown then return false end
    lastRequest[src] = t
    return true
end

local function organizations(pd)
    if not started('qbx_core') then return nil end
    local ok, jobs = pcall(function() return exports.qbx_core:GetJobs() end)
    local ok2, gangs = pcall(function() return exports.qbx_core:GetGangs() end)
    if not ok or not ok2 then return nil end
    local duty = {}
    for name in pairs(jobs or {}) do
        local okc, count = pcall(function() return exports.qbx_core:GetDutyCountJob(name) end)
        duty[name] = okc and tonumber(count) or 0
    end
    return PXDPanel.organizations(jobs, gangs, pd and pd.jobs, pd and pd.gangs, duty,
        pd and pd.job and { name = pd.job.name, onduty = pd.job.onduty } or nil, Config)
end

local function staticData()
    return {
        serverName = Config.serverName,
        storeUrl = (type(Config.storeUrl) == 'string' and Config.storeUrl:match('^https://')) and Config.storeUrl or nil,
        discord = Config.discord,
        timeZone = Config.timeZone,
        support = Config.support,
        news = Config.news,
        rulesIntro = PXDRules.intro,
        rules = PXDRules.list,
    }
end

local function dynamicData(src)
    local pd = playerData(src)
    local hasProgress = started('pxd_progress')
    local data = {
        now = now(),
        online = GetNumPlayerIndices(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        profile = PXDPanel.profile(pd, hasProgress and progress('GetProfile', src) or nil)
            or { name = GetPlayerName(src) or '', cash = 0, bank = 0 },
        events = PXDPanel.events(Config.events, now()),
        orgs = organizations(pd),
        progress = hasProgress,
        framework = pd ~= nil,
    }
    if pd then data.fines = justice('GetPlayerView', src) end
    if hasProgress then
        data.daily = progress('GetDaily', src)
        data.achievements = progress('GetAchievements', src)
    end
    return data
end

RegisterNetEvent('pxd_panel:server:open', function(withStatic)
    local src = source
    if not allowed(src) then return end
    local data = dynamicData(src)
    if withStatic == true then data.static = staticData() end
    TriggerClientEvent('pxd_panel:client:data', src, data)
end)

local function answer(src, ok, message)
    TriggerClientEvent('pxd_panel:client:result', src, { ok = ok == true, message = type(message) == 'string' and message or nil })
    TriggerClientEvent('pxd_panel:client:data', src, dynamicData(src))
end

RegisterNetEvent('pxd_panel:server:claimDaily', function()
    local src = source
    if not allowed(src) then return end
    if not started('pxd_progress') then return answer(src, false, 'Las recompensas no están disponibles.') end
    local ok, message = progress('ClaimDaily', src)
    answer(src, ok, message)
end)

RegisterNetEvent('pxd_panel:server:claimAchievement', function(id)
    local src = source
    if not allowed(src) then return end
    if type(id) ~= 'string' or #id > 64 or not id:match('^[%w_%-%.:]+$') then return end
    if not started('pxd_progress') then return answer(src, false, 'Los logros no están disponibles.') end
    local ok, message = progress('ClaimAchievement', src, id)
    answer(src, ok, message)
end)

-- Multas (pxd_justice decide todo: propietario, importe, fondos y bloqueo por multa).
RegisterNetEvent('pxd_panel:server:payFine', function(id, amount, method)
    local src = source
    if not allowed(src) then return end
    local function int(v) v = tonumber(v) return v and math.tointeger(v) end
    id, amount = int(id), int(amount)
    if not id or not amount or id < 1 or amount < 1 or (method ~= 'cash' and method ~= 'bank') then return end
    if not started('pxd_justice') then return answer(src, false, 'Las multas no están disponibles.') end
    local ok, message = justice('PayFine', src, id, amount, method)
    answer(src, ok, message)
end)

RegisterNetEvent('pxd_panel:server:searchFines', function(query)
    local src = source
    if not allowed(src) then return end
    if type(query) ~= 'string' or #query > 64 then return end
    local view, err = justice('SearchFines', src, query)
    TriggerClientEvent('pxd_panel:client:fineSearch', src, view and { ok = true, result = view }
        or { ok = false, message = type(err) == 'string' and err or 'Las multas no están disponibles.' })
end)

-- Volver a la selección de personaje (qbx_core: export Logout).
RegisterNetEvent('pxd_panel:server:logout', function()
    local src = source
    local t = GetGameTimer() / 1000
    if lastLogout[src] and t - lastLogout[src] < 10 then return end
    lastLogout[src] = t
    if not playerData(src) then return end
    exports.qbx_core:Logout(src)
end)

AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
    lastLogout[source] = nil
end)
