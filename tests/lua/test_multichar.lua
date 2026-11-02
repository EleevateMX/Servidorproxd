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
        local saved, saved3 = _G.vec4, _G.vec3
        _G.vec4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
        _G.vec3 = function(x, y, z) return { x = x, y = y, z = z } end
        Config = nil
        dofile(DIR .. 'config.lua')
        _G.vec4, _G.vec3 = saved, saved3
        -- Cámara propia de la aparición: aérea (no la escena de personajes)
        local c = Config.spawnCamera
        T.truthy(c and c.from and c.at and c.optionOffset)
        T.truthy(c.from.z > 100 and c.optionOffset.z > 20, 'vista desde arriba')
        T.truthy(c.interpMs > 0 and c.fov > 0)
        T.truthy(#Config.scenes > 0)
        for _, s in ipairs(Config.scenes) do T.truthy(s.pedCoords.w and s.camCoords.w) end
        T.truthy(Config.dateMin < Config.dateMax)
        T.eq(type(Config.storeUrl), 'string')
    end)
end)

T.describe('pxd_multichar · aparición', function()
    T.it('lee si qbx_core da apartamento inicial', function()
        T.eq(PXDChar.qbxStartingApartment('characters = { startingApartment = false, }'), false)
        T.eq(PXDChar.qbxStartingApartment('characters = { startingApartment = true, }'), true)
        T.eq(PXDChar.qbxStartingApartment(nil), true, 'sin leer: valor por defecto de qbx_core')
    end)

    T.it('opciones: última ubicación, casas y puntos, con ids estables y coordenadas válidas', function()
        local list, byId = PXDChar.buildSpawnOptions(
            { coords = { x = 1, y = 2, z = 3 }, propertyId = 7 },
            { { label = 'Del Perro 12', coords = { x = 4, y = 5, z = 6 }, propertyId = 12 }, { label = 'Rota', coords = { x = 0 / 0, y = 0, z = 0 } } },
            { { label = 'Plaza', detail = 'Centro', coords = { x = 7, y = 8, z = 9, w = 10 }, image = 'img/a.jpg' } })
        T.eq(#list, 3, 'la casa con coordenadas inválidas se descarta')
        T.eq(list[1].id, 'last'); T.eq(list[1].kind, 'last')
        T.eq(list[2].id, 'property:12'); T.eq(byId['property:12'].propertyId, 12)
        T.eq(list[3].id, 'point:1'); T.eq(list[3].image, 'img/a.jpg')
        T.falsy(list[3].coords, 'a la NUI no le llegan coordenadas')
        T.eq(byId['point:1'].coords.w, 10)
    end)

    T.it('sin última ubicación ni casas: solo los puntos', function()
        local list = PXDChar.buildSpawnOptions(nil, nil, { { label = 'Plaza', coords = { x = 1, y = 1, z = 1 } } })
        T.eq(#list, 1); T.eq(list[1].kind, 'point')
    end)
end)

-- ── Apariencia: formato de illenium-appearance 5.7.0 y saneado ─────────
T.describe('pxd_multichar · apariencia (formato de illenium)', function()
    PXDLook = nil
    dofile(DIR .. 'shared/appearance.lua')
    local L = PXDLook

    T.it('los 20 rasgos y los 12 overlays en el orden de illenium (índice = el del native)', function()
        T.eq(#L.FACE_FEATURES, 20); T.eq(L.FACE_FEATURES[1].key, 'noseWidth'); T.eq(L.FACE_FEATURES[20].key, 'neckThickness')
        T.eq(L.FACE_FEATURES[17].key, 'chinBoneLenght', 'con la errata de illenium, o no lo leería')
        T.eq(#L.OVERLAYS, 12); T.eq(L.OVERLAYS[2].key, 'beard'); T.eq(L.OVERLAYS[3].key, 'eyebrows'); T.eq(L.OVERLAYS[12].key, 'bodyBlemishes')
        T.eq(L.OVERLAYS[5].colorType, 2, 'maquillaje con la paleta de maquillaje (como illenium)')
        T.eq(#L.PROP_IDS, 5); T.eq(#L.COMPONENT_IDS, 12)
    end)

    T.it('por defecto: freemode completo con las claves que lee illenium', function()
        for g = 0, 1 do
            local d = L.default(g)
            T.eq(d.model, g == 1 and 'mp_f_freemode_01' or 'mp_m_freemode_01')
            for _, k in ipairs({ 'shapeFirst', 'shapeSecond', 'shapeThird', 'skinFirst', 'skinSecond', 'skinThird', 'shapeMix', 'skinMix', 'thirdMix' }) do
                T.truthy(d.headBlend[k] ~= nil, k)
            end
            T.eq(#d.components, 12); T.eq(#d.props, 5)
            T.truthy(d.hair.style and d.hair.color and d.hair.highlight and d.hair.texture)
            for _, o in ipairs(L.OVERLAYS) do T.truthy(d.headOverlays[o.key].opacity ~= nil) end
        end
        local m = L.default(0)
        local top
        for _, c in ipairs(m.components) do if c.component_id == 11 then top = c end end
        T.eq(top.drawable, 15, 'ropa inicial de qbx_core')
    end)

    T.it('saneado: rangos reales, decimales como illenium y modelo freemode al crear', function()
        local lim = L.defaultLimits()
        lim.components[2] = { drawables = 74, textures = 3 }
        lim.overlays[1] = 29
        local look = L.default(0)
        look.faceFeatures.noseWidth = 3.14159
        look.headBlend.shapeMix = 1.7
        look.headBlend.shapeFirst = 99
        look.hair.style = 500
        look.headOverlays.beard = { style = 80, opacity = 0.876, color = -3, secondColor = 9000 }
        local s = L.sanitize(look, lim, true)
        T.eq(s.faceFeatures.noseWidth, 1); T.eq(s.headBlend.shapeMix, 1); T.eq(s.headBlend.shapeFirst, 45)
        T.eq(s.hair.style, 73); T.eq(s.components[3].drawable, 73, 'el componente 2 sigue a hair')
        T.eq(s.headOverlays.beard.style, 28); T.eq(s.headOverlays.beard.opacity, 0.9); T.eq(s.headOverlays.beard.color, 0)
        T.eq(s.headOverlays.beard.secondColor, 63)
        look.model = 'a_m_y_hipster_01'
        T.falsy(L.sanitize(look, lim, true), 'crear: solo freemode')
        T.truthy(L.sanitize(look, lim, false), 'personajes existentes con otro modelo se respetan')
        T.falsy(L.sanitize({ model = "x'; DROP" }, lim, false), 'nombre de modelo raro')
        T.falsy(L.sanitize('nada'))
    end)

    T.it('accesorios: -1 = ninguno (textura -1), como los guarda illenium', function()
        local look = L.default(0)
        look.props[1] = { prop_id = 0, drawable = -1, texture = 4 }
        look.props[2] = { prop_id = 1, drawable = 3, texture = 2 }
        local s = L.sanitize(look, nil, true)
        T.eq(s.props[1].drawable, -1); T.eq(s.props[1].texture, -1)
        T.eq(s.props[2].drawable, 3); T.eq(s.props[2].texture, 2)
    end)

    T.it('editor restringido (peluquería): solo cambia lo permitido; el modelo nunca', function()
        local old = L.default(0)
        local new = L.copy(old)
        new.model = 'mp_f_freemode_01'
        new.hair.style = 9; new.headOverlays.beard.opacity = 1; new.faceFeatures.noseWidth = 0.5
        new.headBlend.shapeFirst = 30; new.components[12].drawable = 40
        local r = L.restrict(new, old, { 'hair' })
        T.eq(r.model, 'mp_m_freemode_01'); T.eq(r.hair.style, 9); T.eq(r.headOverlays.beard.opacity, 1)
        T.eq(r.faceFeatures.noseWidth, 0); T.eq(r.headBlend.shapeFirst, 0); T.eq(r.components[12].drawable, 15)
        T.eq(r.components[3].drawable, 9, 'el pelo del componente 2 acompaña')
    end)
end)

-- ── Servidor: guardado verificado, buckets, R.I.P. (MariaDB simulada) ───
T.describe('pxd_multichar · servidor (simulado)', function()
    local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
    local db, callbacks, players, buckets

    local function boot(opts)
        opts = opts or {}
        callbacks, buckets = {}, {}
        db = { skins = {}, status = opts.status or {}, players = opts.players or { { citizenid = 'MINE1', license = 'license:1' }, { citizenid = 'MINE2', license = 'license:1' }, { citizenid = 'OTHER', license = 'license:2' } },
            queries = {}, failTx = opts.failTx, corrupt = opts.corrupt }
        players = { [1] = { PlayerData = { citizenid = 'MINE1' } } }
        Fx.reset({ resourceName = 'pxd_multichar', resourceStates = { qbx_core = 'started' },
            exports = { qbx_core = {
                GetPlayer = function(src) return players[src] end,
                SetPlayerBucket = function(src, b) buckets[src] = b; return true end,
            } },
            files = {
                ['qbx_core/config/client.lua'] = 'characters = { useExternalCharacters = true }',
                ['qbx_core/data/nationalities.lua'] = "return { 'Mexican' }",
            } })
        _G.vec4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
        _G.vec3 = function(x, y, z) return { x = x, y = y, z = z } end
        _G.lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
        _G.json = { encode = Fx.json.encode, decode = Fx.json.decode }
        _G.MySQL = {
            query = { await = function(q, p)
                db.queries[#db.queries + 1] = q
                if q:find('CREATE TABLE') then return {} end
                if q:find('SELECT citizenid FROM players') then
                    local out = {}
                    for _, r in ipairs(db.players) do if r.license == p[1] or r.license == p[2] then out[#out + 1] = { citizenid = r.citizenid } end end
                    return out
                end
                if q:find('FROM pxd_character_status') then
                    local out = {}
                    for _, cid in ipairs(p) do if db.status[cid] then out[#out + 1] = { citizenid = cid, status = db.status[cid] } end end
                    return out
                end
                if q:find('SELECT citizenid, metadata FROM players') then return {} end
                error('consulta no simulada: ' .. q)
            end },
            transaction = { await = function(list)
                if db.failTx then return false end
                for _, it in ipairs(list) do
                    db.queries[#db.queries + 1] = it.query
                    local q, v = it.query, it.values
                    if q:find('^UPDATE playerskins SET active = 0') then for _, r in ipairs(db.skins) do if r.citizenid == v[1] then r.active = 0 end end
                    elseif q:find('^DELETE FROM playerskins') then
                        for i = #db.skins, 1, -1 do if db.skins[i].citizenid == v[1] and db.skins[i].model == v[2] then table.remove(db.skins, i) end end
                    elseif q:find('^INSERT INTO playerskins') then db.skins[#db.skins + 1] = { citizenid = v[1], model = v[2], skin = v[3], active = 1 }
                    else error('transacción no simulada: ' .. q) end
                end
                return true
            end },
            single = { await = function(q, p)
                db.queries[#db.queries + 1] = q
                if q:find('FROM playerskins WHERE citizenid = %? AND active = 1') then
                    for _, r in ipairs(db.skins) do
                        if r.citizenid == p[1] and r.active == 1 then return { citizenid = r.citizenid, model = r.model, skin = db.corrupt and '{}' or r.skin } end
                    end
                    return nil
                end
                if q:find('SELECT id FROM playerskins') then for _, r in ipairs(db.skins) do if r.citizenid == p[1] then return { id = 1 } end end return nil end
                error('single no simulado: ' .. q)
            end },
        }
        Config, PXDChar, PXDLook, PXDCharServer = nil, nil, nil, nil
        Fx.load(DIR, { 'config.lua', 'shared/multichar.lua', 'shared/appearance.lua', 'server/main.lua' })
        Fx.addPlayer(1, 'yo', nil, nil, { license = 'license:1' })
        Fx.addPlayer(2, 'otro', nil, nil, { license = 'license:2' })
    end
    local function call(name, src, ...) return callbacks[name](src, ...) end

    T.it('guarda en playerskins como illenium (una activa por personaje) y lo comprueba al releer', function()
        boot()
        Fx.advance(5)
        local look = PXDLook.default(1)
        look.faceFeatures.chinHole = 0.4
        local r = call('pxd_multichar:server:saveAppearance', 1, look, 'create')
        T.truthy(r.ok, r.error); T.eq(r.citizenid, 'MINE1')
        T.eq(#db.skins, 1); T.eq(db.skins[1].model, 'mp_f_freemode_01'); T.eq(db.skins[1].active, 1)
        local stored = json.decode(db.skins[1].skin)
        T.eq(stored.faceFeatures.chinHole, 0.4, 'mismo formato que lee illenium (json de la apariencia)')
        -- Volver a guardar con otro modelo: la anterior queda inactiva, no se duplica.
        Fx.advance(5)
        local r2 = call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'recover')
        T.truthy(r2.ok); T.eq(#db.skins, 2)
        local active = 0
        for _, s in ipairs(db.skins) do if s.active == 1 then active = active + 1; T.eq(s.model, 'mp_m_freemode_01') end end
        T.eq(active, 1)
    end)

    T.it('solo toca playerskins del citizenid cargado: nunca players, properties ni otras tablas', function()
        boot()
        Fx.advance(5)
        call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'create')
        for _, q in ipairs(db.queries) do
            if not q:find('CREATE TABLE') and not q:find('^SELECT') then
                T.truthy(q:find('playerskins'), 'escritura fuera de playerskins: ' .. q)
            end
        end
    end)

    T.it('crear/recuperar exige freemode; si la relectura no coincide o la BD falla, no da por buena la apariencia', function()
        boot(); Fx.advance(5)
        local bad = PXDLook.default(0); bad.model = 'a_m_y_hipster_01'
        T.falsy(call('pxd_multichar:server:saveAppearance', 1, bad, 'create').ok)
        boot({ failTx = true }); Fx.advance(5)
        T.falsy(call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'create').ok)
        boot({ corrupt = true }); Fx.advance(5)
        local r = call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'create')
        T.falsy(r.ok); T.truthy(r.error:find('no coincide'))
        players[1] = nil
        Fx.advance(5)
        T.falsy(call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'create').ok, 'sin personaje cargado')
    end)

    T.it('limita la frecuencia de guardado (anti spam)', function()
        boot(); Fx.advance(5)
        T.truthy(call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'create').ok)
        T.falsy(call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'create').ok)
    end)

    T.it('¿tiene apariencia?: solo personajes propios (los ajenos responden «sí» para no revelar nada)', function()
        boot(); Fx.advance(5)
        T.eq(call('pxd_multichar:server:hasAppearance', 1, 'MINE2'), false)
        call('pxd_multichar:server:saveAppearance', 1, PXDLook.default(0), 'create')
        T.eq(call('pxd_multichar:server:hasAppearance', 1, 'MINE1'), true)
        T.eq(call('pxd_multichar:server:hasAppearance', 1, 'OTHER'), true)
    end)

    T.it('bucket propio durante el editor (fuera del rango de pxd_gamemodes) y vuelta al 0', function()
        boot()
        local b = call('pxd_multichar:server:enterCreator', 1)
        T.eq(b, Config.creator.bucketBase + 1); T.truthy(b > 60000 + 1000, 'lejos de los buckets de partidas')
        T.eq(buckets[1], b)
        call('pxd_multichar:server:leaveCreator', 1)
        T.eq(buckets[1], 0)
        buckets[1] = 55
        call('pxd_multichar:server:leaveCreator', 1)
        T.eq(buckets[1], 55, 'sin haber entrado al editor no toca el bucket (p. ej. una partida)')
    end)

    T.it('R.I.P.: tabla nueva (vacía = todos activos); solo estados de personajes propios', function()
        boot({ status = { MINE2 = 'dead', OTHER = 'dead' } })
        local created = false
        for _, q in ipairs(db.queries) do if q:find('CREATE TABLE IF NOT EXISTS pxd_character_status') then created = true end end
        T.truthy(created, 'CREATE TABLE IF NOT EXISTS: no borra nada')
        local st = call('pxd_multichar:server:statuses', 1)
        T.eq(st.MINE2, 'dead'); T.falsy(st.MINE1); T.falsy(st.OTHER)
        T.eq(call('pxd_multichar:server:setup', 1).statuses.MINE2, 'dead')
    end)
end)
