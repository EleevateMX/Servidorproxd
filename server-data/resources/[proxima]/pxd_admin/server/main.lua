-- pxd_admin (servidor): reportes, panel de staff y acciones. Todo se valida aquí.
local RES = GetCurrentResourceName()

local reports, staffLog = {}, {}
local nextId = 1
local backPos = {}      -- [src] = { x, y, z, bucket } antes de ir/traer
local frozen = {}       -- [src] = true
local spectating = {}   -- [staffSrc] = { bucket = n }
local onDuty = {}       -- [staffSrc] = true (modo servicio)

local reportLimiter = PXDAdmin.newLimiter(Config.reportsPerWindow, Config.reportWindowSec)
local replyLimiter = PXDAdmin.newLimiter(Config.repliesPerMinute, 60)

-- ── Utilidades ──────────────────────────────────────────────────────────────

local function now() return os.time() end

local function online(src)
    src = tonumber(src)
    return src and GetPlayerName(src) ~= nil and src or nil
end

local function isStaff(src)
    return IsPlayerAceAllowed(src, Config.ace)
end

local function aceOf(src)
    return function(ace) return IsPlayerAceAllowed(src, ace) end
end

local function license(src)
    return GetPlayerIdentifierByType(src, 'license')
end

local function notify(src, title, text, kind)
    TriggerClientEvent('pxd_admin:client:notify', src, { title = title, text = text, kind = kind or 'info' })
end

local function qbxPlayer(src)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p and p.PlayerData or nil
end

local function progress(src)
    if GetResourceState('pxd_progress') ~= 'started' then return nil end
    local ok, p = pcall(function() return exports.pxd_progress:GetProfile(src) end)
    return ok and type(p) == 'table' and p or nil
end

--- Datos de un jugador. `full` añade lo que solo ve el staff.
local function playerRow(src, full)
    local pd = qbxPlayer(src)
    local row = { id = src, name = GetPlayerName(src) }
    if pd then
        local ci = pd.charinfo or {}
        row.charName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        row.citizenid = pd.citizenid
        row.proxId = pd.metadata and pd.metadata.pxd_id or nil
        if pd.job then
            row.job = pd.job.label
            row.grade = pd.job.grade and pd.job.grade.name or nil
            row.onduty = pd.job.onduty == true
        end
    end
    if not full then return row end
    row.ping = GetPlayerPing(src)
    row.bucket = GetPlayerRoutingBucket(src)
    row.license = license(src)
    row.discord = GetPlayerIdentifierByType(src, 'discord')
    row.frozen = frozen[src] == true
    if pd and pd.money then row.cash, row.bank = pd.money.cash, pd.money.bank end
    local pr = progress(src)
    if pr then row.level, row.playtime, row.playtimeToday = pr.level, pr.playtime, pr.playtimeToday end
    return row
end

local function allRows(full)
    local out = {}
    for _, id in ipairs(GetPlayers()) do out[#out + 1] = playerRow(tonumber(id), full) end
    return PXDAdmin.filterPlayers(out, '')
end

local function staffOnline()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if isStaff(id) then out[#out + 1] = id end
    end
    return out
end

local function findByLicense(lic)
    if not lic then return nil end
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if license(id) == lic then return id end
    end
    return nil
end

-- ── Guardado ────────────────────────────────────────────────────────────────

local function load()
    local raw = LoadResourceFile(RES, Config.reportsFile)
    local data = raw and raw ~= '' and json.decode(raw)
    if type(data) == 'table' and type(data.reports) == 'table' then
        reports, nextId = data.reports, tonumber(data.nextId) or 1
    end
    raw = LoadResourceFile(RES, Config.logFile)
    data = raw and raw ~= '' and json.decode(raw)
    if type(data) == 'table' then staffLog = data end
end

local function saveReports()
    PXDAdmin.prune(reports, Config.maxReports)
    SaveResourceFile(RES, Config.reportsFile, json.encode({ nextId = nextId, reports = reports }), -1)
end

local function log(staffSrc, action, target, detail)
    local entry = PXDAdmin.logEntry(GetPlayerName(staffSrc) or 'Consola', action, target, detail, now())
    PXDAdmin.pushCapped(staffLog, entry, Config.maxLog)
    SaveResourceFile(RES, Config.logFile, json.encode(staffLog), -1)
    print(('[pxd_admin] %s → %s %s %s'):format(entry.staff, action, tostring(target or ''), tostring(detail or '')))
end

-- Lo que ve el jugador de sus propios reportes (sin datos del staff ni licencias).
local function forPlayer(r)
    return {
        id = r.id, kind = r.kind, categoryLabel = r.categoryLabel, text = r.text, state = r.state,
        stateLabel = PXDAdmin.STATES[r.state], createdAt = r.createdAt, updatedAt = r.updatedAt,
        targetRef = r.targetRef, staff = r.staff, messages = r.messages, note = r.note,
    }
end

local function reportsForStaff()
    local out = {}
    for i = #reports, math.max(1, #reports - 199), -1 do
        local r = reports[i]
        local copy = forPlayer(r)
        copy.reporter = { name = r.reporter.name, charName = r.reporter.charName, online = findByLicense(r.reporter.license) }
        copy.target = r.target
        out[#out + 1] = copy
    end
    return out
end

local function findReport(id)
    id = tonumber(id)
    for _, r in ipairs(reports) do if r.id == id then return r end end
    return nil
end

local function broadcastReport(r, alert)
    local payload = reportsForStaff()
    for _, s in ipairs(staffOnline()) do
        TriggerClientEvent('pxd_admin:client:reports', s, payload)
        if alert then
            TriggerClientEvent('pxd_admin:client:staffAlert', s, { id = r.id, kind = r.kind, categoryLabel = r.categoryLabel,
                reporter = r.reporter.charName ~= '' and r.reporter.charName or r.reporter.name })
        end
    end
end

-- ── Jugadores: soporte y reportes ───────────────────────────────────────────

local function sendSupport(src)
    TriggerClientEvent('pxd_admin:client:support', src, {
        categories = Config.categories,
        reports = (function()
            local out = {}
            for _, r in ipairs(PXDAdmin.reportsOf(reports, license(src), 20)) do out[#out + 1] = forPlayer(r) end
            return out
        end)(),
        isStaff = isStaff(src),
        keyStaff = Config.keyStaff,
    })
end

RegisterNetEvent('pxd_admin:server:openSupport', function()
    sendSupport(source)
end)

RegisterNetEvent('pxd_admin:server:createReport', function(input)
    local src = source
    local lic = license(src)
    if not lic then return notify(src, 'Soporte', 'No se pudo identificar tu cuenta.', 'error') end
    local data, why = PXDAdmin.validateReport(input, Config.categories)
    if not data then return notify(src, 'Soporte', why, 'error') end
    if PXDAdmin.openCount(reports, lic) >= Config.maxOpenPerPlayer then
        return notify(src, 'Soporte', ('Ya tienes %d reportes abiertos. Espera a que el staff los atienda.'):format(Config.maxOpenPerPlayer), 'error')
    end
    if data.kind == 'player' then
        local t = PXDAdmin.resolveTarget(allRows(false), data.target)
        if not t then return notify(src, 'Soporte', 'No encontramos a ese jugador conectado. Revisa el ID o el PROX-ID.', 'error') end
        if t.id == src then return notify(src, 'Soporte', 'No puedes reportarte a ti mismo/a.', 'error') end
        data.targetInfo = { id = t.id, name = t.name, charName = t.charName, proxId = t.proxId, citizenid = t.citizenid }
    end
    local ok, wait = PXDAdmin.allow(reportLimiter, lic, now())
    if not ok then return notify(src, 'Soporte', ('Has enviado varios reportes seguidos. Prueba en %d s.'):format(wait), 'error') end

    local me = playerRow(src, false)
    local r = PXDAdmin.newReport(nextId, data, { license = lic, name = me.name, charName = me.charName or '', src = src }, now())
    nextId = nextId + 1
    reports[#reports + 1] = r
    saveReports()
    notify(src, 'Soporte', ('Reporte #%d enviado. El staff te responderá aquí.'):format(r.id), 'success')
    sendSupport(src)
    broadcastReport(r, true)
end)

RegisterNetEvent('pxd_admin:server:playerReply', function(id, text)
    local src = source
    local r = findReport(id)
    if not r or r.reporter.license ~= license(src) then return end
    if not PXDAdmin.allow(replyLimiter, license(src), now()) then
        return notify(src, 'Soporte', 'Vas muy rápido: espera un momento.', 'error')
    end
    local ok, why = PXDAdmin.reply(r, r.reporter.charName ~= '' and r.reporter.charName or r.reporter.name, text, now(), false)
    if not ok then return notify(src, 'Soporte', why, 'error') end
    saveReports()
    sendSupport(src)
    broadcastReport(r, false)
end)

-- ── Staff ───────────────────────────────────────────────────────────────────

local function sendStaff(src)
    TriggerClientEvent('pxd_admin:client:staff', src, {
        players = allRows(true),
        reports = reportsForStaff(),
        log = (function()
            local out = {}
            for i = #staffLog, math.max(1, #staffLog - 199), -1 do out[#out + 1] = staffLog[i] end
            return out
        end)(),
        me = src,
        canKick = PXDAdmin.can('kick', aceOf(src)),
        txAdminHint = Config.txAdminHint,
        spectating = spectating[src] ~= nil,
        onDuty = onDuty[src] == true,
        commands = PXDAdmin.COMMANDS,
    })
end

RegisterNetEvent('pxd_admin:server:openStaff', function()
    local src = source
    if not isStaff(src) then return notify(src, 'Staff', 'No tienes permiso de staff.', 'error') end
    sendStaff(src)
end)

local function coordsOf(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    return { x = c.x, y = c.y, z = c.z, bucket = GetPlayerRoutingBucket(src) }
end

local function teleport(src, pos)
    if pos.bucket ~= nil and GetPlayerRoutingBucket(src) ~= pos.bucket then SetPlayerRoutingBucket(src, pos.bucket) end
    SetEntityCoords(GetPlayerPed(src), pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
end

local ACTIONS = {}

ACTIONS['goto'] = function(src, target)
    if target == src then return false, 'Ya estás aquí.' end
    backPos[src] = coordsOf(src)
    local p = coordsOf(target)
    p.x = p.x + 1.0
    teleport(src, p)
    return true, 'Has ido con ' .. GetPlayerName(target) .. '.'
end

function ACTIONS.bring(src, target)
    if target == src then return false, 'No puedes traerte a ti mismo/a.' end
    backPos[target] = coordsOf(target)
    local p = coordsOf(src)
    p.x = p.x + 1.0
    teleport(target, p)
    notify(target, 'Staff', 'Un miembro del staff te ha llevado con él/ella.', 'staff')
    return true, 'Has traído a ' .. GetPlayerName(target) .. '.'
end

function ACTIONS.back(src, target)
    local pos = backPos[target]
    if not pos then return false, 'No hay una posición anterior guardada.' end
    backPos[target] = nil
    teleport(target, pos)
    if target ~= src then notify(target, 'Staff', 'Has vuelto a donde estabas.', 'staff') end
    return true, 'Devuelto a su posición anterior.'
end

function ACTIONS.freeze(src, target)
    local on = not frozen[target]
    frozen[target] = on or nil
    FreezeEntityPosition(GetPlayerPed(target), on)
    if target ~= src then notify(target, 'Staff', on and 'Un miembro del staff te ha congelado.' or 'Ya puedes moverte.', 'staff') end
    return true, on and 'Congelado.' or 'Descongelado.'
end

function ACTIONS.revive(src, target)
    if GetResourceState('qbx_medical') == 'started' then
        exports.qbx_medical:Revive(target)
    else
        TriggerClientEvent('pxd_admin:client:revive', target)
    end
    return true, 'Reanimado.'
end

function ACTIONS.heal(src, target)
    if GetResourceState('qbx_medical') == 'started' then
        exports.qbx_medical:Heal(target)
    else
        TriggerClientEvent('pxd_admin:client:heal', target)
    end
    return true, 'Curado.'
end

function ACTIONS.spectate(src, target)
    if target == src then return false, 'No puedes espectarte a ti mismo/a.' end
    if not spectating[src] then spectating[src] = { bucket = GetPlayerRoutingBucket(src) } end
    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(target))
    TriggerClientEvent('pxd_admin:client:spectate', src, target, coordsOf(target), GetPlayerName(target))
    return true, 'Espectando a ' .. GetPlayerName(target) .. '. Pulsa ' .. Config.keyStaff .. ' para salir.'
end

function ACTIONS.message(src, target, payload)
    local text = tostring(type(payload) == 'table' and payload.text or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 300)
    if #text < 1 then return false, 'Escribe un mensaje.' end
    notify(target, 'Mensaje del staff', text, 'staff')
    return true, 'Mensaje enviado.', text
end

function ACTIONS.kick(src, target, payload)
    if target == src then return false, 'No puedes expulsarte a ti mismo/a.' end
    local reason = tostring(type(payload) == 'table' and payload.reason or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 200)
    if #reason < 3 then return false, 'Indica el motivo.' end
    local name = GetPlayerName(target)
    DropPlayer(target, 'Expulsado/a por el staff de Próxima RP: ' .. reason)
    return true, name .. ' ha sido expulsado/a.', reason
end

function ACTIONS.duty(src)
    local on = not onDuty[src]
    onDuty[src] = on or nil
    Player(src).state:set('pxd_staff', on or nil, true)
    TriggerClientEvent('pxd_admin:client:duty', src, on)
    return true, on and 'Estás de servicio: atuendo STAFF, invencible y comandos activos.' or 'Has salido de servicio.'
end

function ACTIONS.needs(src, target)
    if GetResourceState('qbx_core') ~= 'started' then return false, 'Hace falta qbx_core.' end
    for key, value in pairs({ hunger = 100, thirst = 100, stress = 0 }) do
        pcall(function() exports.qbx_core:SetMetadata(target, key, value) end)
    end
    -- Mismos avisos que usa qbx_medical / qbx_hud para refrescar el HUD.
    TriggerClientEvent('hud:client:UpdateNeeds', target, 100, 100)
    TriggerClientEvent('hud:client:UpdateStress', target, 0)
    return true, 'Necesidades llenas.'
end

function ACTIONS.wounds(src, target)
    local st = Player(target).state
    local w = PXDAdmin.woundsReport(function(key) return st[key] end)
    TriggerClientEvent('pxd_admin:client:wounds', src, { id = target, name = GetPlayerName(target), report = w })
    local n = #w.parts
    return true, n == 0 and ('Sin heridas · %s'):format(w.state) or ('%d zona(s) herida(s) · %s'):format(n, w.state)
end

for _, tool in ipairs({ 'noclip', 'invisible', 'tpm', 'repair', 'dv' }) do
    ACTIONS[tool] = function(src)
        TriggerClientEvent('pxd_admin:client:tool', src, tool)
        return true, nil
    end
end

function ACTIONS.car(src, _, payload)
    local model = PXDAdmin.validModel(type(payload) == 'table' and payload.model or payload)
    if not model then return false, 'Modelo no válido.' end
    TriggerClientEvent('pxd_admin:client:tool', src, 'car', model)
    return true, nil, model
end

function ACTIONS.announce(src, _, payload)
    local text = tostring(type(payload) == 'table' and payload.text or payload or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 240)
    if #text < 3 then return false, 'Escribe el anuncio.' end
    TriggerClientEvent('pxd_admin:client:announce', -1, { text = text })
    return true, 'Anuncio enviado.', text
end

--- Ejecuta una acción de staff con todas las comprobaciones (panel y comandos).
local function runAction(src, action, target, payload)
    if type(action) ~= 'string' or not ACTIONS[action] or not PXDAdmin.ACTIONS[action] then return end
    if not PXDAdmin.can(action, aceOf(src)) then return notify(src, 'Staff', 'No tienes permiso para esa acción.', 'error') end
    if PXDAdmin.needsDuty(action) and not onDuty[src] then
        return notify(src, 'Staff', 'Activa el modo servicio con /duty para usar esto.', 'error')
    end
    local kind = PXDAdmin.ACTIONS[action].target
    if kind == 'self' or kind == 'none' then target = src end
    target = online(target)
    if not target then return notify(src, 'Staff', 'Ese jugador ya no está conectado.', 'error') end
    local ok, msg, detail = ACTIONS[action](src, target, payload)
    if msg then notify(src, 'Staff', msg, ok and 'success' or 'error') end
    if ok then
        log(src, action, kind == 'self' and nil or ('%s (#%d)'):format(GetPlayerName(target) or '?', target), detail)
    end
    return ok
end

RegisterNetEvent('pxd_admin:server:action', function(action, target, payload)
    local src = source
    if runAction(src, action, target, payload) and action ~= 'spectate' then sendStaff(src) end
end)

-- Vehículo creado por el cliente con /coche: le damos las llaves (qbx_vehiclekeys).
RegisterNetEvent('pxd_admin:server:carSpawned', function(netId)
    local src = source
    if not onDuty[src] or not PXDAdmin.can('car', aceOf(src)) then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 15.0 then return end
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    end
end)

-- /dv: el cliente elige el vehículo; el servidor comprueba distancia y lo borra.
RegisterNetEvent('pxd_admin:server:deleteVehicle', function(netId)
    local src = source
    if not onDuty[src] or not PXDAdmin.can('dv', aceOf(src)) then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return notify(src, 'Staff', 'No hay vehículo.', 'error') end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 10.0 then
        return notify(src, 'Staff', 'El vehículo está demasiado lejos.', 'error')
    end
    DeleteEntity(veh)
    notify(src, 'Staff', 'Vehículo borrado.', 'success')
end)

-- Comandos de chat: misma validación que el panel.
for _, c in ipairs(PXDAdmin.COMMANDS) do
    RegisterCommand(c.name, function(src, args)
        if src == 0 then return print('[pxd_admin] Este comando se usa dentro del juego.') end
        if not isStaff(src) then return end
        local payload
        if c.action == 'car' then payload = { model = args[1] }
        elseif c.action == 'announce' then payload = { text = table.concat(args, ' ') } end
        local target, why = PXDAdmin.commandTarget(c.action, args[1], src)
        if not target then return notify(src, 'Staff', why, 'error') end
        runAction(src, c.action, target, payload)
    end, false)
end

RegisterNetEvent('pxd_admin:server:spectateEnd', function()
    local src = source
    local s = spectating[src]
    if not s then return end
    spectating[src] = nil
    SetPlayerRoutingBucket(src, s.bucket)
end)

RegisterNetEvent('pxd_admin:server:refreshStaff', function()
    local src = source
    if isStaff(src) then sendStaff(src) end
end)

RegisterNetEvent('pxd_admin:server:reportAction', function(action, id, text)
    local src = source
    if not isStaff(src) then return end
    local r = findReport(id)
    if not r or not PXDAdmin.canTransition(r, action) then return notify(src, 'Staff', 'Ese reporte ya no admite esa acción.', 'error') end
    local staffName = GetPlayerName(src)
    local reporter = findByLicense(r.reporter.license)
    if action == 'claim' then
        PXDAdmin.claim(r, staffName, now())
        if reporter then notify(reporter, 'Soporte', ('%s está atendiendo tu reporte #%d.'):format(staffName, r.id), 'staff') end
    elseif action == 'reply' then
        local ok, why = PXDAdmin.reply(r, staffName, text, now(), true)
        if not ok then return notify(src, 'Staff', why, 'error') end
        if reporter then notify(reporter, ('Respuesta a tu reporte #%d'):format(r.id), tostring(text):sub(1, 300), 'staff') end
    elseif action == 'close' then
        PXDAdmin.close(r, staffName, text, now())
        if reporter then notify(reporter, 'Soporte', ('Tu reporte #%d se ha cerrado. ¡Gracias!'):format(r.id), 'success') end
    elseif action == 'goto' then
        if not reporter then return notify(src, 'Staff', 'Quien reportó ya no está conectado.', 'error') end
        if not runAction(src, 'goto', reporter) then return end
    end
    log(src, 'report:' .. action, ('#%d'):format(r.id), action == 'reply' and text or nil)
    saveReports()
    if reporter then sendSupport(reporter) end
    broadcastReport(r, false)
    sendStaff(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    backPos[src], frozen[src], spectating[src], onDuty[src] = nil, nil, nil, nil
end)

load()
PXDAdmin.server = { reports = function() return reports end, log = function() return staffLog end, onDuty = onDuty }   -- para pruebas
