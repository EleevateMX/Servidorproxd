-- Pruebas de pxd_phone: lógica pura y servidor (Qbox y oxmysql falsos).
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_phone/'

PXDPhone = nil
dofile(DIR .. 'shared/phone.lua')
local P = PXDPhone

T.describe('pxd_phone (lógica)', function()
    T.it('limpia el texto: controles, etiquetas, espacios y longitud sin partir UTF-8', function()
        T.eq(P.cleanText('  hola\n\tmundo  <b>x</b> '), 'hola mundo bx/b')
        T.eq(P.cleanText(nil), '')
        T.eq(P.cleanText('ñññ', 3), 'ñ')   -- cada ñ son 2 bytes: no se corta a medias
        T.eq(#P.cleanText(string.rep('a', 300), 140), 140)
    end)

    T.it('límite de frecuencia por clave', function()
        local book = {}
        T.truthy(P.allow(book, 1, 100, 60))
        local ok, wait = P.allow(book, 1, 130, 60)
        T.falsy(ok); T.eq(wait, 30)
        T.truthy(P.allow(book, 2, 130, 60), 'otra clave no se bloquea')
        T.truthy(P.allow(book, 1, 160, 60))
    end)

    T.it('separa propiedades en venta (por precio) y mías (dueño o llave)', function()
        local rows = {
            { id = 1, property_name = 'Cara', price = 900, owner = nil, keyholders = '[]' },
            { id = 2, property_name = 'Barata', price = 100, owner = nil, keyholders = '[]', rent_interval = 24 },
            { id = 3, property_name = 'Mía', price = 0, owner = 'CID1', keyholders = '[]' },
            { id = 4, property_name = 'Con llave', price = 0, owner = 'OTRO', keyholders = '["CID1"]' },
            { id = 5, property_name = 'Ajena', price = 0, owner = 'OTRO', keyholders = '[]' },
        }
        json = Fx.json
        local r = P.splitProperties(rows, 'CID1')
        T.eq(#r.sale, 2); T.eq(r.sale[1].name, 'Barata'); T.eq(r.sale[1].rentHours, 24)
        T.eq(#r.mine, 2); T.eq(r.mine[1].id, 3); T.eq(r.mine[2].id, 4)
        T.eq(#P.splitProperties(rows, nil).mine, 0, 'sin personaje no hay «mías»')
        T.eq(#P.splitProperties(rows, 'CID1', 1).sale, 1, 'respeta el máximo')
    end)

    T.it('cola de taxis: pedir, aceptar una vez, cancelar, caducar y desconexiones', function()
        local q = P.Taxi.new(600)
        local r = q:request(1, 0, 'puerta', { x = 1, y = 2, z = 3 })
        T.eq(r.id, 1)
        T.falsy(q:request(1, 5, ''), 'una petición abierta por cliente')
        T.falsy(q:accept(1, 1, 10), 'no puede aceptarse a sí mismo')
        T.truthy(q:accept(1, 7, 10))
        local _, err = q:accept(1, 8, 11)
        T.truthy(err:find('Otro taxista'))
        T.eq(#q:pending(12), 0)
        local back = q:dropPlayer(7)
        T.eq(#back, 1); T.eq(q:pending(13)[1].id, 1, 'si el taxista se va, vuelve a pendiente')
        T.truthy(q:cancel(1)); T.eq(#q:pending(14), 0)
        q:request(2, 100, '')
        T.eq(#q:pending(800), 0, 'caduca')
    end)
end)

-- ── Servidor ────────────────────────────────────────────────────────────────
local db
local function boot(players, duty)
    db = { rows = {}, coords = {} }
    local exports = {
        qbx_core = {
            GetPlayer = function(src) return players[src] end,
            Notify = function(src, text, kind) Fx.sent[#Fx.sent + 1] = { name = 'notify', target = src, args = { text, kind } } end,
            GetDutyCountType = function(t) local l = duty[t] or {} return #l, l end,
            GetDutyCountJob = function(j) local l = duty[j] or {} return #l, l end,
        },
    }
    Fx.reset({ resourceName = 'pxd_phone', exports = exports,
        resourceStates = { pxd_phone = 'started', qbx_core = 'started', oxmysql = 'started' } })
    MySQL = {
        query = { await = function() return db.rows end },
        single = { await = function(_, args) local c = db.coords[args[1]] return c and { coords = c } or nil end },
    }
    Config = nil; PXDPhone = nil
    Fx.load(DIR, { 'config.lua', 'shared/phone.lua', 'server/main.lua' })
    local t = 1000
    PXDPhone.setClock(function() return t end)
    for src, p in pairs(players) do Fx.addPlayer(src, 'P' .. src, p.pos or { x = 10, y = 20, z = 30 }) end
    return function(dt) t = t + dt end
end

local function call(src, action, data)
    Fx.emit('pxd_phone:server:req', src, 7, action, data)
    local res = Fx.lastTo(src, 'pxd_phone:client:res')
    return res and res.args[2]
end

local function pd(job, cid, name)
    return { PlayerData = { citizenid = cid, job = job, charinfo = { firstname = name or 'Ana', lastname = 'López' } } }
end

T.describe('pxd_phone (servidor)', function()
    T.it('Emergencias: llega a quien está de servicio con la posición del servidor, y con límite', function()
        local wait = boot({ [1] = pd({ name = 'unemployed' }, 'C1'), [2] = pd({ name = 'police', type = 'leo', onduty = true }, 'C2') },
            { leo = { 2 } })
        local r = call(1, 'sos_send', { service = 'police', text = '<b>robo</b> en la tienda' })
        T.eq(r.sent, 1)
        local alert = Fx.lastTo(2, 'pxd_phone:client:alert')
        T.eq(alert.args[1].coords.x, 10.0, 'coordenadas del servidor')
        T.eq(alert.args[1].text, 'brobo/b en la tienda', 'texto limpio')
        T.truthy(call(1, 'sos_send', { service = 'police' }).error:find('Espera'))
        wait(61)
        T.eq(call(1, 'sos_send', { service = 'ems' }).sent, 0, 'sin EMS de servicio: nadie lo recibe')
        T.truthy(call(1, 'sos_send', { service = 'bomberos' }).error, 'servicio desconocido')
        T.truthy(call(1, 'hack', {}).error, 'acción desconocida')
    end)

    T.it('Taxi: sin taxistas no se pide; el taxista acepta y recibe la ruta', function()
        local taxiJob = { name = 'taxi', onduty = true }
        local players = { [1] = pd({ name = 'unemployed' }, 'C1'), [3] = pd(taxiJob, 'C3', 'Tito') }
        boot(players, { taxi = {} })
        T.truthy(call(1, 'taxi_request', {}).error:find('No hay taxistas'))
        boot(players, { taxi = { 3 } })
        local s = call(1, 'taxi_request', { text = 'en la puerta' })
        T.eq(s.request.status, 'pending')
        T.truthy(call(1, 'taxi_accept', { id = s.request.id }).error, 'un cliente no puede aceptar')
        local d = call(3, 'taxi_state')
        T.truthy(d.driver); T.eq(#d.pending, 1)
        local acc = call(3, 'taxi_accept', { id = d.pending[1].id })
        T.eq(acc.waypoint.x, 10.0)
        T.truthy(Fx.lastTo(3, 'pxd_phone:client:alert'))
        local mine = call(1, 'taxi_state')
        T.eq(mine.request.status, 'accepted'); T.eq(mine.request.driverName, 'Tito López')
    end)

    T.it('Dynasty 8: lista y GPS con datos de la base de datos', function()
        boot({ [1] = pd({ name = 'unemployed' }, 'C1') }, {})
        db.rows = { { id = 1, property_name = 'Casa', price = 500, owner = nil, keyholders = '[]' } }
        db.coords[1] = '{"x":1.5,"y":2.5,"z":3}'
        local l = call(1, 'd8_list')
        T.eq(l.sale[1].name, 'Casa')
        T.eq(call(1, 'd8_mark', { id = 1 }).x, 1.5)
        T.truthy(call(1, 'd8_mark', { id = 99 }).error)
    end)
end)
