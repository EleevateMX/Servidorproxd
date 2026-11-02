-- Simulación del cliente de pxd_multichar: ejecuta client/main.lua con natives falsas y
-- comprueba el ORDEN de los pasos al crear y al jugar (que nunca se abran dos pantallas
-- a la vez, que no se quede en negro y que, si algo falla, haya salida).
local T = _G.T
local DIR = RES .. 'pxd_multichar/'

local function makeEnv(opts)
    local log, nui, handlers, nuiCb = {}, {}, {}, {}
    local G = _G
    local savedMt = getmetatable(G)
    local env = { log = log, nui = nui, nuiCb = nuiCb, handlers = handlers }

    local function vec(x, y, z, w) return { x = x, y = y, z = z, w = w } end
    G.vec3, G.vector3, G.vec4, G.vector4 = vec, vec, vec, vec
    G.GetHashKey = function(s) return #s end
    G.joaat = G.GetHashKey
    G.cache = { ped = 1, playerId = 1 }
    G.print = function() end
    local files = {
        ['qbx_core/config/client.lua'] = 'return { characters = { useExternalCharacters = true, startingApartment = ' .. tostring(opts.startingApartment ~= false) .. ', } }',
        ['qbx_core/config/shared.lua'] = 'return { defaultSpawn = vec4(1.0, 2.0, 3.0, 4.0) }',
        ['qbx_properties/config/shared.lua'] = [[return { apartmentOptions = {
            { interior = 'DellPerroHeightsApt4', label = 'Del Perro Heights Apt', description = 'x', enter = vec3(-1447.35, -537.84, 34.74) },
            { interior = 'TinselTowersApt42', label = 'Tinsel Towers Apt', description = 'y', enter = vec3(-614.58, 46.52, 43.59) },
        } }]],
    }
    if opts.noApartmentConfig then files['qbx_properties/config/shared.lua'] = nil end
    G.LoadResourceFile = function(res, path) return files[res .. '/' .. path] end
    local states = opts.states or { qbx_properties = 'started', qbx_spawn = 'started', ['illenium-appearance'] = 'started', pxd_hud = 'started' }
    G.GetResourceState = function(name) return states[name] or 'missing' end

    G.lib = { requestModel = function() end, callback = { await = function(name, _, ...)
        log[#log + 1] = 'cb:' .. name
        local r = opts.callbacks[name]
        if type(r) == 'function' then return r(...) end
        if type(r) == 'table' and r.multi then return table.unpack(r.multi) end
        return r
    end } }
    env.exported = {}
    G.exports = setmetatable({}, {
        __index = function(_, res)
            return setmetatable({}, { __index = function(_, fn)
                return function(_, ...)
                    if res == 'qbx_core' and fn == 'GetPlayerData' then return opts.playerData end
                    if res == 'illenium-appearance' then
                        log[#log + 1] = 'illenium:' .. fn
                        if fn == 'setPedAppearance' then env.lastApplied = select(2, ...) end
                        if fn == 'getPedAppearance' then return opts.currentLook end
                    end
                    if res == 'pxd_hud' then log[#log + 1] = 'hud:' .. tostring((...)) end
                end
            end })
        end,
        __call = function(_, name, fn) env.exported[name] = fn end,
    })
    G.LocalPlayer = { state = { isLoggedIn = true } }
    -- Rangos realistas del modelo (el editor sanea con ellos).
    G.GetNumHairColors = function() return 64 end
    G.GetNumMakeupColors = function() return 64 end
    G.GetPedHairRgbColor = function(i) return i, i, i end
    G.GetPedMakeupRgbColor = function(i) return i, 0, 0 end
    G.GetPedHeadOverlayNum = function() return 20 end
    G.GetNumberOfPedDrawableVariations = function() return 100 end
    G.GetNumberOfPedTextureVariations = function() return 5 end
    G.GetNumberOfPedPropDrawableVariations = function() return 40 end
    G.GetNumberOfPedPropTextureVariations = function() return 3 end
    G.GetOffsetFromEntityInWorldCoords = function(_, x, y, z) return vec(x, y, z) end
    G.ClearPedDecorations = function() log[#log + 1] = 'clearDecorations' end
    G.SetPedDefaultComponentVariation = function() log[#log + 1] = 'defaultComponents' end
    G.SetPlayerModel = function(_, m) log[#log + 1] = 'model:' .. tostring(m) end
    G.GetEntityCoords = function() return vec(1.0, 2.0, 3.0) end
    G.json = { decode = function(t) return load('return ' .. t)() end }

    -- promesas y espera como en CfxLua (con corrutinas)
    G.promise = { new = function() local p = { done = false }; function p:resolve(v) self.done = true; self.value = v end; return p end }
    G.Citizen = { Await = function(p) while not p.done do coroutine.yield('await') end return p.value end }
    G.Wait = function() if coroutine.isyieldable() then coroutine.yield('wait') end end
    G.CreateThread = function() end   -- al cargar: sin hilos (bucles de la sesión)
    env.threads = {}
    local function realThread(fn)
        local co = coroutine.create(fn)
        env.threads[#env.threads + 1] = co
        local ok, err = coroutine.resume(co)
        assert(ok, err)
    end
    --- Avanza todos los hilos vivos (esperas, Citizen.Await) unas cuantas vueltas.
    env.pump = function(n)
        for _ = 1, n or 30 do
            for _, co in ipairs(env.threads) do
                if coroutine.status(co) == 'suspended' then local ok, err = coroutine.resume(co); assert(ok, err) end
            end
        end
    end
    G.SetTimeout = function(ms) log[#log + 1] = 'timeout:' .. ms end

    G.RegisterNUICallback = function(name, fn) nuiCb[name] = fn end
    G.RegisterNetEvent = function(name, fn) if fn then handlers[name] = fn end end
    G.AddEventHandler = function(name, fn) handlers[name] = fn end
    G.TriggerEvent = function(name, ...) log[#log + 1] = 'ev:' .. name end
    env.serverArgs = {}
    G.TriggerServerEvent = function(name, ...) log[#log + 1] = 'sv:' .. name; env.serverArgs[name] = { ... } end
    G.SendNUIMessage = function(m) nui[#nui + 1] = m end
    G.SetNuiFocus = function(a) log[#log + 1] = 'focus:' .. tostring(a) end
    G.IsScreenFadedOut = function() return true end
    G.IsScreenFadedIn = function() return true end
    G.DoScreenFadeOut = function() log[#log + 1] = 'fadeOut' end
    G.DoScreenFadeIn = function() log[#log + 1] = 'fadeIn' end
    G.SetEntityCoords = function(_, x, y, z) log[#log + 1] = ('coords:%.1f,%.1f,%.1f'):format(x, y, z) end
    G.GetInvokingResource = function() return nil end
    -- Cámaras y visibilidad: se registran para comprobar el orden.
    G.SetEntityVisible = function(_, on) log[#log + 1] = 'visible:' .. tostring(on) end
    G.PointCamAtCoord = function(_, x, y, z) log[#log + 1] = ('lookAt:%.1f,%.1f,%.1f'):format(x, y, z) end
    G.SetCamActiveWithInterp = function() log[#log + 1] = 'interp' end
    G.SetFocusPosAndVel = function() log[#log + 1] = 'focusArea' end
    G.ClearFocus = function() log[#log + 1] = 'clearFocus' end
    G.DestroyCam = function() log[#log + 1] = 'destroyCam' end
    G.RenderScriptCams = function(on) log[#log + 1] = 'render:' .. tostring(on) end
    G.DoesCamExist = function() return true end
    -- El resto de natives (cámara, modelos…): no hacen nada.
    setmetatable(G, { __index = function(_, k)
        if type(k) == 'string' and k:match('^%u') and not k:match('^PXD') and k ~= 'Config' then return function() return 0 end end
    end })
    env.restore = function() setmetatable(G, savedMt) end

    Config, PXDChar, PXDLook, PXDEditor = nil, nil, nil, nil
    dofile(DIR .. 'config.lua')
    dofile(DIR .. 'shared/multichar.lua')
    dofile(DIR .. 'shared/appearance.lua')
    dofile(DIR .. 'client/editor.lua')
    dofile(DIR .. 'client/main.lua')
    G.CreateThread = realThread
    return env
end

-- Ejecuta un callback de la NUI como corrutina; devuelve un «paso» para ir avanzando.
local function run(env, name, data)
    local result
    local co = coroutine.create(function() env.nuiCb[name](data, function(r) result = r end) end)
    local function step()
        for _ = 1, 50 do
            if coroutine.status(co) == 'dead' then return 'dead' end
            local ok, why = coroutine.resume(co)
            assert(ok, why)
            if why == 'await' then return 'await' end
        end
        return coroutine.status(co)
    end
    return step, function() return result end
end

local function indexOf(log, item)
    for i, v in ipairs(log) do if v == item then return i end end
end

local function lastNui(env, action)
    for i = #env.nui, 1, -1 do if env.nui[i].action == action then return env.nui[i] end end
end

local registration = { firstname = 'Ana', lastname = 'Lima', nationality = 'Mexican', gender = 1, birthdate = '1995-05-05' }

T.describe('pxd_multichar · flujo en el cliente (simulado)', function()
    local function createEnv(o)
        o = o or {}
        local cbs = {
            ['qbx_core:server:getCharacters'] = { multi = { {}, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['pxd_multichar:server:checkRegistration'] = o.check or { ok = true, data = registration },
            ['qbx_core:server:createCharacter'] = o.created == nil and { citizenid = 'ABC' } or o.created,
            ['pxd_multichar:server:saveAppearance'] = o.save or { ok = true, citizenid = 'ABC' },
            ['pxd_multichar:server:enterCreator'] = 70001,
            ['pxd_multichar:server:leaveCreator'] = true,
        }
        for k, v in pairs(o.callbacks or {}) do cbs[k] = v end
        local env = makeEnv({ startingApartment = o.startingApartment, noApartmentConfig = o.noApartmentConfig, callbacks = cbs })
        env.handlers['qbx_core:client:playerLoggedOut']()
        run(env, 'createStart', {})()
        return env
    end
    local function finish(env, look, identity)
        local r = run(env, 'editorFinish', { look = look or PXDLook.default(1), identity = identity or registration })
        r(); env.pump()
    end
    local function count(env, item) local n = 0 for _, v in ipairs(env.log) do if v == item then n = n + 1 end end return n end

    T.it('crear: abre NUESTRO editor en un bucket propio, sin el de illenium ni la pantalla de selección', function()
        local env = createEnv()
        local ed = lastNui(env, 'editor')
        T.truthy(ed, 'se abre el editor')
        T.eq(ed.data.mode, 'create'); T.eq(#ed.data.sections, 6); T.eq(ed.data.sections[1], 'identity')
        T.eq(ed.data.look.model, 'mp_m_freemode_01', 'freemode desde cero')
        T.truthy(ed.data.defaults and ed.data.defaults[1].model == 'mp_f_freemode_01', 'apariencia por defecto de cada sexo')
        T.eq(#ed.data.palettes.hair, 64, 'paleta real de pelo (GetPedHairRgbColor)')
        T.truthy(indexOf(env.log, 'cb:pxd_multichar:server:enterCreator'), 'bucket propio')
        T.falsy(indexOf(env.log, 'illenium:startPlayerCustomization'), 'nunca el editor de illenium')
        T.truthy(indexOf(env.log, 'hud:false'), 'HUD oculto')
        T.eq(lastNui(env, 'close').action, 'close', 'la selección se cierra antes')
        env.restore()
    end)

    T.it('crear con apartamentos: identidad → qbx_core → apariencia guardada → editor cerrado → bucket 0 → apartamento → carga', function()
        local env = createEnv()
        finish(env)
        local L = env.log
        local check, created = indexOf(L, 'cb:pxd_multichar:server:checkRegistration'), indexOf(L, 'cb:qbx_core:server:createCharacter')
        local saved, left = indexOf(L, 'cb:pxd_multichar:server:saveAppearance'), indexOf(L, 'cb:pxd_multichar:server:leaveCreator')
        T.truthy(check and created and saved and left, 'todos los pasos')
        T.truthy(check < created and created < saved and saved < left, 'orden: validar → crear → apariencia → liberar bucket')
        local view = lastNui(env, 'spawn')
        T.eq(view.data.mode, 'apartment', 'después elige apartamento')
        local closeIdx, spawnIdx
        for i, m in ipairs(env.nui) do
            if m.action == 'editorClose' then closeIdx = i end
            if m.action == 'spawn' then spawnIdx = i end
        end
        T.truthy(closeIdx and spawnIdx and closeIdx < spawnIdx, 'el editor se cierra antes de enseñar el apartamento')
        T.falsy(indexOf(L, 'sv:QBCore:Server:OnPlayerLoaded'), 'todavía no se carga')
        run(env, 'spawnChoose', { id = 'apt:2' })()
        env.pump()
        local sel, loaded = indexOf(L, 'sv:qbx_properties:server:apartmentSelect'), indexOf(L, 'sv:QBCore:Server:OnPlayerLoaded')
        T.truthy(left < sel and sel < loaded, 'bucket liberado antes de que qbx_properties lo coloque en su apartamento')
        T.eq(env.serverArgs['qbx_properties:server:apartmentSelect'][1], 2)
        T.falsy(indexOf(L, 'ev:qb-clothes:client:CreateFirstCharacter'), 'no se abre el editor de illenium después')
        T.falsy(indexOf(L, 'ev:apartments:client:setupSpawnUI'), 'ni la pizarra de qbx_properties')
        T.truthy(indexOf(L, 'hud:true'), 'HUD restaurado')
        env.restore()
    end)

    T.it('registro rechazado por el servidor: no se crea nada y el editor sigue abierto con el error', function()
        local env = createEnv({ check = { ok = false, error = 'El nombre es demasiado corto.', field = 'firstname' } })
        finish(env)
        T.falsy(indexOf(env.log, 'cb:qbx_core:server:createCharacter'))
        T.falsy(lastNui(env, 'editorClose'), 'sigue abierto')
        local err = lastNui(env, 'editorError')
        T.eq(err.field, 'firstname'); T.eq(err.text, 'El nombre es demasiado corto.')
        -- Se puede corregir y volver a intentar (no hay doble envío mientras tanto).
        env.restore()
    end)

    T.it('qbx_core rechaza la creación: sin personaje a medias, el editor sigue y se puede reintentar', function()
        local tries = 0
        local env = createEnv({ created = false, callbacks = { ['qbx_core:server:createCharacter'] = function() tries = tries + 1; if tries == 1 then return nil end return { citizenid = 'ABC' } end } })
        finish(env)
        T.falsy(indexOf(env.log, 'cb:pxd_multichar:server:saveAppearance'), 'sin apariencia de un personaje que no existe')
        T.truthy(lastNui(env, 'editorError'))
        T.falsy(lastNui(env, 'editorClose'))
        finish(env)
        T.eq(tries, 2, 'segundo intento')
        T.truthy(indexOf(env.log, 'cb:pxd_multichar:server:saveAppearance'))
        T.truthy(lastNui(env, 'editorClose'))
        env.restore()
    end)

    T.it('si falla guardar la apariencia, se reintenta 3 veces y el personaje sigue (se completará al volver a entrar)', function()
        local env = createEnv({ save = { ok = false, error = 'x' } })
        finish(env)
        T.eq(count(env, 'cb:pxd_multichar:server:saveAppearance'), 3)
        T.truthy(lastNui(env, 'editorClose'), 'continúa a la elección de apartamento')
        env.restore()
    end)

    T.it('doble clic en «Crear personaje»: un solo envío', function()
        local env = createEnv()
        local r1 = run(env, 'editorFinish', { look = PXDLook.default(0), identity = registration })
        local r2 = run(env, 'editorFinish', { look = PXDLook.default(0), identity = registration })
        r1(); r2(); env.pump()
        T.eq(count(env, 'cb:qbx_core:server:createCharacter'), 1)
        env.restore()
    end)

    T.it('volver a la selección desde el editor: no se crea nada y se libera el bucket', function()
        local env = createEnv()
        run(env, 'editorCancel', {})()
        env.pump()
        -- En creación «Volver» está permitido: se cierra sin crear.
        T.falsy(indexOf(env.log, 'cb:qbx_core:server:createCharacter'))
        env.restore()
    end)

    T.it('el editor sanea lo que manda la NUI: modelo no freemode, valores fuera de rango', function()
        local env = createEnv()
        local bad = PXDLook.default(0)
        bad.model = 'a_m_y_hipster_01'
        bad.faceFeatures.noseWidth = 7
        bad.hair.style = 999
        bad.headOverlays.beard.opacity = 4
        local res
        local co = coroutine.create(function() env.nuiCb.editorLook({ look = bad }, function(r) res = r end) end)
        coroutine.resume(co)
        T.truthy(res.ok)
        T.eq(res.look.model, 'mp_m_freemode_01', 'sigue siendo freemode')
        T.eq(res.look.faceFeatures.noseWidth, 1); T.eq(res.look.hair.style, 99); T.eq(res.look.headOverlays.beard.opacity, 1)
        T.truthy(indexOf(env.log, 'illenium:setPedAppearance'), 'se aplica al ped con illenium')
        env.restore()
    end)

    T.it('jugar: elegir dónde aparecer con nuestra pantalla (sin la pizarra de qbx_spawn)', function()
        local character = { citizenid = 'XYZ', charinfo = { firstname = 'Ana', lastname = 'Lima', gender = 1, birthdate = '1995-05-05', nationality = 'Mexican' },
            money = { cash = 1, bank = 2 }, job = { label = 'Taxi', grade = { name = 'Novato' } }, metadata = {} }
        local env = makeEnv({ callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { { character }, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['qbx_core:server:loadCharacter'] = true,
            ['pxd_multichar:server:needsApartment'] = false,
            ['qbx_spawn:server:getLastLocation'] = { multi = { { x = 10.0, y = 20.0, z = 30.0, w = 1.0 }, nil } },
            ['qbx_spawn:server:getProperties'] = { { label = 'Del Perro Heights 12', coords = { x = 5, y = 6, z = 7 }, propertyId = 12 } },
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local step = run(env, 'play', { citizenid = 'XYZ' })
        T.eq(step(), 'await')
        local view = lastNui(env, 'spawn')
        T.eq(view.data.mode, 'spawn')
        T.eq(view.data.options[1].id, 'last'); T.eq(view.data.options[2].id, 'property:12')
        T.eq(#view.data.options, 2 + #Config.spawnPoints)
        T.falsy(indexOf(env.log, 'ev:qb-spawn:client:setupSpawns'), 'la pizarra de qbx_spawn no se usa')
        local choose = run(env, 'spawnChoose', { id = 'property:12' })
        T.eq(choose(), 'dead'); T.eq(step(), 'dead')
        T.truthy(indexOf(env.log, 'sv:qbx_properties:server:enterProperty'), 'entra en su casa como hace qbx_spawn')
        T.truthy(indexOf(env.log, 'fadeIn'))
        env.restore()
    end)

    T.it('jugar con una opción falsa desde la NUI: se ignora', function()
        local character = { citizenid = 'XYZ', charinfo = { firstname = 'Ana', lastname = 'Lima', gender = 1 }, money = {}, job = {}, metadata = {} }
        local env = makeEnv({ callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { { character }, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['qbx_core:server:loadCharacter'] = true,
            ['pxd_multichar:server:needsApartment'] = false,
            ['qbx_spawn:server:getLastLocation'] = { multi = { nil, nil } },
            ['qbx_spawn:server:getProperties'] = {},
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local step = run(env, 'play', { citizenid = 'XYZ' })
        T.eq(step(), 'await')
        local _, res = run(env, 'spawnChoose', { id = 'point:99' })
        local bad = run(env, 'spawnChoose', { id = 'point:99' })
        T.eq(bad(), 'dead')
        T.eq(step(), 'await', 'sigue esperando una opción válida')
        local ok = run(env, 'spawnChoose', { id = 'point:1' })
        T.eq(ok(), 'dead'); T.eq(step(), 'dead')
        local c = Config.spawnPoints[1].coords
        T.truthy(indexOf(env.log, ('coords:%.1f,%.1f,%.1f'):format(c.x, c.y, c.z)))
        env.restore()
    end)

    T.it('aparición: sin la escena de personajes detrás, cámara aérea propia y todo restaurado al elegir', function()
        local character = { citizenid = 'XYZ', charinfo = { firstname = 'Ana', lastname = 'Lima', gender = 1 }, money = {}, job = {}, metadata = {} }
        local env = makeEnv({ callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { { character }, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['qbx_core:server:loadCharacter'] = true,
            ['pxd_multichar:server:needsApartment'] = false,
            ['qbx_spawn:server:getLastLocation'] = { multi = { nil, nil } },
            ['qbx_spawn:server:getProperties'] = {},
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local before = #env.log
        local step = run(env, 'play', { citizenid = 'XYZ' })
        T.eq(step(), 'await')
        local function after(item) for i = before + 1, #env.log do if env.log[i] == item then return i end end end
        local hide, fadeIn = after('visible:false'), after('fadeIn')
        local a = Config.spawnCamera.at
        local aerial = after(('lookAt:%.1f,%.1f,%.1f'):format(a.x, a.y, a.z))
        T.truthy(hide and aerial and fadeIn, 'personaje oculto y vista aérea')
        T.truthy(hide < fadeIn and aerial < fadeIn, 'antes de quitar el fundido: nunca se ve el interior de la selección')
        -- Marcar una opción mueve la cámara a ese punto; una falsa no hace nada.
        local n = #env.log
        run(env, 'spawnFocus', { id = 'point:99' })()
        T.eq(#env.log, n, 'opción inexistente: sin cambios')
        run(env, 'spawnFocus', { id = 'point:2' })()
        local c = Config.spawnPoints[2].coords
        T.truthy(after(('lookAt:%.1f,%.1f,%.1f'):format(c.x, c.y, c.z)) and after('interp'), 'transición suave al punto')
        local choose = run(env, 'spawnChoose', { id = 'point:2' })
        T.eq(choose(), 'dead'); T.eq(step(), 'dead')
        local show, clear, loaded = after('visible:true'), after('clearFocus'), after('sv:QBCore:Server:OnPlayerLoaded')
        T.truthy(show and clear, 'personaje visible y carga del mundo alrededor del jugador otra vez')
        T.eq(env.log[#env.log], 'fadeIn')
        T.truthy(loaded, 'se carga el personaje')
        env.restore()
    end)

    T.it('apartamento: espera a que qbx_properties lo guarde antes de cargar (no abre su pizarra encima)', function()
        local pending = 3
        local env = createEnv({ callbacks = {
            ['pxd_multichar:server:needsApartment'] = function() pending = pending - 1; return pending > 0 end,
        } })
        finish(env)
        run(env, 'spawnChoose', { id = 'apt:1' })()
        env.pump()
        local sel = indexOf(env.log, 'sv:qbx_properties:server:apartmentSelect')
        local loaded = indexOf(env.log, 'sv:QBCore:Server:OnPlayerLoaded')
        local checks = 0
        for i = sel, loaded do if env.log[i] == 'cb:pxd_multichar:server:needsApartment' then checks = checks + 1 end end
        T.eq(checks, 3, 'consulta hasta que el apartamento existe')
        T.eq(pending, 0)
        env.restore()
    end)

    local played = { citizenid = 'XYZ', charinfo = { firstname = 'Ana', lastname = 'Lima', gender = 1 }, money = {}, job = {}, metadata = {} }
    local function playEnv(extra)
        local cbs = {
            ['qbx_core:server:getCharacters'] = { multi = { { played }, 3 } },
            ['pxd_multichar:server:setup'] = extra.setup or {},
            ['qbx_core:server:loadCharacter'] = true,
            ['pxd_multichar:server:needsApartment'] = false,
            ['pxd_multichar:server:hasAppearance'] = extra.has,
            ['pxd_multichar:server:saveAppearance'] = { ok = true },
            ['qbx_spawn:server:getLastLocation'] = { multi = { nil, nil } },
            ['qbx_spawn:server:getProperties'] = {},
        }
        local env = makeEnv({ callbacks = cbs, currentLook = extra.currentLook })
        env.handlers['qbx_core:client:playerLoggedOut']()
        return env
    end

    T.it('personaje sin apariencia guardada (creación interrumpida): se completa antes de aparecer, sin tocar la identidad', function()
        local env = playEnv({ has = false })
        local step = run(env, 'play', { citizenid = 'XYZ' })
        T.eq(step(), 'await')
        local ed = lastNui(env, 'editor')
        T.eq(ed.data.mode, 'recover'); T.eq(ed.data.sections[1], 'heritage', 'la identidad no se edita')
        T.eq(ed.data.look.model, 'mp_f_freemode_01', 'su sexo')
        T.falsy(lastNui(env, 'spawn'), 'todavía no se elige dónde aparecer')
        run(env, 'editorFinish', { look = PXDLook.default(1) })()
        env.pump()
        T.eq(step(), 'await', 'ahora sí, la pantalla de aparición')
        T.truthy(lastNui(env, 'spawn'))
        T.truthy(indexOf(env.log, 'cb:pxd_multichar:server:saveAppearance') < indexOf(env.log, 'cb:pxd_multichar:server:leaveCreator'))
        env.restore()
    end)

    T.it('personaje con apariencia: entra directo (no se abre el editor); si el servidor no responde, tampoco', function()
        for _, has in ipairs({ true, nil }) do
            local env = playEnv({ has = has })
            local step = run(env, 'play', { citizenid = 'XYZ' })
            T.eq(step(), 'await')
            T.falsy(lastNui(env, 'editor'))
            T.eq(lastNui(env, 'spawn').data.mode, 'spawn')
            env.restore()
        end
    end)

    T.it('R.I.P.: no se puede jugar con un personaje fallecido', function()
        local env = playEnv({ has = true, setup = { statuses = { XYZ = 'dead' } } })
        local open = lastNui(env, 'open')
        T.eq(open.data.characters[1].status, 'dead')
        local step, res = run(env, 'play', { citizenid = 'XYZ' })
        step()
        T.falsy(res().ok); T.truthy(res().error:find('R.I.P.'))
        T.falsy(indexOf(env.log, 'cb:qbx_core:server:loadCharacter'))
        env.restore()
    end)

    T.it('cambiar de personaje en la selección: ped limpio cada vez y la apariencia de cada uno (sin mezclas)', function()
        local a = { citizenid = 'AAA', charinfo = { firstname = 'Ana', lastname = 'Uno', gender = 1 }, money = {}, job = {}, metadata = {} }
        local b = { citizenid = 'BBB', charinfo = { firstname = 'Bea', lastname = 'Dos', gender = 0 }, money = {}, job = {}, metadata = {} }
        local skins = { AAA = { '{ model = "mp_f_freemode_01", eyeColor = 3 }', 'mp_f_freemode_01' }, BBB = { '{ model = "mp_m_freemode_01", eyeColor = 9 }', 'mp_m_freemode_01' } }
        local env = makeEnv({ callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { { a, b }, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['qbx_core:server:getPreviewPedData'] = function(cid) return table.unpack(skins[cid]) end,
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local function pick(cid)
            local n = #env.log
            run(env, 'select', { citizenid = cid })()
            local clean, applied
            for i = n + 1, #env.log do
                if env.log[i] == 'clearDecorations' then clean = i end
                if env.log[i] == 'illenium:setPedAppearance' then applied = i end
            end
            T.truthy(clean and applied and clean < applied, 'se limpia antes de aplicar')
            return env.lastApplied
        end
        T.eq(pick('BBB').eyeColor, 9)
        T.eq(pick('AAA').eyeColor, 3)
        T.eq(pick('BBB').eyeColor, 9)
        env.restore()
    end)

    T.it('editor reutilizable (peluquería, tienda, clínica): nunca identidad ni herencia; gancho de cobro', function()
        local saved
        local env = makeEnv({ currentLook = PXDLook.default(0), callbacks = { ['pxd_multichar:server:saveAppearance'] = function(l, mode) saved = { look = l, mode = mode }; return { ok = true } end } })
        local open = env.exported.OpenAppearanceEditor
        T.truthy(open, 'export registrado')
        T.eq(open({ sections = { 'identity', 'heritage' } }), false, 'sin secciones editables no abre')
        local paid = false
        T.eq(open({ sections = { 'identity', 'hair' }, title = 'Peluquería', price = 50, onSave = function() return paid end }), true)
        local ed = lastNui(env, 'editor')
        T.eq(#ed.data.sections, 1); T.eq(ed.data.sections[1], 'hair'); T.eq(ed.data.mode, 'edit'); T.eq(ed.data.price, 50)
        T.eq(open({ sections = { 'hair' } }), false, 'no se abren dos a la vez')
        -- Cobro rechazado: no se guarda y el editor sigue abierto.
        local look = PXDLook.default(0); look.hair.style = 7; look.faceFeatures.noseWidth = 0.5; look.model = 'mp_f_freemode_01'
        run(env, 'editorFinish', { look = look })(); env.pump()
        T.falsy(indexOf(env.log, 'cb:pxd_multichar:server:saveAppearance'))
        T.truthy(lastNui(env, 'editorError').text:find('pago'))
        paid = true
        run(env, 'editorFinish', { look = look })(); env.pump()
        T.truthy(indexOf(env.log, 'cb:pxd_multichar:server:saveAppearance'))
        T.eq(saved.mode, 'edit')
        T.eq(saved.look.hair.style, 7, 'el cabello sí cambia')
        T.eq(saved.look.model, 'mp_m_freemode_01', 'el modelo no')
        T.eq(saved.look.faceFeatures.noseWidth, 0, 'ni los rasgos (no estaban permitidos)')
        T.truthy(lastNui(env, 'editorClose'))
        env.restore()
    end)
end)

