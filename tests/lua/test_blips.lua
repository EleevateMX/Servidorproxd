-- Pruebas de pxd_blips (lógica pura y configuración).
local T = _G.T
Config = nil
PXDBlips = nil
dofile(RES .. 'pxd_blips/config.lua')
dofile(RES .. 'pxd_blips/shared/blips.lua')

T.describe('pxd_blips', function()
    local bySprite, sprites = PXDBlips.index(Config.rules)

    T.it('la configuración no tiene reglas mal escritas', function()
        T.eq(#PXDBlips.validate(Config.rules), 0)
    end)

    T.it('nombra por sprite solo los blips de corto alcance', function()
        T.eq(PXDBlips.match(bySprite, 59, { x = 0, y = 0 }, true).name, 'Tienda')
        T.eq(PXDBlips.match(bySprite, 59, { x = 0, y = 0 }, false), nil, 'avisos/rutas de largo alcance no se tocan')
        T.eq(PXDBlips.match(bySprite, 1, { x = 0, y = 0 }, true), nil, 'sprite sin regla')
    end)

    T.it('una regla con zona gana a la genérica (comisaría vs. prisión)', function()
        T.eq(PXDBlips.match(bySprite, 60, { x = 434.0, y = -983.0 }, true).name, 'Comisaría')
        T.eq(PXDBlips.match(bySprite, 60, { x = 1700.0, y = 2600.0 }, true).name, 'Prisión')
        T.eq(PXDBlips.match(bySprite, 61, { x = 1746.37, y = 2467.26 }, true).name, 'Enfermería de la prisión')
        T.eq(PXDBlips.match(bySprite, 61, { x = 304.27, y = -600.33 }, true).name, 'Hospital')
    end)

    T.it('sprites compartidos: concesionario por zona y el resto genérico', function()
        T.eq(PXDBlips.match(bySprite, 326, { x = -45.67, y = -1098.34 }, true).name, 'Concesionario')
        T.eq(PXDBlips.match(bySprite, 326, { x = 489.65, y = -1331.82 }, true).name, 'Vehículos de trabajo')
    end)

    T.it('skip: los embarcaderos se nombran y el pescador de pxd_jobs se respeta', function()
        T.eq(PXDBlips.match(bySprite, 356, { x = -277.4, y = 6637.01 }, true).name, 'Embarcadero')
        T.eq(PXDBlips.match(bySprite, 356, { x = -1847.7, y = -1196.2 }, true), nil)
    end)

    T.it('reglas de largo alcance explícitas (zona de buceo)', function()
        T.eq(PXDBlips.match(bySprite, 729, { x = 0, y = 0 }, false).name, 'Zona de buceo')
    end)

    T.it('lista de sprites ordenada y sin duplicados', function()
        local seen = {}
        for i, s in ipairs(sprites) do
            T.falsy(seen[s], 'duplicado ' .. s); seen[s] = true
            if i > 1 then T.truthy(sprites[i - 1] < s) end
        end
    end)

    T.it('validate detecta errores', function()
        local p = PXDBlips.validate({ { name = 'x' }, { sprite = 1 }, { sprite = 2, name = 'y', near = { x = 1 } } })
        T.eq(#p, 3)
    end)
end)
