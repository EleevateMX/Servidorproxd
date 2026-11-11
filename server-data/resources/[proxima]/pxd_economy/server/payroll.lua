-- Paga cada 30 minutos de tiempo activo (docs/41-economia-viva.md).
-- Un solo dueño de la nómina: con el parche de qbx_core (sendPaycheck comprueba
-- GlobalState.pxdPayroll) paga pxd_economy; sin él, sigue pagando qbx_core y aquí no se paga.
local P, Store, Tax = PXDPayroll, PXDLiveStore, PXDTax
local cfg = Config.payroll

local ready, active, startedAt = false, false, nil
local states = {}       -- [citizenid] = estado del ciclo (P.newState) + src, lastTick, lastPaidAt
local bySource = {}     -- [src] = citizenid
local ticks = 0

local function clock() return (PXDEconomyClock and PXDEconomyClock()) or os.time() end
local function uptime() return GetGameTimer() / 1000 end
local function started(res) return GetResourceState(res) == 'started' end
local function interval() return (cfg.intervalMinutes or 30) * 60 end

local function getPlayer(src)
    if not started('qbx_core') then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function jobDef(name)
    local ok, def = pcall(function() return exports.qbx_core:GetJob(name) end)
    return ok and def or nil
end

--- ¿Tiene qbx_core el parche que le hace ceder la nómina?
local function qbxPatched()
    local code = LoadResourceFile('qbx_core', 'config/server.lua')
    return code ~= nil and code:find(P.PATCH_MARK, 1, true) ~= nil
end

local function setActive(on, why)
    active = on
    GlobalState.pxdPayroll = on
    if not on and why then print('[pxd_economy] ^3Paga de Próxima desactivada: ' .. why .. '^7') end
end

local function publish(src, st, afk, eligible)
    Player(src).state:set('pxdPayday', {
        active = active, remaining = P.remaining(st, cfg), interval = interval(), afk = afk == true, eligible = eligible == true,
    }, true)
end

local function load(src, pd)
    local cid = pd.citizenid
    local st = states[cid]
    if not st then
        local row = Store.payrollLoad(cid)
        st = P.newState(row.progress, uptime())
        st.lastPaidAt = tonumber(row.last_paid_at) or 0
        states[cid] = st
    end
    st.src, st.lastTick = src, uptime()
    bySource[src] = cid
    return st
end

local function unload(src)
    local cid = bySource[src]
    bySource[src] = nil
    local st = cid and states[cid]
    if not st or st.src ~= src then return end
    states[cid] = nil
    if ready then pcall(Store.payrollSave, cid, math.floor(st.progress)) end
end

local function pendingOf(cid)
    local fines, invoices = 0, 0
    if started('pxd_justice') then
        local ok, v = pcall(function() return exports.pxd_justice:GetOutstanding(cid) end)
        if ok then fines = tonumber(v) or 0 end
    end
    if PXDEconomyServer and PXDEconomyServer.isReady() then
        local ok, v = pcall(PXDEconomyStore.outstanding, cid)
        if ok then invoices = tonumber(v) or 0 end
    end
    return { fines = fines, invoices = invoices }
end

local function societyTake(job, amount)
    local ok, done = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(job, amount) end)
    return ok and done == true
end

local function societyGive(job, amount)
    pcall(function() return exports['Renewed-Banking']:addAccountMoney(job, amount) end)
end

--- Paga el ciclo. Devuelve true si se pagó.
local function pay(src, player, st, gross, kind)
    if st.busy then return false end
    st.busy = true
    local paid = false
    local ok, err = pcall(function()
        local pd = player.PlayerData
        local cid, job = pd.citizenid, pd.job or {}
        local tax = Tax.amount('payroll', gross)
        local net = gross - tax
        local nowE = clock()
        local fromSociety = kind == 'sueldo' and cfg.society[job.name] == true
        if fromSociety and not societyTake(job.name, gross) then
            -- La empresa no puede pagar: no se pierde el ciclo, se reintenta en unos minutos.
            st.progress = math.max(0, interval() - (cfg.societyRetryMinutes or 5) * 60)
            TriggerClientEvent('pxd_economy:client:paydayFailed', src, 'Tu empresa no tiene fondos para pagar la nómina. Se volverá a intentar.')
            return
        end
        local prevPaidAt = st.lastPaidAt or 0
        if not Store.payrollClaim(cid, nowE, net, nowE - interval() + (cfg.tickSeconds or 30) * 2) then
            if fromSociety then societyGive(job.name, gross) end
            st.progress = 0   -- ya cobró dentro de este ciclo: no hay segunda paga
            return
        end
        if not player.Functions.AddMoney(cfg.moneyType or 'bank', net, 'pxd-nomina') then
            Store.payrollRevert(cid, prevPaidAt, interval(), net, nowE)
            if fromSociety then societyGive(job.name, gross) end
            error('qbx_core rechazó el ingreso')
        end
        st.progress, st.lastPaidAt = 0, nowE
        paid = true
        if tax > 0 then Tax.collect('payroll', cid, gross, tax, job.label or job.name) end
        if cfg.audit and started('pxd_audit') then
            pcall(function()
                exports.pxd_audit:Log({ category = 'economia', action = 'nomina', actor = 'system', target = cid,
                    data = { gross = gross, tax = tax, net = net, job = job.name, kind = kind, source = fromSociety and 'empresa' or 'estado' } })
            end)
        end
        local b = P.breakdown(gross, tax, kind, job.label or job.name, pendingOf(cid))
        b.next = interval()
        TriggerClientEvent('pxd_economy:client:payday', src, b)
    end)
    st.busy = false
    if not ok then print(('[pxd_economy] error al pagar la nómina de %s: %s'):format(tostring(bySource[src]), tostring(err))) end
    return paid
end

--- Una revisión de todos los jugadores con personaje cargado.
local function tick()
    if not ready then return end
    ticks = ticks + 1
    local t = uptime()
    -- Tras arrancar se espera un margen sin pagar: si qbx_core siguiera pagando en memoria
    -- (parche aplicado sin reiniciar), su onPaycheck lo delata antes de la primera paga.
    local canPay = active and (t - startedAt) >= (cfg.startGraceMinutes or 11) * 60
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local player = getPlayer(src)
        if player and player.PlayerData and Player(src).state.isLoggedIn then
            local pd = player.PlayerData
            local st = states[pd.citizenid]
            if not st or st.src ~= src then st = load(src, pd) end
            local elapsed = t - (st.lastTick or t)
            st.lastTick = t
            local ped = GetPlayerPed(src)
            local pos, heading
            if ped and ped ~= 0 then pos, heading = GetEntityCoords(ped), GetEntityHeading(ped) end
            local afk = P.activity(st, pos, heading, t, cfg.afk)
            local gross, kind = P.gross(pd.job, pd.job and jobDef(pd.job.name), cfg)
            local due = P.accumulate(st, elapsed, gross > 0, afk, cfg)
            if due and canPay then pay(src, player, st, gross, kind) end
            publish(src, st, afk, gross > 0)
        end
    end
    if ticks % (cfg.saveEveryTicks or 10) == 0 then
        for cid, st in pairs(states) do pcall(Store.payrollSave, cid, math.floor(st.progress)) end
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not ready or type(player) ~= 'table' or not player.PlayerData then return end
    local st = load(player.PlayerData.source, player.PlayerData)
    publish(player.PlayerData.source, st, false, true)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) unload(tonumber(src)) end)
AddEventHandler('playerDropped', function() unload(source) end)

-- qbx_core sigue pagando (su configuración en memoria no tiene el parche): se cede la nómina
-- para no pagar dos veces. Vuelve a activarse en el siguiente arranque.
AddEventHandler('qbx_core:server:onPaycheck', function()
    if active then setActive(false, 'qbx_core sigue pagando su nómina (¿parche aplicado sin reiniciar el servidor?). Paga qbx_core hasta el próximo reinicio.') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    GlobalState.pxdPayroll = false
    if not ready then return end
    for cid, st in pairs(states) do pcall(Store.payrollSave, cid, math.floor(st.progress)) end
end)

--- Otra señal de actividad para el anti-AFK (chat, interacciones…).
exports('MarkActive', function(src)
    local st = states[bySource[tonumber(src)] or '']
    if st then P.touch(st, uptime()) end
end)

--- Estado de la paga de un jugador: { active, remaining, interval, progress } o nil.
exports('GetPaydayStatus', function(src)
    local st = states[bySource[tonumber(src)] or '']
    if not st then return nil end
    return { active = active, remaining = P.remaining(st, cfg), interval = interval(), progress = st.progress }
end)

-- Solo consola: adelanta la paga de un jugador (para probar en el servidor).
RegisterCommand('pxd_nomina', function(src, args)
    if src ~= 0 then return end
    local st = states[bySource[tonumber(args[1]) or -1] or '']
    if not st then return print('[pxd_economy] Uso: pxd_nomina <id de jugador con personaje cargado>') end
    st.progress = interval()
    print(('[pxd_economy] La paga de #%s se abonará en la próxima revisión (%s).'):format(args[1],
        active and ('máx. %d s'):format(cfg.tickSeconds or 30) or 'la nómina de Próxima está desactivada'))
end, true)

CreateThread(function()
    startedAt = uptime()
    if not cfg.enabled then return end
    local ok, err = pcall(Store.initPayroll)
    if not ok then return print('[pxd_economy] ^1No se pudo preparar la tabla de la paga: ' .. tostring(err) .. '^7') end
    ready = true
    if qbxPatched() then
        setActive(true)
    else
        setActive(false, 'qbx_core no tiene el parche de docs/41 (ejecuta pxd_update y reinicia). Mientras tanto paga qbx_core cada 10 minutos.')
    end
    while true do
        Wait((cfg.tickSeconds or 30) * 1000)
        local okTick, e = pcall(tick)
        if not okTick then print('[pxd_economy] error en la revisión de la paga: ' .. tostring(e)) end
    end
end)

PXDPayrollServer = { tick = tick, isActive = function() return active end, isReady = function() return ready end,
    states = function() return states end }   -- para pruebas
