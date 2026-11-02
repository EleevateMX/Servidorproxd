-- pxd_chat (servidor): todo lo que se escribe en el chat es rol y solo lo ven los
-- jugadores cercanos. Lo decide el servidor con la posición de cada uno.
local limiter = PXDChat.newLimiter(Config.spam.max, Config.spam.window)

local function now() return os.time() end

local function system(target, text)
    TriggerClientEvent('chat:addMessage', target, { templateId = 'pxd_system', args = { text } })
end

-- Identidad (pxd_interact, opcional): ID público PROX-XXXX y a quién conoce cada uno.
local function interactOn() return GetResourceState('pxd_interact') == 'started' end

local function publicId(src)
    if not interactOn() then return nil end
    local ok, id = pcall(function() return exports.pxd_interact:GetPublicId(src) end)
    return ok and id or nil
end

local function knows(reader, id)
    if not id or not interactOn() then return false end
    local ok, res = pcall(function() return exports.pxd_interact:Knows(reader, id) end)
    return ok and res == true
end

local function charName(src)
    if GetResourceState('qbx_core') ~= 'started' then return GetPlayerName(src) end
    local ok, name = pcall(function()
        local p = exports.qbx_core:GetPlayer(src)
        local ci = p and p.PlayerData and p.PlayerData.charinfo
        return ci and (ci.firstname .. ' ' .. ci.lastname) or nil
    end)
    return ok and name or nil
end

local function loggedIn(src)
    if GetResourceState('qbx_core') ~= 'started' then return true end
    return Player(src).state.isLoggedIn == true
end

local function playersWithCoords()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            out[#out + 1] = { src = src, x = c.x, y = c.y, z = c.z, bucket = GetPlayerRoutingBucket(src) }
        end
    end
    return out
end

--- Envía un mensaje de rol a quien esté cerca de `src`.
local function speak(src, kind, rawText)
    if not loggedIn(src) then return end
    local text = PXDChat.clean(rawText, Config.maxLength)
    if not text then return end
    if not limiter.allow(src, now()) then
        return system(src, 'Vas muy rápido: espera un momento antes de volver a escribir.')
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local origin = GetEntityCoords(ped)
    local bucket = GetPlayerRoutingBucket(src)
    local all = {}
    for _, p in ipairs(playersWithCoords()) do
        if p.bucket == bucket then all[#all + 1] = p end -- nadie oye a través de mundos distintos
    end
    local id, name = publicId(src), charName(src)
    for _, target in ipairs(PXDChat.inRange(origin, all, Config.range[kind] or Config.range.say)) do
        local label = kind == 'ooc' and GetPlayerName(src) or PXDChat.label({
            self = target == src, knows = knows(target, id), name = name, publicId = id, unknown = Config.unknownLabel,
        })
        TriggerClientEvent('chat:addMessage', target, { templateId = 'pxd_' .. kind, args = { label, text } })
    end
    print(('[pxd_chat] %s %s (%s): %s'):format(kind, GetPlayerName(src), id or src, text))
end

-- Lo que se escribe sin comando: el personaje habla. Los comandos que no existen
-- llegan aquí como «/algo» (commandFallback del chat): solo se avisa al que escribió.
exports.chat:registerMessageHook(function(source, outMessage, hookRef)
    if source < 1 then return end -- consola: se deja pasar
    hookRef.cancel()
    local args = outMessage.args or {}
    local text = args[#args]
    if PXDChat.isCommand(text) then
        return system(source, 'Ese comando no existe.')
    end
    speak(source, 'say', text)
end)

local function command(name, kind)
    RegisterCommand(name, function(source, args)
        if source < 1 then return end
        speak(source, kind, table.concat(args, ' '))
    end, false)
end
command('do', 'do')
command('susurrar', 'whisper')
command('gritar', 'shout')
command('b', 'ooc')

-- /me lo tiene qbx_core (texto 3D sobre la cabeza con la state bag «me»).
-- Aquí se añade la línea de chat por proximidad. Sin qbx_core, /me es nuestro.
if GetResourceState('qbx_core') == 'missing' then
    command('me', 'me')
else
    AddStateBagChangeHandler('me', nil, function(bagName, _, value)
        if type(value) ~= 'string' or value == '' then return end
        local src = GetPlayerFromStateBagName(bagName)
        if src and src > 0 then speak(src, 'me', value) end
    end)
end

-- Anuncio a toda la ciudad (staff).
RegisterCommand('anuncio', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, Config.announceAce) then
        return system(source, 'No tienes permiso para hacer anuncios.')
    end
    local text = PXDChat.clean(table.concat(args, ' '), Config.maxLength)
    if not text then return end
    TriggerClientEvent('chat:addMessage', -1, { templateId = 'pxd_announce', args = { Config.announceLabel, text } })
end, false)

AddEventHandler('playerDropped', function() limiter.forget(source) end)
