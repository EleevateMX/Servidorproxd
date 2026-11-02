local T = _G.T

local function load()
    PXDProps = nil
    dofile(RES .. 'pxd_props/shared/layouts.lua')
    return PXDProps.Layouts
end

T.describe('Layouts', function()
    T.it('crea layouts con ids válidos y rechaza duplicados', function()
        local L = load()
        local s = L.newStore()
        T.truthy(L.createLayout(s, 'plaza_central', 'Plaza central', 1))
        T.falsy(L.createLayout(s, 'plaza_central', 'x'))
        T.falsy(L.createLayout(s, 'Con Espacios', 'x'))
        T.falsy(L.createLayout(s, 'a', 'x'))
        T.eq(L.list(s)[1].name, 'Plaza central')
    end)

    T.it('limpia nombres peligrosos', function()
        local L = load()
        local s = L.newStore()
        local l = L.createLayout(s, 'x1', '  <script>alert(1)</script>  ')
        T.falsy(l.name:find('<'), 'sin < ni >')
    end)

    T.it('valida modelo, coordenadas y normaliza rotaciones', function()
        local L = load()
        local s = L.newStore()
        L.createLayout(s, 'l1', 'L1')
        T.falsy(L.addProp(s, 'l1', { model = 'prop barrier', x = 0, y = 0, z = 0 }), 'modelo con espacios')
        T.falsy(L.addProp(s, 'l1', { model = 'prop_x', x = 0 / 0, y = 0, z = 0 }), 'NaN')
        T.falsy(L.addProp(s, 'l1', { model = 'prop_x', x = 99999, y = 0, z = 0 }), 'fuera del mapa')
        local p = L.addProp(s, 'l1', { model = 'prop_barrier_work05', x = 1.23456, y = 2, z = 3, rz = 540 })
        T.truthy(p)
        T.eq(p.x, 1.235); T.eq(p.rz, 180.0); T.eq(p.frozen, true); T.eq(p.collision, true)
        T.eq(L.normAngle(-190), 170.0)
    end)

    T.it('actualiza props de forma parcial y los borra', function()
        local L = load()
        local s = L.newStore()
        L.createLayout(s, 'l1', 'L1')
        local p = L.addProp(s, 'l1', { model = 'prop_a', x = 1, y = 2, z = 3 })
        local u = L.updateProp(s, 'l1', p.id, { z = 10, collision = false })
        T.eq(u.x, 1); T.eq(u.z, 10); T.eq(u.collision, false); T.eq(u.model, 'prop_a')
        T.falsy(L.updateProp(s, 'l1', p.id, { model = '../../x' }))
        T.truthy(L.removeProp(s, 'l1', p.id))
        T.falsy(L.removeProp(s, 'l1', p.id))
    end)

    T.it('respeta el límite de props por layout', function()
        local L = load()
        local s = L.newStore()
        L.createLayout(s, 'l1', 'L1')
        L.LIMITS.maxPropsPerLayout = 2
        L.addProp(s, 'l1', { model = 'prop_a', x = 0, y = 0, z = 0 })
        L.addProp(s, 'l1', { model = 'prop_a', x = 0, y = 0, z = 0 })
        local p, err = L.addProp(s, 'l1', { model = 'prop_a', x = 0, y = 0, z = 0 })
        T.falsy(p); T.truthy(err:find('límite'))
    end)

    T.it('puntos: tipos válidos, una sola zona y orden automático de checkpoints', function()
        local L = load()
        local s = L.newStore()
        L.createLayout(s, 'l1', 'L1')
        T.falsy(L.addPoint(s, 'l1', { kind = 'otro', x = 0, y = 0, z = 0 }))
        L.addPoint(s, 'l1', { kind = 'zone', x = 0, y = 0, z = 0, radius = 10 })
        L.addPoint(s, 'l1', { kind = 'zone', x = 5, y = 5, z = 0, radius = 15 })
        local a = L.addPoint(s, 'l1', { kind = 'checkpoint', x = 1, y = 0, z = 0 })
        local b = L.addPoint(s, 'l1', { kind = 'checkpoint', x = 2, y = 0, z = 0 })
        T.eq(a.order, 1); T.eq(b.order, 2)
        local zones = 0
        for _, p in ipairs(s.layouts.l1.points) do if p.kind == 'zone' then zones = zones + 1 end end
        T.eq(zones, 1)
        T.falsy(L.addPoint(s, 'l1', { kind = 'zone', x = 0, y = 0, z = 0, radius = 999 }), 'radio')
    end)

    T.it('importa descartando elementos inválidos y conserva ids', function()
        local L = load()
        local s = L.newStore()
        local l, dropped = L.importLayout(s, {
            id = 'imp', name = 'Importado', active = true,
            props = { { id = 7, model = 'prop_a', x = 1, y = 1, z = 1 }, { model = 'mal modelo', x = 0, y = 0, z = 0 }, 'basura' },
            points = { { id = 9, kind = 'spawn', x = 0, y = 0, z = 0, h = 90 } },
        })
        T.truthy(l); T.eq(dropped, 2)
        T.eq(l.props[1].id, 7); T.eq(l.points[1].id, 9); T.eq(l.nextId, 10)
        T.eq(l.active, true)
        T.falsy(L.importLayout(s, { id = 'imp' }), 'sin overwrite no pisa')
        T.truthy(L.importLayout(s, { id = 'imp' }, { overwrite = true }))
    end)

    T.it('loadStore tolera datos corruptos', function()
        local L = load()
        local s, dropped = L.loadStore({ layouts = { ok_1 = { name = 'OK', props = {} }, ['MAL ID'] = {} } })
        T.truthy(s.layouts.ok_1); T.eq(dropped, 1)
        T.truthy(L.loadStore(nil))
    end)
end)
