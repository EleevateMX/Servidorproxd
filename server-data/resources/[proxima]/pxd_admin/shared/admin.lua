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

-- ── Permisos por acción ─────────────────────────────────────────────────────

-- target: 'required' (otro jugador), 'optional' (otro o uno mismo), 'self' (solo uno mismo), 'none'.
PXDAdmin.ACTIONS = {
    duty = { ace = 'pxd.admin', target = 'self', duty = false },
    ['goto'] = { ace = 'pxd.admin', target = 'required' },
    bring = { ace = 'pxd.admin', target = 'required' },
    back = { ace = 'pxd.admin', target = 'optional' },
    freeze = { ace = 'pxd.admin', target = 'required' },
    revive = { ace = 'pxd.admin', target = 'optional' },
    heal = { ace = 'pxd.admin', target = 'optional' },
    needs = { ace = 'pxd.admin', target = 'optional' },
    wounds = { ace = 'pxd.admin', target = 'optional' },
    spectate = { ace = 'pxd.admin', target = 'required' },
    noclip = { ace = 'pxd.admin', target = 'self' },
    invisible = { ace = 'pxd.admin', target = 'self' },
    tpm = { ace = 'pxd.admin', target = 'self' },
    car = { ace = 'pxd.admin', target = 'self' },
    dv = { ace = 'pxd.admin', target = 'self' },
    repair = { ace = 'pxd.admin', target = 'self' },
    announce = { ace = 'pxd.admin', target = 'none' },
    -- Sin modo servicio también (moderación de emergencia y contacto):
    message = { ace = 'pxd.admin', target = 'required', duty = false },
    kick = { ace = 'pxd.admin.kick', target = 'required', duty = false },
}

--- `hasAce(ace)` dice si el jugador tiene el ACE. Las acciones con ACE propio
--- (p. ej. kick) también se permiten con `pxd.admin.all`.
function PXDAdmin.can(action, hasAce)
    local a = PXDAdmin.ACTIONS[action]
    if not a then return false end
    if not hasAce('pxd.admin') then return false end
    if a.ace == 'pxd.admin' then return true end
    return hasAce(a.ace) or hasAce('pxd.admin.all')
end

--- ¿Hace falta estar de servicio (/duty) para esta acción?
function PXDAdmin.needsDuty(action)
    local a = PXDAdmin.ACTIONS[action]
    return a ~= nil and a.duty ~= false
end

-- Comandos de chat (todos piden ACE; los marcados con la acción piden servicio).
PXDAdmin.COMMANDS = {
    { name = 'duty', action = 'duty', args = '', desc = 'Entrar o salir de servicio: atuendo STAFF, etiqueta e invencible.' },
    { name = 'revivir', action = 'revive', args = '[id]', desc = 'Reanima a un jugador (o a ti).' },
    { name = 'vida', action = 'heal', args = '[id]', desc = 'Salud y armadura al máximo y quita heridas.' },
    { name = 'llenarnecesidades', action = 'needs', args = '[id]', desc = 'Hambre y sed al 100 y estrés a 0.' },
    { name = 'wounds', action = 'wounds', args = '[id]', desc = 'Muestra heridas por zona, sangrado y estado.' },
    { name = 'tp', action = 'goto', args = '<id>', desc = 'Ir con un jugador.' },
    { name = 'tpm', action = 'tpm', args = '', desc = 'Ir al marcador del mapa.' },
    { name = 'traer', action = 'bring', args = '<id>', desc = 'Traer a un jugador contigo.' },
    { name = 'volver', action = 'back', args = '[id]', desc = 'Volver (o devolver a alguien) a la posición anterior.' },
    { name = 'noclip', action = 'noclip', args = '', desc = 'Volar atravesando paredes (W/A/S/D, Espacio sube, Ctrl baja, Shift rápido).' },
    { name = 'invisible', action = 'invisible', args = '', desc = 'Hacerte invisible o visible.' },
    { name = 'congelar', action = 'freeze', args = '<id>', desc = 'Congelar o descongelar a un jugador.' },
    { name = 'coche', action = 'car', args = '<modelo>', desc = 'Sacar un vehículo (p. ej. /coche sultan).' },
    { name = 'dv', action = 'dv', args = '', desc = 'Borrar el vehículo en el que estás o el más cercano.' },
    { name = 'reparar', action = 'repair', args = '', desc = 'Reparar y limpiar tu vehículo.' },
    { name = 'anuncio', action = 'announce', args = '<texto>', desc = 'Aviso a toda la ciudad.' },
    { name = 'spectate', action = 'spectate', args = '<id>', desc = 'Espectar a un jugador (misma orden o la tecla del panel para salir).' },
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

return PXDAdmin
