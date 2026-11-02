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

local CARD_OPTS = { serverName = Config.serverName, tagline = Config.tagline, icon = Config.cardIcon }

--- Presenta una tarjeta y espera la respuesta. Mientras no responda, la vuelve a
--- presentar unos segundos (los mensajes de progreso de otros recursos la tapan) y
--- cancela tras Config.cardTimeoutSec. Devuelve la respuesta o { timeout = true }.
local function ask(deferrals, card)
    local p = promise.new()
    local answered = false
    local raw = json.encode(card)
    local function onAnswer(data)
        if answered then return end
        answered = true
        p:resolve(type(data) == 'table' and data or {})
    end
    deferrals.presentCard(raw, onAnswer)
    CreateThread(function()
        local started = GetGameTimer()
        while not answered do
            Wait(1500)
            if answered then return end
            local elapsed = GetGameTimer() - started
            if elapsed >= Config.cardTimeoutSec * 1000 then
                answered = true
                p:resolve({ timeout = true })
                return
            end
            if elapsed <= Config.cardRefreshSec * 1000 then
                deferrals.presentCard(raw, onAnswer)
            end
        end
    end)
    return Citizen.Await(p)
end

local function accessOptions()
    local code = GetConvar(Config.accessCodeConvar, '')
    return { accessCode = code, codeHash = code ~= '' and GetHashKey(code) or nil, rulesVersion = Config.rulesVersion }
end

local function connect(src, name, deferrals)
    deferrals.update(('✦ %s · Preparando tu llegada…'):format(Config.serverName))
    Wait(0)

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
            local data = ask(deferrals, Login.codeCard(CARD_OPTS, err, attempts))
            if data.timeout then return deferrals.done('Se agotó el tiempo para escribir el código. Vuelve a conectarte.') end
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
        local data = ask(deferrals, Login.rulesCard(CARD_OPTS, Config.rules, name))
        if data.timeout then return deferrals.done('Se agotó el tiempo para aceptar las normas. Vuelve a conectarte.') end
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
end

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    -- Si algo falla aquí, nunca dejamos al jugador colgado en la conexión.
    local ok, err = pcall(connect, src, name, deferrals)
    if not ok then
        print(('[pxd_login] ERROR al conectar %s: %s'):format(tostring(name), tostring(err)))
        Wait(0)
        deferrals.done('Hubo un error en el login de Próxima RP. Inténtalo de nuevo y avisa al staff si se repite.')
    end
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
