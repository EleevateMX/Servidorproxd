-- pxd_multichar (servidor): datos extra para la pantalla y validación del registro.
-- Crear, cargar y borrar personajes lo siguen haciendo los callbacks de qbx_core
-- (qbx_core:server:createCharacter / loadCharacter / deleteCharacter), que validan
-- propiedad, límites y tipos.

local RES = GetCurrentResourceName()
local statuses -- se define más abajo (estado R.I.P.)

-- ¿Sigue qbx_core gestionando los personajes? Entonces habría dos pantallas a la vez.
local qbxConfig = LoadResourceFile('qbx_core', 'config/client.lua')
local qbxManages = PXDChar.qbxManagesCharacters(qbxConfig)
if qbxManages then
    print(('^1[%s] qbx_core sigue gestionando los personajes. Pon «useExternalCharacters = true» en qbx_core/config/client.lua y reinicia el servidor. Mientras tanto %s no hace nada.^7'):format(RES, RES))
end

-- Nacionalidades de qbx_core (data/nationalities.lua devuelve una lista de textos).
local nationalities = {}
do
    local text = LoadResourceFile('qbx_core', 'data/nationalities.lua')
    local chunk = text and load(text, '@qbx_core/data/nationalities.lua', 't', {})
    local ok, list = false, nil
    if chunk then ok, list = pcall(chunk) end
    if ok and type(list) == 'table' then
        for i = 1, #list do
            if type(list[i]) == 'string' then nationalities[#nationalities + 1] = list[i] end
        end
    end
    if #nationalities == 0 then
        print(('^3[%s] No se pudo leer qbx_core/data/nationalities.lua; la nacionalidad será texto libre.^7'):format(RES))
    end
end

local function registrationOpts()
    return {
        nationalities = nationalities,
        limitNationalities = Config.limitNationalities and #nationalities > 0,
        dateMin = Config.dateMin,
        dateMax = Config.dateMax,
        profanity = Config.profanityWords,
    }
end

--- Resumen de progreso (nivel, XP, tiempo jugado) de cada personaje de la licencia.
local function summaries(source)
    if GetResourceState('pxd_progress') ~= 'started' then return {} end
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license2 and not license then return {} end
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT citizenid, metadata FROM players WHERE license = ? OR license = ?', { license, license2 })
    end)
    if not ok or type(rows) ~= 'table' then return {} end
    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        local meta = type(row.metadata) == 'string' and json.decode(row.metadata) or row.metadata
        local okSum, sum = pcall(function() return exports.pxd_progress:SummaryFromMetadata(meta or {}) end)
        if okSum and type(sum) == 'table' and type(row.citizenid) == 'string' then
            out[row.citizenid] = {
                level = tonumber(sum.level),
                xp = tonumber(sum.xp),
                xpNext = tonumber(sum.xpNext),
                playtime = tonumber(sum.playtime),
            }
        end
    end
    return out
end

lib.callback.register('pxd_multichar:server:setup', function(source)
    return {
        managedByQbx = qbxManages,
        nationalities = nationalities,
        limitNationalities = Config.limitNationalities and #nationalities > 0,
        summaries = summaries(source),
        statuses = statuses(source),
    }
end)

--- El cliente valida mientras escribes; aquí se valida de nuevo antes de crear.
lib.callback.register('pxd_multichar:server:checkRegistration', function(_, input)
    local data, err, field = PXDChar.validateRegistration(input, registrationOpts())
    if not data then return { ok = false, error = err, field = field } end
    return { ok = true, data = data }
end)

-- ¿Este personaje (ya cargado) necesita elegir su apartamento inicial?
-- Misma consulta que qbx_properties (server/apartmentselect.lua) antes de enseñar su pizarra.
lib.callback.register('pxd_multichar:server:needsApartment', function(source)
    if GetResourceState('qbx_properties') ~= 'started' then return false end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    local row = MySQL.single.await('SELECT id FROM properties WHERE owner = ? LIMIT 1', { player.PlayerData.citizenid })
    return row == nil
end)

-- ── Estado de los personajes (R.I.P.) ──────────────────────────────────
-- Solo la representación: vacía = todos activos. La mecánica de CK (quién marca a un
-- personaje como fallecido y con qué autorización) no está implementada todavía.
local statusReady = false
CreateThread(function()
    local ok, err = pcall(MySQL.query.await, [[CREATE TABLE IF NOT EXISTS pxd_character_status (
        citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
        status ENUM('active','dead') NOT NULL DEFAULT 'active',
        reason VARCHAR(255) NULL,
        set_by VARCHAR(100) NULL,
        set_at INT UNSIGNED NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    if ok then statusReady = true else print(('^3[%s] No se pudo preparar pxd_character_status: %s^7'):format(RES, tostring(err))) end
end)

--- citizenids de la licencia del jugador (para no tocar personajes ajenos).
local function ownedCitizenIds(source)
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license2 and not license then return {} end
    local ok, rows = pcall(MySQL.query.await, 'SELECT citizenid FROM players WHERE license = ? OR license = ?', { license, license2 })
    local out = {}
    if ok and type(rows) == 'table' then for _, r in ipairs(rows) do out[r.citizenid] = true end end
    return out
end

statuses = function(source)
    if not statusReady then return {} end
    local owned, list = ownedCitizenIds(source), {}
    for cid in pairs(owned) do list[#list + 1] = cid end
    if #list == 0 then return {} end
    local ok, rows = pcall(MySQL.query.await, ('SELECT citizenid, status FROM pxd_character_status WHERE citizenid IN (%s)'):format(('?,'):rep(#list):sub(1, -2)), list)
    local out = {}
    if ok and type(rows) == 'table' then for _, r in ipairs(rows) do out[r.citizenid] = r.status end end
    return out
end

lib.callback.register('pxd_multichar:server:statuses', function(source) return statuses(source) end)

-- ── Escenario del editor: bucket propio por jugador ────────────────────
-- qbx_core:SetPlayerBucket (server/functions.lua) actualiza también el state «instance».
-- Rango propio (Config.creator.bucketBase + id) para no chocar con pxd_gamemodes (60000+).
local inCreator = {}
lib.callback.register('pxd_multichar:server:enterCreator', function(source)
    local bucket = Config.creator.bucketBase + source
    inCreator[source] = true
    pcall(function() exports.qbx_core:SetPlayerBucket(source, bucket) end)
    return bucket
end)
lib.callback.register('pxd_multichar:server:leaveCreator', function(source)
    if not inCreator[source] then return true end
    inCreator[source] = nil
    pcall(function() exports.qbx_core:SetPlayerBucket(source, 0) end)
    return true
end)
AddEventHandler('playerDropped', function() inCreator[source] = nil end)

-- ── Apariencia: guardar en el formato de illenium y comprobarla ─────────
-- Igual que illenium-appearance 5.7.0 (server/framework/qb/main.lua → Framework.SaveAppearance):
-- todas inactivas, borrar la del mismo modelo y añadir la nueva activa. En una transacción
-- y después se relee para comprobar que corresponde al citizenid cargado.
local lastSave = {}
local function saveAppearance(source, look, strict)
    local now = GetGameTimer()
    if lastSave[source] and now - lastSave[source] < 1500 then return { ok = false, error = 'Espera un momento.' } end
    lastSave[source] = now
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return { ok = false, error = 'El personaje no está cargado.' } end
    local citizenid = player.PlayerData.citizenid
    local clean, why = PXDLook.sanitize(look, nil, strict)
    if not clean then return { ok = false, error = 'Apariencia no válida (' .. tostring(why) .. ').' } end
    local skin = json.encode(clean)
    local ok, err = pcall(MySQL.transaction.await, {
        { query = 'UPDATE playerskins SET active = 0 WHERE citizenid = ?', values = { citizenid } },
        { query = 'DELETE FROM playerskins WHERE citizenid = ? AND model = ?', values = { citizenid, clean.model } },
        { query = 'INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1)', values = { citizenid, clean.model, skin } },
    })
    if not ok or err == false then return { ok = false, error = 'No se pudo guardar la apariencia.' } end
    local row = MySQL.single.await('SELECT citizenid, model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    if not row or row.citizenid ~= citizenid or row.model ~= clean.model or row.skin ~= skin then
        return { ok = false, error = 'La apariencia guardada no coincide.' }
    end
    return { ok = true, citizenid = citizenid }
end
PXDCharServer = { saveAppearance = saveAppearance }   -- para pruebas

--- Creación y recuperación: modelo freemode obligatorio. Edición: el modelo actual.
lib.callback.register('pxd_multichar:server:saveAppearance', function(source, look, mode)
    return saveAppearance(source, look, mode == 'create' or mode == 'recover')
end)

--- ¿Tiene apariencia guardada un personaje propio? (para recuperar creaciones interrumpidas)
lib.callback.register('pxd_multichar:server:hasAppearance', function(source, citizenid)
    if type(citizenid) ~= 'string' or not ownedCitizenIds(source)[citizenid] then return true end
    local row = MySQL.single.await('SELECT id FROM playerskins WHERE citizenid = ? LIMIT 1', { citizenid })
    return row ~= nil
end)
