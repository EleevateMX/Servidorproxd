-- Pruebas del login al conectar (tarjetas adaptativas simuladas).
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_login/'

local function boot(opts)
    opts = opts or {}
    opts.resourceName = 'pxd_login'
    Fx.reset(opts)
    PXDLogin = nil
    Config = nil
    Fx.load(DIR, { 'config.lua', 'shared/login.lua', 'server/main.lua' })
end

--- Simula una conexión; `answers` responde a cada tarjeta en orden.
local function connect(src, name, answers)
    Fx.addPlayer(src, name, { x = 0, y = 0, z = 0 })
    local d = { cards = {}, updates = {}, result = nil }
    local i = 0
    d.defer = function() end
    d.update = function(m) d.updates[#d.updates + 1] = m end
    d.handover = function(h) d.handoverData = h end
    d.presentCard = function(card, cb)
        d.cards[#d.cards + 1] = Fx.json.decode(card)
        i = i + 1
        local answer = answers[i]
        if answer then cb(answer, Fx.json.encode(answer)) end
    end
    d.done = function(reason) d.result = reason or 'OK' end
    Fx.emit('playerConnecting', src, name, function() end, d)
    for _ = 1, 10 do Fx.advance(0) end
    return d
end

T.describe('pxd_login', function()
    T.it('sin código: pide aceptar normas una vez y recuerda al jugador', function()
        boot()
        local d = connect(1, 'Nova', { { submitId = 'accept' } })
        T.eq(d.result, 'OK')
        T.eq(#d.cards, 1)
        T.eq(d.cards[1].actions[1].id, 'accept')
        T.eq(d.handoverData.firstTime, true)
        -- Segunda conexión: ya no hay tarjetas.
        local d2 = connect(1, 'Nova', {})
        T.eq(d2.result, 'OK'); T.eq(#d2.cards, 0); T.eq(d2.handoverData.firstTime, false)
    end)

    T.it('rechaza a quien no acepta las normas', function()
        boot()
        local d = connect(1, 'Nova', { { submitId = 'decline' } })
        T.truthy(d.result:find('aceptar las normas'))
    end)

    T.it('código de acceso: reintentos y bloqueo', function()
        boot({ convars = { pxd_login_accessCode = 'proxima-dev-2026' } })
        local d = connect(1, 'Nova', { { code = 'x' }, { code = 'y' }, { code = 'z' } })
        T.eq(d.result, 'Código de acceso incorrecto.')
        T.eq(#d.cards, 3)
        local warn = d.cards[2].body[3].text
        T.truthy(warn:find('Intentos restantes: 2'))

        local ok = connect(2, 'Lumen', { { code = 'proxima-dev-2026' }, { submitId = 'accept' } })
        T.eq(ok.result, 'OK')
    end)

    T.it('si cambia el código, se vuelve a pedir', function()
        boot({ convars = { pxd_login_accessCode = 'codigo-uno' } })
        connect(1, 'Nova', { { code = 'codigo-uno' }, { submitId = 'accept' } })
        Fx.convars.pxd_login_accessCode = 'codigo-dos'
        local d = connect(1, 'Nova', {})
        T.eq(#d.cards, 1); T.eq(d.cards[1].body[3].id, 'code')
    end)

    T.it('si suben las normas (rulesVersion), se vuelven a pedir', function()
        boot()
        connect(1, 'Nova', { { submitId = 'accept' } })
        Config.rulesVersion = 2
        local d = connect(1, 'Nova', { { submitId = 'accept' } })
        T.eq(#d.cards, 1)
    end)

    T.it('persiste los registros en disco', function()
        boot()
        connect(1, 'Nova', { { submitId = 'accept' } })
        Fx.advance(6)
        local saved = Fx.files['data/players.json']
        T.truthy(saved and saved:find('license:1'))
        boot({ files = { ['data/players.json'] = saved } })
        T.eq(PXDLogin.players()['license:1'].rulesVersion, 1)
    end)

    T.it('sin licencia no puede entrar', function()
        boot()
        Fx.addPlayer(5, 'SinLicencia', { x = 0, y = 0, z = 0 }, {}, {})
        local result
        local d = { defer = function() end, update = function() end, presentCard = function() end,
            handover = function() end, done = function(r) result = r end }
        Fx.emit('playerConnecting', 5, 'SinLicencia', function() end, d)
        for _ = 1, 3 do Fx.advance(0) end
        T.truthy(result and result:find('licencia'))
    end)
end)
