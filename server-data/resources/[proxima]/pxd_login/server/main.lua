-- Login de Próxima RP al conectar: código de acceso opcional + normas, con tarjetas
-- adaptativas (deferrals.presentCard). Recuerda a cada jugador por su licencia.
local Login = PXDLogin.Login
local RES = GetCurrentResourceName()
local players = {}   -- [license] = registro
local dirty = false

do
    local raw = LoadResourceFile(RES, Config.dataFile)
    local data = raw and raw ~= '' and json.decode(raw) or nil
    if type(data) == 'table' then
        for license, r in pairs(data) do
            local clean = Login.cleanRecord(r)
            if type(license) == 'string' and clean then players[license] = clean end
        end
    end
end

local function save()
    if not dirty then return end
    if SaveResourceFile(RES, Config.dataFile, json.encode(players), -1) then dirty = false end
end

CreateThread(function()
    while true do
        Wait(5000)
        save()
    end
end)
AddEventHandler('onResourceStop', function(name) if name == RES then save() end end)

--- Presenta una tarjeta y espera la respuesta del jugador.
local function ask(deferrals, card)
    local p = promise.new()
    deferrals.presentCard(json.encode(card), function(data) p:resolve(type(data) == 'table' and data or {}) end)
    return Citizen.Await(p)
end

local function accessOptions()
    local code = GetConvar(Config.accessCodeConvar, '')
    return { accessCode = code, codeHash = code ~= '' and GetHashKey(code) or nil, rulesVersion = Config.rulesVersion }
end

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(('Comprobando tu acceso a %s…'):format(Config.serverName))

    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then
        Wait(0)
        return deferrals.done('No encontramos tu licencia de Rockstar. Abre FiveM con tu cuenta y vuelve a intentarlo.')
    end

    local rec = players[license] or { rulesVersion = 0, visits = 0 }
    local opts = accessOptions()
    local step = Login.nextStep(rec, opts)

    if step == 'code' then
        local attempts, err = Config.maxCodeAttempts, nil
        while true do
            local data = ask(deferrals, Login.codeCard(Config.serverName, err, attempts))
            if Login.safeEquals(tostring(data.code or ''), opts.accessCode) then
                rec.codeHash = opts.codeHash
                break
            end
            attempts = attempts - 1
            if attempts <= 0 then
                print(('[pxd_login] %s (%s) falló el código de acceso'):format(name, license))
                return deferrals.done('Código de acceso incorrecto.')
            end
            err = 'Código incorrecto.'
        end
        step = Login.nextStep(rec, opts)
    end

    if step == 'rules' then
        local data = ask(deferrals, Login.rulesCard(Config.serverName, Config.rules, name))
        if data.submitId ~= 'accept' then
            return deferrals.done(('Necesitas aceptar las normas para jugar en %s.'):format(Config.serverName))
        end
        rec.rulesVersion = Config.rulesVersion
    end

    local t = os.time()
    local firstTime = rec.firstSeen == nil
    rec.firstSeen = rec.firstSeen or t
    rec.lastSeen = t
    rec.visits = (rec.visits or 0) + 1
    rec.name = name
    players[license] = rec
    dirty = true

    -- Datos para la pantalla de carga (window.nuiHandoverData).
    deferrals.handover({ name = name, firstTime = firstTime, serverName = Config.serverName })
    Wait(0)
    deferrals.done()
end)

-- Perfil para la pantalla de bienvenida.
RegisterNetEvent('pxd_login:server:ready', function()
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    local rec = license and players[license] or {}
    TriggerClientEvent('pxd_login:client:profile', src, {
        name = GetPlayerName(src),
        serverName = Config.serverName,
        firstTime = (rec.visits or 0) <= 1,
        visits = rec.visits or 1,
        canEditProps = IsPlayerAceAllowed(src, 'pxd.props.edit'),
        modesAvailable = GetResourceState('pxd_gamemodes') == 'started',
    })
end)

PXDLogin.players = function() return players end
