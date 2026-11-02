-- pxd_multichar (servidor): datos extra para la pantalla y validación del registro.
-- Crear, cargar y borrar personajes lo siguen haciendo los callbacks de qbx_core
-- (qbx_core:server:createCharacter / loadCharacter / deleteCharacter), que validan
-- propiedad, límites y tipos.

local RES = GetCurrentResourceName()

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
