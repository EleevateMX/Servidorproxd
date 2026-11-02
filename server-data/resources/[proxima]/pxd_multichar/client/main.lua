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
    lib.requestModel(model, Config.loadingModelsTimeout)
    SetPlayerModel(cache.playerId, model)
    pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), appearance) end)
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
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
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
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end)

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

local function buildPayload(characters, amount)
    cards, cardsById = {}, {}
    allowedAmount = tonumber(amount) or 0
    local sums = setup.summaries or {}
    for i = 1, #characters do
        local card = PXDChar.toCard(characters[i], sums[characters[i].citizenid])
        if card and card.citizenid then
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

RegisterNUICallback('play', function(data, cb)
    if busy or type(data) ~= 'table' or not cardsById[data.citizenid] then return cb({ ok = false }) end
    cb({ ok = true })
    setBusy(true)
    setUi(false)
    DoScreenFadeOut(10)
    lib.callback.await('qbx_core:server:loadCharacter', false, data.citizenid)
    if GetResourceState('qbx_apartments'):find('start') then
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

RegisterNUICallback('create', function(data, cb)
    if busy then return cb({ ok = false, error = 'Espera un momento…' }) end
    if #cards >= allowedAmount then return cb({ ok = false, error = 'No te quedan ranuras libres.' }) end
    setBusy(true)
    local check = lib.callback.await('pxd_multichar:server:checkRegistration', false, data)
    if not check or not check.ok then
        setBusy(false)
        return cb({ ok = false, error = check and check.error or 'No se pudo comprobar el registro.', field = check and check.field })
    end
    cb({ ok = true })
    setUi(false)
    DoScreenFadeOut(150)
    local newData = lib.callback.await('qbx_core:server:createCharacter', false, check.data)
    if not newData then
        -- Límite alcanzado o datos rechazados por qbx_core: volvemos a la pantalla.
        DoScreenFadeIn(250)
        setBusy(false)
        uiOpen = true
        SetNuiFocus(true, true)
        refresh()
        SendNUIMessage({ action = 'toast', text = 'No se pudo crear el personaje. Inténtalo de nuevo.' })
        return
    end
    if GetResourceState('qbx_spawn') == 'missing' then
        spawnDefault()
    elseif Config.startingApartment and GetResourceState('qbx_apartments'):find('start') then
        TriggerEvent('apartments:client:setupSpawnUI', newData)
    else
        TriggerEvent('qbx_core:client:spawnNoApartments')
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
    if uiOpen then SetNuiFocus(false, false) end
    destroyPreviewCam()
end)
