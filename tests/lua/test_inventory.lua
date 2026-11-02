-- Pruebas de pxd_inventory (lógica pura: ropa, signos vitales, notificaciones).
local T = _G.T
Config = nil
PXDInv = nil
dofile(RES .. 'pxd_inventory/config.lua')
dofile(RES .. 'pxd_inventory/shared/inventory.lua')
local slot = function(id) return PXDInv.slot(Config.clothing, id) end

T.describe('pxd_inventory', function()
    T.it('quitar el torso cambia también camiseta interior y brazos; ponerlo restaura todo', function()
        local top = slot('top')
        local current = { [11] = { 120, 2 }, [8] = { 31, 0 }, [3] = { 4, 0 } }
        local ops, keep, on = PXDInv.toggle(top, nil, current, 'male')
        T.eq(on, false)
        T.eq(#ops, 3)
        T.eq(table.concat(ops[1], ','), 'comp,11,15,0')
        T.eq(table.concat(ops[2], ','), 'comp,8,15,0')
        T.eq(table.concat(ops[3], ','), 'comp,3,15,0')
        local back, saved, on2 = PXDInv.toggle(top, keep, current, 'male')
        T.eq(on2, true); T.eq(saved, nil)
        T.eq(table.concat(back[1], ','), 'comp,11,120,2')
        T.eq(table.concat(back[2], ','), 'comp,8,31,0')
    end)

    T.it('ropa base distinta para mujer', function()
        local ops = PXDInv.toggle(slot('pants'), nil, { [4] = { 20, 1 } }, 'female')
        T.eq(table.concat(ops[1], ','), 'comp,4,15,3')
    end)

    T.it('accesorios (props): quitar es -1 y no hace nada si no lleva', function()
        local hat = slot('hat')
        local ops, keep = PXDInv.toggle(hat, nil, { [0] = { 12, 3 } }, 'male')
        T.eq(table.concat(ops[1], ','), 'prop,0,-1,-1')
        T.eq(keep[1].kind, 'prop')
        local back = PXDInv.toggle(hat, keep, { [0] = { -1, -1 } }, 'male')
        T.eq(table.concat(back[1], ','), 'prop,0,12,3')
        local none = PXDInv.toggle(hat, nil, { [0] = { -1, -1 } }, 'male')
        T.eq(#none, 0, 'sin sombrero no hay nada que quitar')
    end)

    T.it('isOn compara con la ropa base', function()
        T.eq(PXDInv.isOn(slot('shoes'), { 34, 0 }, 'male'), false)
        T.eq(PXDInv.isOn(slot('shoes'), { 10, 0 }, 'male'), true)
        T.eq(PXDInv.isOn(slot('glasses'), { -1, -1 }, 'male'), false)
    end)

    T.it('salud en % (100 = muerto) y datos para la interfaz', function()
        T.eq(PXDInv.healthPercent(200, 200), 100)
        T.eq(PXDInv.healthPercent(150, 200), 50)
        T.eq(PXDInv.healthPercent(90, 200), 0)
        local v = PXDInv.view({ charinfo = { firstname = 'Edy', lastname = 'Ríos' }, money = { cash = 500.7, bank = 5000 },
            metadata = { hunger = 40, pxd_id = 'PROX-7KQ2' } },
            { health = 175, maxHealth = 200, armour = 120, state = { thirst = 33.4 } }, Config.clothing, { top = true })
        T.eq(v.name, 'Edy Ríos'); T.eq(v.id, 'PROX-7KQ2'); T.eq(v.cash, 500); T.eq(v.bank, 5000)
        T.eq(v.vitals.hunger, 40); T.eq(v.vitals.thirst, 33); T.eq(v.vitals.health, 75); T.eq(v.vitals.armour, 100)
        T.eq(#v.clothing, #Config.clothing)
        T.eq(v.clothing[3].on, true); T.eq(v.clothing[1].on, false)
    end)

    T.it('sin Qbox: no se inventa nada (sin nombre, dinero, comida, bebida ni estrés)', function()
        local v = PXDInv.view(nil, { health = 200, maxHealth = 200, armour = 0 }, Config.clothing, {})
        T.eq(v.name, nil); T.eq(v.cash, nil); T.eq(v.bank, nil)
        T.eq(v.vitals.hunger, nil); T.eq(v.vitals.thirst, nil); T.eq(v.vitals.stress, nil)
        T.eq(v.vitals.health, 100, 'la salud sale del ped, siempre existe'); T.eq(v.vitals.armour, 0)
        T.eq(v.contract, PXDInv.CONTRACT)
    end)

    T.it('estado de qbx_core: el state bag manda sobre los metadata; 0 es un valor real', function()
        local v = PXDInv.view({ money = { cash = 0, bank = 12 }, metadata = { hunger = 80, thirst = 70, stress = 10 } },
            { health = 150, maxHealth = 200, armour = 0, state = { hunger = 0, stress = 55.6 }, preview = true }, Config.clothing, {})
        T.eq(v.vitals.hunger, 0); T.eq(v.vitals.thirst, 70); T.eq(v.vitals.stress, 56)
        T.eq(v.cash, 0); T.eq(v.bank, 12); T.eq(v.preview, true)
    end)

    T.it('notificaciones: la más reciente primero, recortadas y con límite', function()
        local list = {}
        for i = 1, 25 do PXDInv.pushNotice(list, { title = 'Aviso ' .. i, text = ('x'):rep(300) }, i, 20) end
        T.eq(#list, 20)
        T.eq(list[1].title, 'Aviso 25')
        T.eq(#list[1].text, 240)
        PXDInv.pushNotice(list, { title = 5 }, 26, 20)
        T.eq(list[1].title, 'Aviso 25', 'sin texto válido no se guarda')
    end)
end)
