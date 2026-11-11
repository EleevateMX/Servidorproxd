-- pxd_orgs (servidor): organizaciones y bandas creadas por jugadores.
-- · La ficha (nombre, tipo, identidad, reputación, estado) vive en pxd_orgs (MariaDB).
-- · Los miembros y sus rangos son de qbx_core: cada organización oficial es una banda «pxo_<id>»
--   creada con exports.qbx_core:CreateGangs(…, true). El `true` la guarda en shared/gangs.lua de
--   qbx_core; así sobrevive al reinicio y a su limpieza de player_groups (qbx:cleanPlayerGroups).
-- · Los fondos son la cuenta de Renewed-Banking con el mismo nombre que la banda.
-- Todo se valida aquí; la interfaz solo pide. docs/42-organizaciones.md
local O, Store = PXDOrgs, PXDOrgStore
local MSG = O.MESSAGES

local ready = false
local orgs, bySlug = {}, {}   -- organizaciones vivas (pendientes y oficiales)
local drafts = {}             -- [citizenid de quien funda] = fundación en curso (en memoria)
local invites = {}            -- [citizenid invitado] = { [orgId] = invitación }
local busy = {}               -- organizaciones con una operación de dinero o disolución en curso
local lastCall = {}
local nameCache = {}          -- [citizenid] = nombre (miembros desconectados)
local accountTried = {}

local function now() return os.time() end
local function started(res) return GetResourceState(res) == 'started' end

--- Llama a un export de otro recurso sin romper si falla. Devuelve ok, resultados…
local function call(res, fn, ...)
    if not started(res) then return false, 'recurso no iniciado' end
    local n, args = select('#', ...), { ... }
    return pcall(function() return exports[res][fn](exports[res], table.unpack(args, 1, n)) end)
end

local function getPlayer(src)
    local ok, p = call('qbx_core', 'GetPlayer', src)
    return ok and p or nil
end

local function playerByCitizen(cid)
    local ok, p = call('qbx_core', 'GetPlayerByCitizenId', cid)
    return ok and p or nil
end

local function fullName(p)
    local c = p and p.PlayerData and p.PlayerData.charinfo or {}
    local n = ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or nil
end

local function notify(src, text, kind)
    if not src or src <= 0 then return end
    call('qbx_core', 'Notify', src, text, kind or 'inform')
end

local function isStaff(src) return src == 0 or IsPlayerAceAllowed(src, Config.ace.manage) end
local function money(n) return '$' .. tostring(math.floor(n)) end

local function throttled(src, write)
    local t = GetGameTimer() / 1000
    local slot = lastCall[src] or {}
    lastCall[src] = slot
    local kind = write and 'write' or 'read'
    if slot[kind] and t - slot[kind] < (Config.cooldown[kind] or 0.3) then return true end
    slot[kind] = t
    return false
end

-- ── Datos del jugador respecto a las organizaciones ───────────────────────────
local function orgOf(pd)
    local g = pd and pd.gang
    return g and g.name and g.name ~= 'none' and bySlug[g.name] or nil
end

local function gradeIn(pd, org)
    if not org or not pd or not pd.gang or pd.gang.name ~= org.slug then return nil end
    return tonumber(pd.gang.grade and pd.gang.grade.level) or 0
end

local function inAnyGang(pd)
    if pd.gang and pd.gang.name and pd.gang.name ~= 'none' then return true end
    return type(pd.gangs) == 'table' and next(pd.gangs) ~= nil
end

local function levelOf(src)
    if not started('pxd_progress') then return nil end
    local ok, prof = call('pxd_progress', 'GetProfile', src)
    return ok and type(prof) == 'table' and tonumber(prof.level) or nil
end

local function bankOf(src)
    local ok, v = call('qbx_core', 'GetMoney', src, 'bank')
    return ok and tonumber(v) or 0
end

-- ── Auditoría: historial propio y, si está, la auditoría común ────────────────
local function audit(org, action, actor, target, amount, detail)
    local cid, name = nil, 'consola'
    if type(actor) == 'table' then cid, name = actor.PlayerData.citizenid, fullName(actor)
    elseif type(actor) == 'string' then name = actor end
    local d = detail and tostring(detail):sub(1, 255) or nil
    local ok, err = pcall(Store.event, org.id, action, cid, name, target and tostring(target):sub(1, 128) or nil, amount, d, now())
    if not ok then print(('[pxd_orgs] no se pudo registrar %s de #%s: %s'):format(action, tostring(org.id), tostring(err))) end
    if started('pxd_audit') then
        pcall(function()
            exports.pxd_audit:Log({ category = 'orgs', action = action, actor = cid or name, target = ('org:%d'):format(org.id),
                data = { org = org.name, slug = org.slug, target = target, amount = amount, detail = d, staff = name } })
        end)
    end
end

-- ── Caché ─────────────────────────────────────────────────────────────────────
local function remember(row)
    row.id = tonumber(row.id)
    orgs[row.id] = row
    if row.slug then bySlug[row.slug] = row end
    return row
end

local function forget(org)
    orgs[org.id] = nil
    if org.slug then bySlug[org.slug] = nil end
    for cid, byOrg in pairs(invites) do byOrg[org.id] = nil; if next(byOrg) == nil then invites[cid] = nil end end
end

local function find(idOrSlug)
    if type(idOrSlug) == 'string' and bySlug[idOrSlug] then return bySlug[idOrSlug] end
    return orgs[tonumber(idOrSlug) or -1]
end

--- Estado replicado del jugador (lo leerán etiquetas, grafitis y el mapa de barrios).
local function publish(src, pd)
    local org = orgOf(pd)
    local value = nil
    if org and org.status == 'official' then
        value = { id = org.id, name = org.name, type = org.type, color = org.color, font = org.font, emblem = org.emblem,
            grade = gradeIn(pd, org) }
    end
    Player(src).state:set('pxdOrg', value, true)
end

local function publishOrg(org)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local p = getPlayer(src)
        if p and p.PlayerData.gang and p.PlayerData.gang.name == org.slug then publish(src, p.PlayerData) end
    end
end

-- ── Miembros (de qbx_core) ────────────────────────────────────────────────────
local function memberRows(org)
    local ok, rows = call('qbx_core', 'GetGroupMembers', org.slug, 'gang')
    return ok and type(rows) == 'table' and rows or {}
end

local function memberName(cid, online)
    if online then
        local n = fullName(online)
        if n then nameCache[cid] = n end
        return n or cid
    end
    if nameCache[cid] then return nameCache[cid] end
    local ok, p = call('qbx_core', 'GetOfflinePlayer', cid)
    local n = ok and fullName(p) or nil
    nameCache[cid] = n or cid
    return nameCache[cid]
end

local function memberList(org)
    local out = {}
    for _, r in ipairs(memberRows(org)) do
        local online = playerByCitizen(r.citizenid)
        local grade = tonumber(r.grade) or 0
        out[#out + 1] = { citizenid = r.citizenid, name = memberName(r.citizenid, online), grade = grade,
            gradeName = O.gradeName(org.type, grade, Config), online = online ~= nil, leader = O.isLeader(grade, Config) }
    end
    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return out
end

local function memberGrade(org, cid)
    for _, r in ipairs(memberRows(org)) do if r.citizenid == cid then return tonumber(r.grade) or 0 end end
    return nil
end

local function pendingInvites(org)
    local list, t = {}, now()
    for cid, byOrg in pairs(invites) do
        local inv = byOrg[org.id]
        if inv and inv.expires > t then list[#list + 1] = { citizenid = cid, name = inv.name, by = inv.byName, expires = inv.expires } end
    end
    return list
end

local function slotsLeft(org)
    local lvl = O.levelFor(org.reputation, Config)
    return lvl.slots - #memberRows(org) - #pendingInvites(org)
end

-- ── Banco de la organización (Renewed-Banking) ────────────────────────────────
local RB = 'Renewed-Banking'
local RB_MARK = 'Player.PlayerData.gang.bankAuth == true'
local rbPatched

--- ¿Tiene Renewed-Banking el parche de docs/42? Sin él, su IsGangAuth falla con bandas creadas en marcha.
local function bankPatched()
    if rbPatched == nil then
        local code = LoadResourceFile(RB, 'server/framework.lua')
        rbPatched = code ~= nil and code:find(RB_MARK, 1, true) ~= nil
    end
    return rbPatched
end

local function balance(org)
    local ok, v = call(RB, 'getAccountMoney', org.slug)
    if ok and type(v) == 'number' then return v end
    return nil
end

--- Cuenta de la organización. Si aún no existe se crea (solo con el parche: sin él, el banco de
--- Renewed-Banking daría error a los miembros hasta el reinicio, que es cuando la crea él solo).
local function ensureAccount(org)
    local b = balance(org)
    if b then return b end
    if accountTried[org.id] or not bankPatched() then return nil end
    accountTried[org.id] = true
    call(RB, 'CreateJobAccount', { name = org.slug, label = org.name }, 0)
    return balance(org)
end

local function bankLog(org, title, amount, message, issuer, kind)
    call(RB, 'handleTransaction', org.slug, title, amount, tostring(message or ''):sub(1, 120), tostring(issuer or 'Miembro'):sub(1, 50),
        org.name:sub(1, 50), kind)
end

--- Cobra al jugador y lo ingresa en la cuenta de la organización, con reembolso si falla un paso.
local function chargeToOrg(src, method, amount, org, reason, payer)
    if started('pxd_economy') then
        local ok, done, code = call('pxd_economy', 'ChargeToAccount', src, method, amount, org.slug,
            { reason = reason, title = 'Aportación', message = 'Aportación a ' .. org.name, payer = payer })
        if ok then return done == true, code end
    end
    local okG, have = call('qbx_core', 'GetMoney', src, method)
    if not okG or (tonumber(have) or 0) < amount then return false, 'fondos' end
    local okR, removed = call('qbx_core', 'RemoveMoney', src, method, amount, reason)
    if not okR or not removed then return false, 'fondos' end
    local okA, added = call(RB, 'addAccountMoney', org.slug, amount)
    if not okA or not added then
        call('qbx_core', 'AddMoney', src, method, amount, reason .. '-reembolso')
        return false, 'banco'
    end
    bankLog(org, 'Aportación', amount, 'Aportación a ' .. org.name, payer, 'deposit')
    return true
end

-- ── Hacer oficial / rechazar / disolver ───────────────────────────────────────
local function gangExists(org)
    local ok, g = call('qbx_core', 'GetGang', org.slug)
    return ok and g ~= nil
end

local function createGang(org)
    local ok, done, err = call('qbx_core', 'CreateGangs', { [org.slug] = { label = org.name, grades = O.gradesFor(org.type, Config) } }, true)
    if not ok or not done then
        print(('[pxd_orgs] ^1qbx_core no pudo crear la banda %s: %s^7'):format(org.slug, tostring(ok and err or done)))
        return false
    end
    return true
end

local function joinGang(cid, org, grade)
    local ok, added, err = call('qbx_core', 'AddPlayerToGang', cid, org.slug, grade)
    if not ok or not added then
        return false, type(err) == 'table' and err.code or tostring(ok and err or added)
    end
    call('qbx_core', 'SetPlayerPrimaryGang', cid, org.slug)
    return true
end

--- Pasa una solicitud a oficial: crea la banda en qbx_core, mete a los fundadores y abre la cuenta.
local function makeOfficial(org, by, reason)
    if org.status ~= 'pending' then return false, MSG.estado end
    if not createGang(org) then return false, MSG.sin_servicio end
    if not Store.decide(org.id, 'official', by, reason, now()) then
        call('qbx_core', 'RemoveGang', org.slug, true)
        return false, MSG.estado
    end
    org.status, org.decided_by = 'official', by
    local top = O.topGrade(Config)
    for _, f in ipairs(Store.founders(org.id)) do
        local grade = f.citizenid == org.leader_citizenid and top or Config.founderGrade
        local ok, why = joinGang(f.citizenid, org, grade)
        if not ok then print(('[pxd_orgs] %s no entró en %s al hacerse oficial: %s'):format(f.citizenid, org.slug, tostring(why))) end
    end
    ensureAccount(org)
    audit(org, 'official', by, nil, nil, reason)
    publishOrg(org)
    TriggerEvent('pxd_orgs:created', org.id, O.publicOrg(org, Config))
    local leader = playerByCitizen(org.leader_citizenid)
    if leader then notify(leader.PlayerData.source, ('«%s» ya es una organización oficial. Gestiónala con /%s.'):format(org.name, Config.command), 'success') end
    return true
end

local function reject(org, by, reason)
    if org.status ~= 'pending' then return false, MSG.estado end
    if not Store.decide(org.id, 'rejected', by, reason, now()) then return false, MSG.estado end
    local cost = tonumber(org.cost_paid) or 0
    if cost > 0 then
        local ok, done = call('qbx_core', 'AddMoney', org.created_by, 'bank', cost, ('pxd-org-reembolso-%d'):format(org.id))
        if not ok or not done then print(('[pxd_orgs] ^1No se pudo devolver la tasa (%d) a %s^7'):format(cost, org.created_by)) end
    end
    audit(org, 'rejected', by, org.created_by, cost > 0 and cost or nil, reason)
    forget(org)
    local creator = playerByCitizen(org.created_by)
    if creator then
        notify(creator.PlayerData.source, ('Tu solicitud de «%s» fue rechazada: %s%s'):format(org.name, reason,
            cost > 0 and (' Se te devolvieron %s.'):format(money(cost)) or ''), 'error')
    end
    return true
end

--- Disuelve una organización oficial: fondos a quien lidera, miembros fuera, banda eliminada.
--- La ficha y su historial se conservan con estado «disuelta».
local function dissolve(org, actor, reason)
    if org.status ~= 'official' then return false, MSG.estado end
    if busy[org.id] then return false, MSG.en_curso end
    busy[org.id] = true
    local ok, a, b = pcall(function()
        local left = balance(org) or 0
        if left > 0 then
            local okR, removed = call(RB, 'removeAccountMoney', org.slug, left)
            if not okR or not removed then return false, MSG.banco end
            local okA, added = call('qbx_core', 'AddMoney', org.leader_citizenid, 'bank', left, ('pxd-org-disolucion-%d'):format(org.id))
            if not okA or not added then
                call(RB, 'addAccountMoney', org.slug, left)
                return false, MSG.banco
            end
            bankLog(org, 'Disolución', left, 'Fondos entregados a quien lideraba', 'Sistema', 'withdraw')
        end
        local members = memberRows(org)
        for _, r in ipairs(members) do call('qbx_core', 'RemovePlayerFromGang', r.citizenid, org.slug) end
        call('qbx_core', 'RemoveGang', org.slug, true)
        Store.dissolve(org.id, type(actor) == 'table' and (fullName(actor) or actor.PlayerData.citizenid) or tostring(actor), reason, now())
        org.status = 'dissolved'
        audit(org, 'dissolved', actor, nil, left > 0 and left or nil, reason)
        forget(org)
        for _, r in ipairs(members) do
            local p = playerByCitizen(r.citizenid)
            if p then
                publish(p.PlayerData.source, { gang = { name = 'none' } })
                notify(p.PlayerData.source, ('«%s» se ha disuelto.'):format(org.name), 'inform')
            end
        end
        TriggerEvent('pxd_orgs:dissolved', org.id)
        return true
    end)
    busy[org.id] = nil
    if not ok then
        print(('[pxd_orgs] error al disolver #%d: %s'):format(org.id, tostring(a)))
        return false, MSG.sin_servicio
    end
    return a, b
end

-- ── Cercanía ──────────────────────────────────────────────────────────────────
local function near(a, b, dist)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or not pb or pa == 0 or pb == 0 then return false end
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= dist
end

--- Jugadores cerca de `src` con personaje y sin banda (candidatos a cofundar o a ser invitados).
local function nearbyFree(src, dist)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        if other ~= src and near(src, other, dist) then
            local p = getPlayer(other)
            if p and not inAnyGang(p.PlayerData) then
                out[#out + 1] = { id = other, name = fullName(p) or ('#' .. other) }
            end
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- ── Fundación ─────────────────────────────────────────────────────────────────
local function pendingOf(cid)
    for _, org in pairs(orgs) do
        if org.status == 'pending' then
            if org.created_by == cid then return org end
            for _, f in ipairs(org.founders or {}) do if f.citizenid == cid then return org end end
        end
    end
    return nil
end

local function draftCount(d)
    local n = 1
    for _, f in pairs(d.invited) do if f.accepted then n = n + 1 end end
    return n
end

local function dropDraft(cid, tell)
    local d = drafts[cid]
    if not d then return end
    drafts[cid] = nil
    if tell then
        for fcid in pairs(d.invited) do
            local p = playerByCitizen(fcid)
            if p then notify(p.PlayerData.source, ('La fundación de «%s» se canceló.'):format(d.name), 'inform') end
        end
    end
end

local function pruneDrafts()
    local t = now()
    for cid, d in pairs(drafts) do if d.expires <= t then dropDraft(cid, true) end end
    O.pruneInvites(invites, t)
end

--- Valida lo que envía el formulario. Devuelve la fundación saneada o nil, mensaje.
local function validateCreate(src, player, data, staff)
    local t = type(data.type) == 'string' and Config.types[data.type] or nil
    if not t or not t.creatable or (t.staffOnly and not staff) then return nil, MSG.tipo end
    local name, why = O.validName(data.name, Config)
    if not name then return nil, MSG[why]:format(Config.name.min, Config.name.max) end
    local key = O.nameKey(name)
    if not staff and O.blocked(key, Config.blockedNames) then return nil, MSG.nombre_bloqueado end
    if Store.nameTaken(key) then return nil, MSG.nombre_usado end
    for _, d in pairs(drafts) do if d.key == key and d.creator ~= player.PlayerData.citizenid then return nil, MSG.nombre_usado end end
    local okG, gangs = call('qbx_core', 'GetGangs')
    if okG and type(gangs) == 'table' then
        for _, g in pairs(gangs) do
            if type(g.label) == 'string' and O.nameKey(g.label) == key then return nil, MSG.nombre_usado end
        end
    end
    local identity, ierr = O.identity({ color = data.color, font = data.font, emblem = data.emblem or O.emblemFrom(name),
        motto = data.motto }, Config, { emblem = O.emblemFrom(name) })
    if not identity then return nil, MSG[ierr] end
    return { name = name, key = key, type = data.type, identity = identity }
end

local function createContext(src, player, founders, staff)
    return { level = levelOf(src), bank = bankOf(src), founders = founders, staff = staff }
end

local function startCreate(src, data)
    local player = getPlayer(src)
    if not player then return false, MSG.sin_servicio end
    local pd, staff = player.PlayerData, isStaff(src)
    local cid = pd.citizenid
    if inAnyGang(pd) then return false, MSG.ya_en_org end
    if pendingOf(cid) then return false, MSG.pendiente end
    pruneDrafts()
    if drafts[cid] then return false, MSG.borrador end
    for _, d in pairs(drafts) do if d.invited[cid] and d.invited[cid].accepted then return false, MSG.borrador end end
    if not staff then
        local last = Store.lastByCreator(cid)
        if last and last + Config.create.cooldownSeconds > now() then return false, MSG.espera end
    end
    local d, why = validateCreate(src, player, data, staff)
    if not d then return false, why end

    -- Cofundadores elegidos: conectados, cerca y sin banda.
    local invited, seen = {}, {}
    for _, id in ipairs(type(data.founders) == 'table' and data.founders or {}) do
        id = tonumber(id)
        if id and math.tointeger(id) and id ~= src and not seen[id] then
            seen[id] = true
            local other = getPlayer(id)
            if not other or inAnyGang(other.PlayerData) or pendingOf(other.PlayerData.citizenid) then return false, MSG.fundador_no_valido end
            if not near(src, id, Config.create.founderDistance) then return false, MSG.lejos end
            invited[other.PlayerData.citizenid] = { name = fullName(other) or ('#' .. id), accepted = false }
        end
    end
    local count = 1
    for _ in pairs(invited) do count = count + 1 end
    if not staff and count < Config.create.minFounders then return false, MSG.fundadores end
    local _, okReq = O.requirements(createContext(src, player, count, staff), Config)
    if not okReq then return false, MSG.requisitos end

    d.creator, d.creatorName, d.invited, d.staff = cid, fullName(player) or cid, invited, staff
    d.expires = now() + Config.create.draftSeconds
    drafts[cid] = d
    for fcid, f in pairs(invited) do
        local p = playerByCitizen(fcid)
        if p then
            notify(p.PlayerData.source, ('%s te propone fundar «%s». Responde con /%s.'):format(d.creatorName, d.name, Config.command), 'inform')
            TriggerClientEvent('pxd_orgs:client:refresh', p.PlayerData.source)
        end
    end
    return true
end

local function answerFounder(src, creatorCid, accept)
    local player = getPlayer(src)
    if not player then return false, MSG.sin_servicio end
    pruneDrafts()
    local d = type(creatorCid) == 'string' and drafts[creatorCid] or nil
    local cid = player.PlayerData.citizenid
    local mine = d and d.invited[cid]
    if not mine then return false, MSG.sin_invitacion end
    local creator = playerByCitizen(d.creator)
    if accept then
        if inAnyGang(player.PlayerData) then return false, MSG.ya_en_org end
        mine.accepted = true
        if creator then notify(creator.PlayerData.source, ('%s acepta fundar «%s» contigo.'):format(mine.name, d.name), 'success') end
    else
        d.invited[cid] = nil
        if creator then notify(creator.PlayerData.source, ('%s rechazó fundar «%s».'):format(mine.name, d.name), 'error') end
    end
    if creator then TriggerClientEvent('pxd_orgs:client:refresh', creator.PlayerData.source) end
    return true
end

--- Quien funda confirma: se vuelven a comprobar los requisitos, se cobra la tasa y se crea la solicitud.
local function confirmCreate(src)
    local player = getPlayer(src)
    if not player then return false, MSG.sin_servicio end
    local pd = player.PlayerData
    pruneDrafts()
    local d = drafts[pd.citizenid]
    if not d then return false, MSG.sin_invitacion end
    if inAnyGang(pd) then return false, MSG.ya_en_org end
    local staff = d.staff and isStaff(src)

    local founders = { { citizenid = pd.citizenid, name = d.creatorName } }
    for fcid, f in pairs(d.invited) do
        if f.accepted then
            local p = playerByCitizen(fcid)
            if not p or inAnyGang(p.PlayerData) then return false, MSG.fundador_no_valido end
            if not near(src, p.PlayerData.source, Config.create.founderDistance) then return false, MSG.lejos end
            founders[#founders + 1] = { citizenid = fcid, name = f.name }
        end
    end
    if not staff and #founders < Config.create.minFounders then return false, MSG.fundadores end
    local _, okReq = O.requirements(createContext(src, player, #founders, staff), Config)
    if not okReq then return false, MSG.requisitos end
    if Store.nameTaken(d.key) then drafts[pd.citizenid] = nil return false, MSG.nombre_usado end

    -- Tasa de registro: del banco, nunca en negativo. Se devuelve si algo falla o si se rechaza.
    local cost = staff and 0 or (Config.create.cost or 0)
    local reason = 'pxd-org-registro'
    if cost > 0 then
        if bankOf(src) < cost then return false, MSG.fondos end
        local okR, removed = call('qbx_core', 'RemoveMoney', src, 'bank', cost, reason)
        if not okR or not removed then return false, MSG.fondos end
    end
    local okI, id, slug = pcall(Store.insert, {
        name = d.name, name_key = d.key, type = d.type, leader_citizenid = pd.citizenid, color = d.identity.color, font = d.identity.font,
        motto = d.identity.motto, emblem = d.identity.emblem, cost_paid = cost, created_by = pd.citizenid,
    }, now())
    if not okI or not id then
        if cost > 0 then call('qbx_core', 'AddMoney', src, 'bank', cost, reason .. '-reembolso') end
        if not okI then print('[pxd_orgs] error al crear la solicitud: ' .. tostring(id)) end
        return false, MSG.sin_servicio
    end
    drafts[pd.citizenid] = nil
    for _, f in ipairs(founders) do pcall(Store.addFounder, id, f.citizenid, f.name, now()) end
    local org = remember({
        id = id, slug = slug, name = d.name, name_key = d.key, type = d.type, status = 'pending', leader_citizenid = pd.citizenid,
        color = d.identity.color, font = d.identity.font, motto = d.identity.motto, emblem = d.identity.emblem, reputation = 0,
        cost_paid = cost, created_by = pd.citizenid, created_at = now(), founders = founders,
    })
    audit(org, 'requested', player, nil, cost > 0 and cost or nil, ('%s · %d fundadores'):format(d.type, #founders))

    if staff or Config.approval == 'auto' then
        local ok, why = makeOfficial(org, staff and (fullName(player) or 'staff') or 'automática', staff and 'creada por el staff' or 'requisitos cumplidos')
        if not ok then return false, why end
        return true, ('«%s» ya es oficial.'):format(org.name)
    end
    for _, pid in ipairs(GetPlayers()) do
        local s = tonumber(pid)
        if s ~= src and IsPlayerAceAllowed(s, Config.ace.manage) then
            notify(s, ('Nueva solicitud de organización: «%s» (#%d). Revísala con /%s.'):format(org.name, org.id, Config.command), 'inform')
        end
    end
    return true, ('Solicitud enviada. «%s» queda pendiente de aprobación del staff.'):format(org.name)
end

-- ── Vista para la interfaz ────────────────────────────────────────────────────
local function permsOf(grade)
    return { invite = O.hasPerm(grade, 'invite', Config), manage = O.hasPerm(grade, 'manage', Config),
        funds = O.hasPerm(grade, 'funds', Config), identity = O.hasPerm(grade, 'identity', Config), leader = O.isLeader(grade, Config) }
end

local function pendingView(org, full)
    local v = O.publicOrg(org, Config)
    v.founders = {}
    for _, f in ipairs(org.founders or {}) do v.founders[#v.founders + 1] = full and { citizenid = f.citizenid, name = f.name } or { name = f.name } end
    v.cost = tonumber(org.cost_paid) or 0
    return v
end

local function view(src)
    local player = getPlayer(src)
    if not player then return nil end
    local pd, staff = player.PlayerData, isStaff(src)
    local cid = pd.citizenid
    pruneDrafts()
    local out = { me = { name = fullName(player) or cid, citizenid = cid }, command = Config.command }

    local org = orgOf(pd)
    if org and org.status == 'official' then
        local grade = gradeIn(pd, org)
        local v = O.publicOrg(org, Config)
        v.grade, v.gradeName, v.perms = grade, O.gradeName(org.type, grade, Config), permsOf(grade)
        v.members = memberList(org)
        v.funds = ensureAccount(org)          -- nil = la cuenta aún no está disponible
        v.fundMethods = Config.funds.methods
        v.invites = v.perms.invite and pendingInvites(org) or {}
        v.nearby = v.perms.invite and nearbyFree(src, Config.invite.distance) or {}
        v.grades = {}
        for g = 0, O.topGrade(Config) do v.grades[#v.grades + 1] = { level = g, name = O.gradeName(org.type, g, Config) } end
        if v.perms.manage then v.history = Store.events(org.id, 15) end
        out.org = v
    elseif inAnyGang(pd) then
        out.otherGang = pd.gang and pd.gang.label or 'otra banda'   -- banda de qbx_core que no gestiona pxd_orgs
    end

    -- Invitaciones recibidas y propuestas para cofundar.
    out.invites = {}
    for orgId, inv in pairs(invites[cid] or {}) do
        local o = orgs[orgId]
        if o and o.status == 'official' then
            local id = O.identityOf(o, Config)
            id.by, id.expires, id.typeLabel = inv.byName, inv.expires, (Config.types[o.type] or {}).label
            out.invites[#out.invites + 1] = id
        end
    end
    out.founding = {}
    for creator, d in pairs(drafts) do
        local mine = d.invited[cid]
        if mine then
            out.founding[#out.founding + 1] = { creator = creator, by = d.creatorName, name = d.name, type = d.type,
                typeLabel = (Config.types[d.type] or {}).label, color = d.identity.color, font = d.identity.font,
                emblem = d.identity.emblem, accepted = mine.accepted, expires = d.expires }
        end
    end

    local d = drafts[cid]
    if d then
        local list = {}
        for fcid, f in pairs(d.invited) do list[#list + 1] = { citizenid = fcid, name = f.name, accepted = f.accepted } end
        table.sort(list, function(a, b) return a.name < b.name end)
        out.draft = { name = d.name, type = d.type, typeLabel = (Config.types[d.type] or {}).label, identity = d.identity,
            founders = list, count = draftCount(d), needed = d.staff and 1 or Config.create.minFounders, expires = d.expires,
            cost = d.staff and 0 or Config.create.cost }
    end
    local pend = pendingOf(cid)
    if pend then out.pending = pendingView(pend, false) end

    if not out.org then
        local types = {}
        for id, t in pairs(Config.types) do
            if t.creatable and (not t.staffOnly or staff) then types[#types + 1] = { id = id, label = t.label } end
        end
        table.sort(types, function(a, b) return a.label < b.label end)
        local reqs = O.requirements(createContext(src, player, 1, staff), Config)
        out.create = { types = types, colors = Config.colors, fonts = Config.fonts, requirements = reqs, staff = staff,
            cost = staff and 0 or Config.create.cost, minFounders = staff and 1 or Config.create.minFounders,
            nameMin = Config.name.min, nameMax = Config.name.max, mottoMax = Config.motto.max, approval = Config.approval,
            nearby = nearbyFree(src, Config.create.founderDistance), blocked = inAnyGang(pd) }
    else
        out.identityOptions = { colors = Config.colors, fonts = Config.fonts, mottoMax = Config.motto.max }
    end

    -- Directorio de organizaciones oficiales.
    out.directory = {}
    for _, o in pairs(orgs) do
        if o.status == 'official' then
            local id = O.publicOrg(o, Config)
            out.directory[#out.directory + 1] = { id = id.id, name = id.name, typeLabel = id.typeLabel, color = id.color, font = id.font,
                fontFamily = id.fontFamily, emblem = id.emblem, level = id.level, motto = id.motto }
        end
    end
    table.sort(out.directory, function(a, b) return a.name < b.name end)

    if staff then
        out.staff = { pending = {} }
        for _, o in pairs(orgs) do if o.status == 'pending' then out.staff.pending[#out.staff.pending + 1] = pendingView(o, true) end end
        table.sort(out.staff.pending, function(a, b) return a.id < b.id end)
    end
    return out
end

-- ── Acciones de miembros ──────────────────────────────────────────────────────
--- Organización oficial y rango de quien pide. Devuelve player, org, grade o nil, mensaje.
local function actor(src)
    local player = getPlayer(src)
    if not player then return nil, MSG.sin_servicio end
    local org = orgOf(player.PlayerData)
    if not org or org.status ~= 'official' then return nil, MSG.sin_org end
    return player, org, gradeIn(player.PlayerData, org)
end

local function invite(src, target)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.hasPerm(grade, 'invite', Config) then return false, MSG.permiso end
    target = tonumber(target)
    local other = target and math.tointeger(target) and target ~= src and getPlayer(target) or nil
    if not other then return false, MSG.jugador end
    if not near(src, target, Config.invite.distance) then return false, MSG.lejos end
    if inAnyGang(other.PlayerData) then return false, MSG.ocupado end
    local cid = other.PlayerData.citizenid
    O.pruneInvites(invites, now())
    if invites[cid] and invites[cid][org.id] then return false, MSG.invitado end
    if slotsLeft(org) < 1 then return false, MSG.llena end
    invites[cid] = invites[cid] or {}
    invites[cid][org.id] = { by = player.PlayerData.citizenid, byName = fullName(player) or 'Un miembro', name = fullName(other) or ('#' .. target),
        at = now(), expires = now() + Config.invite.seconds }
    audit(org, 'invite', player, cid)
    notify(target, ('%s te invita a unirte a «%s». Responde con /%s.'):format(invites[cid][org.id].byName, org.name, Config.command), 'inform')
    TriggerClientEvent('pxd_orgs:client:refresh', target)
    return true, ('Invitación enviada a %s.'):format(invites[cid][org.id].name)
end

local function answerInvite(src, orgId, accept)
    local player = getPlayer(src)
    if not player then return false, MSG.sin_servicio end
    local cid = player.PlayerData.citizenid
    O.pruneInvites(invites, now())
    local org = orgs[tonumber(orgId) or -1]
    local inv = org and invites[cid] and invites[cid][org.id]
    if not inv or org.status ~= 'official' then return false, MSG.sin_invitacion end
    invites[cid][org.id] = nil
    if next(invites[cid]) == nil then invites[cid] = nil end
    local inviter = playerByCitizen(inv.by)
    if not accept then
        if inviter then notify(inviter.PlayerData.source, ('%s rechazó la invitación a «%s».'):format(inv.name, org.name), 'inform') end
        return true, 'Invitación rechazada.'
    end
    if inAnyGang(player.PlayerData) then return false, MSG.ya_en_org end
    if O.levelFor(org.reputation, Config).slots - #memberRows(org) < 1 then return false, MSG.llena end
    local ok, why = joinGang(cid, org, Config.joinGrade)
    if not ok then
        print(('[pxd_orgs] %s no pudo entrar en %s: %s'):format(cid, org.slug, tostring(why)))
        return false, MSG.sin_servicio
    end
    audit(org, 'join', player, cid, nil, 'invitación de ' .. tostring(inv.byName))
    if inviter then notify(inviter.PlayerData.source, ('%s se unió a «%s».'):format(inv.name, org.name), 'success') end
    return true, ('Ahora formas parte de «%s».'):format(org.name)
end

local function cancelInvite(src, cid)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.hasPerm(grade, 'invite', Config) then return false, MSG.permiso end
    if type(cid) ~= 'string' or not invites[cid] or not invites[cid][org.id] then return false, MSG.sin_invitacion end
    invites[cid][org.id] = nil
    if next(invites[cid]) == nil then invites[cid] = nil end
    return true, 'Invitación retirada.'
end

local function kick(src, cid)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.hasPerm(grade, 'manage', Config) then return false, MSG.permiso end
    if type(cid) ~= 'string' then return false, MSG.miembro end
    if cid == player.PlayerData.citizenid then return false, MSG.propio end
    local tg = memberGrade(org, cid)
    if not tg then return false, MSG.miembro end
    if not O.canActOn(grade, tg) then return false, MSG.rango end
    local ok, done = call('qbx_core', 'RemovePlayerFromGang', cid, org.slug)
    if not ok or not done then return false, MSG.sin_servicio end
    audit(org, 'kick', player, cid)
    local p = playerByCitizen(cid)
    if p then notify(p.PlayerData.source, ('Te han expulsado de «%s».'):format(org.name), 'error') end
    return true, ('%s ya no pertenece a la organización.'):format(memberName(cid, p))
end

local function setGrade(src, cid, new)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.hasPerm(grade, 'manage', Config) then return false, MSG.permiso end
    if type(cid) ~= 'string' then return false, MSG.miembro end
    if cid == player.PlayerData.citizenid then return false, MSG.propio end
    local tg = memberGrade(org, cid)
    if not tg then return false, MSG.miembro end
    new = tonumber(new)
    if not O.validGradeChange(grade, tg, new, Config) then return false, MSG.rango end
    local ok, done = call('qbx_core', 'AddPlayerToGang', cid, org.slug, new)
    if not ok or not done then return false, MSG.sin_servicio end
    audit(org, new > tg and 'promote' or 'demote', player, cid, nil, ('%d → %d'):format(tg, new))
    local p = playerByCitizen(cid)
    if p then notify(p.PlayerData.source, ('Tu rango en «%s» ahora es %s.'):format(org.name, O.gradeName(org.type, new, Config)), 'inform') end
    return true, ('%s ahora es %s.'):format(memberName(cid, p), O.gradeName(org.type, new, Config))
end

local function transfer(src, cid)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.isLeader(grade, Config) then return false, MSG.permiso end
    if type(cid) ~= 'string' then return false, MSG.miembro end
    if cid == player.PlayerData.citizenid then return false, MSG.propio end
    if not memberGrade(org, cid) then return false, MSG.miembro end
    local top = O.topGrade(Config)
    local ok, done = call('qbx_core', 'AddPlayerToGang', cid, org.slug, top)
    if not ok or not done then return false, MSG.sin_servicio end
    call('qbx_core', 'AddPlayerToGang', player.PlayerData.citizenid, org.slug, top - 1)
    Store.setLeader(org.id, cid, now())
    org.leader_citizenid = cid
    audit(org, 'transfer', player, cid)
    local p = playerByCitizen(cid)
    if p then notify(p.PlayerData.source, ('Ahora lideras «%s».'):format(org.name), 'success') end
    return true, ('Liderazgo transferido a %s.'):format(memberName(cid, p))
end

local function leave(src)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if O.isLeader(grade, Config) then return false, MSG.lider end
    local ok, done = call('qbx_core', 'RemovePlayerFromGang', player.PlayerData.citizenid, org.slug)
    if not ok or not done then return false, MSG.sin_servicio end
    audit(org, 'leave', player, player.PlayerData.citizenid)
    return true, ('Has salido de «%s».'):format(org.name)
end

local function dissolveOwn(src, confirmName)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.isLeader(grade, Config) then return false, MSG.permiso end
    if type(confirmName) ~= 'string' or O.nameKey(confirmName) ~= org.name_key then return false, MSG.confirmar end
    local ok, why = dissolve(org, player, 'disuelta por quien la lideraba')
    if not ok then return false, why end
    return true, ('«%s» se ha disuelto. Los fondos se ingresaron en tu banco.'):format(org.name)
end

local function deposit(src, amount, method)
    local player, org = actor(src)
    if not player then return false, org end
    if type(method) ~= 'string' or not Config.funds.methods[method] then return false, MSG.metodo end
    amount = O.amount(amount, Config.funds.maxOperation)
    if not amount then return false, MSG.importe end
    if not ensureAccount(org) then return false, MSG.banco end
    if busy[org.id] then return false, MSG.en_curso end
    busy[org.id] = true
    local ok, done, code = pcall(chargeToOrg, src, method, amount, org, ('pxd-org-aporte-%d'):format(org.id), fullName(player))
    busy[org.id] = nil
    if not ok then print('[pxd_orgs] error al aportar: ' .. tostring(done)) return false, MSG.sin_servicio end
    if not done then return false, MSG[code] or MSG.banco end
    audit(org, 'deposit', player, nil, amount, method)
    return true, ('Aportaste %s a «%s».'):format(money(amount), org.name)
end

local function withdraw(src, amount)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.hasPerm(grade, 'funds', Config) then return false, MSG.permiso end
    amount = O.amount(amount, Config.funds.maxOperation)
    if not amount then return false, MSG.importe end
    local have = ensureAccount(org)
    if not have then return false, MSG.banco end
    if have < amount then return false, MSG.fondos_org end
    if busy[org.id] then return false, MSG.en_curso end
    busy[org.id] = true
    local ok, a, b = pcall(function()
        local okR, removed = call(RB, 'removeAccountMoney', org.slug, amount)
        if not okR or not removed then return false, MSG.fondos_org end
        local okA, added = call('qbx_core', 'AddMoney', src, 'bank', amount, ('pxd-org-retiro-%d'):format(org.id))
        if not okA or not added then
            call(RB, 'addAccountMoney', org.slug, amount)
            return false, MSG.banco
        end
        bankLog(org, 'Retiro', amount, 'Retiro de fondos', fullName(player), 'withdraw')
        audit(org, 'withdraw', player, nil, amount)
        return true, ('Retiraste %s de «%s» a tu banco.'):format(money(amount), org.name)
    end)
    busy[org.id] = nil
    if not ok then print('[pxd_orgs] error al retirar: ' .. tostring(a)) return false, MSG.sin_servicio end
    return a, b
end

local function setIdentity(src, data)
    local player, org, grade = actor(src)
    if not player then return false, org end
    if not O.hasPerm(grade, 'identity', Config) then return false, MSG.permiso end
    local identity, why = O.identity(data, Config, org)
    if not identity then return false, MSG[why] end
    if not Store.setIdentity(org.id, identity, now()) then return false, MSG.sin_servicio end
    org.color, org.font, org.motto, org.emblem = identity.color, identity.font, identity.motto, identity.emblem
    audit(org, 'identity', player, nil, nil, ('%s · %s · %s'):format(identity.color, identity.font, identity.emblem))
    publishOrg(org)
    TriggerEvent('pxd_orgs:identityChanged', org.id, O.identityOf(org, Config))
    return true, 'Identidad actualizada.'
end

-- ── Staff ─────────────────────────────────────────────────────────────────────
local function staffName(src)
    if src == 0 then return 'Consola' end
    local p = getPlayer(src)
    return p and fullName(p) or GetPlayerName(src) or ('#' .. tostring(src))
end

local function approve(src, id)
    if not isStaff(src) then return false, MSG.permiso end
    local org = orgs[tonumber(id) or -1]
    if not org then return false, MSG.no_existe end
    local ok, why = makeOfficial(org, staffName(src), 'aprobada por el staff')
    if not ok then return false, why end
    return true, ('«%s» aprobada.'):format(org.name)
end

local function rejectRequest(src, id, reason)
    if not isStaff(src) then return false, MSG.permiso end
    local org = orgs[tonumber(id) or -1]
    if not org then return false, MSG.no_existe end
    reason = O.reason(reason)
    if not reason then return false, MSG.motivo end
    local ok, why = reject(org, staffName(src), reason)
    if not ok then return false, why end
    return true, ('Solicitud de «%s» rechazada.'):format(org.name)
end

local function staffDissolve(src, id, reason)
    if not isStaff(src) then return false, MSG.permiso end
    local org = find(id)
    if not org then return false, MSG.no_existe end
    reason = O.reason(reason)
    if not reason then return false, MSG.motivo end
    local ok, why = dissolve(org, src == 0 and 'Consola' or (getPlayer(src) or staffName(src)), reason)
    if not ok then return false, why end
    return true, ('«%s» disuelta.'):format(org.name)
end

-- ── Peticiones de la interfaz ─────────────────────────────────────────────────
-- write = true: cambia algo (límite de frecuencia más estricto). Cada acción devuelve ok, mensaje.
local RPC = {
    view = { fn = function() return true end },
    createStart = { write = true, fn = function(src, p) return startCreate(src, p) end },
    createConfirm = { write = true, fn = function(src) return confirmCreate(src) end },
    createCancel = { write = true, fn = function(src)
        local player = getPlayer(src)
        if player then dropDraft(player.PlayerData.citizenid, true) end
        return true, 'Fundación cancelada.'
    end },
    founderAnswer = { write = true, fn = function(src, p) return answerFounder(src, p.creator, p.accept == true) end },
    invite = { write = true, fn = function(src, p) return invite(src, p.target) end },
    inviteAnswer = { write = true, fn = function(src, p) return answerInvite(src, p.org, p.accept == true) end },
    inviteCancel = { write = true, fn = function(src, p) return cancelInvite(src, p.citizenid) end },
    kick = { write = true, fn = function(src, p) return kick(src, p.citizenid) end },
    setGrade = { write = true, fn = function(src, p) return setGrade(src, p.citizenid, p.grade) end },
    transfer = { write = true, fn = function(src, p) return transfer(src, p.citizenid) end },
    leave = { write = true, fn = function(src) return leave(src) end },
    dissolve = { write = true, fn = function(src, p) return dissolveOwn(src, p.confirm) end },
    deposit = { write = true, fn = function(src, p) return deposit(src, p.amount, p.method) end },
    withdraw = { write = true, fn = function(src, p) return withdraw(src, p.amount) end },
    identity = { write = true, fn = function(src, p) return setIdentity(src, p) end },
    approve = { write = true, fn = function(src, p) return approve(src, p.id) end },
    reject = { write = true, fn = function(src, p) return rejectRequest(src, p.id, p.reason) end },
    staffDissolve = { write = true, fn = function(src, p) return staffDissolve(src, p.id, p.reason) end },
}

RegisterNetEvent('pxd_orgs:server:rpc', function(reqId, action, payload)
    local src = source
    if type(reqId) ~= 'number' or type(action) ~= 'string' then return end
    local h = RPC[action]
    local res
    if not h then res = { ok = false, error = 'Acción no válida.' }
    elseif not ready then res = { ok = false, error = MSG.sin_servicio }
    elseif throttled(src, h.write) then res = { ok = false, error = MSG.rapido }
    else
        local ok, done, msg = pcall(h.fn, src, type(payload) == 'table' and payload or {})
        if not ok then
            -- En el siguiente tick: lo impreso durante la petición de un jugador no debe volver a su chat.
            local line = ('[pxd_orgs] error en %s: %s'):format(action, tostring(done))
            SetTimeout(0, function() print(line) end)
            res = { ok = false, error = MSG.sin_servicio }
        elseif done then res = { ok = true, message = msg, state = view(src) }
        else res = { ok = false, error = msg or MSG.sin_servicio, state = action ~= 'view' and view(src) or nil } end
    end
    TriggerClientEvent('pxd_orgs:client:rpc', src, reqId, res)
end)

-- ── Comandos de consola y staff ───────────────────────────────────────────────
local function reply(src, ok, msg)
    if src == 0 then print('[pxd_orgs] ' .. tostring(msg)) else notify(src, msg, ok and 'success' or 'error') end
end

RegisterCommand('org_pendientes', function(src)
    if not isStaff(src) then return end
    local n = 0
    for _, o in pairs(orgs) do
        if o.status == 'pending' then
            n = n + 1
            reply(src, true, ('#%d «%s» (%s) · solicitada por %s'):format(o.id, o.name, o.type, o.created_by))
        end
    end
    if n == 0 then reply(src, true, 'No hay solicitudes pendientes.') end
end, false)

RegisterCommand('org_aprobar', function(src, args)
    local ok, msg = approve(src, args[1])
    reply(src, ok, msg)
end, false)

RegisterCommand('org_rechazar', function(src, args)
    local ok, msg = rejectRequest(src, args[1], table.concat(args, ' ', 2))
    reply(src, ok, msg)
end, false)

RegisterCommand('org_disolver', function(src, args)
    local ok, msg = staffDissolve(src, args[1], table.concat(args, ' ', 2))
    reply(src, ok, msg)
end, false)

-- ── Exports para otros sistemas ───────────────────────────────────────────────
--- Organización por id o por banda de qbx_core («pxo_12»). nil si no existe o no está viva.
exports('GetOrg', function(idOrSlug)
    local org = find(idOrSlug)
    return org and O.publicOrg(org, Config) or nil
end)

--- Organización oficial de un jugador (id de servidor o citizenid) y su rango.
local function playerOrg(who)
    local p = type(who) == 'string' and playerByCitizen(who) or getPlayer(tonumber(who))
    if not p and type(who) == 'string' then
        local ok, off = call('qbx_core', 'GetOfflinePlayer', who)
        p = ok and off or nil
    end
    if not p then return nil end
    local org = orgOf(p.PlayerData)
    if not org or org.status ~= 'official' then return nil end
    return org, gradeIn(p.PlayerData, org)
end

exports('GetPlayerOrg', function(who)
    local org, grade = playerOrg(who)
    if not org then return nil end
    return O.publicOrg(org, Config), grade
end)

exports('IsMember', function(who, idOrSlug)
    local org = playerOrg(who)
    local want = find(idOrSlug)
    return org ~= nil and want ~= nil and org.id == want.id
end)

--- Permiso de rango: 'invite', 'manage', 'funds', 'identity' o 'leader'.
exports('HasPermission', function(who, perm)
    local org, grade = playerOrg(who)
    if not org then return false end
    if perm == 'leader' then return O.isLeader(grade, Config) end
    return O.hasPerm(grade, perm, Config)
end)

--- Identidad visual: { id, slug, name, type, color, font, fontFamily, motto, emblem }.
exports('GetIdentity', function(idOrSlug)
    local org = find(idOrSlug)
    return org and org.status == 'official' and O.identityOf(org, Config) or nil
end)

--- Suma (o resta) reputación con motivo. Devuelve la nueva reputación y el nivel, o nil, error.
local function addReputation(idOrSlug, amount, reason)
    if not ready then return nil, 'sin_servicio' end
    local org = find(idOrSlug)
    if not org or org.status ~= 'official' then return nil, 'no_existe' end
    reason = O.clean(reason, 120)
    if not reason then return nil, 'motivo' end
    local new = O.addReputation(org.reputation, amount, Config)
    if not new then return nil, 'importe' end
    local before = O.levelFor(org.reputation, Config).level
    if not Store.setReputation(org.id, new, now()) then return nil, 'sin_servicio' end
    org.reputation = new
    local after = O.levelFor(new, Config).level
    audit(org, 'reputation', GetInvokingResource() or 'sistema', nil, math.floor(amount), reason)
    TriggerEvent('pxd_orgs:reputationChanged', org.id, new, after)
    if after > before then
        TriggerEvent('pxd_orgs:levelUp', org.id, after)
        for _, r in ipairs(memberRows(org)) do
            local p = playerByCitizen(r.citizenid)
            if p then notify(p.PlayerData.source, ('«%s» sube al nivel %d.'):format(org.name, after), 'success') end
        end
    end
    return new, after
end
exports('AddReputation', addReputation)

--- Organizaciones vivas. filter = { type = 'banda', status = 'official' | 'pending' } (por defecto, oficiales).
exports('ListOrgs', function(filter)
    filter = type(filter) == 'table' and filter or {}
    local status = filter.status or 'official'
    local out = {}
    for _, o in pairs(orgs) do
        if o.status == status and (not filter.type or o.type == filter.type) then out[#out + 1] = O.publicOrg(o, Config) end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

--- Miembros (de qbx_core) con nombre y rango. Para el mapa de barrios y el panel de staff.
exports('GetMembers', function(idOrSlug)
    local org = find(idOrSlug)
    return org and org.status == 'official' and memberList(org) or {}
end)

-- Para pxd_admin: src = 0 es la consola; un jugador necesita el ACE pxd.orgs.manage.
exports('Approve', function(src, id) return approve(tonumber(src) or 0, id) end)
exports('Reject', function(src, id, reason) return rejectRequest(tonumber(src) or 0, id, reason) end)
exports('Dissolve', function(src, id, reason) return staffDissolve(tonumber(src) or 0, id, reason) end)

-- ── Estado de los jugadores ───────────────────────────────────────────────────
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not ready or type(player) ~= 'table' or not player.PlayerData then return end
    publish(player.PlayerData.source, player.PlayerData)
end)

AddEventHandler('QBCore:Server:OnGangUpdate', function(src, gang)
    if not ready or type(src) ~= 'number' then return end
    publish(src, { gang = gang })
    TriggerClientEvent('pxd_orgs:client:refresh', src)
end)

-- Entrar, salir o cambiar de rango en una banda (qbx_core avisa con el nombre del grupo).
AddEventHandler('qbx_core:server:onGroupUpdate', function(src, group)
    if not ready or type(src) ~= 'number' or not bySlug[group] then return end
    local p = getPlayer(src)
    if p then publish(src, p.PlayerData) end
    TriggerClientEvent('pxd_orgs:client:refresh', src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastCall[src] = nil
end)

-- ── Arranque ──────────────────────────────────────────────────────────────────
--- Recrea en qbx_core lo que falte de una organización oficial (banda, liderazgo y cuenta).
local function restore(org)
    if not gangExists(org) then
        if not createGang(org) then return end
        local ok, why = joinGang(org.leader_citizenid, org, O.topGrade(Config))
        print(('[pxd_orgs] ^3La banda %s («%s») no estaba en qbx_core y se ha recreado%s.^7'):format(org.slug, org.name,
            ok and '' or (' (liderazgo no restaurado: ' .. tostring(why) .. ')')))
    end
end

CreateThread(function()
    local ok, err = pcall(Store.init)
    if not ok then
        print('[pxd_orgs] ^1No se pudo preparar la base de datos: ' .. tostring(err) .. '^7')
        return
    end
    for _, row in ipairs(Store.loadLive()) do
        local org = remember(row)
        if org.status == 'pending' then org.founders = Store.founders(org.id) end
    end
    for _, org in pairs(orgs) do
        if org.status == 'official' then restore(org) end
    end
    ready = true
    if started(RB) and not bankPatched() then
        print('[pxd_orgs] ^3Renewed-Banking no tiene el parche de docs/42: la cuenta de una organización nueva estará disponible tras el siguiente reinicio.^7')
    end
    for _, id in ipairs(GetPlayers()) do
        local p = getPlayer(tonumber(id))
        if p then publish(tonumber(id), p.PlayerData) end
    end
end)

PXDOrgsServer = {   -- para pruebas
    isReady = function() return ready end, orgs = function() return orgs end, drafts = function() return drafts end,
    invites = function() return invites end, view = view, start = startCreate, confirm = confirmCreate, answerFounder = answerFounder,
    invite = invite, answerInvite = answerInvite, kick = kick, setGrade = setGrade, transfer = transfer, leave = leave,
    dissolveOwn = dissolveOwn, deposit = deposit, withdraw = withdraw, setIdentity = setIdentity, approve = approve,
    reject = rejectRequest, staffDissolve = staffDissolve, addReputation = addReputation, RB_MARK = RB_MARK,
}
