-- pxd_multichar (cliente): mismo flujo que qbx_core/client/character.lua, con interfaz propia.
-- Solo actúa si qbx_core tiene useExternalCharacters = true (si no, habría dos pantallas).

if PXDChar.qbxManagesCharacters(LoadResourceFile('qbx_core', 'config/client.lua')) then
    print('^1[pxd_multichar] qbx_core sigue gestionando los personajes (useExternalCharacters = false). No hago nada.^7')
    return
end

local defaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88)
do -- el punto de aparición por defecto de qbx_core (config/shared.lua), si se puede leer
    local text = LoadResourceFile('qbx_core', 'config/shared.lua')
    local chunk = text and load(text, '@qbx_core/config/shared.lua', 't', { vec4 = vec4, vector4 = vector4, vec3 = vec3, vector3 = vector3, joaat = joaat })
    local ok, cfg = false, nil
    if chunk then ok, cfg = pcall(chunk) end
    if ok and type(cfg) == 'table' and cfg.defaultSpawn then defaultSpawn = cfg.defaultSpawn end
end

-- ¿qbx_core da apartamento inicial? (characters.startingApartment, true por defecto)
local qbxStartingApartment = PXDChar.qbxStartingApartment(LoadResourceFile('qbx_core', 'config/client.lua'))

-- Apartamentos iniciales de qbx_properties (config/shared.lua → apartmentOptions).
-- Si no se pueden leer, se usa su pizarra original.
local function apartmentOptions()
    local text = LoadResourceFile('qbx_properties', 'config/shared.lua')
    local chunk = text and load(text, '@qbx_properties/config/shared.lua', 't', { vec3 = vec3, vector3 = vector3, vec4 = vec4, vector4 = vector4, joaat = joaat })
    local ok, cfg = false, nil
    if chunk then ok, cfg = pcall(chunk) end
    if not ok or type(cfg) ~= 'table' or type(cfg.apartmentOptions) ~= 'table' then return nil end
    return cfg.apartmentOptions
end

-- Aspectos por defecto al crear (los mismos que usa qbx_core).
local defaultPeds = {
    [0] = {
        model = GetHashKey('mp_m_freemode_01'),
        headOverlays = {
            beard = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            eyebrows = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            chestHair = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            ageing = { color = 0, style = 0, secondColor = 0, opacity = 1 },
        },
        components = {
            { texture = 0, drawable = 0, component_id = 0 }, { texture = 0, drawable = 0, component_id = 1 },
            { texture = 0, drawable = 0, component_id = 2 }, { texture = 0, drawable = 0, component_id = 5 },
            { texture = 0, drawable = 0, component_id = 7 }, { texture = 0, drawable = 0, component_id = 9 },
            { texture = 0, drawable = 0, component_id = 10 }, { texture = 0, drawable = 15, component_id = 11 },
            { texture = 0, drawable = 15, component_id = 8 }, { texture = 0, drawable = 15, component_id = 3 },
            { texture = 0, drawable = 34, component_id = 6 }, { texture = 0, drawable = 61, component_id = 4 },
        },
        props = {
            { prop_id = 0, drawable = -1, texture = -1 }, { prop_id = 1, drawable = -1, texture = -1 },
            { prop_id = 2, drawable = -1, texture = -1 }, { prop_id = 6, drawable = -1, texture = -1 },
            { prop_id = 7, drawable = -1, texture = -1 },
        },
    },
    [1] = {
        model = GetHashKey('mp_f_freemode_01'),
        headBlend = { shapeMix = 0.3, skinFirst = 0, shapeFirst = 31, skinSecond = 0, shapeSecond = 0, skinMix = 0, thirdMix = 0, shapeThird = 0, skinThird = 0 },
        hair = { color = 0, style = 15, texture = 0, highlight = 0 },
        headOverlays = {
            ageing = { secondColor = 0, opacity = 1, color = 0, style = 0 },
            eyebrows = { secondColor = 0, opacity = 1, color = 0, style = 0 },
        },
        components = {
            { drawable = 0, component_id = 0, texture = 0 }, { drawable = 0, component_id = 1, texture = 0 },
            { drawable = 0, component_id = 2, texture = 0 }, { drawable = 0, component_id = 5, texture = 0 },
            { drawable = 0, component_id = 7, texture = 0 }, { drawable = 0, component_id = 9, texture = 0 },
            { drawable = 0, component_id = 10, texture = 0 }, { drawable = 15, component_id = 3, texture = 0 },
            { drawable = 15, component_id = 11, texture = 3 }, { drawable = 14, component_id = 8, texture = 0 },
            { drawable = 15, component_id = 4, texture = 3 }, { drawable = 35, component_id = 6, texture = 0 },
        },
        props = {
            { prop_id = 0, drawable = -1, texture = -1 }, { prop_id = 1, drawable = -1, texture = -1 },
            { prop_id = 2, drawable = -1, texture = -1 }, { prop_id = 6, drawable = -1, texture = -1 },
            { prop_id = 7, drawable = -1, texture = -1 },
        },
    },
}

local scene = Config.scenes[math.random(1, #Config.scenes)]
local previewCam
local cards, cardsById, setup, allowedAmount = {}, {}, {}, 0
local uiOpen, busy = false, false

-- ── Cámara ─────────────────────────────────────────────────────────────
local function setupPreviewCam()
    DoScreenFadeIn(1000)
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(1.0)
    FreezeEntityPosition(cache.ped, false)
    local c = scene.camCoords
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, -6.0, 0.0, c.w, 40.0, false, 0)
    SetCamActive(previewCam, true)
    SetCamUseShallowDofMode(previewCam, true)
    SetCamNearDof(previewCam, 0.4)
    SetCamFarDof(previewCam, 1.8)
    SetCamDofStrength(previewCam, 0.7)
    RenderScriptCams(true, false, 1, true, true)
    CreateThread(function()
        while previewCam and DoesCamExist(previewCam) do
            SetUseHiDof()
            Wait(0)
        end
    end)
    SetTimecycleModifier('default')
end

local function destroyPreviewCam()
    if not previewCam then return end
    SetTimecycleModifier('default')
    SetCamActive(previewCam, false)
    DestroyCam(previewCam, true)
    RenderScriptCams(false, false, 1, true, true)
    FreezeEntityPosition(cache.ped, false)
    DisplayRadar(true)
    previewCam = nil
end

-- ── Vista previa del personaje ─────────────────────────────────────────
local function applyAppearance(model, appearance)
    if type(model) == 'string' then model = joaat(model) end
    lib.requestModel(model, Config.loadingModelsTimeout)
    SetPlayerModel(cache.playerId, model)
    -- Ped nuevo y limpio: sin ropa, tatuajes ni rasgos del personaje anterior.
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    ClearPedDecorations(ped)
    if type(appearance) == 'table' then
        pcall(function() exports['illenium-appearance']:setPedAppearance(ped, appearance) end)
    end
    SetModelAsNoLongerNeeded(model)
end

local function previewDefault(gender)
    local ped = defaultPeds[gender == 1 and 1 or 0]
    applyAppearance(ped.model, ped)
end

local function previewPed(citizenId)
    if not citizenId then return previewDefault(math.random(0, 1)) end
    local clothing, model = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
    if model and clothing then
        applyAppearance(model, json.decode(clothing))
    else
        previewDefault(cardsById[citizenId] and cardsById[citizenId].gender or 0)
    end
    local p = scene.pedCoords
    SetEntityCoords(PlayerPedId(), p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), p.w)
end

-- ── Interfaz ───────────────────────────────────────────────────────────
local function setUi(open, payload)
    uiOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({ action = open and 'open' or 'close', data = payload })
end

local function setBusy(value)
    busy = value
    SendNUIMessage({ action = 'busy', value = value })
end

-- ── Aparición (igual que qbx_core) ─────────────────────────────────────
local function spawnAt(coords)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    destroyPreviewCam()
    pcall(function() exports.spawnmanager:spawnPlayer({ x = coords.x, y = coords.y, z = coords.z, heading = coords.w }) end)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    while not IsScreenFadedIn() do Wait(0) end
end

local function spawnDefault()
    spawnAt(defaultSpawn)
end

local function spawnLastLocation()
    -- qbx_core envía los datos del personaje justo después de cargarlo.
    local data, waited = nil, 0
    repeat
        data = exports.qbx_core:GetPlayerData()
        if data and data.position then break end
        Wait(100); waited = waited + 100
    until waited >= 5000
    spawnAt(data and data.position or defaultSpawn)
end

-- La registra qbx_core en client/character.lua, que no se carga con personajes externos.
RegisterNetEvent('qbx_core:client:spawnNoApartments', function()
    DoScreenFadeOut(500)
    Wait(2000)
    SetEntityCoords(cache.ped, defaultSpawn.x, defaultSpawn.y, defaultSpawn.z, false, false, false, false)
    SetEntityHeading(cache.ped, defaultSpawn.w)
    Wait(500)
    destroyPreviewCam()
    SetEntityVisible(cache.ped, true, false)
    Wait(500)
    DoScreenFadeIn(250)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    TriggerEvent('qb-weathersync:client:EnableSync')
end)

-- ── Escenario de la pantalla de aparición ──────────────────────────────
-- La selección de personaje usa una escena (interior) con cámara propia; la aparición
-- NO debe verla: se destruye esa cámara, se oculta el personaje y se usa una vista
-- aérea de la ciudad que se desplaza a la opción elegida. Natives verificados en
-- citizenfx/natives: CreateCamWithParams, PointCamAtCoord, SetCamActiveWithInterp,
-- RenderScriptCams, SetFocusPosAndVel, ClearFocus, HideHudAndRadarThisFrame.
local spawnStage, spawnCam = false, nil

local function spawnCamTo(from, at, fov, ms)
    SetFocusPosAndVel(at.x, at.y, at.z, 0.0, 0.0, 0.0)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, fov or 50.0, false, 0)
    PointCamAtCoord(cam, at.x, at.y, at.z)
    local old = spawnCam
    if old and DoesCamExist(old) and ms and ms > 0 then
        SetCamActiveWithInterp(cam, old, ms, 1, 1)
        SetTimeout(ms + 200, function() if DoesCamExist(old) then DestroyCam(old, false) end end)
    else
        if old and DoesCamExist(old) then DestroyCam(old, false) end
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    spawnCam = cam
end

--- Vista sobre una opción: un poco al sur y por encima, mirando al punto.
local function focusCoords(c)
    local o = Config.spawnCamera.optionOffset
    return vec3(c.x + o.x, c.y + o.y, c.z + o.z), vec3(c.x, c.y, c.z)
end

local function enterSpawnStage()
    if spawnStage then return end
    spawnStage = true
    destroyPreviewCam()
    ClearTimecycleModifier()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    local v = Config.spawnCamera
    spawnCamTo(v.from, v.at, v.fov, 0)
    CreateThread(function()
        while spawnStage do
            HideHudAndRadarThisFrame()   -- ni minimapa ni HUD del juego en esta pantalla
            Wait(0)
        end
    end)
end

local function leaveSpawnStage()
    if not spawnStage then return end
    spawnStage = false
    if spawnCam and DoesCamExist(spawnCam) then
        SetCamActive(spawnCam, false)
        DestroyCam(spawnCam, false)
    end
    spawnCam = nil
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
end

-- ── Pantalla de aparición propia ───────────────────────────────────────
local pickerChoice -- promise mientras la pantalla está abierta
local pickerIds, pickerCoords, pickerFocused = {}, {}, nil

--- Abre la pantalla de elección y espera. view: { mode, kicker, title, text, confirm, options }
--- coords[id] (opcional): punto al que se mueve la cámara al marcar esa opción.
local function pick(view, ids, coords)
    pickerIds, pickerCoords, pickerFocused = ids, coords or {}, nil
    pickerChoice = promise.new()
    enterSpawnStage()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'spawn', data = view })
    local id = Citizen.Await(pickerChoice)
    pickerChoice = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'spawnClose' })
    return id
end

RegisterNUICallback('spawnChoose', function(data, cb)
    local id = type(data) == 'table' and data.id
    if not pickerChoice or type(id) ~= 'string' or not pickerIds[id] then return cb({ ok = false }) end
    cb({ ok = true })
    pickerChoice:resolve(id)
end)

RegisterNUICallback('spawnFocus', function(data, cb)
    cb({ ok = true })
    local id = type(data) == 'table' and data.id
    if not pickerChoice or not spawnStage or type(id) ~= 'string' or id == pickerFocused then return end
    local c = pickerCoords[id]
    if not c then return end
    pickerFocused = id
    local from, at = focusCoords(c)
    spawnCamTo(from, at, Config.spawnCamera.optionFov, Config.spawnCamera.interpMs)
end)

--- Elegir y crear el apartamento inicial (como qbx_properties/client/apartmentselect.lua,
--- inputConfirm). Devuelve false si no se pudo usar nuestra pantalla.
local function chooseApartment()
    local options = apartmentOptions()
    if not options or #options == 0 then return false end
    local list, ids, coords = {}, {}, {}
    for i, a in ipairs(options) do
        local t = Config.apartmentTexts[a.interior] or {}
        local id = 'apt:' .. i
        ids[id] = i
        if a.enter then coords[id] = a.enter end
        list[#list + 1] = { id = id, kind = 'apartment', label = t.label or a.label, detail = t.detail or a.description, image = Config.spawnImages.apartment }
    end
    local id = pick({ mode = 'apartment', kicker = 'Tu primer hogar', title = 'Elige tu apartamento',
        text = 'Es gratis y será tu casa en la ciudad: ahí guardas tus cosas y te cambias de ropa.', confirm = 'Mudarme aquí', options = list }, ids, coords)
    local index = ids[id]
    local apt = options[index]
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    leaveSpawnStage()
    destroyPreviewCam()
    FreezeEntityPosition(cache.ped, false)
    SetEntityCoords(cache.ped, apt.enter.x, apt.enter.y, apt.enter.z - 2.0, false, false, false, false)
    Wait(0)
    TriggerServerEvent('qbx_properties:server:apartmentSelect', index)
    -- qbx_properties abre SU pizarra de apartamentos en QBCore:Server:OnPlayerLoaded si el
    -- personaje aún no tiene apartamento. Antes se esperaba 1 s fijo y, si su INSERT tardaba
    -- más, se abrían las dos pantallas. Ahora se espera a que el apartamento exista (máx. 10 s).
    local waited = 1000
    Wait(1000)
    while waited < 10000 and lib.callback.await('pxd_multichar:server:needsApartment', false) do
        Wait(500); waited = waited + 500
    end
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    -- Por si nada vuelve a mostrar la pantalla (qbx_properties la abre al entrar).
    SetTimeout(6000, function() if IsScreenFadedOut() then DoScreenFadeIn(500) end end)
    return true
end

--- Elegir dónde aparecer un personaje existente (como qbx_spawn/client/main.lua).
local function chooseSpawn()
    local last, properties
    if GetResourceState('qbx_spawn'):find('start') then
        local coords, propertyId = lib.callback.await('qbx_spawn:server:getLastLocation')
        if coords then last = { coords = coords, propertyId = propertyId } end
        properties = lib.callback.await('qbx_spawn:server:getProperties') or {}
    else
        local data = exports.qbx_core:GetPlayerData()
        if data and data.position then last = { coords = data.position } end
    end
    if last then last.image = Config.spawnImages.last end
    for _, p in ipairs(properties or {}) do p.image = Config.spawnImages.property end
    local list, byId = PXDChar.buildSpawnOptions(last, properties, Config.spawnPoints)
    if #list == 0 then return spawnAt(defaultSpawn) end
    local coords = {}
    for oid, o in pairs(byId) do coords[oid] = o.coords end
    local id = pick({ mode = 'spawn', kicker = '¿Dónde apareces?', title = 'Elige dónde empezar',
        text = 'Vuelve donde lo dejaste, a tu casa o a un punto de la ciudad.', confirm = 'Aparecer', options = list }, byId, coords)
    local opt = byId[id]
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    leaveSpawnStage()
    destroyPreviewCam()
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    FreezeEntityPosition(cache.ped, false)
    DisplayRadar(true)
    if opt.propertyId then
        TriggerServerEvent('qbx_properties:server:enterProperty', { id = opt.propertyId, isSpawn = true })
    else
        SetEntityCoords(cache.ped, opt.coords.x, opt.coords.y, opt.coords.z, false, false, false, false)
        SetEntityHeading(cache.ped, opt.coords.w or 0.0)
    end
    DoScreenFadeIn(800)
end

local function apartmentsEnabled()
    return qbxStartingApartment and GetResourceState('qbx_properties'):find('start') ~= nil
end

-- ── Pantalla de personajes ─────────────────────────────────────────────
local chooseCharacter

local function closeLoadingScreen()
    if GetResourceState('pxd_loadscreen') == 'started' then
        TriggerEvent('pxd_loadscreen:close') -- transición propia (≈1,6 s)
        Wait(1800)
    end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

--- «Calle, Zona» de una posición (GetStreetNameAtCoord, GetStreetNameFromHashKey,
--- GetNameOfZone, GetLabelText). nil si no hay posición.
function placeName(pos)
    if type(pos) ~= 'table' and type(pos) ~= 'vector3' and type(pos) ~= 'vector4' then return nil end
    local x, y, z = tonumber(pos.x), tonumber(pos.y), tonumber(pos.z)
    if not x or not y or not z then return nil end
    local street = GetStreetNameAtCoord(x + 0.0, y + 0.0, z + 0.0)
    local name = street and street ~= 0 and GetStreetNameFromHashKey(street) or nil
    local zone = GetLabelText(GetNameOfZone(x + 0.0, y + 0.0, z + 0.0))
    if zone == 'NULL' then zone = nil end
    if name and name ~= '' and zone then return name .. ', ' .. zone end
    return (name ~= '' and name) or zone
end

local function buildPayload(characters, amount)
    cards, cardsById = {}, {}
    allowedAmount = tonumber(amount) or 0
    local sums = setup.summaries or {}
    for i = 1, #characters do
        local card = PXDChar.toCard(characters[i], sums[characters[i].citizenid])
        if card and card.citizenid then
            card.status = (setup.statuses or {})[card.citizenid] == 'dead' and 'dead' or 'active'
            card.location = placeName(characters[i].position)
            cards[#cards + 1] = card
            cardsById[card.citizenid] = card
        end
    end
    return {
        serverName = Config.serverName,
        characters = cards,
        slots = PXDChar.buildSlots(cards, amount, Config.lockedSlotsShown),
        lockedLabel = Config.lockedSlotLabel,
        storeUrl = Config.storeUrl ~= '' and Config.storeUrl or nil,
        enableDelete = Config.enableDelete,
        nationalities = setup.nationalities or {},
        limitNationalities = setup.limitNationalities,
        defaultNationality = Config.defaultNationality,
        dateMin = Config.dateMin,
        dateMax = Config.dateMax,
    }
end

chooseCharacter = function()
    local characters, amount = lib.callback.await('qbx_core:server:getCharacters')
    setup = lib.callback.await('pxd_multichar:server:setup') or {}
    characters = characters or {}
    scene = Config.scenes[math.random(1, #Config.scenes)]

    local payload = buildPayload(characters, amount)
    previewPed(cards[1] and cards[1].citizenid)

    SetFollowPedCamViewMode(2)
    DisplayRadar(false)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() and cache.ped ~= PlayerPedId() do Wait(0) end

    FreezeEntityPosition(cache.ped, true)
    Wait(1000)
    local p = scene.pedCoords
    SetEntityCoords(cache.ped, p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(cache.ped, p.w)

    NetworkStartSoloTutorialSession()
    while not NetworkIsInTutorialSession() do Wait(0) end

    Wait(1500)
    closeLoadingScreen()
    setupPreviewCam()
    setBusy(false)
    setUi(true, payload)
end

local function refresh()
    local characters, amount = lib.callback.await('qbx_core:server:getCharacters')
    setup = lib.callback.await('pxd_multichar:server:setup') or setup
    local payload = buildPayload(characters or {}, amount)
    previewPed(cards[1] and cards[1].citizenid)
    SendNUIMessage({ action = 'open', data = payload })
end

-- ── Callbacks de la NUI ───────────────────────────────────────────────
RegisterNUICallback('select', function(data, cb)
    cb({ ok = true })
    if busy or type(data) ~= 'table' then return end
    if data.citizenid and cardsById[data.citizenid] then
        previewPed(data.citizenid)
    elseif data.gender ~= nil then
        previewDefault(tonumber(data.gender) == 1 and 1 or 0)
    end
end)

-- ── Creación con el editor propio (React + adaptador client/editor.lua) ───
-- Orden: identidad → apariencia → datos de Qbox → apariencia en illenium (verificada en el
-- servidor) → liberar el bucket → apartamento o ubicación → aparecer. Si algo falla antes de
-- crear en qbx_core, el editor sigue abierto con lo editado; si falla la apariencia después,
-- el personaje se completa la próxima vez que se elija (pxd_multichar:server:hasAppearance).

--- Guarda la apariencia (3 intentos). true si quedó guardada y comprobada.
local function saveLook(look, mode)
    for attempt = 1, 3 do
        local r = lib.callback.await('pxd_multichar:server:saveAppearance', false, look, mode)
        if r and r.ok then return true end
        if attempt < 3 then Wait(1600) end
    end
    return false
end

local function leaveCreator()
    lib.callback.await('pxd_multichar:server:leaveCreator', false)
end

local onCreatorDone

local function afterCreate(newData)
    if Config.spawnPicker and apartmentsEnabled() then
        enterSpawnStage()
        DoScreenFadeIn(300)
        if not chooseApartment() then
            TriggerEvent('apartments:client:setupSpawnUI', newData) -- su pizarra, si no pudimos leer su config
        end
    elseif GetResourceState('qbx_spawn') == 'missing' then
        spawnDefault()
    elseif Config.startingApartment and GetResourceState('qbx_apartments'):find('start') then
        TriggerEvent('apartments:client:setupSpawnUI', newData)
    else
        TriggerEvent('qbx_core:client:spawnNoApartments')
    end
    destroyPreviewCam()
    PXDEditor.restoreHud()
    setBusy(false)
end

local function finalizeCreation(result)
    local identity = type(result.identity) == 'table' and result.identity or {}
    identity.gender = PXDLook.FREEMODE[result.look.model] or identity.gender
    local check = lib.callback.await('pxd_multichar:server:checkRegistration', false, identity)
    if not check or not check.ok then
        PXDEditor.onDone(onCreatorDone)
        return PXDEditor.fail(check and check.error or 'No se pudo comprobar el registro.', check and check.field or 'identity')
    end
    local newData = lib.callback.await('qbx_core:server:createCharacter', false, check.data)
    if not newData then
        PXDEditor.onDone(onCreatorDone)
        return PXDEditor.fail('No se pudo crear el personaje (¿sin ranuras libres?). Inténtalo de nuevo.')
    end
    if not saveLook(result.look, 'create') then
        -- El personaje ya existe en qbx_core: la próxima vez que se elija, se pedirá la apariencia.
        print('^3[pxd_multichar] No se pudo guardar la apariencia del personaje nuevo; se pedirá al volver a entrar.^7')
    end
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    PXDEditor.done()
    leaveCreator()
    afterCreate(newData)
end

onCreatorDone = function(result)
    if result.ok then return CreateThread(function() finalizeCreation(result) end) end
    -- «Volver a la selección» sin crear nada.
    CreateThread(function()
        DoScreenFadeOut(300)
        while not IsScreenFadedOut() do Wait(0) end
        leaveCreator()
        PXDEditor.restoreHud()
        chooseCharacter()
    end)
end

local function startCreator()
    setBusy(true)
    setUi(false)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    destroyPreviewCam()
    lib.callback.await('pxd_multichar:server:enterCreator', false)
    PXDEditor.open({
        mode = 'create', title = 'Crear personaje', look = PXDLook.default(0), onDone = onCreatorDone,
        identity = {
            firstname = '', lastname = '', gender = 0, birthdate = '', nationality = Config.defaultNationality,
            nationalities = setup.nationalities or {}, limitNationalities = setup.limitNationalities,
            dateMin = Config.dateMin, dateMax = Config.dateMax,
        },
    })
    DoScreenFadeIn(400)
    setBusy(false)
end

RegisterNUICallback('createStart', function(_, cb)
    if busy or PXDEditor.isOpen() then return cb({ ok = false }) end
    if #cards >= allowedAmount then return cb({ ok = false, error = 'No te quedan ranuras libres.' }) end
    cb({ ok = true })
    CreateThread(startCreator)
end)

--- Personaje sin apariencia guardada (creación interrumpida): se completa antes de jugar.
local function recoverAppearance(card)
    destroyPreviewCam()
    lib.callback.await('pxd_multichar:server:enterCreator', false)
    local done = promise.new()
    local function onDone(result)
        if not result.ok then return end
        CreateThread(function()
            if saveLook(result.look, 'recover') then
                PXDEditor.done()
                done:resolve(true)
            else
                PXDEditor.onDone(onDone)
                PXDEditor.fail('No se pudo guardar la apariencia. Inténtalo de nuevo.')
            end
        end)
    end
    PXDEditor.open({ mode = 'recover', title = 'Completa tu apariencia', onDone = onDone,
        sections = { 'heritage', 'face', 'skin', 'hair', 'clothes' }, look = PXDLook.default(card and card.gender or 0) })
    DoScreenFadeIn(300)
    Citizen.Await(done)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    leaveCreator()
end

RegisterNUICallback('play', function(data, cb)
    if busy or type(data) ~= 'table' or not cardsById[data.citizenid] then return cb({ ok = false }) end
    if cardsById[data.citizenid].status == 'dead' then return cb({ ok = false, error = 'Este personaje ha fallecido (R.I.P.).' }) end
    cb({ ok = true })
    setBusy(true)
    setUi(false)
    DoScreenFadeOut(10)
    lib.callback.await('qbx_core:server:loadCharacter', false, data.citizenid)
    if lib.callback.await('pxd_multichar:server:hasAppearance', false, data.citizenid) == false then
        recoverAppearance(cardsById[data.citizenid])
    end
    if Config.spawnPicker then
        enterSpawnStage()
        DoScreenFadeIn(300)
        if apartmentsEnabled() and lib.callback.await('pxd_multichar:server:needsApartment', false) and chooseApartment() then
            -- ya colocado en su apartamento nuevo
        else
            chooseSpawn()
        end
    elseif GetResourceState('qbx_apartments'):find('start') then
        TriggerEvent('apartments:client:setupSpawnUI', data.citizenid)
    elseif GetResourceState('qbx_spawn'):find('start') then
        TriggerEvent('qb-spawn:client:setupSpawns', data.citizenid)
        TriggerEvent('qb-spawn:client:openUI', true)
    else
        spawnLastLocation()
    end
    destroyPreviewCam()
    setBusy(false)
end)

RegisterNUICallback('delete', function(data, cb)
    if busy or not Config.enableDelete or type(data) ~= 'table' then return cb({ ok = false }) end
    local card = cardsById[data.citizenid]
    if not card or not PXDChar.confirmName(card, data.confirm) then
        return cb({ ok = false, error = 'Escribe el nombre completo del personaje para confirmar.' })
    end
    setBusy(true)
    local success = lib.callback.await('qbx_core:server:deleteCharacter', false, card.citizenid)
    setBusy(false)
    cb({ ok = success == true, error = success and nil or 'No se pudo eliminar el personaje.' })
    if success then refresh() end
end)

-- ── Arranque (igual que qbx_core) ──────────────────────────────────────
RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end -- solo desde el servidor
    chooseCharacter()
end)

NetworkStartSoloTutorialSession()

CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
            Wait(250)
            chooseCharacter()
            break
        end
    end
    -- En la selección el personaje no debe poder morir.
    while NetworkIsInTutorialSession() do
        SetEntityInvincible(PlayerPedId(), true)
        Wait(250)
    end
    SetEntityInvincible(PlayerPedId(), false)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if uiOpen or pickerChoice then SetNuiFocus(false, false) end
    leaveSpawnStage()
    PXDEditor.close()
    destroyPreviewCam()
end)


-- ── Editor reutilizable: exports.pxd_multichar:OpenAppearanceEditor(opts) ──
-- opts = { sections = { 'face' | 'skin' | 'hair' | 'clothes' }, title, price, onSave }
-- · La identidad, el modelo y la herencia nunca se editan fuera de la creación.
-- · onSave(look) (opcional) decide si se acepta: devuelve true para guardar, false/nil para
--   rechazar (p. ej. sin fondos). Gancho para cobrar con pxd_economy (ChargeToAccount) cuando
--   se habilite; sin onSave se guarda sin cobrar. Devuelve false si no se pudo abrir.
local EDITABLE = { face = true, skin = true, hair = true, clothes = true }
exports('OpenAppearanceEditor', function(opts)
    opts = type(opts) == 'table' and opts or {}
    if PXDEditor.isOpen() or uiOpen or pickerChoice or not LocalPlayer.state.isLoggedIn then return false end
    local sections = {}
    for _, sec in ipairs(type(opts.sections) == 'table' and opts.sections or {}) do
        if EDITABLE[sec] then sections[#sections + 1] = sec end
    end
    if #sections == 0 then return false end
    local ped = PlayerPedId()
    local ok, current = pcall(function() return exports['illenium-appearance']:getPedAppearance(ped) end)
    if not ok or type(current) ~= 'table' then return false end
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local function unfreeze() FreezeEntityPosition(PlayerPedId(), false); PXDEditor.restoreHud() end
    local function onDone(result)
        if not result.ok then return unfreeze() end
        CreateThread(function()
            local accept = true
            if type(opts.onSave) == 'function' or type(opts.onSave) == 'table' then
                local okHook, r = pcall(opts.onSave, result.look)
                accept = okHook and r == true
            end
            if accept and saveLook(result.look, 'edit') then
                PXDEditor.done()
                unfreeze()
            else
                PXDEditor.onDone(onDone)
                PXDEditor.fail(accept and 'No se pudo guardar. Inténtalo de nuevo.' or 'No se ha podido completar el pago.')
            end
        end)
    end
    return PXDEditor.open({ mode = 'edit', title = type(opts.title) == 'string' and opts.title or 'Editar apariencia',
        sections = sections, look = current, price = tonumber(opts.price), onDone = onDone, scene = vec4(c.x, c.y, c.z, h) })
end)
