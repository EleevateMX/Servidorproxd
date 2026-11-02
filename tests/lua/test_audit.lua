-- Pruebas de pxd_audit: registro, consultas, respaldo JSON, migración idempotente y su uso
-- desde pxd_compat y pxd_justice. MariaDB simulada con la MISMA semántica que las consultas reales.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_audit/'
local FILES = { 'config.lua', 'shared/audit.lua', 'server/store.lua', 'server/migrate.lua', 'server/main.lua' }

local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

-- ── MariaDB simulada: pxd_audit + las tablas antiguas de pxd_justice ──────────
local db
local function newDb()
    db = { audit = {}, refs = {}, nextAudit = 1, created = 0, tables = {},
        fines = {}, nextFine = 1, fineEvents = {}, selects = 0, failInsert = false }
end

local function auditQuery(AQ, q, p)
    -- Reconstruye el filtro a partir de las cláusulas que montó server/store.lua.
    local i, f = 1, {}
    for _, k in ipairs({ 'category', 'action', 'source', 'target', 'actor', 'since' }) do
        if q:find(AQ.where[k], 1, true) then f[k] = p[i]; i = i + 1 end
    end
    local limit, offset = p[i], p[i + 1]
    local rows = {}
    for _, r in ipairs(db.audit) do
        local ok = true
        for _, k in ipairs({ 'category', 'action', 'source', 'target', 'actor' }) do
            if f[k] ~= nil and r[k] ~= f[k] then ok = false end
        end
        if f.since and r.created_at < f.since then ok = false end
        if ok then rows[#rows + 1] = copy(r) end
    end
    table.sort(rows, function(a, b) if a.created_at ~= b.created_at then return a.created_at > b.created_at end return a.id > b.id end)
    local out = {}
    for j = offset + 1, math.min(#rows, offset + limit) do out[#out + 1] = rows[j] end
    return out
end

local function addAudit(p)
    if p[8] ~= nil and db.refs[p[8]] then return false end
    local r = { id = db.nextAudit, created_at = p[1], category = p[2], action = p[3], actor = p[4], target = p[5],
        data = p[6], source = p[7], legacy_ref = p[8] }
    db.nextAudit = db.nextAudit + 1
    db.audit[#db.audit + 1] = r
    if r.legacy_ref then db.refs[r.legacy_ref] = true end
    return r.id
end

local function fakeMySQL()
    local AQ = PXDAuditStore.Q
    local JQ = PXDFineStore and PXDFineStore.Q or {}
    local M = {}
    M.query = { await = function(q, p)
        if q == AQ.create then db.created = db.created + 1; db.tables.pxd_audit = true return {} end
        if q:sub(1, #AQ.select) == AQ.select then return auditQuery(AQ, q, p) end
        if q == AQ.fineEvents or q == AQ.fineEventsNoJoin then
            db.selects = db.selects + 1
            local out = {}
            for _, e in ipairs(db.fineEvents) do
                if e.id > p[1] and #out < p[2] then
                    local r = copy(e)
                    if q == AQ.fineEvents then r.fine_citizenid = db.fines[e.fine_id] and db.fines[e.fine_id].citizenid or nil end
                    out[#out + 1] = r
                end
            end
            return out
        end
        if q == JQ.createFines then db.tables.pxd_fines = true return {} end
        if q == JQ.createEvents then db.tables.pxd_fine_events = true return {} end
        if q == JQ.events then
            local out = {}
            for _, e in ipairs(db.fineEvents) do if e.fine_id == p[1] then out[#out + 1] = copy(e) end end
            return out
        end
        error('consulta no simulada: ' .. q)
    end }
    M.insert = { await = function(q, p)
        if q == AQ.insert then
            if db.failInsert then error('conexión perdida') end
            if p[8] ~= nil and db.refs[p[8]] then error("Duplicate entry for key 'legacy_ref'") end   -- UNIQUE
            return addAudit(p)
        end
        if q == JQ.insert then
            local id = db.nextFine; db.nextFine = id + 1
            db.fines[id] = { id = id, citizenid = p[1], officer_citizenid = p[2], officer_name = p[3], reason = p[4], notes = p[5],
                amount = p[6], paid = 0, status = 'pending', society = p[7], record_ref = p[8], issued_at = p[9], updated_at = p[10] }
            return id
        end
        if q == JQ.event then
            local id = #db.fineEvents + 1
            db.fineEvents[id] = { id = id, fine_id = p[1], action = p[2], actor_citizenid = p[3], actor_name = p[4], amount = p[5], detail = p[6], created_at = p[7] }
            return id
        end
        error('insert no simulado: ' .. q)
    end }
    M.update = { await = function(q, p)
        if q == AQ.insertLegacy then return addAudit(p) and 1 or 0 end
        error('update no simulado: ' .. q)
    end }
    M.scalar = { await = function(q, p)
        if q == AQ.tableExists then return db.tables[p[1]] and 1 or 0 end
        if q == JQ.outstanding then
            local s = 0
            for _, r in pairs(db.fines) do if r.citizenid == p[1] and (r.status == 'pending' or r.status == 'partial') then s = s + r.amount - r.paid end end
            return s
        end
        error('scalar no simulado: ' .. q)
    end }
    M.single = { await = function(q, p)
        if q == JQ.get then local r = db.fines[p[1]] return r and copy(r) or nil end
        error('single no simulado: ' .. q)
    end }
    return M
end

-- Registros antiguos de ejemplo: 3 del hospital (pxd_compat) y 2 eventos de multas.
local COMPAT_FILE = Fx.json.encode({ nextId = 4, entries = {
    { id = 1, at = 1000, resource = 'pxd_compat', category = 'medical', action = 'confiscate', actor = 'system', target = 'CID7', data = { item = 'WEAPON_PISTOL', serial = 'ABC123' } },
    { id = 2, at = 1001, resource = 'pxd_compat', category = 'medical', action = 'confiscate', actor = 'system', target = 'CID7', data = { item = 'ammo-9', count = 24 } },
    { id = 3, at = 1002, resource = 'pxd_compat', category = 'medical', action = 'confiscate', target = 'CID8' },
} })

local function seedLegacy()
    db.tables.pxd_fines, db.tables.pxd_fine_events = true, true
    db.fines[1] = { id = 1, citizenid = 'CIT2', amount = 500, paid = 0, status = 'pending' }
    db.nextFine = 2
    db.fineEvents[1] = { id = 1, fine_id = 1, action = 'issue', actor_citizenid = 'COP1', actor_name = 'Ana Agente', amount = 500, detail = 'Exceso', created_at = 2000 }
    db.fineEvents[2] = { id = 2, fine_id = 1, action = 'edit', actor_name = 'consola', amount = 300, detail = '500 → 300 · rebaja', created_at = 2100 }
end

--- Arranca pxd_audit. opts: sql (true por defecto), legacy, onStart, files, oxmysql.
local function boot(opts)
    opts = opts or {}
    newDb()
    if opts.legacy then seedLegacy() end
    local files = opts.files or {}
    if opts.legacy then files['pxd_compat/data/audit.json'] = COMPAT_FILE end
    local sql = opts.sql ~= false
    Fx.reset({ resourceName = 'pxd_audit', files = files,
        resourceStates = { oxmysql = sql and (opts.oxmysql or 'started') or 'missing', pxd_audit = 'started' } })
    Config, PXDAuditLib, PXDAuditStore, PXDAuditMigrate, PXDAuditService, PXDFineStore = nil, nil, nil, nil, nil, nil
    MySQL = nil
    Fx.load(DIR, { 'config.lua', 'shared/audit.lua', 'server/store.lua' })
    if sql then MySQL = fakeMySQL() end
    if opts.onStart ~= nil then Config.migration.onStart = opts.onStart end
    if opts.config then opts.config(Config) end
    Fx.load(DIR, { 'server/migrate.lua', 'server/main.lua' })
end

local A = function() return Fx.exports.pxd_audit end
local function logged(pattern) for _, l in ipairs(Fx.logs) do if l:find(pattern) then return l end end end
local function count(pred) local n = 0 for _, r in ipairs(db.audit) do if pred(r) then n = n + 1 end end return n end

T.describe('pxd_audit · lógica pura', function()
    T.it('valida categoría, acción, actor, destino y tamaño de data', function()
        dofile(DIR .. 'shared/audit.lua')
        local ctx = { now = 50, source = 'pxd_x', encode = Fx.json.encode, limits = { data = 40 } }
        local row = PXDAuditLib.normalize({ category = 'fines', action = 'pay', actor = 'CIT2', target = 7, data = { a = 1 } }, ctx)
        T.eq(row.actor, 'CIT2'); T.eq(row.target, '7'); T.eq(row.source, 'pxd_x'); T.eq(row.created_at, 50); T.eq(row.data, '{"a":1}')
        T.eq(PXDAuditLib.normalize({ category = 'x', action = 'y' }, ctx).actor, 'system', 'sin actor es el sistema')
        T.eq(select(2, PXDAuditLib.normalize({ action = 'y' }, ctx)), 'category')
        T.eq(select(2, PXDAuditLib.normalize({ category = "a'; DROP", action = 'y' }, ctx)), 'category')
        T.eq(select(2, PXDAuditLib.normalize({ category = 'a', action = string.rep('y', 33) }, ctx)), 'action')
        T.eq(select(2, PXDAuditLib.normalize({ category = 'a', action = 'y', actor = { } }, ctx)), 'actor')
        T.eq(select(2, PXDAuditLib.normalize({ category = 'a', action = 'y', target = 'a\nb' }, ctx)), 'target')
        T.eq(select(2, PXDAuditLib.normalize({ category = 'a', action = 'y', data = 'texto' }, ctx)), 'data')
        local big = PXDAuditLib.normalize({ category = 'a', action = 'y', data = { s = string.rep('x', 100) } }, ctx)
        T.eq(Fx.json.decode(big.data).truncated, true, 'lo grande se guarda recortado, no se pierde')
    end)

    T.it('acota los filtros de consulta', function()
        local f = PXDAuditLib.normalizeFilter({ limit = 99999, offset = -3, since = '10' }, {})
        T.eq(f.limit, 500); T.eq(f.offset, 0); T.eq(f.since, 10)
        T.eq(PXDAuditLib.normalizeFilter(nil, {}).limit, 100)
        T.falsy(PXDAuditLib.normalizeFilter({ category = 'a b' }, {}))
        T.falsy(PXDAuditLib.normalizeFilter({ limit = 'mucho' }, {}))
        T.falsy(PXDAuditLib.normalizeFilter('todo', {}))
    end)

    T.it('las multas tienen el mismo formato en pxd_justice y en la migración', function()
        dofile(RES .. 'pxd_justice/shared/fines.lua')
        local a = PXDFines.auditEntry(9, 'pay', 'CIT2', 'Lía Ríos', 100, 'bank', 'CIT2')
        local b = PXDAuditLib.fineEntry(9, 'pay', 'CIT2', 'Lía Ríos', 100, 'bank', 'CIT2')
        T.eq(Fx.json.encode(a), Fx.json.encode(b))
    end)
end)

T.describe('pxd_audit · servidor con oxmysql', function()
    T.it('crea la tabla sin borrar nada y registra con Log', function()
        boot({ onStart = false })
        T.eq(db.created, 1)
        local id = A().Log({ category = 'economy', action = 'transfer', actor = 'CIT1', target = 'CIT2', data = { amount = 50 }, source = 'pxd_bank' })
        T.eq(id, 1)
        local r = db.audit[1]
        T.eq(r.category, 'economy'); T.eq(r.source, 'pxd_bank'); T.eq(r.data, '{"amount":50}'); T.falsy(r.legacy_ref)
        T.truthy(r.created_at > 0)
    end)

    T.it('rechaza entradas no válidas; nadie puede fijar legacy_ref ni antedatar desde Log', function()
        boot({ onStart = false })
        local id, err = A().Log({ action = 'x' })
        T.falsy(id); T.eq(err, 'category')
        T.falsy(A().Log('texto'))
        A().Log({ category = 'a', action = 'b', legacy_ref = 'compat:1', created_at = 5 })
        T.falsy(db.audit[1].legacy_ref)
        T.truthy(db.audit[1].created_at > 5, 'la hora la pone el servidor')
        T.eq(#db.audit, 1)
    end)

    T.it('consultas: filtros, orden más reciente primero, límite y desplazamiento', function()
        boot({ onStart = false })
        for i = 1, 5 do
            Fx.time = i
            A().Log({ category = i % 2 == 0 and 'fines' or 'medical', action = 'x', actor = 'A' .. i, target = 'CIT' .. (i % 2), data = { n = i } })
        end
        local all = A().Query({})
        T.eq(#all, 5)
        T.eq(A().Query({ category = 'fines' })[1].data.n, 4, 'data viene decodificado')
        T.eq(#A().Query({ target = 'CIT1' }), 3)
        T.eq(A().Query({ actor = 'A3' })[1].data.n, 3)
        local page = A().Query({ limit = 2, offset = 1 })
        T.eq(#page, 2)
        T.eq(page[1].id, all[2].id)
        T.falsy(A().Query({ category = 'a b' }))
    end)

    T.it('si la BD falla al escribir, la entrada va al respaldo JSON y no se pierde', function()
        boot({ onStart = false })
        db.failInsert = true
        local id = A().Log({ category = 'medical', action = 'confiscate', target = 'CID1' })
        T.truthy(id)
        T.eq(#db.audit, 0)
        local saved = Fx.json.decode(Fx.files['data/audit.json'])
        T.eq(#saved.entries, 1)
        T.truthy(logged('respaldo JSON'))
        -- …y la migración la sube a la tabla cuando la BD vuelve.
        db.failInsert = false
        local report = PXDAuditService.migrate()
        T.eq(report.audit_json.imported, 1)
        T.eq(db.audit[1].category, 'medical')
    end)
end)

T.describe('pxd_audit · respaldo JSON sin oxmysql', function()
    T.it('avisa en la consola y guarda en data/audit.json', function()
        boot({ sql = false, onStart = false })
        T.eq(PXDAuditService.backend(), 'json')
        T.truthy(logged('oxmysql no está disponible'))
        local id = A().Log({ category = 'medical', action = 'confiscate', actor = 'system', target = 'CID7', data = { item = 'WEAPON_PISTOL' } })
        T.eq(id, 1)
        local q = A().Query({ target = 'CID7' })
        T.eq(#q, 1); T.eq(q[1].data.item, 'WEAPON_PISTOL')
        T.eq(#Fx.json.decode(Fx.files['data/audit.json']).entries, 1)
    end)

    T.it('rota: las antiguas pasan a audit.1.json, .1 a .2…', function()
        boot({ sql = false, onStart = false, config = function(c) c.json.maxEntries = 4; c.json.keepAfterRotate = 2; c.json.rotateFiles = 2 end })
        for i = 1, 5 do A().Log({ category = 'a', action = 'b', data = { n = i } }) end
        local main = Fx.json.decode(Fx.files['data/audit.json'])
        T.eq(#main.entries, 2)
        local a1 = Fx.json.decode(Fx.files['data/audit.1.json'])
        T.eq(#a1.entries, 3); T.eq(a1.entries[1].id, 1)
        for i = 6, 8 do A().Log({ category = 'a', action = 'b', data = { n = i } }) end
        T.eq(Fx.json.decode(Fx.files['data/audit.2.json']).entries[1].id, 1, 'el archivo anterior se desplaza')
        T.eq(Fx.json.decode(Fx.files['data/audit.1.json']).entries[1].id, 4)
        T.eq(Fx.json.decode(Fx.files['data/audit.json']).nextId, 9, 'los ids siguen creciendo')
    end)

    T.it('espera a oxmysql si aún está arrancando', function()
        boot({ oxmysql = 'starting', onStart = false })
        T.falsy(PXDAuditService.backend())
        Fx.resourceStates.oxmysql = 'started'
        Fx.advance(1)
        T.eq(PXDAuditService.backend(), 'sql')
    end)
end)

T.describe('pxd_audit · migración', function()
    T.it('importa el hospital y las multas con su legacy_ref sin tocar los originales', function()
        boot({ legacy = true })
        T.eq(#db.audit, 5)
        local c1 = nil
        for _, r in ipairs(db.audit) do if r.legacy_ref == 'compat:1' then c1 = r end end
        T.eq(c1.category, 'medical'); T.eq(c1.created_at, 1000); T.eq(c1.source, 'pxd_compat'); T.eq(Fx.json.decode(c1.data).serial, 'ABC123')
        local f2 = nil
        for _, r in ipairs(db.audit) do if r.legacy_ref == 'fine_event:2' then f2 = r end end
        T.eq(f2.category, 'fines'); T.eq(f2.target, 'fine:1'); T.eq(f2.actor, 'system'); T.eq(f2.created_at, 2100)
        T.eq(Fx.json.decode(f2.data).citizenid, 'CIT2', 'con el citizenid de la multa (pxd_fines)')
        T.eq(Fx.json.decode(f2.data).actor_name, 'consola')
        T.eq(count(function(r) return r.legacy_ref == 'compat:3' and r.actor == 'system' end), 1, 'sin actor → system')
        -- Originales intactos.
        T.eq(Fx.files['pxd_compat/data/audit.json'], COMPAT_FILE)
        T.eq(#db.fineEvents, 2)
        T.truthy(logged('3 importadas, 0 omitidas'))
        T.truthy(logged('2 importadas, 0 omitidas'))
    end)

    T.it('es idempotente: dos ejecuciones dan el mismo resultado', function()
        boot({ legacy = true })
        local before = Fx.json.encode(db.audit)
        local r = PXDAuditService.migrate()
        T.eq(r.compat.imported, 0); T.eq(r.compat.skipped, 3)
        T.eq(r.fine_events.imported, 0); T.eq(r.fine_events.skipped, 2)
        T.eq(Fx.json.encode(db.audit), before, 'la tabla no cambia')
        -- Un evento nuevo en la tabla antigua solo añade ese.
        db.fineEvents[3] = { id = 3, fine_id = 1, action = 'cancel', actor_name = 'consola', amount = 300, created_at = 2200 }
        r = PXDAuditService.migrate()
        T.eq(r.fine_events.imported, 1); T.eq(r.fine_events.skipped, 2)
        T.eq(#db.audit, 6)
    end)

    T.it('lee pxd_fine_events por lotes', function()
        boot({ legacy = true, onStart = false, config = function(c) c.migration.batch = 1 end })
        local r = PXDAuditService.migrate()
        T.eq(r.fine_events.imported, 2)
        T.eq(db.selects, 3, 'dos lotes con datos y uno vacío')
    end)

    T.it('el comando pxd_audit_migrar solo funciona desde la consola e informa', function()
        boot({ legacy = true, onStart = false })
        Fx.commands.pxd_audit_migrar(1, {})
        T.eq(#db.audit, 0, 'un jugador no puede')
        Fx.commands.pxd_audit_migrar(0, {})
        T.eq(#db.audit, 5)
        T.truthy(logged('pxd_compat/data/audit.json: 3 importadas, 0 omitidas'))
        T.truthy(logged('pxd_fine_events: 2 importadas, 0 omitidas'))
        Fx.commands.pxd_audit_migrar(0, {})
        T.truthy(logged('pxd_compat/data/audit.json: 0 importadas, 3 omitidas'))
    end)

    T.it('sin oxmysql migra el hospital al JSON y explica por qué no las multas', function()
        boot({ legacy = true, sql = false })
        local q = A().Query({ category = 'medical' })
        T.eq(#q, 3)
        T.truthy(logged('pxd_fine_events: requiere oxmysql'))
        local r = PXDAuditService.migrate()
        T.eq(r.compat.imported, 0); T.eq(r.compat.skipped, 3)
        T.eq(#A().Query({}), 3, 'tampoco duplica en el JSON')
    end)

    T.it('al volver la BD, lo migrado al JSON no se duplica con la migración directa', function()
        -- Primero sin BD: el hospital se migra al JSON con legacy_ref 'compat:<id>'.
        boot({ legacy = true, sql = false })
        local jsonFile = Fx.files['data/audit.json']
        -- Después con BD y el mismo JSON: compat:<id> aparece una sola vez.
        boot({ legacy = true, files = { ['data/audit.json'] = jsonFile } })
        T.eq(count(function(r) return r.category == 'medical' end), 3)
        T.eq(#db.audit, 5)
    end)
end)

-- ── Integración real: pxd_compat y pxd_justice escribiendo en pxd_audit ──────
local function loadAs(name, dir, files)
    Fx.resourceName = name
    Config = nil
    Fx.load(dir, files)
end

T.describe('pxd_audit · con pxd_compat', function()
    T.it('Audit y GetAudit de pxd_compat delegan en pxd_audit', function()
        boot({ onStart = false })
        Fx.resourceStates.pxd_compat = 'started'
        PXDAudit = nil
        loadAs('pxd_compat', RES .. 'pxd_compat/', { 'config.lua', 'server/audit.lua' })
        local id = PXDAudit.audit({ category = 'medical', action = 'confiscate', actor = 'system', target = 'CID7', data = { item = 'WEAPON_PISTOL' } })
        T.eq(id, 1)
        T.eq(db.audit[1].category, 'medical'); T.eq(db.audit[1].source, 'pxd_compat')
        T.falsy(Fx.files['data/audit.json'], 'no escribe su JSON')
        local list = PXDAudit.get({ category = 'medical', target = 'CID7' })
        T.eq(#list, 1); T.eq(list[1].data.item, 'WEAPON_PISTOL'); T.truthy(list[1].at)
    end)
end)

T.describe('pxd_audit · con pxd_justice', function()
    local players, notes
    local function bootJustice(opts)
        opts = opts or {}
        boot({ legacy = opts.legacy, onStart = opts.onStart or false })
        players, notes = {}, {}
        local cit = { PlayerData = { source = 2, citizenid = 'CIT2', charinfo = { firstname = 'Lía', lastname = 'Ríos' },
            job = { type = 'none' }, money = { cash = 0, bank = 0 } } }
        players[2] = cit
        Fx.exports.qbx_core = {
            GetPlayer = function(src) return players[tonumber(src)] end,
            GetPlayerByCitizenId = function(cid) for _, p in pairs(players) do if p.PlayerData.citizenid == cid then return p end end end,
            Notify = function(src, text) notes[#notes + 1] = { src = src, text = text } end,
        }
        Fx.resourceStates.qbx_core = 'started'
        Fx.resourceStates.pxd_justice = 'started'
        Fx.files['qbx_police/server/main.lua'] = '-- sin parche'
        PXDFines, PXDFineStore, PXDJustice = nil, nil, nil
        Fx.resourceName = 'pxd_justice'
        Config = nil
        Fx.load(RES .. 'pxd_justice/', { 'config.lua', 'shared/fines.lua', 'server/store.lua' })
        -- Misma BD simulada, ahora también con las consultas de pxd_justice.
        MySQL = fakeMySQL()
        Fx.load(RES .. 'pxd_justice/', { 'server/main.lua' })
        Fx.addPlayer(2, 'ciudadana')
    end

    T.it('IssueSystemFine deja la multa pendiente y la audita en pxd_audit como sistema', function()
        bootJustice()
        local id = Fx.exports.pxd_justice.IssueSystemFine('CIT2', 'Radar de velocidad', 250, { source = 'radar' })
        T.eq(id, 1)
        T.eq(db.fines[1].status, 'pending'); T.eq(db.fines[1].officer_name, 'Sistema')
        T.eq(#db.fineEvents, 0, 'pxd_fine_events ya no se escribe')
        local r = db.audit[1]
        T.eq(r.category, 'fines'); T.eq(r.action, 'issue'); T.eq(r.actor, 'system'); T.eq(r.target, 'fine:1'); T.eq(r.source, 'pxd_justice')
        local d = Fx.json.decode(r.data)
        T.eq(d.citizenid, 'CIT2'); T.eq(d.origin, 'radar'); T.eq(d.amount, 250)
        T.eq(Fx.playerStates[2].pxdFines, 250)
    end)

    T.it('GetFineEvents une lo migrado, lo antiguo sin migrar y lo nuevo, sin duplicados', function()
        bootJustice({ legacy = true })
        -- fine_event 1 y 2 en la tabla antigua; se migra solo hasta aquí.
        PXDAuditService.migrate()
        -- Un evento antiguo más que aún no se ha migrado y uno nuevo en pxd_audit.
        db.fineEvents[3] = { id = 3, fine_id = 1, action = 'pay_failed', actor_citizenid = 'CIT2', actor_name = 'Lía Ríos', amount = 100, created_at = 2150 }
        Fx.exports.pxd_audit.Log(PXDFines.auditEntry(1, 'cancel', nil, 'consola', 300, 'error', 'CIT2'))
        local ev = Fx.exports.pxd_justice.GetFineEvents(1)
        local actions = {}
        for _, e in ipairs(ev) do actions[#actions + 1] = e.action end
        T.eq(table.concat(actions, ','), 'issue,edit,pay_failed,cancel')
        T.eq(ev[1].id, 1, 'lo migrado conserva el id antiguo'); T.eq(ev[1].actor_citizenid, 'COP1')
        T.eq(ev[2].actor_citizenid, nil); T.eq(ev[2].actor_name, 'consola')
        T.eq(ev[4].audit_id, db.nextAudit - 1)
        PXDAuditService.migrate()
        T.eq(#Fx.exports.pxd_justice.GetFineEvents(1), 4, 'tras migrar todo, sigue sin duplicados')
    end)
end)
