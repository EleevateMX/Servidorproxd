-- Almacenes de pxd_audit: tabla `pxd_audit` en MariaDB (oxmysql) o, si no hay, el respaldo
-- data/audit.json con rotación. Todas las consultas SQL están aquí, siempre con parámetros.
-- Fechas como marca de tiempo UNIX (UTC).
local Cfg = Config
local RES = GetCurrentResourceName()

PXDAuditStore = {}
local S = PXDAuditStore

local COLS = '(created_at, category, action, actor, target, data, source, legacy_ref) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
local Q = {
    create = [[
CREATE TABLE IF NOT EXISTS `pxd_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `created_at` BIGINT NOT NULL,
  `category` VARCHAR(32) NOT NULL,
  `action` VARCHAR(32) NOT NULL,
  `actor` VARCHAR(64) NOT NULL DEFAULT 'system',
  `target` VARCHAR(64) DEFAULT NULL,
  `data` LONGTEXT DEFAULT NULL,
  `source` VARCHAR(64) NOT NULL,
  `legacy_ref` VARCHAR(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `legacy_ref` (`legacy_ref`),
  KEY `category_time` (`category`, `created_at`),
  KEY `target` (`target`),
  KEY `actor` (`actor`)
)]],
    insert = 'INSERT INTO pxd_audit ' .. COLS,
    -- Migración: si legacy_ref ya existe no inserta nada (0 filas afectadas) y no da error.
    insertLegacy = 'INSERT IGNORE INTO pxd_audit ' .. COLS,
    select = 'SELECT id, created_at, category, action, actor, target, data, source, legacy_ref FROM pxd_audit WHERE 1 = 1',
    where = {
        category = ' AND category = ?', action = ' AND action = ?', source = ' AND source = ?',
        target = ' AND target = ?', actor = ' AND actor = ?', since = ' AND created_at >= ?',
    },
    order = ' ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?',
    tableExists = 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
    fineEvents = 'SELECT e.id, e.fine_id, e.action, e.actor_citizenid, e.actor_name, e.amount, e.detail, e.created_at, f.citizenid AS fine_citizenid FROM pxd_fine_events e LEFT JOIN pxd_fines f ON f.id = e.fine_id WHERE e.id > ? ORDER BY e.id ASC LIMIT ?',
    fineEventsNoJoin = 'SELECT id, fine_id, action, actor_citizenid, actor_name, amount, detail, created_at FROM pxd_fine_events WHERE id > ? ORDER BY id ASC LIMIT ?',
}
S.Q = Q
local FILTERS = { 'category', 'action', 'source', 'target', 'actor', 'since' }

local function params(row)
    return { row.created_at, row.category, row.action, row.actor, row.target, row.data, row.source, row.legacy_ref }
end

-- ── MariaDB ────────────────────────────────────────────────────────────────

function S.sqlState() return MySQL ~= nil and GetResourceState('oxmysql') or 'missing' end

function S.initSql() MySQL.query.await(Q.create) end

--- Inserta una fila. Devuelve su id.
function S.sqlInsert(row) return MySQL.insert.await(Q.insert, params(row)) end

--- Inserta una fila migrada. true si se insertó; false si su legacy_ref ya estaba.
function S.sqlInsertLegacy(row) return (tonumber(MySQL.update.await(Q.insertLegacy, params(row))) or 0) > 0 end

function S.sqlQuery(f)
    local sql, p = { Q.select }, {}
    for _, k in ipairs(FILTERS) do
        if f[k] ~= nil then sql[#sql + 1] = Q.where[k]; p[#p + 1] = f[k] end
    end
    sql[#sql + 1] = Q.order
    p[#p + 1] = f.limit; p[#p + 1] = f.offset
    return MySQL.query.await(table.concat(sql), p) or {}
end

function S.sqlTableExists(name) return (tonumber(MySQL.scalar.await(Q.tableExists, { name })) or 0) > 0 end

--- Lote de pxd_fine_events con id > afterId (con el citizenid de la multa si existe pxd_fines).
function S.sqlFineEvents(afterId, limit, withFines)
    return MySQL.query.await(withFines and Q.fineEvents or Q.fineEventsNoJoin, { afterId, limit }) or {}
end

-- ── Respaldo JSON ───────────────────────────────────────────────────────────
-- Formato: { version = 1, fileId, nextId, refs = { [legacy_ref] = true }, entries = { fila… } }
-- (`data` de cada fila es texto JSON, igual que en la tabla).
local doc

local function archiveName(i) return (Cfg.json.file:gsub('%.json$', '')) .. '.' .. i .. '.json' end
S.archiveName = archiveName

local function readFile(path)
    local raw = LoadResourceFile(RES, path)
    if not raw or raw == '' then return nil end
    local data = json.decode(raw)
    return type(data) == 'table' and data or nil
end

function S.jsonDoc()
    if doc then return doc end
    local data = readFile(Cfg.json.file) or {}
    doc = {
        version = 1,
        fileId = data.fileId or (tostring(os.time()) .. tostring(math.random(1000, 9999))),
        nextId = math.tointeger(tonumber(data.nextId)) or 1,
        refs = type(data.refs) == 'table' and data.refs or {},
        entries = type(data.entries) == 'table' and data.entries or {},
    }
    return doc
end

function S.jsonReset() doc = nil end   -- para pruebas

local function save()
    local ok = SaveResourceFile(RES, Cfg.json.file, json.encode(doc), -1)
    if not ok then print(('[pxd_audit] ^1No se pudo escribir %s.^7'):format(Cfg.json.file)) end
    return ok
end

--- Mueve las entradas más antiguas a data/audit.1.json (y desplaza .1 → .2 …).
local function rotate()
    local max = Cfg.json.maxEntries
    if #doc.entries <= max then return end
    local keep = math.max(0, math.min(Cfg.json.keepAfterRotate or math.floor(max / 2), max))
    local cut = #doc.entries - keep
    local old = {}
    for i = 1, cut do old[i] = doc.entries[i] end
    local rest = {}
    for i = cut + 1, #doc.entries do rest[#rest + 1] = doc.entries[i] end
    doc.entries = rest
    local files = Cfg.json.rotateFiles or 0
    if files < 1 then
        print(('[pxd_audit] ^3Se descartan %d entradas antiguas del respaldo JSON (rotateFiles = 0).^7'):format(cut))
        return
    end
    if LoadResourceFile(RES, archiveName(files)) then
        print(('[pxd_audit] ^3Rotación: se sobrescribe %s (el archivo más antiguo).^7'):format(archiveName(files)))
    end
    for i = files, 2, -1 do
        local prev = LoadResourceFile(RES, archiveName(i - 1))
        if prev then SaveResourceFile(RES, archiveName(i), prev, -1) end
    end
    SaveResourceFile(RES, archiveName(1), json.encode({ version = 1, fileId = doc.fileId, entries = old }), -1)
    print(('[pxd_audit] Respaldo JSON rotado: %d entradas pasan a %s.'):format(cut, archiveName(1)))
end

--- Guarda una fila en el JSON. Devuelve su id, o false si su legacy_ref ya estaba.
function S.jsonInsert(row)
    S.jsonDoc()
    if row.legacy_ref then
        if doc.refs[row.legacy_ref] then return false end
        doc.refs[row.legacy_ref] = true
    end
    local e = {}
    for k, v in pairs(row) do e[k] = v end
    e.id = doc.nextId
    doc.nextId = doc.nextId + 1
    doc.entries[#doc.entries + 1] = e
    rotate()
    save()
    return e.id
end

function S.jsonQuery(f)
    S.jsonDoc()
    local matched = {}
    for _, e in ipairs(doc.entries) do
        if PXDAuditLib.matches(e, f) then matched[#matched + 1] = e end
    end
    table.sort(matched, PXDAuditLib.newerFirst)
    local out = {}
    for i = f.offset + 1, math.min(#matched, f.offset + f.limit) do out[#out + 1] = matched[i] end
    return out
end

--- Todas las filas del respaldo (principal y archivos rotados) y su fileId, para migrarlas a la BD.
function S.jsonAllForMigration()
    local out = {}
    local main = readFile(Cfg.json.file)
    local fileId = main and main.fileId
    for i = Cfg.json.rotateFiles or 0, 1, -1 do
        local a = readFile(archiveName(i))
        if a and type(a.entries) == 'table' then
            for _, e in ipairs(a.entries) do out[#out + 1] = { e = e, fileId = a.fileId or fileId } end
        end
    end
    if main and type(main.entries) == 'table' then
        for _, e in ipairs(main.entries) do out[#out + 1] = { e = e, fileId = fileId } end
    end
    return out
end

return S
