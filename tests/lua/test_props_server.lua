-- Pruebas de integración del servidor de pxd_props (eventos, persistencia y API web).
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_props/'
local TOKEN = 'token-de-prueba-largo-123456'

local function boot(opts)
    opts = opts or {}
    opts.resourceName = 'pxd_props'
    opts.convars = opts.convars or { pxd_props_webToken = TOKEN }
    Fx.reset(opts)
    PXDProps = nil
    Config = nil
    -- Archivos estáticos reales para comprobar que se sirven.
    for _, f in ipairs({ 'html/index.html', 'html/app.js', 'html/style.css', 'html/catalog.json' }) do
        local h = io.open(DIR .. f, 'rb')
        if h then Fx.files[f] = h:read('a'); h:close() end
    end
    Fx.load(DIR, { 'config.lua', 'shared/layouts.lua', 'server/main.lua' })
    Fx.addPlayer(1, 'Editor', { x = 0, y = 0, z = 0 }, { ['pxd.props.edit'] = true })
    Fx.addPlayer(2, 'Visitante', { x = 0, y = 0, z = 0 })
end

local function http(method, path, headers, body)
    local r = {}
    local req = {
        method = method, path = path, headers = headers or {}, address = '203.0.113.7',
        setDataHandler = function(fn) fn(body or '') end,
    }
    local res = {
        writeHead = function(code, h) r.code, r.headers = code, h end,
        send = function(b) r.body = b end,
    }
    Fx.httpHandler(req, res)
    r.json = r.body and Fx.json.decode(r.body)
    return r
end

local AUTH = { Authorization = 'Bearer ' .. TOKEN }

T.describe('pxd_props servidor', function()
    T.it('solo los editores con ACE pueden modificar', function()
        boot()
        Fx.emit('pxd_props:server:op', 2, 1, 'createLayout', { id = 'plaza', name = 'Plaza' })
        local r = Fx.lastTo(2, 'pxd_props:client:opResult')
        T.eq(r.args[2], false); T.truthy(r.args[3]:find('permiso'))

        Fx.emit('pxd_props:server:op', 1, 7, 'createLayout', { id = 'plaza', name = 'Plaza' })
        r = Fx.lastTo(1, 'pxd_props:client:opResult')
        T.eq(r.args[1], 7); T.eq(r.args[2], true)
        local b = Fx.lastTo(-1, 'pxd_props:client:layout')
        T.eq(b.args[1], 'plaza'); T.eq(b.args[2].name, 'Plaza')
    end)

    T.it('sync envía layouts y si el jugador puede editar', function()
        boot()
        Fx.emit('pxd_props:server:op', 1, 1, 'createLayout', { id = 'plaza', name = 'Plaza' })
        Fx.emit('pxd_props:server:sync', 2)
        local s = Fx.lastTo(2, 'pxd_props:client:sync')
        T.truthy(s.args[1].plaza); T.eq(s.args[2], false)
    end)

    T.it('guarda en disco y recarga al reiniciar', function()
        boot()
        Fx.emit('pxd_props:server:op', 1, 1, 'createLayout', { id = 'plaza', name = 'Plaza' })
        Fx.emit('pxd_props:server:op', 1, 2, 'addProp', { layout = 'plaza', prop = { model = 'prop_mp_cone_02', x = 1, y = 2, z = 3 } })
        Fx.advance(3)
        local saved = Fx.files['data/layouts.json']
        T.truthy(saved and saved:find('prop_mp_cone_02'), 'escribe el JSON')
        boot({ files = { ['data/layouts.json'] = saved } })
        local l = PXDProps.store().layouts.plaza
        T.truthy(l); T.eq(l.props[1].model, 'prop_mp_cone_02')
    end)

    T.it('limita las operaciones por segundo', function()
        boot()
        Fx.emit('pxd_props:server:op', 1, 1, 'createLayout', { id = 'plaza', name = 'Plaza' })
        local fails = 0
        for i = 1, 40 do
            Fx.emit('pxd_props:server:op', 1, 100 + i, 'addProp', { layout = 'plaza', prop = { model = 'prop_a', x = 0, y = 0, z = 0 } })
            local r = Fx.lastTo(1, 'pxd_props:client:opResult')
            if not r.args[2] then fails = fails + 1 end
        end
        T.truthy(fails > 0, 'rechaza el exceso')
    end)

    T.it('rechaza operaciones desconocidas o datos raros', function()
        boot()
        T.falsy(PXDProps.dispatch('t', 'os.execute', {}))
        T.falsy(PXDProps.dispatch('t', 'addProp', 'x'))
        Fx.emit('pxd_props:server:op', 1, 'no-numero', 'createLayout', { id = 'x1' })
        T.falsy(Fx.lastTo(1, 'pxd_props:client:opResult'), 'ignora reqId no numérico')
    end)
end)

T.describe('pxd_props API web', function()
    T.it('sirve la interfaz sin token y con cabeceras de seguridad', function()
        boot()
        local r = http('GET', '/')
        T.eq(r.code, 200); T.truthy(r.body:find('<html'))
        T.eq(r.headers['X-Frame-Options'], 'DENY')
        T.eq(http('GET', '/../server/main.lua').code, 404)
        T.eq(http('GET', '/app.js').headers['Content-Type'], 'application/javascript; charset=utf-8')
    end)

    T.it('la API exige token y queda desactivada si es corto o no existe', function()
        boot({ convars = { pxd_props_webToken = 'corto' } })
        T.eq(http('GET', '/api/layouts', AUTH).code, 503)
        boot()
        T.eq(http('GET', '/api/layouts').code, 401)
        T.eq(http('GET', '/api/layouts', { Authorization = 'Bearer otro' }).code, 401)
        local r = http('GET', '/api/layouts', AUTH)
        T.eq(r.code, 200); T.eq(r.json.ok, true)
    end)

    T.it('bloquea una IP tras muchos intentos fallidos', function()
        boot()
        for _ = 1, 10 do http('GET', '/api/layouts', { Authorization = 'Bearer mal' }) end
        T.eq(http('GET', '/api/layouts', AUTH).code, 429)
    end)

    T.it('crea y edita mediante POST /api/op y avisa a los jugadores', function()
        boot()
        local r = http('POST', '/api/op', AUTH, Fx.json.encode({ op = 'createLayout', payload = { id = 'circuito', name = 'Circuito' } }))
        T.eq(r.code, 200)
        r = http('POST', '/api/op', AUTH, Fx.json.encode({ op = 'addPoint', payload = { layout = 'circuito', point = { kind = 'checkpoint', x = 1, y = 2, z = 3 } } }))
        T.eq(r.code, 200); T.eq(r.json.result.order, 1)
        T.truthy(Fx.lastTo(-1, 'pxd_props:client:layout'), 'difunde a los clientes')
        r = http('GET', '/api/layouts/circuito', AUTH)
        T.eq(r.json.result.points[1].kind, 'checkpoint')
        T.eq(http('POST', '/api/op', AUTH, '{roto').code, 400)
        T.eq(http('GET', '/api/layouts/nope', AUTH).code, 404)
    end)
end)

T.describe('pxd_props anclas y blueprints', function()
    T.it('/ancla guarda la posición del editor y se lee por la API', function()
        boot()
        Fx.movePlayer(1, { x = 215.5, y = -810.25, z = 30.7 })
        Fx.commands['ancla'](1, { 'plaza' })
        T.truthy(Fx.lastTo(1, 'pxd_props:client:toast').args[1]:find('plaza'))
        Fx.commands['ancla'](2, { 'robada' })   -- sin permiso: ignorado
        local r = http('GET', '/api/anchors', AUTH)
        T.eq(r.json.result.plaza.x, 215.5)
        T.falsy(r.json.result.robada)
        Fx.advance(3)
        boot({ files = { ['data/layouts.json'] = Fx.files['data/layouts.json'] } })
        T.truthy(PXDProps.store().anchors.plaza, 'persiste tras reiniciar')
    end)

    T.it('los blueprints de ejemplo compilados se importan sin descartes', function()
        boot()
        local script = ([[node --input-type=module -e "
import { compile } from '%stools/blueprint.mjs';
import { readFileSync, readdirSync } from 'node:fs';
const dir = '%sblueprints/';
const out = readdirSync(dir).filter(f => f.endsWith('.json')).map(f => {
  const bp = JSON.parse(readFileSync(dir + f, 'utf8'));
  return compile(bp, { [bp.anchor]: { x: 215.5, y: -810.25, z: 30.7, h: 70 } }).layout;
});
process.stdout.write(JSON.stringify(out));"]]):format(ROOT, ROOT)
        local p = io.popen(script)
        local raw = p:read('a'); p:close()
        local layouts = Fx.json.decode(raw)
        T.truthy(layouts and #layouts >= 2, 'node compiló los ejemplos')
        for _, layout in ipairs(layouts) do
            local before = #layout.props + #layout.points
            local ok, res = PXDProps.dispatch('test', 'importLayout', { data = layout })
            T.truthy(ok, tostring(res))
            T.eq(#res.props + #res.points, before, 'sin descartes en ' .. layout.id)
        end
    end)
end)
