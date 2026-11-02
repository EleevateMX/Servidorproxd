-- pxd_economy (servidor): facturas de empresas y servicios (A-3, A-4) con cobro seguro.
-- Fuente de verdad: tabla pxd_invoices. El dinero sale de qbx_core (efectivo/banco, nunca en
-- negativo) y entra en la cuenta del trabajo en Renewed-Banking. docs/35-economia.md
local E, Store, Money = PXDEconomy, PXDEconomyStore, PXDMoney
local MSG = E.MESSAGES

local ready = false
local busy = {}       -- facturas con una operación en curso
local lastCall = {}

local function now() return os.time() end
local function started(res) return GetResourceState(res) == 'started' end

local function getPlayer(src)
    if not started('qbx_core') then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function playerByCitizen(cid)
    if not started('qbx_core') then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    return ok and p or nil
end

local function fullName(p)
    local c = p and p.PlayerData and p.PlayerData.charinfo or {}
    local n = ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or nil
end

local function notify(src, text, kind)
    if not src or src <= 0 or not started('qbx_core') then return end
    pcall(function() exports.qbx_core:Notify(src, text, kind or 'inform') end)
end

local function money(n) return '$' .. tostring(math.floor(n)) end

local function throttled(src)
    local t = GetGameTimer() / 1000
    if lastCall[src] and t - lastCall[src] < (Config.cooldown or 1.0) then return true end
    lastCall[src] = t
    return false
end

--- Registro propio (pxd_invoice_events) y, si está en marcha, la auditoría común (pxd_audit).
local function audit(id, action, actor, amount, detail, target)
    local cid, name = nil, 'consola'
    if type(actor) == 'table' then cid, name = actor.PlayerData.citizenid, fullName(actor)
    elseif type(actor) == 'string' then name = actor end
    local d = detail and tostring(detail):sub(1, 255) or nil
    local ok, err = pcall(Store.event, id, action, cid, name, amount, d, now())
    if not ok then print(('[pxd_economy] no se pudo registrar %s #%s: %s'):format(action, tostring(id), tostring(err))) end
    if started('pxd_audit') then
        pcall(function()
            exports.pxd_audit:Log({ category = 'economia', action = 'factura_' .. action, actor = cid or name,
                target = target, data = { invoice = id, amount = amount, detail = d } })
        end)
    end
end

local function refresh(citizenid, id, action)
    local total = Store.outstanding(citizenid)
    local p = playerByCitizen(citizenid)
    if p then Player(p.PlayerData.source).state:set('pxdInvoices', total, true) end
    TriggerEvent('pxd_economy:invoiceChanged', citizenid, id, action, total)
    return total
end

-- ── Emisión ───────────────────────────────────────────────
--- Emite una factura del trabajo de `issuerSrc` a `targetSrc`. Devuelve id o nil, mensaje.
local function issueInvoice(issuerSrc, targetSrc, amount, concept)
    if not ready then return nil, MSG.sin_servicio end
    local issuer = getPlayer(issuerSrc)
    if not issuer then return nil, MSG.sin_servicio end
    local rule, rerr = E.issuerRule(issuer.PlayerData.job, Config)
    if not rule then return nil, MSG[rerr] end
    local a, c = E.validateIssue(amount, concept, Config.maxInvoice)
    if not a then return nil, MSG[c] end
    targetSrc = tonumber(targetSrc)
    if not targetSrc or not math.tointeger(targetSrc) or targetSrc <= 0 or targetSrc == issuerSrc then return nil, MSG.cliente end
    local target = getPlayer(targetSrc)
    if not target then return nil, MSG.cliente end
    local pa, pb = GetPlayerPed(issuerSrc), GetPlayerPed(targetSrc)
    if pa == 0 or pb == 0 or GetPlayerRoutingBucket(issuerSrc) ~= GetPlayerRoutingBucket(targetSrc)
        or #(GetEntityCoords(pa) - GetEntityCoords(pb)) > Config.maxDistance then
        return nil, MSG.lejos
    end
    local cid = target.PlayerData.citizenid
    if Store.countOpen(cid, rule.job) >= Config.maxOpenPerClient then return nil, MSG.demasiadas end

    local id = Store.insert({
        job = rule.job, job_label = rule.label, account = rule.account,
        issuer_citizenid = issuer.PlayerData.citizenid, issuer_name = fullName(issuer),
        citizenid = cid, client_name = fullName(target), concept = c, amount = a,
    }, now())
    if not id then return nil, MSG.sin_servicio end
    audit(id, 'issue', issuer, a, c, cid)
    refresh(cid, id, 'issue')
    notify(targetSrc, ('%s te ha enviado una factura de %s: %s. Págala con /facturas.'):format(rule.label, money(a), c), 'inform')
    notify(issuerSrc, ('Factura #%d enviada a %s por %s.'):format(id, fullName(target) or 'cliente', money(a)), 'success')
    return id
end

-- ── Pago ──────────────────────────────────────────────────
local function payInvoice(src, id, amount, method)
    if not ready then return false, MSG.sin_servicio end
    id = tonumber(id)
    if not id or not math.tointeger(id) or id < 1 then return false, MSG.no_existe end
    local player = getPlayer(src)
    if not player then return false, MSG.sin_servicio end
    if busy[id] then return false, MSG.en_curso end
    busy[id] = true
    local ok, a, b = pcall(function()
        local row = Store.get(id)
        local pay, err = E.validatePayment(row, player.PlayerData.citizenid, amount, method, Config)
        if not pay then return false, MSG[err] or err end
        local reason = ('pxd-factura-%d'):format(id)
        local done, code = Money.chargeToAccount(player, method, pay, row.account, {
            reason = reason, title = ('Factura #%d'):format(id), message = row.concept, payer = fullName(player),
            record = function() return Store.pay(id, pay, now()) end,
            undo = function() Store.unpay(id, pay, now()) end,
        })
        if not done then
            if code == 'banco' then audit(id, 'pay_failed', player, pay, 'cuenta de la empresa no disponible', row.citizenid) end
            return false, MSG[code] or MSG.sin_servicio
        end
        audit(id, 'pay', player, pay, method, row.citizenid)
        local left = math.max(0, E.outstanding(row) - pay)
        refresh(row.citizenid, id, 'pay')
        local issuer = row.issuer_citizenid and playerByCitizen(row.issuer_citizenid)
        if issuer then
            notify(issuer.PlayerData.source, ('%s pagó %s de la factura #%d.'):format(fullName(player) or 'El cliente', money(pay), id), 'success')
        end
        if left == 0 then return true, ('Factura #%d pagada.'):format(id) end
        return true, ('Pagaste %s. Quedan %s de la factura #%d.'):format(money(pay), money(left), id)
    end)
    busy[id] = nil
    if not ok then
        print(('[pxd_economy] error al pagar #%d: %s'):format(id, tostring(a)))
        return false, MSG.sin_servicio
    end
    return a, b
end

-- ── Cancelación ───────────────────────────────────────────
local function cancelInvoice(src, id, reason)
    if not ready then return false, MSG.sin_servicio end
    local row = Store.get(tonumber(id) or -1)
    if not row then return false, MSG.no_existe end
    local isStaff = src == 0 or IsPlayerAceAllowed(src, Config.ace.manage)
    local actor = src > 0 and getPlayer(src) or nil
    local job = actor and actor.PlayerData.job or nil
    if not E.canCancel(row, actor and actor.PlayerData.citizenid, job, isStaff) then return false, MSG.permiso end
    if busy[row.id] then return false, MSG.en_curso end
    if not Store.cancel(row.id, now()) then return false, MSG.cerrada end
    audit(row.id, 'cancel', actor or 'consola', E.outstanding(row), reason, row.citizenid)
    refresh(row.citizenid, row.id, 'cancel')
    local client = playerByCitizen(row.citizenid)
    if client then notify(client.PlayerData.source, ('La factura #%d de %s fue cancelada.'):format(row.id, row.job_label or row.job), 'inform') end
    return true, ('Factura #%d cancelada. Lo ya pagado no se devuelve automáticamente.'):format(row.id)
end

-- ── Consultas ─────────────────────────────────────────────
local function clientView(src)
    local player = getPlayer(src)
    if not ready or not player then return nil end
    local v = E.summarize(Store.listClient(player.PlayerData.citizenid, Config.historyLimit))
    v.methods = Config.paymentMethods
    return v
end

local function jobView(src)
    local player = getPlayer(src)
    if not ready or not player then return nil end
    local rule = Config.invoiceJobs[player.PlayerData.job.name]
    if not rule then return nil end
    local v = E.summarize(Store.listJob(player.PlayerData.job.name, Config.historyLimit))
    v.job = player.PlayerData.job.label or player.PlayerData.job.name
    return v
end

-- ── Comandos y eventos de la interfaz (ox_lib en el cliente) ──
local function reply(src, ok, msg)
    if src == 0 then print('[pxd_economy] ' .. tostring(msg)) else notify(src, msg, ok and 'success' or 'error') end
end

-- /factura <id jugador> <importe> <concepto…>   (sin argumentos abre el formulario)
RegisterCommand('factura', function(src, args)
    if src == 0 then return print('[pxd_economy] /factura solo dentro del juego.') end
    if #args == 0 then
        local player = getPlayer(src)
        local rule, err = E.issuerRule(player and player.PlayerData.job, Config)
        if not rule then return notify(src, MSG[err], 'error') end
        return TriggerClientEvent('pxd_economy:client:issueForm', src, Config.maxInvoice)
    end
    if throttled(src) then return end
    local id, msg = issueInvoice(src, tonumber(args[1]), tonumber(args[2]), table.concat(args, ' ', 3))
    if not id then notify(src, msg, 'error') end
end, false)

RegisterCommand('facturas', function(src)
    if src == 0 then return end
    local v = clientView(src)
    if not v then return notify(src, MSG.sin_servicio, 'error') end
    TriggerClientEvent('pxd_economy:client:invoices', src, v, jobView(src))
end, false)

RegisterCommand('factura_cancelar', function(src, args)
    local ok, msg = cancelInvoice(src, args[1], table.concat(args, ' ', 2))
    reply(src, ok, msg)
end, false)

RegisterNetEvent('pxd_economy:server:issue', function(target, amount, concept)
    local src = source
    if throttled(src) then return end
    if type(concept) ~= 'string' then return notify(src, MSG.concepto, 'error') end
    local id, msg = issueInvoice(src, tonumber(target), tonumber(amount), concept)
    if not id then notify(src, msg, 'error') end
end)

RegisterNetEvent('pxd_economy:server:pay', function(id, amount, method)
    local src = source
    if throttled(src) then return end
    local ok, msg = payInvoice(src, id, amount, method)
    notify(src, msg, ok and 'success' or 'error')
    if ok then
        local v = clientView(src)
        if v then TriggerClientEvent('pxd_economy:client:invoices', src, v, jobView(src), true) end
    end
end)

RegisterNetEvent('pxd_economy:server:cancel', function(id)
    local src = source
    if throttled(src) then return end
    local ok, msg = cancelInvoice(src, id, 'desde el menú')
    notify(src, msg, ok and 'success' or 'error')
end)

-- ── Exports ───────────────────────────────────────────────
exports('IssueInvoice', function(issuerSrc, targetSrc, amount, concept) return issueInvoice(tonumber(issuerSrc), targetSrc, amount, concept) end)
exports('PayInvoice', function(src, id, amount, method) return payInvoice(tonumber(src), id, amount, method) end)
exports('CancelInvoice', function(src, id, reason) return cancelInvoice(tonumber(src) or 0, id, reason) end)
exports('GetOutstandingInvoices', function(citizenid) return ready and Store.outstanding(citizenid) or 0 end)
exports('GetClientView', clientView)
exports('GetInvoiceEvents', function(id) return ready and (MySQL.query.await('SELECT * FROM pxd_invoice_events WHERE invoice_id = ? ORDER BY id', { tonumber(id) or -1 }) or {}) or {} end)
-- X-4: cobro seguro reutilizable por otros recursos de Próxima.
exports('ChargeToAccount', function(src, method, amount, account, opts)
    local player = getPlayer(tonumber(src))
    amount = tonumber(amount)
    if not player or not amount or amount < 1 or amount ~= math.floor(amount) or not Config.paymentMethods[method] then return false, 'invalido' end
    return Money.chargeToAccount(player, method, amount, account, opts)
end)

-- ── Arranque ──────────────────────────────────────────────
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not ready or type(player) ~= 'table' or not player.PlayerData then return end
    Player(player.PlayerData.source).state:set('pxdInvoices', Store.outstanding(player.PlayerData.citizenid), true)
end)

AddEventHandler('playerDropped', function() lastCall[source] = nil end)

CreateThread(function()
    local ok, err = pcall(Store.init)
    if not ok then
        print('[pxd_economy] ^1No se pudo preparar la base de datos: ' .. tostring(err) .. '^7')
        return
    end
    ready = true
end)

PXDEconomyServer = { issue = issueInvoice, pay = payInvoice, cancel = cancelInvoice, clientView = clientView,
    jobView = jobView, isReady = function() return ready end }   -- para pruebas y ledger.lua
