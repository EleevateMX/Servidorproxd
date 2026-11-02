-- Pruebas de la lógica pura del HUD (pxd_hud/shared/hud.lua).
local T = _G.T
PXDHud = nil
dofile(RES .. 'pxd_hud/shared/hud.lua')
local H = PXDHud

T.describe('pxd_hud · formato y barras', function()
    T.it('formatea dinero con separador de miles', function()
        T.eq(H.formatMoney(95846), '$95,846')
        T.eq(H.formatMoney(778358), '$778,358')
        T.eq(H.formatMoney(0), '$0')
        T.eq(H.formatMoney(999), '$999')
        T.eq(H.formatMoney(1000000), '$1,000,000')
        T.eq(H.formatMoney(-1200), '-$1,200')
        T.eq(H.formatMoney('no'), '$0')
    end)

    T.it('salud de 0 a 100 con máximo de Qbox (200)', function()
        T.eq(H.healthPercent(200, 200), 100)
        T.eq(H.healthPercent(150, 200), 50)
        T.eq(H.healthPercent(100, 200), 0)
        T.eq(H.healthPercent(0, 200), 0, 'muerto: no baja de 0')
        T.eq(H.healthPercent(300, 200), 100, 'no pasa de 100')
        T.eq(H.healthPercent(150, 100), 0, 'máximo inválido')
    end)

    T.it('niveles de aviso (normal e inverso para el estrés)', function()
        T.eq(H.level(80, 25, 10), 'ok')
        T.eq(H.level(20, 25, 10), 'low')
        T.eq(H.level(5, 25, 10), 'critical')
        T.eq(H.level(95, 50, 10, true), 'critical', 'estrés 95 es crítico')
        T.eq(H.level(10, 50, 10, true), 'ok')
    end)

    T.it('velocidad en km/h y mph', function()
        T.eq(H.speed(10, 'kmh'), 36)
        T.eq(H.speed(10, 'mph'), 23)
        T.eq(H.speed(-3, 'kmh'), 0)
    end)

    T.it('modo de voz de pma-voice en español', function()
        T.eq(H.voiceLabel({ mode = 'Whisper' }), 'Susurro')
        T.eq(H.voiceLabel({ mode = 'Shouting' }), 'Gritando')
        T.eq(H.voiceLabel(nil), 'Normal')
    end)

    T.it('hora del juego con dos dígitos', function()
        T.eq(H.clock(8, 5), '08:05')
        T.eq(H.clock(23, 59), '23:59')
        T.eq(H.clock(30, -1), '23:00', 'valores fuera de rango se acotan')
    end)
end)

T.describe('pxd_hud · minimapa, estrés y diferencias', function()
    T.it('rectángulo del minimapa a 16:9 sin margen', function()
        local a = H.minimapAnchor(1.0, 16 / 9, 1920, 1080)
        T.eq(a.left, 0.0)
        T.eq(a.bottom, 1.0)
        T.truthy(math.abs(a.width - 0.140625) < 1e-9, 'ancho ' .. a.width)
        T.truthy(math.abs(a.height - 1 / 5.674) < 1e-9)
        T.truthy(math.abs(a.top - (1.0 - 1 / 5.674)) < 1e-9)
    end)

    T.it('con margen de zona segura y pantalla ancha', function()
        local a = H.minimapAnchor(0.9, 21 / 9, 2560, 1080)
        T.truthy(math.abs(a.left - 0.05) < 1e-9, 'izquierda ' .. a.left)
        T.truthy(math.abs(a.bottom - 0.95) < 1e-9)
        T.truthy(a.width < 0.14, 'en 21:9 ocupa menos ancho relativo')
    end)

    T.it('valida y aplica estrés como qbx_hud', function()
        T.truthy(H.validStressAmount(5))
        T.falsy(H.validStressAmount(0))
        T.falsy(H.validStressAmount(101))
        T.falsy(H.validStressAmount(0 / 0))
        T.falsy(H.validStressAmount('5'))
        T.eq(H.applyStress(95, 10), 100)
        T.eq(H.applyStress(3, -10), 0)
        T.eq(H.applyStress(nil, 4), 4)
    end)

    T.it('busca el tramo de efectos por nivel', function()
        local bands = { { min = 50, max = 60, intensity = 1500 }, { min = 60, max = 70, intensity = 2000 } }
        T.eq(H.band(bands, 55, 'intensity', 0), 1500)
        T.eq(H.band(bands, 65, 'intensity', 0), 2000)
        T.eq(H.band(bands, 10, 'intensity', 99), 99)
    end)

    T.it('solo envía lo que cambió', function()
        local prev = { cash = 10, hunger = 50 }
        T.eq(H.diff(prev, { cash = 10, hunger = 50 }), nil)
        local d = H.diff(prev, { cash = 20, hunger = 50, vehicle = true })
        T.eq(d.cash, 20); T.eq(d.vehicle, true); T.eq(d.hunger, nil)
    end)
end)

T.describe('pxd_hud · servidor (estrés)', function()
    local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
    local function boot(job, stress)
        local meta = { stress = stress }
        local player = { PlayerData = { job = { type = job }, metadata = meta } }
        local set = {}
        Fx.reset({ resourceName = 'pxd_hud', resourceStates = { qbx_core = 'started' }, exports = { qbx_core = {
            GetPlayer = function(src) return src == 1 and player or nil end,
            SetMetadata = function(src, k, v) set[#set + 1] = { src, k, v }; meta[k] = v end,
            Notify = function() end,
        } } })
        PXDHud, Config = nil, nil
        Fx.load(RES .. 'pxd_hud/', { 'config.lua', 'shared/hud.lua', 'server/main.lua' })
        return set
    end

    T.it('GainStress sube y guarda con SetMetadata', function()
        local set = boot('unemployed', 40)
        Fx.emit('hud:server:GainStress', 1, 5)
        T.eq(#set, 1); T.eq(set[1][2], 'stress'); T.eq(set[1][3], 45)
    end)

    T.it('rechaza cantidades inválidas y no sube a policías', function()
        local set = boot('leo', 40)
        Fx.emit('hud:server:GainStress', 1, 5)
        Fx.emit('hud:server:GainStress', 1, 1000)
        T.eq(#set, 0)
        Fx.emit('hud:server:RelieveStress', 1, 15)
        T.eq(set[1][3], 25, 'aliviar sí funciona para todos')
    end)

    T.it('límites anti-abuso: enfriamiento y tope por ventana', function()
        local set = boot('unemployed', 100)
        Fx.emit('hud:server:RelieveStress', 1, 60)
        Fx.emit('hud:server:RelieveStress', 1, 60)   -- dentro del enfriamiento: ignorado
        T.eq(#set, 1); T.eq(set[1][3], 40)
        Fx.advance(3)
        Fx.emit('hud:server:RelieveStress', 1, 60)   -- solo quedan 40 en la ventana
        T.eq(set[2][3], 0)
        Fx.advance(3)
        Fx.emit('hud:server:RelieveStress', 1, 10)   -- tope agotado
        T.eq(#set, 2)
        Fx.advance(121)
        Fx.emit('hud:server:GainStress', 1, 50)      -- ganar: máximo 10 por llamada
        T.eq(set[3][3], 10)
    end)

    T.it('limitStress es pura y respeta cada regla', function()
        local lim = { maxPerCall = 10, cooldown = 1, window = 60, maxPerWindow = 25 }
        local rec = {}
        T.eq(PXDHud.limitStress(rec, 50, 0, lim), 10)
        T.eq(PXDHud.limitStress(rec, 5, 0.5, lim), 0, 'enfriamiento')
        T.eq(PXDHud.limitStress(rec, 10, 2, lim), 10)
        T.eq(PXDHud.limitStress(rec, 10, 4, lim), 5, 'tope de la ventana')
        T.eq(PXDHud.limitStress(rec, 10, 70, lim), 10, 'la ventana se renueva')
    end)

    T.it('oculta el HUD mientras el inventario está abierto', function()
        boot('unemployed', 0)
        Fx.emit('ox_inventory:openedInventory', 0, 5, 'trunk')
        local msg = Fx.lastTo(5, 'pxd_hud:client:visible')
        T.truthy(msg, 'se avisa al jugador 5')
        T.eq(msg.args[1], false)
        Fx.emit('ox_inventory:closedInventory', 0, 5)
        T.eq(Fx.lastTo(5, 'pxd_hud:client:visible').args[1], true)
    end)
end)
