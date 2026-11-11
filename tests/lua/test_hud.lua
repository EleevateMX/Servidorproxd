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

T.describe('pxd_hud 2.0 · brújula, vehículo y ajustes', function()
    PXDHud = nil
    dofile(RES .. 'pxd_hud/shared/hud.lua')
    local H2 = PXDHud

    T.it('rumbo de brújula a partir del heading de GTA y punto cardinal en español', function()
        T.eq(H2.compass(0), 0)
        T.eq(H2.compass(90), 270)     -- en GTA 90 es el oeste
        T.eq(H2.compass(-90), 90)     -- la cámara da ángulos negativos
        T.eq(H2.compass(360), 0)
        T.eq(H2.cardinal(0), 'N'); T.eq(H2.cardinal(270), 'O'); T.eq(H2.cardinal(135), 'SE'); T.eq(H2.cardinal(350), 'N')
        T.eq(H2.step(47, 2), 48); T.eq(H2.step(359, 2) % 360, 0)
    end)

    T.it('cuenta atrás de la paga: sin dato no se dibuja; minutos enteros o de 5 en 5 s', function()
        T.eq(H2.payday(nil), nil)
        T.eq(H2.payday('x'), nil)
        T.eq(H2.payday(-3), nil)
        T.eq(H2.payday(1790), 1800)
        T.eq(H2.payday(61), 120)
        T.eq(H2.payday(43), 45)
        T.eq(H2.payday(0), 0)
    end)

    T.it('marcha, piezas, luces y combustible', function()
        T.eq(H2.gear(3, true), '3'); T.eq(H2.gear(0, true), 'R'); T.eq(H2.gear(2, false), 'P')
        T.eq(H2.partPercent(1000), 100); T.eq(H2.partPercent(-4000), 0); T.eq(H2.partPercent(345), 35)
        T.eq(H2.lights(false, false), 0); T.eq(H2.lights(1, 0), 1); T.eq(H2.lights(true, true), 2)
        T.eq(H2.fuel(42.4, 80), 42, 'manda el state bag de ox_fuel')
        T.eq(H2.fuel(nil, 63.6), 64, 'sin state bag, el nivel del vehículo')
        T.eq(H2.fuel(nil, nil), 0)
    end)

    T.it('calle y zona: sin repetir ni «NULL»', function()
        local line, zone = H2.location('Avenida Strawberry', 'Calle Davis', 'Strawberry')
        T.eq(line, 'Avenida Strawberry · Calle Davis'); T.eq(zone, 'Strawberry')
        line, zone = H2.location('Plaza Legion', '', 'NULL')
        T.eq(line, 'Plaza Legion'); T.eq(zone, '')
        T.eq((H2.location('A', 'A', nil)), 'A')
    end)

    T.it('ajustes del jugador: valores por defecto y saneado de lo guardado', function()
        local d = H2.defaultSettings()
        T.eq(d.scale, 1.0); T.eq(d.cinema, false); T.eq(d.show.vehicle, true)
        local s = H2.sanitizeSettings({ scale = 5, cinema = true, show = { minimap = false, otro = true, money = 'no' } })
        T.eq(s.scale, 1.3); T.eq(s.cinema, true); T.eq(s.show.minimap, false); T.eq(s.show.money, false)
        T.eq(s.show.otro, nil, 'solo elementos conocidos')
        T.eq(H2.sanitizeSettings('roto').scale, 1.0)
        T.eq(H2.sanitizeSettings({ scale = 0.93 }).scale, 0.95)
        T.eq(H2.sanitizeSettings({ scale = 0 / 0 }).scale, 1.0)
    end)

    T.it('el HUD se oculta por otro recurso, modo cine, pausa o sin personaje', function()
        local base = { visible = true, cinema = false, loggedIn = true, paused = false, hudHidden = false }
        T.truthy(H2.shouldShow(base))
        for _, k in ipairs({ 'cinema', 'paused', 'hudHidden' }) do
            local o = {} for kk, v in pairs(base) do o[kk] = v end
            o[k] = true
            T.falsy(H2.shouldShow(o), k)
        end
        T.falsy(H2.shouldShow({ visible = false, loggedIn = true }))
        T.falsy(H2.shouldShow({ visible = true, loggedIn = false }))
    end)
end)

T.describe('pxd_ui · interfaz común y adaptador de ox_lib', function()
    local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
    local nui, cbs, focus, timeouts, events

    local function boot(states)
        Fx.reset({ resourceName = 'pxd_ui', resourceStates = states or {} })
        nui, cbs, focus, timeouts, events = {}, {}, {}, {}, {}
        _G.SendNUIMessage = function(m) nui[#nui + 1] = m end
        _G.RegisterNUICallback = function(name, fn) cbs[name] = fn end
        _G.SetNuiFocus = function(a, b) focus[#focus + 1] = a end
        _G.RegisterKeyMapping = function() end
        _G.SetTimeout = function(ms, fn) timeouts[#timeouts + 1] = { ms = ms, fn = fn } end
        _G.AddEventHandler('pxd_ui:oxProgressComplete', function() events[#events + 1] = 'progress' end)
        _G.AddEventHandler('pxd_ui:oxAlertResult', function(r) events[#events + 1] = 'alert:' .. tostring(r) end)
        PXDUi, Config = nil, nil
        Fx.load(RES .. 'pxd_ui/', { 'config.lua', 'shared/ui.lua', 'client/main.lua' })
        cbs.ready({}, function() end)   -- la página ya cargó
    end
    local function last() return nui[#nui] end
    local function ex(name, ...) return Fx.exports.pxd_ui[name](...) end

    T.it('lógica pura: tonos, límites y campos conocidos', function()
        boot()
        T.eq(PXDUi.tone('inform'), 'info'); T.eq(PXDUi.tone('error'), 'error'); T.eq(PXDUi.tone(nil), 'info')
        local n = PXDUi.notify({ id = 7, title = 'Hola', description = 'x', type = 'success', duration = 99999999, position = 'raro', style = { color = 'red' } }, Config.notify)
        T.eq(n.id, '7'); T.eq(n.type, 'success'); T.eq(n.duration, 30000); T.eq(n.position, 'top-right')
        T.eq(n.style, nil, 'no pasan estilos arbitrarios')
        T.eq(PXDUi.notify({}, Config.notify), nil)
        T.eq(PXDUi.notify('texto', Config.notify), nil)
        T.eq(PXDUi.textUi('', {}), nil)
        T.eq(PXDUi.textUi('[E] Abrir', { position = 'top-center' }).position, 'top-center')
        local _, dur, circle = PXDUi.progress({ duration = 5000.7, label = 'x' }, true)
        T.eq(dur, 5000); T.eq(circle, true)
        T.eq(select(2, PXDUi.progress({ duration = -1 })), 0)
        T.eq(PXDUi.alertResult('confirm'), 'confirm'); T.eq(PXDUi.alertResult('otra cosa'), 'cancel')
    end)

    T.it('los mensajes anteriores a que cargue la página se guardan y se envían al estar lista', function()
        Fx.reset({ resourceName = 'pxd_ui' })
        nui, cbs = {}, {}
        _G.SendNUIMessage = function(m) nui[#nui + 1] = m end
        _G.RegisterNUICallback = function(name, fn) cbs[name] = fn end
        _G.SetNuiFocus = function() end
        _G.RegisterKeyMapping = function() end
        PXDUi, Config = nil, nil
        Fx.load(RES .. 'pxd_ui/', { 'config.lua', 'shared/ui.lua', 'client/main.lua' })
        Fx.exports.pxd_ui.Notify({ description = 'antes de cargar' })
        T.eq(#nui, 0)
        cbs.ready({}, function() end)
        T.eq(#nui, 1); T.eq(nui[1].data.description, 'antes de cargar')
    end)

    T.it('avisos: los de ox_lib/qbx_core (OxNotify) y los propios llegan normalizados', function()
        boot()
        T.truthy(ex('OxNotify', { id = 'Banco', title = 'Banco', description = 'Has recibido $500', type = 'inform', position = 'top' }))
        T.eq(last().action, 'notify'); T.eq(last().data.type, 'info'); T.eq(last().data.position, 'top')
        T.falsy(ex('OxNotify', {}), 'sin texto devuelve false: ox_lib usa entonces su interfaz')
        Fx.emit('pxd_ui:client:notify', nil, { description = 'Desde el servidor', type = 'success' })
        T.eq(last().data.description, 'Desde el servidor')
    end)

    T.it('Text UI: mostrar, estado y ocultar', function()
        boot()
        T.truthy(ex('OxTextUI', { text = '[E] Abrir maletero', position = 'right-center' }))
        T.eq(last().action, 'textUi'); T.eq(last().data.text, '[E] Abrir maletero')
        local open, text = ex('IsTextUIOpen')
        T.eq(open, true); T.eq(text, '[E] Abrir maletero')
        ex('OxTextUIHide')
        T.eq(last().action, 'textUiHide'); T.eq((ex('IsTextUIOpen')), false)
        T.falsy(ex('OxTextUI', 'no es tabla'))
    end)

    T.it('progreso de ox_lib: la duración la cuenta Lua y avisa a ox_lib al terminar', function()
        boot()
        T.truthy(ex('OxProgress', { action = 'progress', data = { label = 'Reparando', duration = 4000 } }))
        T.eq(last().action, 'progress'); T.eq(last().circle, false); T.eq(last().data.duration, 4000)
        T.eq(timeouts[1].ms, 4000)
        T.eq(#events, 0)
        timeouts[1].fn()
        T.eq(events[1], 'progress'); T.eq(last().action, 'progressDone')
        T.truthy(ex('OxProgress', { action = 'circleProgress', data = { duration = 1000, position = 'middle' } }))
        T.eq(last().circle, true); T.eq(last().data.position, 'middle')
        T.falsy(ex('OxProgress', { action = 'progress', data = { duration = 0 } }), 'sin duración lo atiende ox_lib')
    end)

    T.it('progreso cancelado: no se avisa del final (ni el de uno anterior)', function()
        boot()
        ex('OxProgress', { action = 'progress', data = { duration = 4000 } })
        ex('OxProgressCancel')
        T.eq(last().action, 'progressCancel')
        timeouts[1].fn()
        T.eq(#events, 0, 'el temporizador cancelado no hace nada')
        ex('OxProgress', { action = 'progress', data = { duration = 2000 } })
        timeouts[1].fn()
        T.eq(#events, 0, 'el temporizador viejo no termina el progreso nuevo')
        timeouts[2].fn()
        T.eq(events[1], 'progress')
    end)

    T.it('diálogo de ox_lib: foco propio, resultado por evento y cierre desde Lua', function()
        boot()
        T.truthy(ex('OxAlert', { header = 'Vender', content = '¿Seguro?', cancel = true }))
        T.eq(last().action, 'alert'); T.eq(focus[#focus], true)
        T.falsy(ex('OxAlert', { header = 'Otro' }), 'solo uno a la vez')
        cbs.alertResult({ result = 'confirm' }, function() end)
        T.eq(events[1], 'alert:confirm'); T.eq(focus[#focus], false)
        ex('OxAlert', { header = 'Tiempo' })
        T.truthy(ex('OxAlertClose'))
        T.eq(last().action, 'alertClose'); T.eq(focus[#focus], false)
        T.falsy(ex('OxAlertClose'), 'ya estaba cerrado')
        cbs.alertResult({ result = 'cualquier cosa' }, function() end)
        T.eq(#events, 1, 'un resultado sin diálogo abierto no hace nada')
    end)

    T.it('Confirm propio: devuelve confirm o cancel (cualquier otro valor es cancelar)', function()
        boot()
        local out = {}
        CreateThread(function() out[1] = ex('Confirm', { header = 'Salir', content = '¿Cerrar sesión?', cancel = true }) end)
        T.eq(last().action, 'alert')
        cbs.alertResult({ result = '<script>' }, function() end)
        Fx.advance(0)
        T.eq(out[1], 'cancel')
        T.eq(ex('Confirm', {}), nil, 'sin texto no abre nada')
    end)

    T.it('Progress propio sin ox_lib: termina o se cancela con el mismo resultado true/false', function()
        boot()
        local out = {}
        CreateThread(function() out[1] = ex('Progress', { label = 'Pescando', duration = 2000 }) end)
        T.eq(last().action, 'progress'); T.eq((ex('ProgressActive')), true)
        Fx.advance(3)
        T.eq(out[1], true); T.eq(last().action, 'progressDone')
        CreateThread(function() out[2] = ex('ProgressCircle', { duration = 5000, canCancel = true }) end)
        T.truthy(ex('CancelProgress'))
        Fx.advance(1)
        T.eq(out[2], false); T.eq(last().action, 'progressCancel')
    end)

    T.it('Progress con ox_lib arrancado: delega en él (animaciones, props y bloqueo de controles)', function()
        boot({ ox_lib = 'started' })
        local seen
        Fx.exports.ox_lib = { progressBar = function(d) seen = d return true end, progressCircle = function() return false end,
            progressActive = function() return false end }
        T.eq(ex('Progress', { label = 'x', duration = 100 }), true)
        T.eq(seen.label, 'x')
        T.eq(ex('ProgressCircle', { duration = 100 }), false)
    end)
end)
