-- Lógica pura de pxd_orgs (sin natives ni base de datos). La usan el servidor y las pruebas.
PXDOrgs = {}
local O = PXDOrgs

O.MESSAGES = {
    sin_servicio = 'Las organizaciones no están disponibles ahora mismo.',
    rapido = 'Vas muy rápido. Espera un momento.',
    permiso = 'Tu rango no permite hacer eso.',
    sin_org = 'No perteneces a ninguna organización de Próxima.',
    no_existe = 'Esa organización no existe.',
    ya_en_org = 'Ya perteneces a una organización. Sal de ella primero.',
    ocupado = 'Esa persona ya pertenece a otra organización.',
    nombre = 'Nombre no válido: de %d a %d caracteres, solo letras, números, espacios, guiones, puntos y &.',
    nombre_usado = 'Ya existe una organización con ese nombre.',
    nombre_bloqueado = 'Ese nombre no se puede usar.',
    tipo = 'Ese tipo de organización no se puede crear.',
    color = 'Elige un color de la paleta.',
    fuente = 'Elige una tipografía de la lista.',
    emblema = 'El emblema son de 1 a 3 letras o números.',
    lema = 'El lema es demasiado largo.',
    requisitos = 'Aún no cumples los requisitos para fundar una organización.',
    fundadores = 'Faltan cofundadores cerca de ti.',
    fundador_no_valido = 'Uno de los cofundadores ya no está disponible.',
    espera = 'Ya enviaste una solicitud hace poco. Inténtalo más tarde.',
    borrador = 'Ya tienes una fundación en curso. Espera a tus cofundadores o cancélala.',
    pendiente = 'Ya tienes una solicitud pendiente de aprobación.',
    fondos = 'No tienes fondos suficientes.',
    fondos_org = 'La organización no tiene fondos suficientes.',
    banco = 'La cuenta de la organización no está disponible. No se movió dinero.',
    importe = 'Importe no válido.',
    metodo = 'Forma de pago no válida.',
    lejos = 'Esa persona está demasiado lejos.',
    jugador = 'Esa persona no está disponible.',
    llena = 'La organización está llena. Suban de nivel para tener más plazas.',
    invitado = 'Esa persona ya tiene una invitación de tu organización.',
    sin_invitacion = 'Esa invitación ya no es válida.',
    miembro = 'Esa persona no pertenece a tu organización.',
    rango = 'No puedes dar ni cambiar ese rango.',
    propio = 'No puedes hacerte eso a ti mismo.',
    lider = 'Quien lidera debe transferir el liderazgo o disolver la organización.',
    confirmar = 'Escribe el nombre exacto de la organización para confirmar.',
    en_curso = 'Hay otra operación en curso con esta organización. Inténtalo de nuevo.',
    motivo = 'Escribe un motivo (de 3 a 200 caracteres).',
    estado = 'Esa solicitud ya no está pendiente.',
}

-- ── Texto ─────────────────────────────────────────────────────────────────────
--- Texto de usuario: sin caracteres de control ni < >, sin espacios dobles. nil si queda vacío o es largo.
function O.clean(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('%c', ' '):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s%s+', ' ')
    local len = utf8.len(s)
    if s == '' or not len or len > max then return nil end
    return s
end

-- Letras con tilde permitidas en nombres (español y portugués) y su forma sin tilde.
local FOLD = {
    ['á'] = 'a', ['à'] = 'a', ['â'] = 'a', ['ã'] = 'a', ['ä'] = 'a', ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e',
    ['í'] = 'i', ['ì'] = 'i', ['î'] = 'i', ['ï'] = 'i', ['ó'] = 'o', ['ò'] = 'o', ['ô'] = 'o', ['õ'] = 'o', ['ö'] = 'o',
    ['ú'] = 'u', ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['ñ'] = 'n', ['ç'] = 'c',
    ['Á'] = 'a', ['À'] = 'a', ['Â'] = 'a', ['Ã'] = 'a', ['Ä'] = 'a', ['É'] = 'e', ['È'] = 'e', ['Ê'] = 'e', ['Ë'] = 'e',
    ['Í'] = 'i', ['Ì'] = 'i', ['Î'] = 'i', ['Ï'] = 'i', ['Ó'] = 'o', ['Ò'] = 'o', ['Ô'] = 'o', ['Õ'] = 'o', ['Ö'] = 'o',
    ['Ú'] = 'u', ['Ù'] = 'u', ['Û'] = 'u', ['Ü'] = 'u', ['Ñ'] = 'n', ['Ç'] = 'c',
}

--- Nombre válido de organización. Devuelve el nombre limpio o nil, código.
function O.validName(s, cfg)
    if type(s) ~= 'string' then return nil, 'nombre' end
    -- No se «limpia»: un nombre con caracteres raros se rechaza entero (así nadie cuela etiquetas).
    local name = s:gsub('^%s+', ''):gsub('%s+$', ''):gsub(' +', ' ')
    local len = utf8.len(name)
    if not len or len < cfg.name.min or len > cfg.name.max then return nil, 'nombre' end
    local letters = 0
    for _, cp in utf8.codes(name) do
        local ch = utf8.char(cp)
        if cp < 128 then
            if ch:match('%a') then letters = letters + 1
            elseif not ch:match('[%d %-%.&]') then return nil, 'nombre' end
        elseif FOLD[ch] then letters = letters + 1
        else return nil, 'nombre' end
    end
    if letters < 2 then return nil, 'nombre' end
    return name
end

--- Clave de unicidad: minúsculas, sin tildes ni separadores («Los Reyes» = «los-reyes»).
function O.nameKey(name)
    local out = {}
    for _, cp in utf8.codes(name) do
        local ch = utf8.char(cp)
        ch = FOLD[ch] or (cp < 128 and ch:lower() or '')
        if ch:match('[%l%d]') then out[#out + 1] = ch end
    end
    return table.concat(out)
end

function O.blocked(key, list)
    for _, b in ipairs(list or {}) do if key == b or (#b >= 5 and key:find(b, 1, true)) then return true end end
    return false
end

--- Emblema por iniciales: hasta 3 letras de las primeras palabras.
function O.emblemFrom(name)
    local out = {}
    for word in name:gmatch('[^%s%-%.&]+') do
        local first
        for _, cp in utf8.codes(word) do first = utf8.char(cp) break end
        first = first and (FOLD[first] or first):upper()
        if first and first:match('^[%u%d]$') then out[#out + 1] = first end
        if #out == 3 then break end
    end
    return #out > 0 and table.concat(out) or 'ORG'
end

function O.validEmblem(s)
    if type(s) ~= 'string' then return nil end
    s = s:upper()
    return s:match('^[%u%d][%u%d]?[%u%d]?$') and s or nil
end

function O.validColor(c, cfg)
    if type(c) ~= 'string' then return nil end
    c = c:lower()
    for _, v in ipairs(cfg.colors) do if v == c then return v end end
    return nil
end

function O.fontById(id, cfg)
    for _, f in ipairs(cfg.fonts) do if f.id == id then return f end end
    return nil
end

--- Identidad saneada a partir de lo que envía la interfaz. `base` = identidad actual o nombre para los valores por defecto.
--- Devuelve { color, font, motto, emblem } o nil, código.
function O.identity(input, cfg, base)
    input = type(input) == 'table' and input or {}
    base = base or {}
    local color = input.color ~= nil and O.validColor(input.color, cfg) or (input.color == nil and (base.color or cfg.colors[1]))
    if not color then return nil, 'color' end
    local fontId = input.font ~= nil and input.font or (base.font or cfg.fonts[1].id)
    if not O.fontById(fontId, cfg) then return nil, 'fuente' end
    local emblem = input.emblem ~= nil and O.validEmblem(input.emblem) or (input.emblem == nil and base.emblem)
    if not emblem then return nil, 'emblema' end
    local motto = base.motto
    if input.motto ~= nil then
        if input.motto == '' then motto = nil
        else
            motto = O.clean(input.motto, cfg.motto.max)
            if not motto then return nil, 'lema' end
        end
    end
    return { color = color, font = fontId, motto = motto, emblem = emblem }
end

-- ── Rangos y permisos ─────────────────────────────────────────────────────────
function O.topGrade(cfg)
    local top = 0
    for g in pairs(cfg.grades) do if g > top then top = g end end
    return top
end

function O.gradeName(orgType, grade, cfg)
    local names = cfg.gradeNames and cfg.gradeNames[orgType]
    return (names and names[grade]) or (cfg.grades[grade] and cfg.grades[grade].name) or ('Rango ' .. tostring(grade))
end

--- Rangos con el formato de qbx_core (CreateGangs): { [0] = { name, isboss?, bankAuth? }, … }.
function O.gradesFor(orgType, cfg)
    local out = {}
    for g, def in pairs(cfg.grades) do
        out[g] = { name = O.gradeName(orgType, g, cfg), isboss = def.isboss and true or nil, bankAuth = def.bankAuth and true or nil }
    end
    return out
end

function O.hasPerm(grade, perm, cfg)
    local def = grade and cfg.grades[grade]
    return def ~= nil and def.perms ~= nil and def.perms[perm] == true
end

function O.isLeader(grade, cfg) return grade ~= nil and grade == O.topGrade(cfg) end

--- ¿Puede `actor` expulsar a `target`? Solo a rangos inferiores.
function O.canActOn(actorGrade, targetGrade)
    return actorGrade ~= nil and targetGrade ~= nil and actorGrade > targetGrade
end

--- ¿Puede `actor` poner a `target` (rango actual) el rango `new`? El rango más alto solo se transfiere.
function O.validGradeChange(actorGrade, targetGrade, new, cfg)
    new = tonumber(new)
    if not new or new ~= math.floor(new) or not cfg.grades[new] then return false end
    if new == targetGrade or new >= O.topGrade(cfg) then return false end
    return O.canActOn(actorGrade, targetGrade) and new < actorGrade
end

-- ── Nivel ─────────────────────────────────────────────────────────────────────
--- Nivel según la reputación. Devuelve la fila del nivel y la del siguiente (o nil).
function O.levelFor(rep, cfg)
    rep = math.max(0, math.floor(tonumber(rep) or 0))
    local cur, nxt = cfg.levels[1], nil
    for i, l in ipairs(cfg.levels) do
        if rep >= l.rep then cur, nxt = l, cfg.levels[i + 1] end
    end
    return cur, nxt
end

--- Reputación tras sumar `amount` (entero, puede ser negativo). Devuelve la nueva o nil si no es válido.
function O.addReputation(current, amount, cfg)
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount == 0 or math.abs(amount) > cfg.maxReputationPerCall then return nil end
    return math.max(0, math.floor(tonumber(current) or 0) + amount)
end

-- ── Requisitos para fundar ────────────────────────────────────────────────────
--- ctx = { level (o nil si no hay pxd_progress), bank, founders (incluido quien crea), staff }.
--- Devuelve la lista para la interfaz y si se cumplen todos. El staff no necesita cumplirlos.
function O.requirements(ctx, cfg)
    local c = cfg.create
    local list = {}
    if c.minLevel and c.minLevel > 0 then
        local ok = ctx.level == nil or ctx.level >= c.minLevel
        list[#list + 1] = { id = 'level', ok = ok, label = ('Nivel %d de personaje'):format(c.minLevel),
            detail = ctx.level and ('Tienes nivel %d'):format(ctx.level) or 'No se exige ahora' }
    end
    if c.cost and c.cost > 0 then
        list[#list + 1] = { id = 'cost', ok = (ctx.bank or 0) >= c.cost, label = ('Tasa de registro de $%d (banco)'):format(c.cost),
            detail = ('Tienes $%d en el banco'):format(math.floor(ctx.bank or 0)) }
    end
    if c.minFounders and c.minFounders > 1 then
        list[#list + 1] = { id = 'founders', ok = (ctx.founders or 1) >= c.minFounders,
            label = ('%d fundadores en total, cerca de ti'):format(c.minFounders),
            detail = ('%d de %d'):format(ctx.founders or 1, c.minFounders) }
    end
    local all = true
    for _, r in ipairs(list) do if not r.ok then all = false end end
    return list, all or ctx.staff == true
end

-- ── Vistas ────────────────────────────────────────────────────────────────────
--- Identidad para otros sistemas (grafitis, mapa de barrios): export GetIdentity.
function O.identityOf(row, cfg)
    local font = O.fontById(row.font, cfg) or cfg.fonts[1]
    return { id = tonumber(row.id), slug = row.slug, name = row.name, type = row.type, color = row.color, font = font.id,
        fontFamily = font.family, motto = row.motto, emblem = row.emblem }
end

--- Organización tal como la ve la interfaz y los exports (sin datos internos).
function O.publicOrg(row, cfg)
    local lvl, nxt = O.levelFor(row.reputation, cfg)
    local out = O.identityOf(row, cfg)
    local t = cfg.types[row.type] or {}
    out.typeLabel = t.label or row.type
    out.status = row.status
    out.reputation = math.max(0, math.floor(tonumber(row.reputation) or 0))
    out.level, out.levelRep, out.nextRep, out.slots = lvl.level, lvl.rep, nxt and nxt.rep or nil, lvl.slots
    out.leader = row.leader_citizenid
    out.createdAt = tonumber(row.created_at)
    return out
end

--- Importe entero entre 1 y `max`.
function O.amount(n, max)
    n = tonumber(n)
    if not n or n ~= math.floor(n) or n < 1 or n > max then return nil end
    return math.tointeger(n) or n
end

function O.reason(s)
    local r = O.clean(s, 200)
    if not r or utf8.len(r) < 3 then return nil end
    return r
end

--- Quita invitaciones caducadas de { [citizenid] = { [orgId] = invitación } }.
function O.pruneInvites(map, now)
    for cid, byOrg in pairs(map) do
        for orgId, inv in pairs(byOrg) do if inv.expires <= now then byOrg[orgId] = nil end end
        if next(byOrg) == nil then map[cid] = nil end
    end
    return map
end

return O
