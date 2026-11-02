-- pxd_justice (servidor): multas con registro, deudas pendientes y pagos seguros.
-- Fuente de verdad: tabla pxd_fines. El dinero sale de qbx_core (efectivo/banco, nunca
-- en negativo) y entra en la cuenta de la sociedad de Renewed-Banking. docs/30-multas.md
local F, Store = PXDFines, PXDFineStore
local MSG = F.MESSAGES

local ready = false
local busy = {}      -- multas con una operación en curso (evita pagos dobles)
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

local function isAuthority(player)
    local job = player and player.PlayerData and player.PlayerData.job
    if not job or not Config.issuerJobTypes[job.type] or not job.onduty then return false end
    return ((job.grade and job.grade.level) or 0) >= (Config.minGrade or 0)
end

local function canView(src, player)
    return isAuthority(player) or IsPlayerAceAllowed(src, Config.ace.view) or IsPlayerAceAllowed(src, Config.ace.manage)
end

local function throttled(src)
    local t = GetGameTimer() / 1000
    if lastCall[src] and t - lastCall[src] < (Config.cooldown or 1.0) then return true end
    lastCall[src] = t
    return false
end

--- Audita una acción sobre una multa. Va a la auditoría común (pxd_audit, categoría 'fines',
--- target 'fine:<id>'). Si pxd_audit no está en marcha o falla, se guarda como antes en
--- pxd_fine_events, y `pxd_audit_migrar` la recoge después (docs/34).
--- `citizenid` es la persona multada; `extra` se añade a `data`.
local function audit(fineId, action, actor, amount, detail, citizenid, extra)
    local cid, name = nil, 'consola'
    if type(actor) == 'table' then cid, name = actor.PlayerData.citizenid, fullName(actor)
    elseif type(actor) == 'string' then name = actor end
    detail = detail and tostring(detail):sub(1, 255) or nil
    if started('pxd_audit') then
        local entry = F.auditEntry(fineId, action, cid, name, amount, detail, citizenid, extra)
        local ok, id = pcall(function() return exports.pxd_audit:Log(entry) end)
        if ok and id then return end
        print(('[pxd_justice] ^3pxd_audit no registró %s #%s (%s): se guarda en pxd_fine_events.^7'):format(action, tostring(fineId), tostring(id)))
    end
    local ok, err = pcall(Store.event, fineId, action, cid, name, amount, detail, now())
    if not ok then print(('[pxd_justice] no se pudo auditar %s #%s: %s'):format(action, tostring(fineId), tostring(err))) end
end

--- Publica lo pendiente del personaje en su state bag (lo lee pxd_hud) y avisa a otros recursos.
local function refresh(citizenid, fineId, action)
    local total = Store.outstanding(citizenid)
    local p = playerByCitizen(citizenid)
    if p then Player(p.PlayerData.source).state:set('pxdFines', total, true) end
    TriggerEvent('pxd_justice:fineChanged', citizenid, fineId, action, total)
    return total
end

-- ── Banco de la sociedad ──────────────────────────────────
local function deposit(society, amount, fineId, reason, payer)
    if not started('Renewed-Banking') then return false end
    local ok, done = pcall(function() return exports['Renewed-Banking']:addAccountMoney(society, amount) end)
    if not ok or not done then return false end
    -- Movimiento en el historial de la cuenta (solo registro; el saldo ya está sumado).
    pcall(function()
        exports['Renewed-Banking']:handleTransaction(society, ('Multa #%d'):format(fineId), amount,
            tostring(reason):sub(1, 120), payer or 'Ciudadano', society, 'deposit')
    end)
    return true
end

-- ── Pago ──────────────────────────────────────────────────
--- Paga (total o parcialmente) una multa del propio jugador. Devuelve ok, mensaje.
local function payFine(src, fineId, amount, method)
    if not ready then return false, MSG.sin_servicio end
    fineId, amount = tonumber(fineId), tonumber(amount)
    if not fineId or fineId < 1 or fineId ~= math.floor(fineId) then return false, MSG.no_existe end
    local player = getPlayer(src)
    if not player then return false, MSG.sin_servicio end
    if busy[fineId] then return false, MSG.en_curso end
    busy[fineId] = true

    -- Pasos completados, para deshacer lo justo si algo falla a mitad (error de BD, etc.).
    local step, pay, reason = 'none', 0, ('pxd-multa-%d'):format(fineId)
    local ok, a, b = pcall(function()
        local row = Store.get(fineId)
        local value, err = F.validatePayment(row, player.PlayerData.citizenid, amount, method, Config)
        if not value then return false, MSG[err] or err end
        pay = value

        -- Doble defensa: aunque qbx_core no tuviera 'bank' en dontAllowMinus, nunca saldo negativo.
        if (tonumber(player.Functions.GetMoney(method)) or 0) < pay then return false, MSG.fondos end
        if not player.Functions.RemoveMoney(method, pay, reason) then return false, MSG.fondos end
        step = 'charged'

        if not Store.pay(fineId, pay, now()) then
            step = 'none'
            player.Functions.AddMoney(method, pay, reason .. '-reembolso')
            return false, MSG.cambio
        end
        step = 'recorded'

        if not deposit(row.society or Config.society, pay, fineId, row.reason, fullName(player)) then
            Store.unpay(fineId, pay, now())
            step = 'none'
            player.Functions.AddMoney(method, pay, reason .. '-reembolso')
            audit(fineId, 'pay_failed', player, pay, 'banco de la sociedad no disponible', row.citizenid)
            return false, MSG.banco
        end
        step = 'deposited'

        audit(fineId, 'pay', player, pay, method, row.citizenid)
        local left = math.max(0, F.outstanding(row) - pay)
        refresh(row.citizenid, fineId, 'pay')
        if left == 0 then return true, ('Multa #%d pagada.'):format(fineId) end
        return true, ('Pagaste %s. Quedan %s de la multa #%d.'):format(money(pay), money(left), fineId)
    end)
    if not ok then
        print(('[pxd_justice] error al pagar #%d (paso %s): %s'):format(fineId, step, tostring(a)))
        if step == 'recorded' then pcall(Store.unpay, fineId, pay, now()) end
        if step == 'charged' or step == 'recorded' then
            pcall(player.Functions.AddMoney, method, pay, reason .. '-reembolso')
        end
        busy[fineId] = nil
        -- Si ya estaba ingresado en la sociedad, el pago es válido: solo falló el aviso/auditoría.
        if step == 'deposited' then return true, ('Multa #%d: pago registrado.'):format(fineId) end
        return false, MSG.sin_servicio
    end
    busy[fineId] = nil
    return a, b
end

-- ── Emisión ───────────────────────────────────────────────
--- Emite una multa. officerSrc = 0 para la consola o un recurso. Devuelve id o nil, mensaje.
local function issueFine(officerSrc, targetSrc, reason, amount, notes, opts)
    opts = opts or {}
    if not ready then return nil, MSG.sin_servicio end
    local okv, err = F.validateIssue(amount, reason, notes, Config.maxFine)
    if not okv then return nil, MSG[err] end
    if type(targetSrc) ~= 'number' or targetSrc <= 0 or targetSrc == officerSrc then return nil, 'Destinatario no válido.' end

    local officer = officerSrc > 0 and getPlayer(officerSrc) or nil
    if officerSrc > 0 then
        if not officer or not isAuthority(officer) then return nil, 'Solo la policía de servicio puede multar.' end
    end
    local target = getPlayer(targetSrc)
    if not target then return nil, 'No se encontró a esa persona.' end
    if officerSrc > 0 and not opts.skipDistance then
        local a, b = GetPlayerPed(officerSrc), GetPlayerPed(targetSrc)
        if a == 0 or b == 0 or GetPlayerRoutingBucket(officerSrc) ~= GetPlayerRoutingBucket(targetSrc)
            or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.maxDistance then
            return nil, 'Esa persona está demasiado lejos.'
        end
    end

    local cid = target.PlayerData.citizenid
    local id = Store.insert({
        citizenid = cid,
        officer_citizenid = officer and officer.PlayerData.citizenid or nil,
        officer_name = officer and fullName(officer) or (opts.issuerName or 'Administración'),
        reason = reason, notes = notes, amount = amount,
        society = opts.society or Config.society, record_ref = opts.recordRef,
    }, now())
    if not id then return nil, MSG.sin_servicio end
    audit(id, 'issue', officer or (opts.issuerName or 'consola'), amount, reason, cid)

    local total = refresh(cid, id, 'issue')
    notify(targetSrc, ('Has recibido una multa de %s: %s. Págala desde el panel (TAB → Multas).'):format(money(amount), reason), 'inform')
    if officerSrc > 0 then notify(officerSrc, ('Multa #%d emitida a %s por %s.'):format(id, fullName(target) or 'ciudadano', money(amount)), 'success') end

    -- Cobro inmediato opcional, solo si hay saldo suficiente (nunca en negativo).
    if Config.autoChargeIfFunds then
        local ok, bank = pcall(function() return target.Functions.GetMoney('bank') end)
        if ok and (tonumber(bank) or 0) >= amount then payFine(targetSrc, id, amount, 'bank') end
    end
    return id, total
end

-- ── Multas del sistema (radares y otros automatismos) ─────
-- No hay agente: el autor es 'system'. La multa queda PENDIENTE como cualquier otra.
-- Hoy no la usa nada: los radares de qbx_police siguen cobrando en el acto (Config.radar.mode
-- = 'instant' y su parche NO está aplicado; texto preparado en docs/30).
local systemLast = {}

local function radarMode()
    local m = Config.radar and Config.radar.mode
    return (m == 'pending') and 'pending' or 'instant'
end

--- Emite una multa del sistema a un citizenid. meta = { source?, issuerName?, notes?, recordRef?, … }.
--- Devuelve id, total pendiente o nil, mensaje.
local function issueSystemFine(citizenid, reason, amount, meta)
    if not ready then return nil, MSG.sin_servicio end
    meta = type(meta) == 'table' and meta or {}
    if type(citizenid) ~= 'string' or #citizenid > 64 or not citizenid:find('^[%w_%-]+$') then
        return nil, 'Ciudadano no válido.'
    end
    local okv, err = F.validateIssue(amount, reason, meta.notes, Config.maxFine)
    if not okv then return nil, MSG[err] end
    local origin = F.systemOrigin(meta.source)
    if not origin then return nil, 'Origen no válido.' end
    local issuer = type(meta.issuerName) == 'string' and meta.issuerName:find('%S') and meta.issuerName:sub(1, 128)
        or Config.systemFine.issuerName
    local recordRef = type(meta.recordRef) == 'string' and meta.recordRef:sub(1, 64) or nil

    -- Enfriamiento por persona y origen (los radares los dispara el cliente).
    local key, t = citizenid .. '|' .. origin, now()
    if systemLast[key] and t - systemLast[key] < (Config.systemFine.cooldownSec or 0) then
        return nil, 'Multa del sistema repetida: espera unos segundos.'
    end
    systemLast[key] = t

    local id = Store.insert({
        citizenid = citizenid, officer_citizenid = nil, officer_name = issuer,
        reason = reason, notes = meta.notes, amount = amount,
        society = Config.society, record_ref = recordRef,
    }, t)
    if not id then systemLast[key] = nil return nil, MSG.sin_servicio end
    audit(id, 'issue', issuer, amount, reason, citizenid, { origin = origin, system = true })

    local total = refresh(citizenid, id, 'issue')
    local p = playerByCitizen(citizenid)
    if p then
        notify(p.PlayerData.source, ('Has recibido una multa de %s: %s. Págala desde el panel (TAB → Multas).'):format(money(amount), reason), 'inform')
    end
    return id, total
end

-- ── Adaptador de qbx_police ───────────────────────────────
-- El /fine de qbx_police abre su formulario y el cliente lanza este evento. Con el parche
-- de docs/30 (return al inicio de su manejador si pxd_justice está arrancado) lo atiende
-- solo este recurso, con las mismas comprobaciones y convirtiéndolo en multa registrada.
-- Marca del parche en qbx_police. Sin ella NO se atiende el evento: si no, qbx_police
-- cobraría la multa en el acto y además quedaría registrada aquí (doble sanción).
local PATCH_MARK = "if GetResourceState('pxd_justice') == 'started' then return end"
local adapterOk
local function adapterActive()
    if adapterOk == nil then
        local code = LoadResourceFile('qbx_police', 'server/main.lua')
        adapterOk = code ~= nil and code:find(PATCH_MARK, 1, true) ~= nil
        if not adapterOk then
            print('[pxd_justice] ^3qbx_police no tiene el parche de docs/30: las multas de /fine siguen cobrándose en el acto y no se registran.^7')
        end
    end
    return adapterOk
end

RegisterNetEvent('police:server:IssueFine', function(targetSrc, lawViolated, fineAmount, notes)
    local src = source
    if not adapterActive() then return end
    if throttled(src) then return end
    if type(targetSrc) ~= 'number' or not math.tointeger(targetSrc) or targetSrc <= 0 then
        return notify(src, 'Multa no válida.', 'error')
    end
    local id, msg = issueFine(src, targetSrc, lawViolated, fineAmount, notes)
    if not id then notify(src, msg, 'error') end
end)

-- ── Consultas ─────────────────────────────────────────────
local function viewFor(citizenid, withNotes)
    return F.summarize(Store.list(citizenid, Config.historyLimit), withNotes)
end

--- Lo que ve el propio jugador en el panel.
local function playerView(src)
    if not ready then return nil end
    local player = getPlayer(src)
    if not player then return nil end
    local v = viewFor(player.PlayerData.citizenid, false)
    v.canSearch = canView(src, player)
    v.methods = Config.paymentMethods
    return v
end

--- Búsqueda para autoridades: ID de servidor, PROX-XXXX o citizenid.
local function searchFines(src, query)
    if not ready then return nil, MSG.sin_servicio end
    local player = getPlayer(src)
    if not canView(src, player) then return nil, 'No tienes permiso para consultar multas.' end
    local kind, value = F.parseQuery(query)
    if not kind then return nil, 'Escribe un ID, un PROX-XXXX o un ID de ciudadano.' end
    local cid, name
    if kind == 'server' then
        local p = getPlayer(value); if not p then return nil, 'No hay nadie con ese ID.' end
        cid, name = p.PlayerData.citizenid, fullName(p)
    elseif kind == 'public' then
        if not started('pxd_interact') then return nil, 'La búsqueda por PROX no está disponible.' end
        local ok, s = pcall(function() return exports.pxd_interact:GetSourceByPublicId(value) end)
        local p = ok and s and getPlayer(s)
        if not p then return nil, 'No hay nadie conectado con ese PROX.' end
        cid, name = p.PlayerData.citizenid, fullName(p)
    else
        cid = value
        local p = playerByCitizen(cid); name = p and fullName(p) or nil
    end
    local v = viewFor(cid, true)
    v.citizenid, v.name = cid, name
    return v
end

-- ── Gestión (cancelar / corregir) ─────────────────────────
local function canManage(src) return src == 0 or IsPlayerAceAllowed(src, Config.ace.manage) end

local function cancelFine(src, fineId, reason)
    if not canManage(src) then return false, 'Sin permiso.' end
    local row = Store.get(tonumber(fineId) or -1)
    if not row then return false, MSG.no_existe end
    if busy[row.id] then return false, MSG.en_curso end
    if not Store.cancel(row.id, now()) then return false, MSG.cerrada end
    audit(row.id, 'cancel', src > 0 and getPlayer(src) or 'consola', F.outstanding(row), reason, row.citizenid)
    refresh(row.citizenid, row.id, 'cancel')
    return true, ('Multa #%d cancelada. Lo ya pagado no se devuelve automáticamente.'):format(row.id)
end

local function editFine(src, fineId, newAmount, reason)
    if not canManage(src) then return false, 'Sin permiso.' end
    newAmount = tonumber(newAmount)
    if not newAmount or newAmount ~= math.floor(newAmount) or newAmount < 1 or newAmount > Config.maxFine then return false, MSG.importe end
    local row = Store.get(tonumber(fineId) or -1)
    if not row then return false, MSG.no_existe end
    if busy[row.id] then return false, MSG.en_curso end
    if newAmount < (tonumber(row.paid) or 0) then return false, 'No puede ser menor que lo ya pagado.' end
    if not Store.edit(row.id, newAmount, now()) then return false, MSG.cerrada end
    audit(row.id, 'edit', src > 0 and getPlayer(src) or 'consola', newAmount, ('%s → %s · %s'):format(row.amount, newAmount, reason or ''), row.citizenid)
    refresh(row.citizenid, row.id, 'edit')
    return true, ('Multa #%d corregida a %s.'):format(row.id, money(newAmount))
end

local function reply(src, ok, msg)
    if src == 0 then print('[pxd_justice] ' .. tostring(msg)) else notify(src, msg, ok and 'success' or 'error') end
end

RegisterCommand('multa_cancelar', function(src, args)
    local ok, msg = cancelFine(src, args[1], table.concat(args, ' ', 2))
    reply(src, ok, msg)
end, false)

RegisterCommand('multa_corregir', function(src, args)
    local ok, msg = editFine(src, args[1], args[2], table.concat(args, ' ', 3))
    reply(src, ok, msg)
end, false)

-- ── Exports ───────────────────────────────────────────────
exports('IssueFine', function(officerSrc, targetSrc, reason, amount, notes, opts)
    return issueFine(tonumber(officerSrc) or 0, tonumber(targetSrc), reason, amount, notes, opts)
end)
exports('PayFine', function(src, fineId, amount, method) return payFine(src, fineId, amount, method) end)
exports('GetOutstanding', function(citizenid) return ready and Store.outstanding(citizenid) or 0 end)
exports('ListFines', function(citizenid, opts)
    if not ready then return {} end
    opts = opts or {}
    return F.summarize(Store.list(citizenid, opts.limit or Config.historyLimit), opts.withNotes == true)
end)
exports('GetPlayerView', playerView)
exports('SearchFines', searchFines)
exports('CancelFine', cancelFine)
exports('EditFine', editFine)
exports('IssueSystemFine', function(citizenid, reason, amount, meta) return issueSystemFine(citizenid, reason, amount, meta) end)
exports('GetRadarMode', radarMode)

--- Historial de una multa: pxd_audit (categoría 'fines') + las filas antiguas de pxd_fine_events
--- que aún no se han migrado, sin duplicados y en orden cronológico.
local function getFineEvents(fineId)
    if not ready then return {} end
    fineId = math.tointeger(tonumber(fineId)) or -1
    local okL, legacy = pcall(Store.events, fineId)
    local audits = {}
    if started('pxd_audit') then
        local ok, rows = pcall(function()
            return exports.pxd_audit:Query({ category = 'fines', target = 'fine:' .. fineId, limit = 500 })
        end)
        if ok and type(rows) == 'table' then audits = rows end
    end
    return F.mergeEvents(okL and legacy or {}, audits)
end
exports('GetFineEvents', getFineEvents)

-- ── Arranque y estado de los jugadores ────────────────────
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not ready or type(player) ~= 'table' or not player.PlayerData then return end
    local total = Store.outstanding(player.PlayerData.citizenid)
    Player(player.PlayerData.source).state:set('pxdFines', total, true)
end)

AddEventHandler('playerDropped', function() lastCall[source] = nil end)
AddEventHandler('onServerResourceStart', function(res) if res == 'qbx_police' then adapterOk = nil end end)

CreateThread(function()
    local ok, err = pcall(Store.init)
    if not ok then
        print('[pxd_justice] ^1No se pudo preparar la base de datos: ' .. tostring(err) .. '^7')
        return
    end
    ready = true
end)

PXDJustice = { pay = payFine, issue = issueFine, search = searchFines, view = playerView,
    cancel = cancelFine, edit = editFine, isReady = function() return ready end,
    issueSystem = issueSystemFine, events = getFineEvents, radarMode = radarMode,
    PATCH_MARK = PATCH_MARK }   -- para pruebas
