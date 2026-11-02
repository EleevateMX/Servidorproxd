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
    local states = opts.states or { qbx_properties = 'started', qbx_spawn = 'started', ['illenium-appearance'] = 'started' }
    G.GetResourceState = function(name) return states[name] or 'missing' end

    G.lib = { requestModel = function() end, callback = { await = function(name, _, ...)
        log[#log + 1] = 'cb:' .. name
        local r = opts.callbacks[name]
        if type(r) == 'function' then return r(...) end
        if type(r) == 'table' and r.multi then return table.unpack(r.multi) end
        return r
    end } }
    G.exports = setmetatable({}, { __index = function(_, res)
        return setmetatable({}, { __index = function(_, fn)
            return function(_, ...) if res == 'qbx_core' and fn == 'GetPlayerData' then return opts.playerData end end
        end })
    end })

    -- promesas y espera como en CfxLua (con corrutinas)
    G.promise = { new = function() local p = { done = false }; function p:resolve(v) self.done = true; self.value = v end; return p end }
    G.Citizen = { Await = function(p) while not p.done do coroutine.yield('await') end return p.value end }
    G.Wait = function() if coroutine.isyieldable() then coroutine.yield('wait') end end
    G.CreateThread = function() end
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

    Config, PXDChar = nil, nil
    dofile(DIR .. 'config.lua')
    dofile(DIR .. 'shared/multichar.lua')
    dofile(DIR .. 'client/main.lua')
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
    T.it('crear con apartamentos: datos → elegir apartamento (nuestra pantalla) → qbx_properties → aspecto', function()
        local env = makeEnv({ callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { {}, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['pxd_multichar:server:checkRegistration'] = { ok = true, data = registration },
            ['qbx_core:server:createCharacter'] = { citizenid = 'ABC' },
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()   -- abre la selección (sin personajes)
        local step = run(env, 'create', registration)
        local s = step()
        T.eq(s, 'await', 'espera a que el jugador elija apartamento')
        local view = lastNui(env, 'spawn')
        T.eq(view.data.mode, 'apartment'); T.eq(#view.data.options, 2)
        T.eq(view.data.options[1].label, 'Del Perro Heights', 'textos en español de Config.apartmentTexts')
        T.falsy(indexOf(env.log, 'ev:qb-clothes:client:CreateFirstCharacter'), 'el editor de ropa aún no se abre')
        T.falsy(indexOf(env.log, 'sv:QBCore:Server:OnPlayerLoaded'), 'todavía no se carga (si no, qbx_properties enseñaría su pizarra)')

        local choose = run(env, 'spawnChoose', { id = 'apt:2' })
        T.eq(choose(), 'dead')
        T.eq(step(), 'dead')
        local sel = indexOf(env.log, 'sv:qbx_properties:server:apartmentSelect')
        local loaded = indexOf(env.log, 'sv:QBCore:Server:OnPlayerLoaded')
        T.truthy(sel and loaded and sel < loaded, 'primero el apartamento y después la carga (como qbx_properties)')
        T.eq(env.serverArgs['qbx_properties:server:apartmentSelect'][1], 2, 'se envía el apartamento elegido')
        T.falsy(indexOf(env.log, 'ev:apartments:client:setupSpawnUI'), 'nunca se abre su pizarra')
        T.falsy(indexOf(env.log, 'ev:qb-clothes:client:CreateFirstCharacter'), 'el editor lo abre qbx_properties tras colocarte (una sola vez)')
        T.truthy(indexOf(env.log, 'timeout:6000'), 'salida de emergencia por si la pantalla se queda en negro')
        T.eq(lastNui(env, 'spawnClose').action, 'spawnClose')
        env.restore()
    end)

    T.it('si no se puede leer la config de qbx_properties, se usa su pizarra (una sola pantalla)', function()
        local env = makeEnv({ noApartmentConfig = true, callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { {}, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['pxd_multichar:server:checkRegistration'] = { ok = true, data = registration },
            ['qbx_core:server:createCharacter'] = { citizenid = 'ABC' },
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local step = run(env, 'create', registration)
        T.eq(step(), 'dead')
        T.truthy(indexOf(env.log, 'ev:apartments:client:setupSpawnUI'))
        T.falsy(lastNui(env, 'spawn'), 'no se abre la nuestra a la vez')
        env.restore()
    end)

    T.it('crear sin apartamento inicial: aparece en el punto por defecto y abre el editor una vez', function()
        local env = makeEnv({ startingApartment = false, callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { {}, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['pxd_multichar:server:checkRegistration'] = { ok = true, data = registration },
            ['qbx_core:server:createCharacter'] = { citizenid = 'ABC' },
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local step = run(env, 'create', registration)
        T.eq(step(), 'dead')
        T.truthy(indexOf(env.log, 'ev:qbx_core:client:spawnNoApartments'))
        T.falsy(lastNui(env, 'spawn'))
        env.restore()
    end)

    T.it('crear rechazado por qbx_core: vuelve a la pantalla con aviso (no se queda en negro)', function()
        local env = makeEnv({ callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { {}, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['pxd_multichar:server:checkRegistration'] = { ok = true, data = registration },
            ['qbx_core:server:createCharacter'] = false,
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local step = run(env, 'create', registration)
        T.eq(step(), 'dead')
        T.truthy(indexOf(env.log, 'fadeIn'))
        T.eq(lastNui(env, 'toast').action, 'toast')
        T.falsy(indexOf(env.log, 'sv:QBCore:Server:OnPlayerLoaded'))
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
        local env = makeEnv({ callbacks = {
            ['qbx_core:server:getCharacters'] = { multi = { {}, 3 } },
            ['pxd_multichar:server:setup'] = {},
            ['pxd_multichar:server:checkRegistration'] = { ok = true, data = registration },
            ['qbx_core:server:createCharacter'] = { citizenid = 'ABC' },
            ['pxd_multichar:server:needsApartment'] = function() pending = pending - 1; return pending > 0 end,
        } })
        env.handlers['qbx_core:client:playerLoggedOut']()
        local step = run(env, 'create', registration)
        T.eq(step(), 'await')
        run(env, 'spawnChoose', { id = 'apt:1' })()
        T.eq(step(), 'dead')
        local sel = indexOf(env.log, 'sv:qbx_properties:server:apartmentSelect')
        local loaded = indexOf(env.log, 'sv:QBCore:Server:OnPlayerLoaded')
        local checks = 0
        for i = sel, loaded do if env.log[i] == 'cb:pxd_multichar:server:needsApartment' then checks = checks + 1 end end
        T.eq(checks, 3, 'consulta hasta que el apartamento existe')
        T.eq(pending, 0)
        env.restore()
    end)
end)

