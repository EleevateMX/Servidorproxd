-- Copias de seguridad y vuelta atrás de pxd_updater.
--
-- Antes de escribir CUALQUIER archivo (recursos pxd_*, parches y capas en recursos de
-- terceros), se guarda el contenido anterior en este mismo recurso, en archivos planos
-- dentro de data/ (SaveResourceFile no crea carpetas, así que no se usan subcarpetas):
--   data/bk_<id>_<n>.bak    contenido previo del archivo n
--   data/bk_<id>.json       { id, ref, fecha, motivo, estado, archivos = { {
--                             resource, path, existia, sha256Antes, sha256Despues, copia } } }
--   data/backups.json       { ids = { "<id más antiguo>", …, "<id más reciente>" } }
-- Solo se escribe en el propio recurso (SaveResourceFile siempre lo permite). FXServer no
-- tiene un native para borrar archivos de un recurso: al podar copias antiguas se vacían.
PXDUpdater = PXDUpdater or {}

local RES = GetCurrentResourceName()
local LIST = 'data/backups.json'
local function indexPath(id) return 'data/bk_' .. id .. '.json' end
local function copyPath(id, name) return 'data/bk_' .. id .. '_' .. name end
PXDUpdater.backupPaths = { list = LIST, index = indexPath, copy = copyPath }

local Backup = {}
Backup.__index = Backup
PXDUpdater.Backup = Backup

local function readJson(path)
    local raw = LoadResourceFile(RES, path)
    local ok, data = pcall(json.decode, raw or '')
    return ok and type(data) == 'table' and data or nil
end

local function writeJson(path, data)
    local text = json.encode(data)
    return SaveResourceFile(RES, path, text, #text)
end

--- Lista de ids de copias, de la más antigua a la más reciente.
function Backup.list()
    local data = readJson(LIST)
    return data and type(data.ids) == 'table' and data.ids or {}
end

--- Índice de una copia concreta (o nil).
function Backup.read(id)
    if type(id) ~= 'string' or not id:match('^[%w%-]+$') then return nil end
    return readJson(indexPath(id))
end

--- Id legible y ordenable: fecha UTC + ref corto (solo letras, números y guiones).
function Backup.makeId(ref, now)
    local stamp = os.date('!%Y%m%dT%H%M%SZ', now)
    local short = tostring(ref or 'local'):gsub('[^%w]', ''):sub(1, 10)
    if short == '' then short = 'local' end
    local id, n = stamp .. '-' .. short, 1
    local taken = {}
    for _, v in ipairs(Backup.list()) do taken[v] = true end
    while taken[id] do n = n + 1; id = ('%s-%s-%d'):format(stamp, short, n) end
    return id
end

--- Nueva sesión de copia. `motivo`: 'update' | 'patch' | 'overlay' | 'rollback'.
function Backup.new(ref, motivo)
    local self = setmetatable({}, Backup)
    self.index = { id = Backup.makeId(ref), ref = tostring(ref or ''), fecha = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        motivo = motivo or 'update', estado = 'en curso', archivos = {} }
    self.written = {}   -- entradas ya escritas en disco (para deshacer si algo falla)
    return self
end

--- Guarda la copia de `resource/path` y después escribe `body`.
--- Devuelve true; o false, motivo ('copia' si no se pudo guardar la copia —no se toca el
--- archivo— o 'escritura' si FXServer rechazó la escritura).
function Backup:write(resource, path, body)
    local prev = LoadResourceFile(resource, path)
    local n = #self.index.archivos + 1
    local entry = { resource = resource, path = path, existia = prev ~= nil,
        sha256Antes = prev and PXDUpdater.sha256(prev) or nil, sha256Despues = PXDUpdater.sha256(body) }
    if prev then
        entry.copia = ('%d.bak'):format(n)
        if not SaveResourceFile(RES, copyPath(self.index.id, entry.copia), prev, #prev) then return false, 'copia' end
    end
    self.index.archivos[n] = entry
    -- Se apunta en el índice ANTES de escribir: si el servidor se cae a mitad, la copia existe.
    if not writeJson(indexPath(self.index.id), self.index) then return false, 'copia' end
    if not SaveResourceFile(resource, path, body, #body) then
        entry.fallo = true
        return false, 'escritura'
    end
    self.written[#self.written + 1] = entry
    return true
end

--- Contenido de la copia de una entrada (o nil si el archivo no existía).
function Backup.content(id, entry)
    if not entry.existia or type(entry.copia) ~= 'string' then return nil end
    return LoadResourceFile(RES, copyPath(id, entry.copia))
end

--- Deshace lo escrito en esta sesión (en orden inverso). Devuelve restaurados, fallidos.
function Backup:revert()
    local ok, bad = 0, 0
    for i = #self.written, 1, -1 do
        local e = self.written[i]
        local prev = Backup.content(self.index.id, e) or ''
        if SaveResourceFile(e.resource, e.path, prev, #prev) then ok = ok + 1 else bad = bad + 1 end
    end
    self.written = {}
    self.index.estado = 'deshecha'
    writeJson(indexPath(self.index.id), self.index)
    return ok, bad
end

--- Cierra la sesión: queda en la lista de copias (si escribió algo) y poda las antiguas.
function Backup:commit(keep)
    if #self.written == 0 then return nil end
    self.index.estado = 'aplicada'
    writeJson(indexPath(self.index.id), self.index)
    local ids = Backup.list()
    ids[#ids + 1] = self.index.id
    keep = tonumber(keep) or 10
    while #ids > keep do
        local old = table.remove(ids, 1)
        local idx = Backup.read(old)
        for _, e in ipairs(idx and idx.archivos or {}) do
            if e.copia then SaveResourceFile(RES, copyPath(old, e.copia), '', 0) end
        end
        if idx then idx.estado = 'podada'; idx.archivos = {}; writeJson(indexPath(old), idx) end
    end
    writeJson(LIST, { ids = ids })
    return self.index.id
end

function Backup:count() return #self.written end

return Backup
