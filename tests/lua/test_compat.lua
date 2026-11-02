-- Pruebas de pxd_compat: guardado del desgaste de piezas de qbx_mechanicjob.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_compat/'

local saves
local function boot(states)
    Fx.reset({ resourceName = 'pxd_compat', resourceStates = states or { qbx_mechanicjob = 'started' } })
    Config, PXDWear, PXDCompat = nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/wear.lua', 'server/wear.lua' })
    saves = {}
    AddEventHandler('vehiclemod:server:saveStatus', function(plate) saves[#saves + 1] = plate end)
end

T.describe('pxd_compat · desgaste de vehículos', function()
    T.it('lógica: matrículas válidas, intervalo por vehículo y vaciado total', function()
        dofile(RES .. 'pxd_compat/shared/wear.lua')
        local st = PXDWear.new(60)
        T.truthy(PXDWear.mark(st, 'ABC 123'))
        T.falsy(PXDWear.mark(st, ''))
        T.falsy(PXDWear.mark(st, 123))
        T.falsy(PXDWear.mark(st, string.rep('X', 17)))
        T.eq(#PXDWear.due(st, 0), 1)
        PXDWear.saved(st, 'ABC 123', 0)
        PXDWear.mark(st, 'ABC 123')
        T.eq(#PXDWear.due(st, 30), 0, 'aún no toca')
        T.eq(#PXDWear.due(st, 30, true), 1, 'al apagar se guarda todo')
        T.eq(#PXDWear.due(st, 60), 1)
    end)

    T.it('guarda los vehículos con cambios de piezas, uno por minuto como mucho', function()
        boot()
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 001', 'engine', 50)
        Fx.emit('vehiclemod:server:fixEverything', 1, 'PXD 002')
        Fx.advance(16)
        T.eq(table.concat(saves, ','), 'PXD 001,PXD 002')
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 001', 'engine', 40)
        Fx.advance(16)
        T.eq(#saves, 2, 'dentro del minuto no repite')
        Fx.advance(60)
        T.eq(saves[3], 'PXD 001')
    end)

    T.it('al parar qbx_mechanicjob o el servidor guarda lo pendiente', function()
        boot()
        Fx.emit('qb-vehicletuning:server:SetPartLevel', 1, 'PXD 009', 'brakes', 3)
        TriggerEvent('onResourceStop', 'qbx_mechanicjob')
        T.eq(saves[1], 'PXD 009')
    end)

    T.it('sin qbx_mechanicjob no hace nada', function()
        boot({})
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 001', 'engine', 50)
        Fx.advance(120)
        T.eq(#saves, 0)
    end)
end)
