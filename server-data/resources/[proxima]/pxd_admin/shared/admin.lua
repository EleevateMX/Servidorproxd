-- Lógica pura de pxd_admin: búsqueda de jugadores, reportes, límites y permisos.
-- Sin natives: recibe `now` (segundos) para poder probarse con Lua.
PXDAdmin = PXDAdmin or {}

local function lower(s) return tostring(s or ''):lower() end

-- ── Búsqueda de jugadores ───────────────────────────────────────────────────

--- ¿Coincide la fila de jugador con la búsqueda? Busca en ID, nombres, citizenid,
--- PROX-ID y trabajo. Vacía = todos.
function PXDAdmin.matchPlayer(p, query)
    local q = lower(query):gsub('^%s+', ''):gsub('%s+$', '')
    if q == '' then return true end
    if tostring(p.id) == q then return true end
    local hay = table.concat({
        lower(p.name), lower(p.charName), lower(p.citizenid), lower(p.proxId), lower(p.job),
    }, '\n')
    return hay:find(q, 1, true) ~= nil
end

function PXDAdmin.filterPlayers(list, query)
    local out = {}
    for _, p in ipairs(list or {}) do
        if PXDAdmin.matchPlayer(p, query) then out[#out + 1] = p end
    end
    table.sort(out, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
    return out
end

--- Busca el destino de un reporte por ID de servidor o PROX-ID entre los conectados.
--- @return table|nil fila del jugador
function PXDAdmin.resolveTarget(list, ref)
    local r = tostring(ref or ''):gsub('^%s+', ''):gsub('%s+$', ''):upper()
    if r == '' then return nil end
    for _, p in ipairs(list or {}) do
        if tostring(p.id) == r then return p end
        if p.proxId and tostring(p.proxId):upper() == r then return p end
    end
    return nil
end

-- ── Reportes ────────────────────────────────────────────────────────────────

PXDAdmin.STATES = { open = 'Nuevo', claimed = 'En curso', closed = 'Cerrado' }
PXDAdmin.MIN_TEXT, PXDAdmin.MAX_TEXT = 5, 600

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

--- Valida lo que manda el jugador. Devuelve los datos limpios o nil + motivo.
function PXDAdmin.validateReport(input, categories)
    if type(input) ~= 'table' then return nil, 'Datos no válidos.' end
    local kind = input.kind == 'player' and 'player' or (input.kind == 'help' and 'help' or nil)
    if not kind then return nil, 'Tipo de reporte no válido.' end
    local category
    for _, c in ipairs(categories or {}) do
        if c.id == input.category and (c.kind == nil or c.kind == kind) then category = c end
    end
    if not category then return nil, 'Elige una categoría.' end
    local text = trim(input.text)
    if #text < PXDAdmin.MIN_TEXT then return nil, 'Cuéntanos un poco más (mínimo 5 caracteres).' end
    if #text > PXDAdmin.MAX_TEXT then text = text:sub(1, PXDAdmin.MAX_TEXT) end
    local target = kind == 'player' and trim(input.target):sub(1, 16) or nil
    if kind == 'player' and (not target or target == '') then return nil, 'Indica el ID o el PROX-ID del jugador.' end
    return { kind = kind, category = category.id, categoryLabel = category.label, text = text, target = target }
end

function PXDAdmin.newReport(id, data, reporter, now)
    return {
        id = id, kind = data.kind, category = data.category, categoryLabel = data.categoryLabel,
        text = data.text, state = 'open', createdAt = now, updatedAt = now,
        reporter = { license = reporter.license, name = reporter.name, charName = reporter.charName, src = reporter.src },
        target = data.targetInfo, targetRef = data.target,
        staff = nil, messages = {}, note = nil,
    }
end

--- Transiciones permitidas: open → claimed → closed; reabrir no (se crea otro).
function PXDAdmin.canTransition(report, action)
    if not report then return false end
    if action == 'claim' then return report.state == 'open' or report.state == 'claimed' end
    if action == 'reply' then return report.state ~= 'closed' end
    if action == 'close' then return report.state ~= 'closed' end
    if action == 'goto' then return true end
    return false
end

function PXDAdmin.claim(report, staffName, now)
    if not PXDAdmin.canTransition(report, 'claim') then return false end
    report.state, report.staff, report.updatedAt = 'claimed', staffName, now
    return true
end

function PXDAdmin.reply(report, author, text, now, fromStaff)
    if not PXDAdmin.canTransition(report, 'reply') then return false, 'El reporte está cerrado.' end
    text = trim(text)
    if #text < 1 then return false, 'Escribe un mensaje.' end
    if #text > PXDAdmin.MAX_TEXT then text = text:sub(1, PXDAdmin.MAX_TEXT) end
    report.messages[#report.messages + 1] = { author = author, text = text, at = now, staff = fromStaff == true }
    if fromStaff and report.state == 'open' then report.state, report.staff = 'claimed', author end
    report.updatedAt = now
    return true
end

function PXDAdmin.close(report, staffName, note, now)
    if not PXDAdmin.canTransition(report, 'close') then return false end
    report.state, report.updatedAt = 'closed', now
    report.staff = report.staff or staffName
    report.note = trim(note):sub(1, 300)
    return true
end

--- Reportes de un jugador (por licencia), los más recientes primero.
function PXDAdmin.reportsOf(reports, license, max)
    local out = {}
    for _, r in ipairs(reports or {}) do
        if r.reporter and r.reporter.license == license then out[#out + 1] = r end
    end
    table.sort(out, function(a, b) return a.id > b.id end)
    while max and #out > max do table.remove(out) end
    return out
end

function PXDAdmin.openCount(reports, license)
    local n = 0
    for _, r in ipairs(reports or {}) do
        if r.state ~= 'closed' and (license == nil or (r.reporter and r.reporter.license == license)) then n = n + 1 end
    end
    return n
end

--- Mantiene como mucho `max` reportes: borra primero los cerrados más antiguos.
function PXDAdmin.prune(reports, max)
    while #reports > max do
        local idx
        for i, r in ipairs(reports) do if r.state == 'closed' then idx = i break end end
        table.remove(reports, idx or 1)
    end
    return reports
end

-- ── Límite de frecuencia ────────────────────────────────────────────────────

--- Ventana deslizante: como mucho `limit` usos de `key` cada `window` segundos.
function PXDAdmin.newLimiter(limit, window)
    return { limit = limit, window = window, hits = {} }
end

function PXDAdmin.allow(limiter, key, now)
    local list = limiter.hits[key] or {}
    local keep = {}
    for _, t in ipairs(list) do if now - t < limiter.window then keep[#keep + 1] = t end end
    if #keep >= limiter.limit then
        limiter.hits[key] = keep
        return false, math.ceil(limiter.window - (now - keep[1]))
    end
    keep[#keep + 1] = now
    limiter.hits[key] = keep
    return true
end

-- ── Roles y permisos ────────────────────────────────────────────────────────
-- Cada permiso es el ACE «pxd.admin.<permiso>». OJO: en FXServer los ACE son jerárquicos
-- («pxd.admin» permite también «pxd.admin.kick»), por eso ningún rol recibe «pxd.admin»
-- a secas: cada rol recibe sus permisos uno a uno.
-- Los grupos group.support / group.mod / group.admin ya existen en la receta de Qbox
-- (con herencia admin → mod → support); se añaden group.superadmin y group.dev.
PXDAdmin.PERMS = {
    ['panel'] = 'Abrir el panel y ver la lista de jugadores',
    ['reports'] = 'Atender reportes',
    ['players.goto'] = 'Ir a un jugador y volver',
    ['players.bring'] = 'Traer a un jugador',
    ['players.heal'] = 'Reanimar, curar, necesidades y heridas',
    ['players.message'] = 'Mensajes privados',
    ['players.spectate'] = 'Espectar',
    ['players.freeze'] = 'Congelar y descongelar',
    ['players.identity'] = 'Ver licencia, Discord, dinero e historial',
    ['players.ip'] = 'Ver la IP',
    ['players.kick'] = 'Expulsar',
    ['players.warn'] = 'Advertencias',
    ['players.ban'] = 'Banear y levantar baneos',
    ['noclip'] = 'Noclip, invisible e ir al marcador',
    ['announce'] = 'Anuncios a la ciudad',
    ['audit'] = 'Historial de acciones del staff',
    ['vehicles.spawn'] = 'Sacar vehículos de prueba',
    ['vehicles.manage'] = 'Reparar, limpiar, borrar y consultar vehículos',
    ['vehicles.owner'] = 'Cambiar la titularidad de un vehículo',
    ['world'] = 'Coordenadas, buckets y herramientas de desarrollo',
    ['props'] = 'Editor de props',
    ['qbxmenu'] = 'Menú avanzado de Qbox (trabajo, banda, datos)',
    ['economy.view'] = 'Consultar economía, multas y facturas',
    ['economy.correct'] = 'Corregir dinero de un jugador',
    ['staff.manage'] = 'Dar y quitar rangos de staff (/darrango, /quitarrango)',
}

PXDAdmin.ROLES = {
    { id = 'soporte', label = 'Soporte', group = 'group.support',
      perms = { 'panel', 'reports', 'players.goto', 'players.bring', 'players.heal', 'players.message' } },
    { id = 'moderador', label = 'Moderador', group = 'group.mod', inherits = 'group.support',
      perms = { 'players.spectate', 'players.freeze', 'players.kick', 'players.warn', 'players.identity', 'noclip',
                'announce', 'audit', 'vehicles.manage' } },
    { id = 'administrador', label = 'Administrador', group = 'group.admin', inherits = 'group.mod',
      perms = { 'players.ban', 'vehicles.spawn', 'world', 'props', 'economy.view', 'qbxmenu' } },
    { id = 'superadministrador', label = 'Superadministrador', group = 'group.superadmin', inherits = 'group.admin',
      perms = { 'players.ip', 'vehicles.owner', 'economy.correct', 'staff.manage' } },
    { id = 'desarrollador', label = 'Desarrollador', group = 'group.dev',
      perms = { 'panel', 'players.goto', 'noclip', 'vehicles.spawn', 'vehicles.manage', 'world', 'props' } },
}

local function roleByGroup(group)
    for _, r in ipairs(PXDAdmin.ROLES) do if r.group == group then return r end end
end

--- Permisos efectivos de un rol (con herencia). Devuelve un conjunto { [perm] = true }.
function PXDAdmin.rolePerms(id)
    local out, role = {}, nil
    for _, r in ipairs(PXDAdmin.ROLES) do if r.id == id then role = r end end
    local guard = 0
    while role and guard < 10 do
        for _, p in ipairs(role.perms) do out[p] = true end
        role = role.inherits and roleByGroup(role.inherits) or nil
        guard = guard + 1
    end
    return out
end

--- Líneas de permissions.pxd.cfg para la matriz (las usa la documentación y las pruebas).
function PXDAdmin.aceLines()
    local lines = {}
    for _, r in ipairs(PXDAdmin.ROLES) do
        if r.inherits then lines[#lines + 1] = ('add_principal %s %s'):format(r.group, r.inherits) end
        for _, p in ipairs(r.perms) do lines[#lines + 1] = ('add_ace %s pxd.admin.%s allow'):format(r.group, p) end
    end
    return lines
end

-- target: 'required' (otro jugador), 'optional' (otro o uno mismo), 'self', 'none'.
-- reason = true: motivo obligatorio (queda en la auditoría).
PXDAdmin.ACTIONS = {
    duty = { perm = 'panel', target = 'self' },
    ['goto'] = { perm = 'players.goto', target = 'required' },
    bring = { perm = 'players.bring', target = 'required' },
    back = { perm = 'players.goto', target = 'optional' },
    freeze = { perm = 'players.freeze', target = 'required' },
    revive = { perm = 'players.heal', target = 'optional' },
    heal = { perm = 'players.heal', target = 'optional' },
    needs = { perm = 'players.heal', target = 'optional' },
    wounds = { perm = 'players.heal', target = 'optional' },
    spectate = { perm = 'players.spectate', target = 'required', reason = true },
    message = { perm = 'players.message', target = 'required' },
    kick = { perm = 'players.kick', target = 'required', reason = true },
    warn = { perm = 'players.warn', target = 'required', reason = true },
    ban = { perm = 'players.ban', target = 'required', reason = true },
    unban = { perm = 'players.ban', target = 'none', reason = true },
    noclip = { perm = 'noclip', target = 'self' },
    invisible = { perm = 'noclip', target = 'self' },
    tpm = { perm = 'noclip', target = 'self' },
    car = { perm = 'vehicles.spawn', target = 'self' },
    repair = { perm = 'vehicles.manage', target = 'self' },
    clean = { perm = 'vehicles.manage', target = 'self' },
    dv = { perm = 'vehicles.manage', target = 'self' },
    vehinfo = { perm = 'vehicles.manage', target = 'self' },
    vehowner = { perm = 'vehicles.owner', target = 'none', reason = true },
    coords = { perm = 'world', target = 'self' },
    devtools = { perm = 'world', target = 'self' },
    props = { perm = 'props', target = 'self' },
    qbxmenu = { perm = 'qbxmenu', target = 'self' },
    announce = { perm = 'announce', target = 'none' },
    money = { perm = 'economy.correct', target = 'required', reason = true },
}

-- Consultas del panel (solo lectura) y el permiso que piden.
PXDAdmin.QUERIES = {
    detail = 'panel', history = 'panel', buckets = 'world', bans = 'players.ban',
    audit = 'audit', economy = 'economy.view', fines = 'economy.view', invoices = 'economy.view',
    vehicle = 'vehicles.manage',
}

--- ¿Tiene el permiso? `hasAce(ace)` = IsPlayerAceAllowed. pxd.admin.all (antiguo) lo da todo.
function PXDAdmin.has(perm, hasAce)
    if not PXDAdmin.PERMS[perm] then return false end
    return hasAce('pxd.admin.' .. perm) == true or hasAce('pxd.admin.all') == true
end

--- ¿Puede hacer la acción? Siempre pide además el permiso base del panel.
function PXDAdmin.can(action, hasAce)
    local a = PXDAdmin.ACTIONS[action]
    if not a then return false end
    if not PXDAdmin.has('panel', hasAce) then return false end
    return PXDAdmin.has(a.perm, hasAce)
end

--- Mapa de permisos para la interfaz (solo para mostrar u ocultar: el servidor vuelve a validar).
function PXDAdmin.permMap(hasAce)
    local out = {}
    for p in pairs(PXDAdmin.PERMS) do out[p] = PXDAdmin.has(p, hasAce) end
    return out
end

--- Nombre del rol más alto que tiene (para mostrarlo).
function PXDAdmin.roleLabel(hasAce)
    local best, dev
    for _, r in ipairs(PXDAdmin.ROLES) do
        local all = true
        for p in pairs(PXDAdmin.rolePerms(r.id)) do if not PXDAdmin.has(p, hasAce) then all = false break end end
        if all then if r.id == 'desarrollador' then dev = r.label else best = r.label end end
    end
    best = best or dev
    return best or (PXDAdmin.has('panel', hasAce) and 'Staff' or nil)
end

--- Motivo obligatorio: 3–200 caracteres, sin saltos de línea.
function PXDAdmin.validReason(v)
    if type(v) ~= 'string' then return nil, 'Indica el motivo.' end
    v = v:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #v < 3 then return nil, 'Indica el motivo (mínimo 3 caracteres).' end
    return v:sub(1, 200)
end

--- /anuncio sin modo servicio: desde la consola (src 0) o con el ACE de compatibilidad
--- `pxd.chat.announce` (antes lo daba pxd_chat).
function PXDAdmin.announceBypass(src, hasAce)
    if src == 0 then return true end
    return hasAce('pxd.chat.announce') == true
end

--- ¿Hace falta estar de servicio (/duty)? Solo si el servidor lo exige (Config.requireDuty)
--- y para acciones sobre el mundo; moderación, consultas y contacto nunca.
local NO_DUTY = { duty = true, message = true, kick = true, warn = true, ban = true, unban = true, money = true,
    vehowner = true, coords = true, devtools = true, props = true, qbxmenu = true, vehinfo = true }
function PXDAdmin.needsDuty(action, requireDuty)
    return requireDuty == true and PXDAdmin.ACTIONS[action] ~= nil and not NO_DUTY[action]
end

--- Corrección de dinero: { account = 'cash'|'bank', amount = entero ≠ 0 (negativo = retirar) }.
function PXDAdmin.validMoney(p, max)
    if type(p) ~= 'table' then return nil, 'Datos no válidos.' end
    if p.account ~= 'cash' and p.account ~= 'bank' then return nil, 'Elige efectivo o banco.' end
    local n = tonumber(p.amount)
    if not n or n ~= math.floor(n) or n == 0 then return nil, 'Importe no válido.' end
    if math.abs(n) > (max or 1000000) then return nil, ('Máximo %d por corrección.'):format(max or 1000000) end
    return { account = p.account, amount = math.floor(n) }
end

--- Duración de un baneo en horas (0 = permanente). Devuelve la fecha de fin (segundos UNIX).
PXDAdmin.PERMANENT = 2147483647   -- máximo de la columna expire (int(11)) de qbx_core
function PXDAdmin.banExpire(hours, now, maxHours)
    local h = tonumber(hours)
    if not h or h ~= math.floor(h) or h < 0 or h > (maxHours or 87600) then return nil, 'Duración no válida.' end
    if h == 0 then return PXDAdmin.PERMANENT end
    return now + h * 3600
end

--- Matrícula con forma razonable (como la guarda GTA: hasta 8 caracteres).
function PXDAdmin.validPlate(v)
    v = tostring(v or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')
    if not v:match('^[%w ]+$') or #v > 8 or #v < 1 then return nil end
    return v
end

--- citizenid de Qbox: letras y números.
function PXDAdmin.validCitizenId(v)
    v = tostring(v or ''):upper():gsub('%s', '')
    if not v:match('^%w+$') or #v > 16 then return nil end
    return v
end

-- Comandos de chat. Todos se validan en el servidor igual que el panel.
-- /admin y /noclip requieren el parche de qbx_adminmenu (docs/37) que renombra los suyos.
PXDAdmin.COMMANDS = {
    { name = 'duty', action = 'duty', args = '', desc = 'Entrar o salir de servicio: atuendo STAFF, etiqueta e invencible.' },
    { name = 'noclip', action = 'noclip', args = '', desc = 'Vuelo libre (W/A/S/D, Espacio sube, X baja, Shift rápido, rueda: velocidad).' },
    { name = 'volar', action = 'noclip', args = '', desc = 'Igual que /noclip.' },
    { name = 'revivir', action = 'revive', args = '[id]', desc = 'Reanima a un jugador (o a ti).' },
    { name = 'vida', action = 'heal', args = '[id]', desc = 'Salud y armadura al máximo y quita heridas.' },
    { name = 'llenarnecesidades', action = 'needs', args = '[id]', desc = 'Hambre y sed al 100 y estrés a 0.' },
    { name = 'wounds', action = 'wounds', args = '[id]', desc = 'Muestra heridas por zona, sangrado y estado.' },
    { name = 'ir', action = 'goto', args = '<id>', desc = 'Ir con un jugador.' },
    { name = 'irmarcador', action = 'tpm', args = '', desc = 'Ir al marcador del mapa.' },
    { name = 'traer', action = 'bring', args = '<id>', desc = 'Traer a un jugador contigo.' },
    { name = 'volver', action = 'back', args = '[id]', desc = 'Volver (o devolver a alguien) a la posición anterior.' },
    { name = 'invisible', action = 'invisible', args = '', desc = 'Hacerte invisible o visible.' },
    { name = 'congelar', action = 'freeze', args = '<id>', desc = 'Congelar o descongelar a un jugador.' },
    { name = 'coche', action = 'car', args = '<modelo>', desc = 'Sacar un vehículo de prueba (p. ej. /coche sultan).' },
    { name = 'borrarvehiculo', action = 'dv', args = '', desc = 'Borrar el vehículo en el que estás o el más cercano.' },
    { name = 'reparar', action = 'repair', args = '', desc = 'Reparar tu vehículo.' },
    { name = 'anuncio', action = 'announce', args = '<texto>', desc = 'Aviso a toda la ciudad.' },
    { name = 'spectate', action = 'spectate', args = '<id> <motivo>', desc = 'Espectar a un jugador (la tecla del panel sale).' },
}

--- Interpreta el argumento de jugador de un comando. Sin argumento: uno mismo
--- (si la acción lo admite). Devuelve el id o nil + motivo.
function PXDAdmin.commandTarget(action, arg, selfId)
    local a = PXDAdmin.ACTIONS[action]
    if not a then return nil, 'Acción desconocida.' end
    if a.target == 'self' or a.target == 'none' then return selfId end
    local id = tonumber(arg)
    if not id then
        if a.target == 'optional' then return selfId end
        return nil, 'Indica el ID del jugador.'
    end
    return math.floor(id)
end

--- Modelo de vehículo con forma razonable (la existencia la comprueba el cliente).
function PXDAdmin.validModel(name)
    name = tostring(name or ''):lower()
    if not name:match('^[%w_]+$') or #name > 32 then return nil end
    return name
end

-- Heridas (qbx_medical guarda la gravedad por zona en state bags del jugador).
PXDAdmin.BODY_PARTS = {
    { key = 'HEAD', label = 'Cabeza' }, { key = 'NECK', label = 'Cuello' }, { key = 'SPINE', label = 'Columna' },
    { key = 'UPPER_BODY', label = 'Torso' }, { key = 'LOWER_BODY', label = 'Abdomen' },
    { key = 'LARM', label = 'Brazo izq.' }, { key = 'LHAND', label = 'Mano izq.' }, { key = 'LFINGER', label = 'Dedos izq.' },
    { key = 'LLEG', label = 'Pierna izq.' }, { key = 'LFOOT', label = 'Pie izq.' },
    { key = 'RARM', label = 'Brazo der.' }, { key = 'RHAND', label = 'Mano der.' }, { key = 'RFINGER', label = 'Dedos der.' },
    { key = 'RLEG', label = 'Pierna der.' }, { key = 'RFOOT', label = 'Pie der.' },
}
PXDAdmin.SEVERITY = { 'Leve', 'Moderada', 'Grave', 'Muy grave' }
PXDAdmin.DEATH_STATES = { [1] = 'Consciente', [2] = 'Herido/a en el suelo', [3] = 'Inconsciente' }

--- `read(key)` devuelve el valor de un state bag. Resultado listo para mostrar.
function PXDAdmin.woundsReport(read)
    local parts = {}
    for _, p in ipairs(PXDAdmin.BODY_PARTS) do
        local v = read('qbx_medical:injuries:' .. p.key)
        local sev = type(v) == 'table' and (v.severity or v[1]) or v
        sev = tonumber(sev)
        if sev and sev > 0 then
            parts[#parts + 1] = { part = p.label, severity = sev, label = PXDAdmin.SEVERITY[math.min(sev, 4)] or tostring(sev) }
        end
    end
    local bleed = tonumber(read('qbx_medical:bleedLevel')) or 0
    local death = tonumber(read('qbx_medical:deathState'))
    return { parts = parts, bleed = bleed, state = PXDAdmin.DEATH_STATES[death] or 'Desconocido' }
end

-- ── Registro ────────────────────────────────────────────────────────────────

function PXDAdmin.logEntry(staff, action, target, detail, now)
    return { at = now, staff = staff, action = action, target = target, detail = detail and tostring(detail):sub(1, 200) or nil }
end

function PXDAdmin.pushCapped(list, item, max)
    list[#list + 1] = item
    while #list > max do table.remove(list, 1) end
    return list
end


-- ── Rangos desde el juego (/darrango, /quitarrango, /checkas) ─────────────────
PXDAdmin.ROLE_ALIASES = {
    soporte = 'soporte', support = 'soporte',
    mod = 'moderador', moderador = 'moderador',
    admin = 'administrador', administrador = 'administrador',
    superadmin = 'superadministrador', superadministrador = 'superadministrador',
    dev = 'desarrollador', desarrollador = 'desarrollador',
}

function PXDAdmin.roleById(id)
    for _, r in ipairs(PXDAdmin.ROLES) do if r.id == id then return r end end
end

--- Rol a partir de lo que escribe el staff («mod», «Admin»…). nil si no existe.
function PXDAdmin.resolveRole(text)
    if type(text) ~= 'string' then return nil end
    local id = PXDAdmin.ROLE_ALIASES[text:lower()]
    return id and PXDAdmin.roleById(id) or nil
end

--- ¿Puede dar este rol? Superadministrador solo desde la consola del servidor (el dueño).
function PXDAdmin.canGrant(isConsole, canManage, roleId)
    if isConsole then return true end
    if not canManage then return false, 'Necesitas el rango de superadministrador para dar rangos.' end
    if roleId == 'superadministrador' then return false, 'El rango de superadministrador solo se da desde la consola del servidor.' end
    return true
end

--- ¿Puede quitar el rango que tiene ahora el objetivo?
function PXDAdmin.canRevoke(isConsole, canManage, currentRoleId, isSelf)
    if isConsole then return true end
    if isSelf then return false, 'No puedes quitarte tu propio rango.' end
    if not canManage then return false, 'Necesitas el rango de superadministrador para quitar rangos.' end
    if currentRoleId == 'superadministrador' then return false, 'A un superadministrador solo se le quita el rango desde la consola.' end
    return true
end

-- Comandos que la consola debe permitir a pxd_admin para aplicar rangos.
PXDAdmin.SETUP_ACES = {
    'add_ace resource.pxd_admin command.add_principal allow',
    'add_ace resource.pxd_admin command.remove_principal allow',
}

--- ¿Llegó el rango? hasAce(ace) del jugador y principalAce(principal, ace). Devuelve true o false, causa.
function PXDAdmin.checkApplied(role, hasAce, principalAce)
    local need = next(PXDAdmin.rolePerms(role.id)) and 'pxd.admin.panel' or nil
    if not need or hasAce(need) then return true end
    if not principalAce(role.group, need) then
        return false, ('el grupo %s no tiene permisos: falta la matriz de roles de permissions.pxd.cfg (o ese archivo no se cargó con exec). Súbelo y reinicia.'):format(role.group)
    end
    return false, 'el servidor no deja a pxd_admin ejecutar add_principal. Pega en la consola: ' .. table.concat(PXDAdmin.SETUP_ACES, '  y  ') .. ' y repite el comando.'
end

--- Problemas de configuración que impiden dar rangos (se avisan en la consola al arrancar).
function PXDAdmin.setupProblems(principalAce)
    local out = {}
    if not principalAce('resource.pxd_admin', 'command.add_principal') then
        out[#out + 1] = '/darrango no podrá aplicar rangos: falta en permissions.pxd.cfg «' .. PXDAdmin.SETUP_ACES[1] .. '» y «' .. PXDAdmin.SETUP_ACES[2] .. '».'
    end
    if not principalAce('group.support', 'pxd.admin.panel') then
        out[#out + 1] = 'Falta la matriz de roles (group.support no tiene pxd.admin.panel): revisa permissions.pxd.cfg.'
    end
    return out
end

return PXDAdmin
