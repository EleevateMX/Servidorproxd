-- Pruebas de la lógica pura de pxd_multichar (validación del registro, formato, ranuras).
local T = _G.T
local DIR = RES .. 'pxd_multichar/'

PXDChar = nil
dofile(DIR .. 'shared/multichar.lua')
local C = PXDChar

local NATS = { 'American', 'Mexican', 'Brazilian' }
local OPTS = {
    nationalities = NATS, limitNationalities = true,
    dateMin = '1930-01-01', dateMax = '2006-12-31',
    profanity = { admin = true, staff = true },
}

local function reg(over)
    local d = { firstname = 'valentina', lastname = 'ríos', nationality = 'mexican', gender = 1, birthdate = '1997-03-12' }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

T.describe('pxd_multichar · nombres', function()
    T.it('capitaliza con acentos, guiones y apóstrofos', function()
        T.eq(C.capitalize('josé ÁNGEL'), 'José Ángel')
        T.eq(C.capitalize("o'neil de-la cruz"), "O'Neil De-La Cruz")
        T.eq(C.capitalize('ñandú'), 'Ñandú')
    end)

    T.it('acepta nombres normales y los limpia', function()
        T.eq(C.validateName('  maría   josé ', 'nombre'), 'María José')
    end)

    T.it('rechaza números, símbolos y separadores sueltos', function()
        T.falsy(C.validateName('J4ck', 'nombre'))
        T.falsy(C.validateName('Ana!', 'nombre'))
        T.falsy(C.validateName("-Ana", 'nombre'))
        T.falsy(C.validateName("Ana-", 'nombre'))
        T.falsy(C.validateName("Ana--Paz", 'nombre'))
    end)

    T.it('limita longitud y número de palabras', function()
        T.falsy(C.validateName('A', 'nombre'))
        T.falsy(C.validateName(string.rep('a', 26), 'nombre'))
        T.falsy(C.validateName('Ana Paz Luz Sol', 'nombre'))
        T.truthy(C.validateName('Ana Paz Luz', 'nombre'))
    end)

    T.it('rechaza palabras prohibidas (sola o dentro del nombre)', function()
        local _, err = C.validateName('Admin', 'nombre', OPTS.profanity)
        T.eq(err, 'Ese nombre no está permitido.')
        T.falsy(C.validateName('El Staff', 'apellido', OPTS.profanity))
    end)

    T.it('no acepta tipos raros', function()
        T.falsy(C.validateName(nil, 'nombre'))
        T.falsy(C.validateName(42, 'nombre'))
        T.falsy(C.validateName('\255\254', 'nombre'))
    end)
end)

T.describe('pxd_multichar · registro', function()
    T.it('devuelve los datos normalizados para qbx_core', function()
        local d = C.validateRegistration(reg(), OPTS)
        T.eq(d.firstname, 'Valentina'); T.eq(d.lastname, 'Ríos')
        T.eq(d.nationality, 'Mexican'); T.eq(d.gender, 1); T.eq(d.birthdate, '1997-03-12')
        T.eq(d.cid, nil, 'el cid lo calcula qbx_core')
    end)

    T.it('nacionalidad fuera de la lista: error en su campo', function()
        local d, err, field = C.validateRegistration(reg({ nationality = 'Marciana' }), OPTS)
        T.falsy(d); T.eq(field, 'nationality'); T.truthy(err:find('lista'))
    end)

    T.it('nacionalidad libre si no se limita', function()
        local d = C.validateRegistration(reg({ nationality = 'yucateca' }), { limitNationalities = false })
        T.eq(d.nationality, 'Yucateca')
    end)

    T.it('sexo solo 0 o 1', function()
        local _, _, field = C.validateRegistration(reg({ gender = 2 }), OPTS)
        T.eq(field, 'gender')
        T.eq(C.validateRegistration(reg({ gender = '0' }), OPTS).gender, 0)
    end)

    T.it('fechas: formato, días reales y límites', function()
        T.truthy(C.validateBirthdate('2000-02-29', OPTS.dateMin, OPTS.dateMax))
        T.falsy(C.validateBirthdate('1999-02-29', OPTS.dateMin, OPTS.dateMax))
        T.falsy(C.validateBirthdate('1999-13-01'))
        T.falsy(C.validateBirthdate('12/03/1997'))
        T.falsy(C.validateBirthdate('2010-01-01', OPTS.dateMin, OPTS.dateMax), 'demasiado joven')
        T.falsy(C.validateBirthdate('1900-01-01', OPTS.dateMin, OPTS.dateMax))
        local _, _, field = C.validateRegistration(reg({ birthdate = '2010-01-01' }), OPTS)
        T.eq(field, 'birthdate')
    end)

    T.it('entrada que no es tabla', function()
        T.falsy(C.validateRegistration('hola', OPTS))
    end)
end)

T.describe('pxd_multichar · formato y ranuras', function()
    T.it('dinero', function()
        T.eq(C.formatMoney(95846), '$95,846')
        T.eq(C.formatMoney(778358.9), '$778,358')
        T.eq(C.formatMoney(0), '$0')
        T.eq(C.formatMoney(-1500), '-$1,500')
        T.eq(C.formatMoney(nil), '$0')
    end)

    T.it('tiempo jugado', function()
        T.eq(C.formatPlaytime(10), 'Recién llegado')
        T.eq(C.formatPlaytime(45 * 60), '45 min')
        T.eq(C.formatPlaytime(3 * 3600 + 12 * 60), '3 h 12 min')
        T.eq(C.formatPlaytime(29 * 86400 + 8 * 3600), '29 días y 8 horas')
        T.eq(C.formatPlaytime(86400 + 3600), '1 día y 1 hora')
        T.eq(C.formatPlaytime(2 * 86400), '2 días')
    end)

    T.it('tarjeta: solo campos conocidos y tipos limpios', function()
        local card = C.toCard({
            citizenid = 'ABC123',
            charinfo = { firstname = 'Ana', lastname = 'Paz', gender = 1, birthdate = '1990-01-01', nationality = 'Mexican', phone = '555' },
            money = { cash = '120', bank = 5000, crypto = 9 },
            job = { label = 'Policía', grade = { name = 'Cadete', level = 0 }, onduty = true },
            metadata = { secreto = true },
        }, { level = 4, xp = 10, xpNext = 100, playtime = 3600 })
        T.eq(card.citizenid, 'ABC123'); T.eq(card.cash, 120); T.eq(card.job, 'Policía'); T.eq(card.grade, 'Cadete')
        T.eq(card.level, 4); T.eq(card.playtime, 3600)
        T.eq(card.phone, nil); T.eq(card.metadata, nil); T.eq(card.crypto, nil)
        T.falsy(C.toCard({ citizenid = 'X' }))
    end)

    T.it('sin resumen de progreso no hay nivel', function()
        local card = C.toCard({ citizenid = 'A', charinfo = { firstname = 'A', lastname = 'B' } })
        T.eq(card.level, nil); T.eq(card.cash, 0)
    end)

    T.it('ranuras: personajes, libres y bloqueadas', function()
        local slots = C.buildSlots({ { citizenid = 'A' }, { citizenid = 'B' } }, 3, 2)
        T.eq(#slots, 5)
        T.eq(slots[1].kind, 'character'); T.eq(slots[2].citizenid, 'B')
        T.eq(slots[3].kind, 'free'); T.eq(slots[4].kind, 'locked'); T.eq(slots[5].index, 5)
    end)

    T.it('ranuras: si hay más personajes que el límite no se esconde ninguno', function()
        local slots = C.buildSlots({ { citizenid = 'A' }, { citizenid = 'B' } }, 1, 0)
        T.eq(#slots, 2); T.eq(slots[2].kind, 'character')
    end)
end)

T.describe('pxd_multichar · integración', function()
    T.it('detecta si qbx_core sigue gestionando los personajes', function()
        T.truthy(C.qbxManagesCharacters('characters = {\n  useExternalCharacters = false, -- x'))
        T.falsy(C.qbxManagesCharacters('characters = {\n  useExternalCharacters = true, -- x'))
        T.truthy(C.qbxManagesCharacters(nil), 'si no se puede leer, mejor no actuar')
    end)

    T.it('confirmar borrado escribiendo el nombre', function()
        local card = { firstname = 'Ana', lastname = 'Ríos' }
        T.truthy(C.confirmName(card, '  ana   ríos '))
        T.truthy(C.confirmName(card, 'ANA RÍOS'))
        T.falsy(C.confirmName(card, 'Ana'))
        T.falsy(C.confirmName(card, nil))
    end)

    T.it('la configuración carga y las escenas tienen coordenadas', function()
        local saved = _G.vec4
        _G.vec4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
        Config = nil
        dofile(DIR .. 'config.lua')
        _G.vec4 = saved
        T.truthy(#Config.scenes > 0)
        for _, s in ipairs(Config.scenes) do T.truthy(s.pedCoords.w and s.camCoords.w) end
        T.truthy(Config.dateMin < Config.dateMax)
        T.eq(type(Config.storeUrl), 'string')
    end)
end)
