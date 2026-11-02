-- Pruebas de pxd_chat: lógica pura y servidor (proximidad, nombres, anti-spam, comandos).
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_chat/'

T.describe('pxd_chat · lógica', function()
    dofile(DIR .. 'shared/chat.lua')
    T.it('limpia colores, espacios y recorta sin partir letras', function()
        T.eq(PXDChat.clean('  ^1hola   ~r~mundo  '), 'hola mundo')
        T.eq(PXDChat.clean('   '), nil)
        T.eq(PXDChat.clean('ñññ', 3), 'ñ…')
    end)
    T.it('anti-spam por ventana de tiempo', function()
        local l = PXDChat.newLimiter(2, 5)
        T.truthy(l.allow(1, 0)); T.truthy(l.allow(1, 1)); T.falsy(l.allow(1, 2))
        T.truthy(l.allow(2, 2), 'cada jugador tiene su cuenta')
        T.truthy(l.allow(1, 7), 'pasada la ventana, vuelve a dejar')
    end)
    T.it('nombre según si te conoce', function()
        local base = { name = 'Valeria Ríos', publicId = 'PROX-1234', unknown = 'Desconocido' }
        T.eq(PXDChat.label(base), 'Desconocido · PROX-1234')
        base.knows = true; T.eq(PXDChat.label(base), 'Valeria Ríos')
        T.eq(PXDChat.label({ self = true, name = 'Yo Mismo', unknown = 'Desconocido' }), 'Yo Mismo')
    end)
end)

local function boot()
    Fx.reset({ resourceName = 'pxd_chat', resourceStates = { qbx_core = 'started', pxd_interact = 'started', chat = 'started' } })
    local hook
    local stateHandlers = {}
    _G.AddStateBagChangeHandler = function(key, _, fn) stateHandlers[key] = fn end
    _G.GetPlayerFromStateBagName = function(bag) return tonumber(bag:match('player:(%d+)')) end
    Fx.exports.chat = { registerMessageHook = function(fn) hook = fn end }
    local ids = { [1] = 'PROX-0001', [2] = 'PROX-0002', [3] = 'PROX-0003' }
    local known = { [2] = { ['PROX-0001'] = true } }  -- el 2 conoce al 1
    Fx.exports.pxd_interact = {
        GetPublicId = function(src) return ids[src] end,
        Knows = function(reader, id) return known[reader] and known[reader][id] == true or false end,
    }
    local names = { [1] = { 'Valeria', 'Ríos' }, [2] = { 'Bruno', 'Salgado' }, [3] = { 'Ana', 'Lima' } }
    Fx.exports.qbx_core = { GetPlayer = function(src) return { PlayerData = { charinfo = { firstname = names[src][1], lastname = names[src][2] } } } end }
    Fx.addPlayer(1, 'steam1', { x = 0, y = 0, z = 0 }, { ['pxd.chat.announce'] = true })
    Fx.addPlayer(2, 'steam2', { x = 5, y = 0, z = 0 })
    Fx.addPlayer(3, 'steam3', { x = 100, y = 0, z = 0 })
    for i = 1, 3 do _G.Player(i).state.isLoggedIn = true end
    Config, PXDChat = nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/chat.lua', 'server/main.lua' })
    return function(src, text) local h = { cancel = function() end }; hook(src, { args = { 'steam', text } }, h) end, stateHandlers
end

local function msgs(target)
    local out = {}
    for _, s in ipairs(Fx.sentTo(target, 'chat:addMessage')) do out[#out + 1] = s.args[1] end
    return out
end

T.describe('pxd_chat · servidor', function()
    T.it('hablar: solo lo oyen los cercanos, con el nombre que cada uno conoce', function()
        local say = boot()
        say(1, 'hola, ¿qué tal?')
        local m1, m2, m3 = msgs(1), msgs(2), msgs(3)
        T.eq(#m1, 1); T.eq(m1[1].templateId, 'pxd_say'); T.eq(m1[1].args[1], 'Valeria Ríos', 'uno mismo ve su nombre')
        T.eq(#m2, 1); T.eq(m2[1].args[1], 'Valeria Ríos', 'el 2 la conoce')
        T.eq(#m3, 0, 'el 3 está a 100 m')
        Fx.movePlayer(3, { x = 8, y = 0, z = 0 })
        Fx.clearSent()
        say(1, 'otra vez')
        T.eq(msgs(3)[1].args[1], 'Desconocido · PROX-0001', 'el 3 no la conoce')
    end)

    T.it('comandos desconocidos y otros mundos (buckets)', function()
        local say = boot()
        say(1, '/vuelo')
        T.eq(msgs(1)[1].templateId, 'pxd_system'); T.eq(#msgs(2), 0)
        Fx.clearSent()
        Fx.players[2].bucket = 60000
        say(1, 'hola')
        T.eq(#msgs(2), 0, 'en una partida (otro bucket) no se oye la ciudad')
    end)

    T.it('susurrar, gritar, /do y /b con su alcance', function()
        boot()
        Fx.commands['susurrar'](1, { 'ven', 'aquí' })
        T.eq(#msgs(2), 0, 'a 5 m no llega un susurro (3 m)')
        Fx.commands['gritar'](1, { '¡cuidado!' })
        T.eq(msgs(2)[1].templateId, 'pxd_shout')
        Fx.commands['do'](1, { 'la', 'puerta', 'está', 'cerrada' })
        T.eq(msgs(2)[2].templateId, 'pxd_do'); T.eq(msgs(2)[2].args[2], 'la puerta está cerrada')
        Fx.commands['b'](1, { 'brb' })
        T.eq(msgs(2)[3].args[1], 'steam1', 'OOC muestra el nombre de FiveM')
    end)

    T.it('/me de qbx_core (state bag) también sale en el chat cercano', function()
        local _, handlers = boot()
        handlers.me('player:1', 'me', 'se ajusta la chaqueta')
        T.eq(msgs(2)[1].templateId, 'pxd_me'); T.eq(msgs(2)[1].args[2], 'se ajusta la chaqueta')
        handlers.me('player:1', 'me', nil)
        T.eq(#msgs(2), 1, 'el reinicio a nil no envía nada')
    end)

    T.it('anti-spam y anuncio solo para staff', function()
        local say = boot()
        for _ = 1, 5 do say(2, 'spam') end
        local last = msgs(2)[#msgs(2)]
        T.eq(last.templateId, 'pxd_system', 'el quinto mensaje se frena')
        Fx.clearSent()
        Fx.commands['anuncio'](2, { 'hola' })
        T.eq(msgs(2)[1].templateId, 'pxd_system')
        T.eq(#Fx.sentTo(-1, 'chat:addMessage'), 0)
        Fx.commands['anuncio'](1, { 'Evento', 'en', 'la', 'playa' })
        T.eq(Fx.sentTo(-1, 'chat:addMessage')[1].args[1].templateId, 'pxd_announce')
    end)
end)
