-- Servidor de pxd_jobs: valida todo (trabajo, distancia, tiempos, topes) y paga.
local RES = GetCurrentResourceName()
local states = {}
local extra = {}

local function qbx() return GetResourceState('qbx_core') == 'started' end

local function now() return GetGameTimer() / 1000 end

local function rnd(a, b) return math.random(a, b) end

-- Lo ganado en la última hora va por CUENTA (licencia), no por conexión: así
-- reconectar o cambiar de personaje no reinicia el tope. Dura lo que dure el servidor
-- encendido (la ventana es de una hora, medida con el reloj del servidor).
local ledgers = {}

local function accountKey(src)
    local id = GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
    return id or ('src:' .. tostring(src))
end

local function st(src)
    if not states[src] then
        local s = PXDJobs.newState()
        local key = accountKey(src)
        ledgers[key] = ledgers[key] or {}
        s.earned = ledgers[key]
        states[src] = s
    end
    return states[src]
end

local function pos(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    return { x = c.x, y = c.y, z = c.z }
end

local function notify(src, text, kind)
    if qbx() then
        pcall(function() exports.qbx_core:Notify(src, text, kind or 'inform') end)
    else
        TriggerClientEvent('pxd_jobs:notify', src, text)
    end
end

--- ¿Puede trabajar en `name`? Con Qbox: debe ser su trabajo principal.
local function hasJob(src, name)
    if not Config.requireJob then return true end
    if qbx() then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        return ok and player and player.PlayerData and player.PlayerData.job
            and player.PlayerData.job.name == name or false
    end
    return st(src).job == name
end

local function pay(src, amount, reason)
    if amount <= 0 then return false end
    if qbx() then
        local ok, res = pcall(function() return exports.qbx_core:AddMoney(src, 'cash', amount, reason) end)
        return ok and res ~= false
    end
    return true
end

local function track(src)
    if GetResourceState('pxd_progress') ~= 'started' then return end
    pcall(function() exports.pxd_progress:Track(src, 'job_task', 1) end)
end

local function jobOf(name)
    if type(name) ~= 'string' then return nil end
    return Config.jobs[name]
end

local function registerQbxJobs()
    if not qbx() then return end
    local ok, res, msg = pcall(function() return exports.qbx_core:CreateJobs(PXDJobs.qbxJobs(Config.jobs), false) end)
    if not ok or res == false then
        print(('[pxd_jobs] No se pudieron registrar los trabajos en Qbox: %s'):format(tostring(ok and msg or res)))
    end
end

-- ── Arranque ────────────────────────────────────────────────────────────────

local function loadExtra()
    local raw = LoadResourceFile(RES, Config.dataFile)
    local ok, data = pcall(json.decode, raw or '')
    extra = ok and type(data) == 'table' and data or {}
    PXDJobs.applyExtra(Config.jobs, extra)
end

local function validateAll()
    local all = {}
    for name, job in pairs(Config.jobs) do
        for _, e in ipairs(PXDJobs.validateJob(name, job)) do all[#all + 1] = e end
    end
    for _, e in ipairs(all) do print('[pxd_jobs] Config: ' .. e) end
    return #all == 0
end

loadExtra()
validateAll()
registerQbxJobs()

AddEventHandler('onResourceStart', function(res)
    if res == 'qbx_core' then registerQbxJobs() end
end)

AddEventHandler('playerDropped', function()
    states[source] = nil
end)

RegisterNetEvent('pxd_jobs:ready', function()
    TriggerClientEvent('pxd_jobs:points', source, extra)
end)

-- ── Alta y baja ─────────────────────────────────────────────────────────────

RegisterNetEvent('pxd_jobs:signOn', function(name)
    local src = source
    local job = jobOf(name)
    if not job then return end
    if PXDJobs.dist(job.signOn, pos(src)) > 5.0 then return notify(src, 'Acércate al punto de alta.', 'error') end
    if qbx() then
        local ok, res = pcall(function() return exports.qbx_core:SetJob(src, name, 0) end)
        if not ok or res == false then return notify(src, 'No se pudo darte de alta.', 'error') end
    end
    local s = st(src)
    s.job, s.carry, s.action, s.delivery = name, 0, nil, nil
    notify(src, ('Ahora trabajas de %s.'):format(job.label), 'success')
end)

RegisterNetEvent('pxd_jobs:signOff', function(name)
    local src = source
    local job = jobOf(name)
    if not job or not hasJob(src, name) then return end
    if PXDJobs.dist(job.signOn, pos(src)) > 5.0 then return notify(src, 'Acércate al punto de alta.', 'error') end
    if qbx() then pcall(function() exports.qbx_core:SetJob(src, 'unemployed', 0) end) end
    states[src] = nil
    TriggerClientEvent('pxd_jobs:route', src, nil)
    notify(src, ('Has dejado el trabajo de %s.'):format(job.label), 'inform')
end)

-- ── Recolección ─────────────────────────────────────────────────────────────

RegisterNetEvent('pxd_jobs:start', function(name, idx)
    local src = source
    local job = jobOf(name)
    if not job or job.kind ~= 'gather' or type(idx) ~= 'number' then return end
    if not hasJob(src, name) then return notify(src, ('Primero date de alta como %s.'):format(job.label), 'error') end
    local ok, res = PXDJobs.startWork(st(src), name, job, math.floor(idx), pos(src), now())
    if not ok then return notify(src, res, 'error') end
    TriggerClientEvent('pxd_jobs:started', src, name, res, job.work.scenario)
end)

RegisterNetEvent('pxd_jobs:finish', function(name)
    local src = source
    local job = jobOf(name)
    if not job or job.kind ~= 'gather' then return end
    local s = st(src)
    local ok, res = PXDJobs.finishWork(s, name, job, pos(src), now(), rnd)
    if not ok then return notify(src, res, 'error') end
    track(src)
    notify(src, ('+%d %s (llevas %d/%d)'):format(res, job.unit, s.carry, job.maxCarry), 'success')
end)

RegisterNetEvent('pxd_jobs:cancel', function()
    if states[source] then PXDJobs.cancel(states[source]) end
end)

RegisterNetEvent('pxd_jobs:sell', function(name)
    local src = source
    local job = jobOf(name)
    if not job or job.kind ~= 'gather' then return end
    if not hasJob(src, name) then return notify(src, ('Primero date de alta como %s.'):format(job.label), 'error') end
    local s = st(src)
    local ok, res, sold = PXDJobs.sell(s, job, pos(src), now(), Config.maxEarningsPerHour)
    if not ok then return notify(src, res, 'error') end
    if not pay(src, res, 'pxd_jobs:' .. name) then
        s.carry = sold
        return notify(src, 'No se pudo cobrar. Inténtalo de nuevo.', 'error')
    end
    notify(src, ('Vendiste %d %s por $%d.'):format(sold, job.unit, res), 'success')
end)

-- ── Repartidor ──────────────────────────────────────────────────────────────

RegisterNetEvent('pxd_jobs:pickup', function(name)
    local src = source
    local job = jobOf(name)
    if not job or job.kind ~= 'delivery' then return end
    if not hasJob(src, name) then return notify(src, ('Primero date de alta como %s.'):format(job.label), 'error') end
    local ok, res = PXDJobs.pickup(st(src), job, pos(src), now(), rnd)
    if not ok then return notify(src, res, 'error') end
    TriggerClientEvent('pxd_jobs:route', src, name, job.deliver.drops[res])
    notify(src, 'Paquete recogido. Sigue la ruta del mapa.', 'success')
end)

RegisterNetEvent('pxd_jobs:deliver', function(name)
    local src = source
    local job = jobOf(name)
    if not job or job.kind ~= 'delivery' then return end
    local ok, res = PXDJobs.deliver(st(src), job, pos(src), now(), Config.maxEarningsPerHour)
    TriggerClientEvent('pxd_jobs:route', src, nil)
    if not ok then return notify(src, res, 'error') end
    pay(src, res, 'pxd_jobs:' .. name)
    track(src)
    notify(src, ('Entrega completada: $%d. Vuelve al depósito por otro paquete.'):format(res), 'success')
end)

-- ── Puntos nuevos desde el juego (staff) ────────────────────────────────────

RegisterCommand('pxd_jobpunto', function(src, args)
    if src == 0 then return print('[pxd_jobs] Usa este comando dentro del juego.') end
    if not IsPlayerAceAllowed(src, Config.ace) then return notify(src, 'No tienes permiso.', 'error') end
    local name, kind = args[1], args[2]
    if not jobOf(name) or not PXDJobs.isKind(kind) then
        return notify(src, 'Uso: /pxd_jobpunto <miner|lumberjack|fisher|courier> <work|sell|drop|signon|depot>', 'error')
    end
    local p = pos(src)
    local pt = { x = math.floor(p.x * 100) / 100, y = math.floor(p.y * 100) / 100, z = math.floor(p.z * 100) / 100 }
    extra[name] = extra[name] or {}
    extra[name][kind] = extra[name][kind] or {}
    table.insert(extra[name][kind], pt)
    PXDJobs.applyExtra(Config.jobs, { [name] = { [kind] = { pt } } })
    SaveResourceFile(RES, Config.dataFile, json.encode(extra), -1)
    TriggerClientEvent('pxd_jobs:points', -1, extra)
    notify(src, ('Punto «%s» añadido a %s.'):format(kind, name), 'success')
end, false)
