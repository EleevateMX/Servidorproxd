-- pxd_admin (servidor): reportes, centro de administración y acciones. Todo se valida aquí:
-- permiso (ACE pxd.admin.<permiso>, ver shared/admin.lua), tipos, objetivo y motivo.
-- Cada acción queda en el registro propio y en la auditoría común (pxd_audit). docs/37.
local RES = GetCurrentResourceName()

local reports, staffLog = {}, {}
local nextId = 1
local backPos = {}      -- [src] = { x, y, z, bucket } antes de ir/traer
local frozen = {}       -- [src] = true
local spectating = {}   -- [staffSrc] = { bucket = n }
local onDuty = {}       -- [staffSrc] = true (modo servicio)
local noclipOn = {}     -- [staffSrc] = true (autorizado por el servidor)

local reportLimiter = PXDAdmin.newLimiter(Config.reportsPerWindow, Config.reportWindowSec)
local replyLimiter = PXDAdmin.newLimiter(Config.repliesPerMinute, 60)
local queryLimiter = PXDAdmin.newLimiter(20, 10)

-- ── Utilidades ──────────────────────────────────────────────────────────────

local function now() return os.time() end
local function started(res) return GetResourceState(res) == 'started' end

local function online(src)
    src = tonumber(src)
    return src and src > 0 and GetPlayerName(src) ~= nil and src or nil
end

local function aceOf(src)
    return function(ace) return IsPlayerAceAllowed(src, ace) end
end

local function has(src, perm)
    if src == 0 then return true end
    return PXDAdmin.has(perm, aceOf(src))
end

local function isStaff(src) return has(src, 'panel') end

local function license(src)
    return GetPlayerIdentifierByType(src, 'license')
end

local function staffName(src)
    if src == 0 then return 'Consola' end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

local function notify(src, title, text, kind)
    if src == 0 then return print(('[pxd_admin] %s: %s'):format(title, text)) end
    TriggerClientEvent('pxd_admin:client:notify', src, { title = title, text = text, kind = kind or 'info' })
end

local function qbxObject(src)
    if not started('qbx_core') then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function qbxPlayer(src)
    local p = qbxObject(src)
    return p and p.PlayerData or nil
end

local function progress(src)
    if not started('pxd_progress') then return nil end
    local ok, p = pcall(function() return exports.pxd_progress:GetProfile(src) end)
    return ok and type(p) == 'table' and p or nil
end

local function publicId(src, pd)
    if started('pxd_interact') then
        local ok, id = pcall(function() return exports.pxd_interact:GetPublicId(src) end)
        if ok and id then return id end
    end
    return pd and pd.metadata and pd.metadata.pxd_id or nil
end

local function db()
    return MySQL ~= nil and started('oxmysql')
end

--- Datos de un jugador. `viewer` = mapa de permisos de quien mira (nil = vista mínima).
local function playerRow(src, viewer)
    local pd = qbxPlayer(src)
    local row = { id = src, name = GetPlayerName(src) }
    if pd then
        local ci = pd.charinfo or {}
        row.charName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        row.citizenid = pd.citizenid
        if pd.job then
            row.job = pd.job.label
            row.grade = pd.job.grade and pd.job.grade.name or nil
            row.onduty = pd.job.onduty == true
        end
    end
    row.proxId = publicId(src, pd)
    if not viewer then return row end
    row.ping = GetPlayerPing(src)
    row.bucket = GetPlayerRoutingBucket(src)
    row.frozen = frozen[src] == true
    row.staff = onDuty[src] == true
    if viewer['players.identity'] then
        row.license = license(src)
        row.discord = GetPlayerIdentifierByType(src, 'discord')
        row.fivem = GetPlayerIdentifierByType(src, 'fivem')
        if pd and pd.money then row.cash, row.bank = pd.money.cash, pd.money.bank end
        local pr = progress(src)
        if pr then row.level, row.playtime, row.playtimeToday = pr.level, pr.playtime, pr.playtimeToday end
    end
    if viewer['players.ip'] then row.ip = GetPlayerIdentifierByType(src, 'ip') end
    return row
end

local function allRows(viewer)
    local out = {}
    for _, id in ipairs(GetPlayers()) do out[#out + 1] = playerRow(tonumber(id), viewer) end
    return PXDAdmin.filterPlayers(out, '')
end

local function staffWith(perm)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if has(id, 'panel') and has(id, perm) then out[#out + 1] = id end
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

-- ── Guardado y auditoría ────────────────────────────────────────────────────

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

--- Registra una acción: responsable, objetivo, fecha y motivo. `target` = id de jugador o texto.
local function audit(src, action, target, info)
    info = info or {}
    local targetKey, targetLabel
    if type(target) == 'number' then
        targetKey = license(target) or ('id:' .. target)
        targetLabel = ('%s (#%d)'):format(GetPlayerName(target) or '?', target)
    elseif type(target) == 'table' then
        targetKey, targetLabel = target.key, target.label
    elseif target ~= nil then
        targetKey, targetLabel = tostring(target), tostring(target)
    end
    local entry = PXDAdmin.logEntry(staffName(src), action, targetLabel, info.detail, now())
    entry.reason = info.reason
    entry.targetKey = targetKey
    PXDAdmin.pushCapped(staffLog, entry, Config.maxLog)
    SaveResourceFile(RES, Config.logFile, json.encode(staffLog), -1)
    print(('[pxd_admin] %s → %s %s %s'):format(entry.staff, action, tostring(targetLabel or ''),
        info.reason and ('· motivo: ' .. info.reason) or tostring(info.detail or '')))
    if started('pxd_audit') then
        local ok, err = pcall(function()
            return exports.pxd_audit:Log({
                category = 'admin', action = action,
                actor = src == 0 and 'console' or (license(src) or ('id:' .. src)),
                target = targetKey,
                data = { staff = staffName(src), target_name = targetLabel, reason = info.reason,
                         detail = info.detail and tostring(info.detail):sub(1, 300) or nil },
            })
        end)
        if not ok then print('[pxd_admin] ^3No se pudo escribir en pxd_audit: ' .. tostring(err) .. '^7') end
    end
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
    for _, s in ipairs(staffWith('reports')) do
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
        local t = PXDAdmin.resolveTarget(allRows(nil), data.target)
        if not t then return notify(src, 'Soporte', 'No encontramos a ese jugador conectado. Revisa el ID o el PROX-ID.', 'error') end
        if t.id == src then return notify(src, 'Soporte', 'No puedes reportarte a ti mismo/a.', 'error') end
        data.targetInfo = { id = t.id, name = t.name, charName = t.charName, proxId = t.proxId, citizenid = t.citizenid }
    end
    local ok, wait = PXDAdmin.allow(reportLimiter, lic, now())
    if not ok then return notify(src, 'Soporte', ('Has enviado varios reportes seguidos. Prueba en %d s.'):format(wait), 'error') end

    local me = playerRow(src, nil)
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

-- ── Panel de administración ─────────────────────────────────────────────────

local function logFor(src)
    if not has(src, 'audit') then return {} end
    local out = {}
    for i = #staffLog, math.max(1, #staffLog - 199), -1 do out[#out + 1] = staffLog[i] end
    return out
end

local function sendStaff(src)
    local perms = PXDAdmin.permMap(aceOf(src))
    TriggerClientEvent('pxd_admin:client:staff', src, {
        players = allRows(perms),
        reports = perms.reports and reportsForStaff() or {},
        log = logFor(src),
        me = src,
        perms = perms,
        role = PXDAdmin.roleLabel(aceOf(src)),
        banHint = Config.banHint,
        spectating = spectating[src] ~= nil,
        onDuty = onDuty[src] == true,
        noclip = noclipOn[src] == true,
        requireDuty = Config.requireDuty == true,
        limits = { maxMoney = Config.maxMoneyCorrection, maxBanHours = Config.maxBanHours },
        commands = PXDAdmin.COMMANDS,
        qbxMenu = started('qbx_adminmenu'),
        economy = started('pxd_economy'),
    })
end

local NO_ACCESS = 'No tienes permisos de staff (falta pxd.admin.panel). Pide a un administrador que te añada a un rol: '
    .. 'group.support, group.mod, group.admin, group.superadmin o group.dev.'

local function openStaff(src)
    if not isStaff(src) then return notify(src, 'Administración', NO_ACCESS, 'error') end
    sendStaff(src)
end

RegisterNetEvent('pxd_admin:server:openStaff', function() openStaff(source) end)

RegisterCommand('admin', function(src)
    if src == 0 then return print('[pxd_admin] /admin se usa dentro del juego. Para revisar permisos: pxd_admin_permisos <id>') end
    openStaff(src)
end, false)

-- Diagnóstico desde la consola: qué rol y permisos tiene un jugador conectado.
RegisterCommand('pxd_admin_permisos', function(src, args)
    if src ~= 0 then return end
    local id = online(args[1])
    if not id then return print('[pxd_admin] Uso: pxd_admin_permisos <id de jugador conectado>') end
    local perms, list = PXDAdmin.permMap(aceOf(id)), {}
    for p, ok in pairs(perms) do if ok then list[#list + 1] = p end end
    table.sort(list)
    print(('[pxd_admin] %s (#%d) · rol: %s · licencia: %s'):format(GetPlayerName(id), id,
        tostring(PXDAdmin.roleLabel(aceOf(id)) or 'ninguno'), tostring(license(id))))
    print('[pxd_admin] permisos: ' .. (#list > 0 and table.concat(list, ', ') or 'ninguno (no ve el panel)'))
end, true)

local function coordsOf(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    return { x = c.x, y = c.y, z = c.z, bucket = GetPlayerRoutingBucket(src) }
end

-- Cambiar de bucket con la función de Qbox (mantiene su estado `instance`); sin Qbox, el native.
local function setBucket(src, bucket)
    if started('qbx_core') then
        local ok = pcall(function() exports.qbx_core:SetPlayerBucket(src, bucket) end)
        if ok then return end
    end
    SetPlayerRoutingBucket(src, bucket)
end

-- Si está en una partida de pxd_gamemodes, sacarlo antes (si no, el lobby lo sigue contando).
local function pullFromMatch(src, reason)
    if not started('pxd_gamemodes') then return false end
    local ok, left = pcall(function() return exports.pxd_gamemodes:LeavePlayer(src, reason) end)
    return ok and left == true
end

local function teleport(src, pos)
    if pos.bucket ~= nil and GetPlayerRoutingBucket(src) ~= pos.bucket then setBucket(src, pos.bucket) end
    SetEntityCoords(GetPlayerPed(src), pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
end

local function tool(src, name, arg)
    TriggerClientEvent('pxd_admin:client:tool', src, name, arg)
end

local function text(v, max)
    return (tostring(v or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, max))
end

-- Cada acción devuelve: ok, mensaje para quien la hace, detalle para el registro, objetivo del registro.
local ACTIONS = {}

ACTIONS['goto'] = function(src, target)
    if target == src then return false, 'Ya estás aquí.' end
    pullFromMatch(src)
    backPos[src] = coordsOf(src)
    local p = coordsOf(target)
    p.x = p.x + 1.0
    teleport(src, p)
    return true, 'Has ido con ' .. GetPlayerName(target) .. '.'
end

function ACTIONS.bring(src, target)
    if target == src then return false, 'No puedes traerte a ti mismo/a.' end
    pullFromMatch(target, 'Un miembro del staff te ha sacado de la partida.')
    pullFromMatch(src)
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
    Player(target).state:set('pxd_frozen', on or nil, true)
    if target ~= src then notify(target, 'Staff', on and 'Un miembro del staff te ha congelado.' or 'Ya puedes moverte.', 'staff') end
    return true, on and 'Congelado.' or 'Descongelado.', on and 'congelar' or 'descongelar'
end

function ACTIONS.revive(src, target)
    if started('qbx_medical') then
        exports.qbx_medical:Revive(target)
    else
        TriggerClientEvent('pxd_admin:client:revive', target)
    end
    return true, 'Reanimado.'
end

function ACTIONS.heal(src, target)
    if started('qbx_medical') then
        exports.qbx_medical:Heal(target)
    else
        TriggerClientEvent('pxd_admin:client:heal', target)
    end
    return true, 'Curado.'
end

function ACTIONS.spectate(src, target)
    if target == src then return false, 'No puedes espectarte a ti mismo/a.' end
    if not spectating[src] then
        pullFromMatch(src)
        spectating[src] = { bucket = GetPlayerRoutingBucket(src) }
    end
    setBucket(src, GetPlayerRoutingBucket(target))
    TriggerClientEvent('pxd_admin:client:spectate', src, target, coordsOf(target), GetPlayerName(target))
    return true, 'Espectando a ' .. GetPlayerName(target) .. '. Pulsa ' .. Config.keyStaff .. ' para salir.'
end

function ACTIONS.message(src, target, payload)
    local msg = text(payload.text, 300)
    if #msg < 1 then return false, 'Escribe un mensaje.' end
    notify(target, 'Mensaje del staff', msg, 'staff')
    return true, 'Mensaje enviado.', msg
end

function ACTIONS.kick(src, target, payload)
    if target == src then return false, 'No puedes expulsarte a ti mismo/a.' end
    local name = GetPlayerName(target)
    DropPlayer(target, 'Expulsado/a por el staff de Próxima RP: ' .. payload.reason)
    return true, name .. ' ha sido expulsado/a.'
end

function ACTIONS.warn(src, target, payload)
    if target == src then return false, 'No puedes advertirte a ti mismo/a.' end
    TriggerClientEvent('pxd_admin:client:warning', target, { reason = payload.reason, by = staffName(src) })
    return true, 'Advertencia registrada y mostrada al jugador.'
end

function ACTIONS.ban(src, target, payload)
    if target == src then return false, 'No puedes banearte a ti mismo/a.' end
    if not db() then return false, 'La base de datos no está disponible: no se ha baneado.' end
    local expire, why = PXDAdmin.banExpire(payload.hours, now(), Config.maxBanHours)
    if not expire then return false, why end
    local name, lic = GetPlayerName(target), license(target)
    if not lic then return false, 'No se pudo leer la licencia del jugador.' end
    -- Misma tabla y columnas que qbx_core (storage.insertBan) y qbx_adminmenu.
    local ok, err = pcall(function()
        return MySQL.insert.await('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            name, lic, GetPlayerIdentifierByType(target, 'discord'), GetPlayerIdentifierByType(target, 'ip'),
            payload.reason, expire, staffName(src),
        })
    end)
    if not ok then
        print('[pxd_admin] ^1No se pudo guardar el baneo: ' .. tostring(err) .. '^7')
        return false, 'No se pudo guardar el baneo (revisa la consola). No se ha expulsado a nadie.'
    end
    local untilText = expire == PXDAdmin.PERMANENT and 'permanente' or ('hasta el ' .. os.date('%d/%m/%Y %H:%M', expire))
    DropPlayer(target, ('Baneado/a de Próxima RP (%s): %s'):format(untilText, payload.reason))
    return true, ('%s baneado/a (%s).'):format(name, untilText), untilText
end

-- Levantar un baneo: se adelanta su fin (no se borra la fila; queda constancia).
function ACTIONS.unban(src, _, payload)
    if not db() then return false, 'La base de datos no está disponible.' end
    local id = tonumber(payload.banId)
    if not id or id ~= math.floor(id) then return false, 'Baneo no válido.' end
    local ok, changed = pcall(function()
        return MySQL.update.await('UPDATE bans SET expire = ? WHERE id = ? AND expire > ?', { now() - 1, id, now() })
    end)
    if not ok then return false, 'No se pudo actualizar el baneo.' end
    if (tonumber(changed) or 0) < 1 then return false, 'Ese baneo no existe o ya terminó.' end
    return true, ('Baneo #%d levantado.'):format(id), nil, ('ban:%d'):format(id)
end

function ACTIONS.duty(src)
    local on = not onDuty[src]
    onDuty[src] = on or nil
    Player(src).state:set('pxd_staff', on or nil, true)
    TriggerClientEvent('pxd_admin:client:duty', src, on)
    return true, on and 'Estás de servicio: atuendo STAFF, etiqueta e invencible.' or 'Has salido de servicio.'
end

function ACTIONS.needs(src, target)
    if not started('qbx_core') then return false, 'Hace falta qbx_core.' end
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

function ACTIONS.noclip(src)
    local on = not noclipOn[src]
    noclipOn[src] = on or nil
    tool(src, 'noclip', { on = on, invisible = Config.noclip.invisible == true,
        speeds = Config.noclip.speeds, speed = Config.noclip.defaultSpeed })
    return true, nil, on and 'activado' or 'desactivado'
end

for _, name in ipairs({ 'invisible', 'tpm', 'repair', 'clean', 'dv', 'vehinfo', 'coords', 'devtools', 'props', 'qbxmenu' }) do
    ACTIONS[name] = function(src)
        tool(src, name)
        return true, nil
    end
end

function ACTIONS.car(src, _, payload)
    local model = PXDAdmin.validModel(payload.model)
    if not model then return false, 'Modelo no válido.' end
    tool(src, 'car', model)
    return true, nil, model
end

function ACTIONS.announce(src, _, payload)
    local msg = text(payload.text, 240)
    if #msg < 3 then return false, 'Escribe el anuncio.' end
    TriggerClientEvent('pxd_admin:client:announce', -1, { text = msg })
    TriggerEvent('pxd_admin:server:announced', msg)   -- pxd_chat lo pinta en el chat
    return true, 'Anuncio enviado.', msg
end

function ACTIONS.money(src, target, payload)
    local m, why = PXDAdmin.validMoney(payload, Config.maxMoneyCorrection)
    if not m then return false, why end
    local p = qbxObject(target)
    if not p then return false, 'Ese jugador no tiene personaje cargado.' end
    local reason = 'pxd-admin: ' .. payload.reason
    local before = tonumber(p.Functions.GetMoney(m.account)) or 0
    local ok
    if m.amount > 0 then
        ok = p.Functions.AddMoney(m.account, m.amount, reason)
    else
        if before < -m.amount then return false, ('Solo tiene $%d: el saldo no puede quedar en negativo.'):format(before) end
        ok = p.Functions.RemoveMoney(m.account, -m.amount, reason)
    end
    if not ok then return false, 'Qbox rechazó el movimiento: no se ha cambiado nada.' end
    local label = m.account == 'cash' and 'efectivo' or 'banco'
    local after = tonumber(p.Functions.GetMoney(m.account)) or 0
    if target ~= src then
        notify(target, 'Staff', ('Corrección de %s: %s$%d.'):format(label, m.amount > 0 and '+' or '−', math.abs(m.amount)), 'staff')
    end
    return true, ('%s: %s$%d (antes $%d, ahora $%d).'):format(label, m.amount > 0 and '+' or '−', math.abs(m.amount), before, after),
        ('%s %+d (%d → %d)'):format(m.account, m.amount, before, after)
end

-- Titularidad de un vehículo (qbx_vehicles): solo superadministración.
function ACTIONS.vehowner(src, _, payload)
    if not started('qbx_vehicles') then return false, 'qbx_vehicles no está en marcha.' end
    local plate = PXDAdmin.validPlate(payload.plate)
    local cid = PXDAdmin.validCitizenId(payload.citizenid)
    if not plate then return false, 'Matrícula no válida.' end
    if not cid then return false, 'Citizen ID no válido.' end
    local vehicleId = exports.qbx_vehicles:GetVehicleIdByPlate(plate)
    if not vehicleId then return false, ('No hay ningún vehículo con matrícula %s.'):format(plate) end
    if not db() then return false, 'La base de datos no está disponible.' end
    local exists = MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ?', { cid })
    if not exists then return false, ('No existe el personaje %s.'):format(cid) end
    local before = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    local ok, err = exports.qbx_vehicles:SetPlayerVehicleOwner(vehicleId, cid)
    if not ok then return false, 'qbx_vehicles rechazó el cambio: ' .. tostring(err and err.message or 'sin motivo') end
    return true, ('El vehículo %s pasa a %s.'):format(plate, cid),
        ('%s: %s → %s'):format(plate, tostring(before and before.citizenid or '¿?'), cid), 'vehicle:' .. plate
end

--- Ejecuta una acción de staff con todas las comprobaciones (panel y comandos).
local function runAction(src, action, target, payload)
    if type(action) ~= 'string' or not ACTIONS[action] or not PXDAdmin.ACTIONS[action] then return end
    if not PXDAdmin.can(action, aceOf(src)) then return notify(src, 'Administración', 'No tienes permiso para esa acción.', 'error') end
    if PXDAdmin.needsDuty(action, Config.requireDuty) and not onDuty[src] then
        return notify(src, 'Administración', 'Activa el modo servicio con /duty para usar esto.', 'error')
    end
    local def = PXDAdmin.ACTIONS[action]
    payload = type(payload) == 'table' and payload or {}
    if def.reason then
        local reason, why = PXDAdmin.validReason(payload.reason)
        if not reason then return notify(src, 'Administración', why, 'error') end
        payload.reason = reason
    end
    if def.target == 'self' then
        target = src
    elseif def.target == 'none' then
        target = nil
    else
        target = online(target)
        if not target then return notify(src, 'Administración', 'Ese jugador ya no está conectado.', 'error') end
    end
    -- Se anota el objetivo antes de actuar: tras expulsar o banear ya no hay identificadores.
    local snap = (target and def.target ~= 'self') and {
        key = license(target) or ('id:' .. target), label = ('%s (#%d)'):format(GetPlayerName(target) or '?', target),
    } or nil
    local ok, msg, detail, auditTarget = ACTIONS[action](src, target, payload)
    if msg then notify(src, 'Administración', msg, ok and 'success' or 'error') end
    if ok then
        local t = auditTarget or snap
        audit(src, action, t, { reason = payload.reason, detail = detail })
    end
    return ok
end

RegisterNetEvent('pxd_admin:server:action', function(action, target, payload)
    local src = source
    if runAction(src, action, target, payload) and action ~= 'spectate' and isStaff(src) then sendStaff(src) end
end)

-- El cliente avisa de que el noclip terminó por su cuenta (muerte, recurso parado…).
RegisterNetEvent('pxd_admin:server:noclipOff', function()
    local src = source
    if not noclipOn[src] then return end
    noclipOn[src] = nil
    audit(src, 'noclip', nil, { detail = 'desactivado (cliente)' })
end)

-- Vehículo creado por el cliente: le damos las llaves (qbx_vehiclekeys).
RegisterNetEvent('pxd_admin:server:carSpawned', function(netId)
    local src = source
    if not PXDAdmin.can('car', aceOf(src)) then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 15.0 then return end
    if started('qbx_vehiclekeys') then
        pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    end
end)

local function nearVehicle(src, netId, maxDist)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil, 'No hay vehículo.' end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > maxDist then return nil, 'El vehículo está demasiado lejos.' end
    return veh
end

-- Borrar: el cliente elige el vehículo; el servidor comprueba permiso y distancia y lo borra.
RegisterNetEvent('pxd_admin:server:deleteVehicle', function(netId)
    local src = source
    if not PXDAdmin.can('dv', aceOf(src)) then return end
    if PXDAdmin.needsDuty('dv', Config.requireDuty) and not onDuty[src] then return end
    local veh, why = nearVehicle(src, netId, 10.0)
    if not veh then return notify(src, 'Administración', why, 'error') end
    local plate = text(GetVehicleNumberPlateText(veh), 8)
    DeleteEntity(veh)
    notify(src, 'Administración', 'Vehículo borrado.', 'success')
    audit(src, 'dv', plate ~= '' and ('vehicle:' .. plate) or nil, {})
end)

local function vehicleOwner(plate)
    if not plate or not started('qbx_vehicles') then return nil end
    local ok, id = pcall(function() return exports.qbx_vehicles:GetVehicleIdByPlate(plate) end)
    if not ok or not id then return nil end
    local ok2, v = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(id) end)
    return ok2 and v and { id = id, citizenid = v.citizenid, garage = v.garage, state = v.state } or { id = id }
end

local function result(src, kind, data)
    TriggerClientEvent('pxd_admin:client:result', src, kind, data)
end

RegisterNetEvent('pxd_admin:server:vehicleInfo', function(netId)
    local src = source
    if not PXDAdmin.can('vehinfo', aceOf(src)) then return end
    local veh, why = nearVehicle(src, netId, 10.0)
    if not veh then return notify(src, 'Administración', why, 'error') end
    local plate = text(GetVehicleNumberPlateText(veh), 8)
    result(src, 'vehicle', { plate = plate, model = GetEntityModel(veh), netId = tonumber(netId),
        owner = vehicleOwner(plate), canOwner = has(src, 'vehicles.owner') })
end)

-- ── Consultas del panel (solo lectura) ──────────────────────────────────────

local function auditQuery(filter)
    if started('pxd_audit') then
        local ok, rows = pcall(function() return exports.pxd_audit:Query(filter) end)
        if ok and type(rows) == 'table' then
            local out = {}
            for _, r in ipairs(rows) do
                local d = type(r.data) == 'table' and r.data or {}
                out[#out + 1] = { at = tonumber(r.created_at), staff = d.staff or r.actor, action = r.action,
                    target = d.target_name or r.target, reason = d.reason, detail = d.detail }
            end
            return out
        end
    end
    -- Sin pxd_audit: el registro propio.
    local out = {}
    for i = #staffLog, 1, -1 do
        local e = staffLog[i]
        if (not filter.action or e.action == filter.action) and (not filter.target or e.targetKey == filter.target) then
            out[#out + 1] = e
            if #out >= (filter.limit or 100) then break end
        end
    end
    return out
end

local QUERY = {}

function QUERY.detail(src, args)
    local t = online(args.target)
    if not t then return nil, 'Ese jugador ya no está conectado.' end
    return playerRow(t, PXDAdmin.permMap(aceOf(src)))
end

function QUERY.history(src, args)
    local t = online(args.target)
    if not t then return nil, 'Ese jugador ya no está conectado.' end
    local lic = license(t)
    local out = { target = t }
    if has(src, 'reports') then
        out.reports = {}
        for _, r in ipairs(PXDAdmin.reportsOf(reports, lic, 20)) do out.reports[#out.reports + 1] = forPlayer(r) end
        out.reported = {}
        for i = #reports, 1, -1 do
            local r = reports[i]
            if r.target and r.target.id == t then out.reported[#out.reported + 1] = forPlayer(r) end
            if #out.reported >= 20 then break end
        end
    end
    if has(src, 'players.warn') and lic then out.warnings = auditQuery({ category = 'admin', action = 'warn', target = lic, limit = 50 }) end
    if has(src, 'players.identity') and lic then out.actions = auditQuery({ category = 'admin', target = lic, limit = 30 }) end
    if has(src, 'players.ban') and lic and db() then
        local ok, rows = pcall(function()
            return MySQL.query.await('SELECT id, reason, expire, bannedby FROM bans WHERE license = ? ORDER BY id DESC LIMIT 20', { lic })
        end)
        out.bans = ok and rows or {}
    end
    return out
end

function QUERY.buckets()
    local by, list = {}, {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local b = GetPlayerRoutingBucket(id)
        if not by[b] then by[b] = { bucket = b, players = {} }; list[#list + 1] = by[b] end
        by[b].players[#by[b].players + 1] = { id = id, name = GetPlayerName(id) }
    end
    table.sort(list, function(a, b) return a.bucket < b.bucket end)
    return list
end

function QUERY.bans()
    if not db() then return nil, 'La base de datos no está disponible.' end
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT id, name, license, reason, expire, bannedby FROM bans WHERE expire > ? ORDER BY id DESC LIMIT 100', { now() })
    end)
    if not ok then return nil, 'No se pudo leer la tabla de baneos.' end
    return { rows = rows or {}, permanent = PXDAdmin.PERMANENT }
end

function QUERY.audit(_, args)
    local action = args.action and PXDAdmin.ACTIONS[args.action] and args.action or nil
    return auditQuery({ category = 'admin', limit = 200, action = action })
end

function QUERY.economy(_, args)
    local out = {}
    if started('pxd_economy') then
        local ok, s = pcall(function() return exports.pxd_economy:GetFlowSummary(tonumber(args.hours) or 24) end)
        if ok then out.summary = s end
    end
    if db() then
        local ok, rows = pcall(function()
            return MySQL.query.await('SELECT id, job_label, issuer_name, client_name, concept, amount, paid, status, issued_at FROM pxd_invoices ORDER BY id DESC LIMIT 30', {})
        end)
        if ok then out.invoices = rows end
    end
    return out
end

local function citizenOf(args)
    local t = online(args.target)
    local pd = t and qbxPlayer(t)
    return pd and pd.citizenid or PXDAdmin.validCitizenId(args.citizenid)
end

function QUERY.fines(_, args)
    local cid = citizenOf(args)
    if not cid then return nil, 'Indica un jugador o un Citizen ID.' end
    if not started('pxd_justice') then return nil, 'pxd_justice no está en marcha.' end
    local ok, v = pcall(function() return exports.pxd_justice:ListFines(cid, { withNotes = true, limit = 25 }) end)
    if not ok then return nil, 'No se pudieron leer las multas.' end
    return { citizenid = cid, fines = v }
end

function QUERY.invoices(_, args)
    local cid = citizenOf(args)
    if not cid then return nil, 'Indica un jugador o un Citizen ID.' end
    if not db() then return nil, 'La base de datos no está disponible.' end
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT id, job_label, issuer_name, concept, amount, paid, status, issued_at FROM pxd_invoices WHERE citizenid = ? ORDER BY id DESC LIMIT 25', { cid })
    end)
    if not ok then return nil, 'No se pudieron leer las facturas (¿está pxd_economy instalado?).' end
    return { citizenid = cid, invoices = rows or {} }
end

function QUERY.vehicle(_, args)
    local plate = PXDAdmin.validPlate(args.plate)
    if not plate then return nil, 'Matrícula no válida.' end
    return { plate = plate, owner = vehicleOwner(plate) }
end

RegisterNetEvent('pxd_admin:server:query', function(kind, args)
    local src = source
    if type(kind) ~= 'string' or not QUERY[kind] or not PXDAdmin.QUERIES[kind] then return end
    if not isStaff(src) or not has(src, PXDAdmin.QUERIES[kind]) then
        return notify(src, 'Administración', 'No tienes permiso para consultar eso.', 'error')
    end
    if not PXDAdmin.allow(queryLimiter, src, GetGameTimer() / 1000) then return end
    local data, why = QUERY[kind](src, type(args) == 'table' and args or {})
    if data == nil then return notify(src, 'Administración', why or 'Sin datos.', 'error') end
    result(src, kind, data)
end)

-- ── Comandos de chat: misma validación que el panel ─────────────────────────

for _, c in ipairs(PXDAdmin.COMMANDS) do
    RegisterCommand(c.name, function(src, args)
        if c.action == 'announce' and PXDAdmin.announceBypass(src, function(ace) return IsPlayerAceAllowed(src, ace) end) then
            -- Consola o ACE de compatibilidad pxd.chat.announce: sin modo servicio.
            local ok, msg = ACTIONS.announce(src, nil, { text = table.concat(args, ' ') })
            if src == 0 then return print('[pxd_admin] ' .. tostring(msg)) end
            if ok then audit(src, 'announce', nil, { detail = table.concat(args, ' ') }) end
            return notify(src, 'Staff', msg, ok and 'success' or 'error')
        end
        if src == 0 then return print('[pxd_admin] Este comando se usa dentro del juego.') end
        if not isStaff(src) then return notify(src, 'Administración', NO_ACCESS, 'error') end
        local payload = {}
        if c.action == 'car' then payload.model = args[1]
        elseif c.action == 'announce' then payload.text = table.concat(args, ' ')
        elseif c.action == 'spectate' then payload.reason = table.concat(args, ' ', 2) end
        local target, why = PXDAdmin.commandTarget(c.action, args[1], src)
        if not target then return notify(src, 'Administración', why, 'error') end
        runAction(src, c.action, target, payload)
    end, false)
end

RegisterNetEvent('pxd_admin:server:spectateEnd', function()
    local src = source
    local s = spectating[src]
    if not s then return end
    spectating[src] = nil
    setBucket(src, s.bucket)
end)

RegisterNetEvent('pxd_admin:server:refreshStaff', function()
    local src = source
    if isStaff(src) then sendStaff(src) end
end)

RegisterNetEvent('pxd_admin:server:reportAction', function(action, id, msg)
    local src = source
    if not isStaff(src) or not has(src, 'reports') then return end
    local r = findReport(id)
    if not r or not PXDAdmin.canTransition(r, action) then return notify(src, 'Staff', 'Ese reporte ya no admite esa acción.', 'error') end
    local name = staffName(src)
    local reporter = findByLicense(r.reporter.license)
    if action == 'claim' then
        PXDAdmin.claim(r, name, now())
        if reporter then notify(reporter, 'Soporte', ('%s está atendiendo tu reporte #%d.'):format(name, r.id), 'staff') end
    elseif action == 'reply' then
        local ok, why = PXDAdmin.reply(r, name, msg, now(), true)
        if not ok then return notify(src, 'Staff', why, 'error') end
        if reporter then notify(reporter, ('Respuesta a tu reporte #%d'):format(r.id), tostring(msg):sub(1, 300), 'staff') end
    elseif action == 'close' then
        PXDAdmin.close(r, name, msg, now())
        if reporter then notify(reporter, 'Soporte', ('Tu reporte #%d se ha cerrado. ¡Gracias!'):format(r.id), 'success') end
    elseif action == 'goto' then
        if not reporter then return notify(src, 'Staff', 'Quien reportó ya no está conectado.', 'error') end
        if not runAction(src, 'goto', reporter) then return end
    end
    audit(src, 'report:' .. action, ('report:%d'):format(r.id), { detail = action == 'reply' and msg or nil })
    saveReports()
    if reporter then sendSupport(reporter) end
    broadcastReport(r, false)
    sendStaff(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if noclipOn[src] then audit(src, 'noclip', nil, { detail = 'desactivado (desconexión)' }) end
    backPos[src], frozen[src], spectating[src], onDuty[src], noclipOn[src] = nil, nil, nil, nil, nil
end)

load()
PXDAdmin.server = { reports = function() return reports end, log = function() return staffLog end, onDuty = onDuty,
    noclip = noclipOn, run = runAction }   -- para pruebas

-- ── Rangos desde el juego: /darrango, /quitarrango y /checkas ──────────────────
-- Se guardan en data/staff-roles.json (licencia → rol) y se aplican con add_principal en cada
-- arranque. Requiere en permissions.pxd.cfg:
--   add_ace resource.pxd_admin command.add_principal allow
--   add_ace resource.pxd_admin command.remove_principal allow
local grants = {}

local function loadGrants()
    local raw = LoadResourceFile(RES, Config.rolesFile)
    local ok, data = pcall(json.decode, raw or '')
    grants = (ok and type(data) == 'table') and data or {}
end

local function saveGrants()
    SaveResourceFile(RES, Config.rolesFile, json.encode(grants), -1)
end

local function principal(lic, group, on)
    if type(lic) ~= 'string' or not lic:match('^license:%w+$') then return end
    ExecuteCommand(('%s identifier.%s %s'):format(on and 'add_principal' or 'remove_principal', lic, group))
end

local function applyGrants()
    for lic, g in pairs(grants) do
        local role = PXDAdmin.roleById(g.role)
        if role then principal(lic, role.group, true) end
    end
end

local function reply(src, ok, text)
    if src == 0 then return print('[pxd_admin] ' .. text) end
    notify(src, 'Rangos', text, ok and 'success' or 'error')
end

--- Objetivo: id de jugador conectado o «license:…» (para quitar rangos a desconectados).
local function resolveTarget(arg)
    local id = online(arg)
    if id then return license(id), id end
    if type(arg) == 'string' and arg:match('^license:%w+$') then return arg, findByLicense(arg) end
end

RegisterCommand('darrango', function(src, args)
    local role = PXDAdmin.resolveRole(args[2])
    local lic, id = resolveTarget(args[1])
    if not lic or not id or not role then
        return reply(src, false, 'Uso: /darrango <id> <soporte|moderador|administrador|superadministrador|desarrollador> [motivo]')
    end
    local ok, why = PXDAdmin.canGrant(src == 0, has(src, 'staff.manage'), role.id)
    if not ok then return reply(src, false, why) end
    local reason = table.concat(args, ' ', 3)
    local old = grants[lic] and PXDAdmin.roleById(grants[lic].role)
    if old and old.group ~= role.group then principal(lic, old.group, false) end
    principal(lic, role.group, true)
    grants[lic] = { role = role.id, name = GetPlayerName(id), by = staffName(src), reason = reason ~= '' and reason or nil, at = now() }
    saveGrants()
    audit(src, 'rango_dar', id, { reason = reason ~= '' and reason or nil, detail = role.label })
    -- Se comprueba que el rango llegó de verdad (add_principal puede estar denegado o faltar la matriz).
    CreateThread(function()
        Wait(200)
        local applied, why = PXDAdmin.checkApplied(role, function(ace) return IsPlayerAceAllowed(id, ace) end,
            function(p, ace) return IsPrincipalAceAllowed(p, ace) end)
        if applied then
            notify(id, 'Rangos', ('Ahora eres %s. Abre el panel con F10 o /admin y revisa tus permisos con /checkas.'):format(role.label), 'success')
            return reply(src, true, ('%s ahora es %s.'):format(GetPlayerName(id) or lic, role.label))
        end
        reply(src, false, ('Rango guardado, pero NO se aplicó: %s'):format(why))
        if src ~= 0 then print('[pxd_admin] ^3/darrango: ' .. why .. '^7') end
    end)
end, false)

RegisterCommand('quitarrango', function(src, args)
    local lic, id = resolveTarget(args[1])
    if not lic then return reply(src, false, 'Uso: /quitarrango <id o license:…> [motivo]') end
    local g = grants[lic]
    if not g then
        return reply(src, false, 'Esa persona no tiene un rango dado con /darrango. Si su rango está en server.cfg, quítalo allí.')
    end
    local ok, why = PXDAdmin.canRevoke(src == 0, has(src, 'staff.manage'), g.role, src ~= 0 and license(src) == lic)
    if not ok then return reply(src, false, why) end
    local role = PXDAdmin.roleById(g.role)
    if role then principal(lic, role.group, false) end
    grants[lic] = nil
    saveGrants()
    local reason = table.concat(args, ' ', 2)
    audit(src, 'rango_quitar', id or { key = lic, label = g.name or lic }, { reason = reason ~= '' and reason or nil, detail = role and role.label })
    if id then notify(id, 'Rangos', 'Ya no tienes rango de staff.', 'info') end
    reply(src, true, ('Rango retirado a %s.'):format(g.name or lic))
end, false)

--- Lo que muestra /checkas: rol, permisos uno a uno y, al staff, la lista de rangos dados.
local function checkData(viewer, target)
    local hasAce = aceOf(target)
    local pd = qbxPlayer(target)
    local lic = license(target)
    local perms = {}
    for p, label in pairs(PXDAdmin.PERMS) do perms[#perms + 1] = { id = p, label = label, ok = PXDAdmin.has(p, hasAce) } end
    table.sort(perms, function(a, b) if a.ok ~= b.ok then return a.ok end return a.id < b.id end)
    local g = lic and grants[lic]
    local out = {
        name = GetPlayerName(target), id = target, publicId = publicId(target, pd),
        role = PXDAdmin.roleLabel(hasAce) or 'Sin rango de staff',
        origin = g and ('Dado con /darrango por %s'):format(g.by or '?') or (PXDAdmin.has('panel', hasAce) and 'server.cfg o txAdmin' or nil),
        license = (viewer == target or has(viewer, 'players.identity')) and lic or nil,
        perms = perms,
    }
    if has(viewer, 'panel') then
        local list = {}
        for l, e in pairs(grants) do
            local r = PXDAdmin.roleById(e.role)
            list[#list + 1] = { name = e.name or l, role = r and r.label or e.role, by = e.by, at = e.at, online = findByLicense(l) ~= nil }
        end
        table.sort(list, function(a, b) return (a.at or 0) > (b.at or 0) end)
        out.staff = list
    end
    return out
end

RegisterCommand('checkas', function(src, args)
    local target = args[1] and online(args[1]) or (src > 0 and src or nil)
    if not target then return reply(src, false, 'Uso: checkas <id de jugador conectado>') end
    if src > 0 and target ~= src and not has(src, 'panel') then
        return reply(src, false, 'Solo el staff puede revisar los permisos de otra persona. Usa /checkas sin número para ver los tuyos.')
    end
    local data = checkData(src > 0 and src or target, target)
    if src == 0 then
        local okList = {}
        for _, p in ipairs(data.perms) do if p.ok then okList[#okList + 1] = p.id end end
        print(('[pxd_admin] %s (#%d) · %s · %s'):format(data.name or '?', target, data.role, data.origin or 'sin rango'))
        return print('[pxd_admin] permisos: ' .. (#okList > 0 and table.concat(okList, ', ') or 'ninguno'))
    end
    TriggerClientEvent('pxd_admin:client:checkas', src, data)
end, false)

loadGrants()
CreateThread(function()
    Wait(1000)   -- tras leer el server.cfg
    for _, msg in ipairs(PXDAdmin.setupProblems(function(p, ace) return IsPrincipalAceAllowed(p, ace) end)) do
        print('[pxd_admin] ^3' .. msg .. '^7')
    end
    applyGrants()
end)
PXDAdmin.server.grants = function() return grants end
