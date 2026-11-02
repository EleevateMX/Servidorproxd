-- pxd_multichar (cliente): adaptador del editor de apariencia.
-- La NUI (React) tiene el estado; aquí se sanea, se aplica al ped con los exports de
-- illenium-appearance 5.7.0 (setPedAppearance, getPedAppearance) y se cuentan los
-- rangos reales con natives verificados en citizenfx/natives:
--   GetPedHeadOverlayNum, GetNumHairColors, GetNumMakeupColors, GetPedHairRgbColor,
--   GetPedMakeupRgbColor, GetNumberOfPedDrawableVariations, GetNumberOfPedTextureVariations,
--   GetNumberOfPedPropDrawableVariations, GetNumberOfPedPropTextureVariations,
--   CreateCamWithParams, PointCamAtCoord, SetCamActiveWithInterp, RenderScriptCams,
--   GetOffsetFromEntityInWorldCoords, SetEntityHeading, HideHudAndRadarThisFrame.
-- Nunca se abre a la vez el editor de illenium (startPlayerCustomization).
PXDEditor = {}
local E = PXDEditor
local L = PXDLook

local state = nil      -- { mode, sections, look, base, onDone, cam, heading, zoom, preset }

local function illenium() return GetResourceState('illenium-appearance') == 'started' end

-- ── Rangos reales del modelo actual ────────────────────────────────────
function E.limits(ped, look)
    local lim = { overlays = {}, components = {}, props = {}, hairColors = GetNumHairColors(), makeupColors = GetNumMakeupColors() }
    if lim.hairColors <= 0 then lim.hairColors = 1 end
    if lim.makeupColors <= 0 then lim.makeupColors = 1 end
    for i = 0, #L.OVERLAYS - 1 do lim.overlays[i] = math.max(1, GetPedHeadOverlayNum(i)) end
    local current = {}
    for _, c in ipairs(look and look.components or {}) do current[c.component_id] = c.drawable end
    for _, id in ipairs(L.COMPONENT_IDS) do
        local n = GetNumberOfPedDrawableVariations(ped, id)
        local d = current[id] or GetPedDrawableVariation(ped, id)
        local t = GetNumberOfPedTextureVariations(ped, id, d)
        lim.components[id] = { drawables = math.max(1, n), textures = math.max(1, t), texturesFor = { [d] = math.max(1, t) } }
    end
    if look and look.hair then
        local t = GetNumberOfPedTextureVariations(ped, 2, look.hair.style)
        lim.components[2].texturesFor[look.hair.style] = math.max(1, t)
        lim.components[2].textures = math.max(1, t)
    end
    local currentProps = {}
    for _, p in ipairs(look and look.props or {}) do currentProps[p.prop_id] = p.drawable end
    for _, id in ipairs(L.PROP_IDS) do
        local n = GetNumberOfPedPropDrawableVariations(ped, id)
        local d = currentProps[id] or -1
        local t = d >= 0 and GetNumberOfPedPropTextureVariations(ped, id, d) or 0
        lim.props[id] = { drawables = math.max(0, n), textures = math.max(1, t), texturesFor = { [d] = math.max(1, t) } }
    end
    return lim
end

--- Paletas reales (para pintar las muestras de color en la NUI).
function E.palettes()
    local hair, makeup = {}, {}
    for i = 0, GetNumHairColors() - 1 do
        local r, g, b = GetPedHairRgbColor(i)
        hair[#hair + 1] = { r or 0, g or 0, b or 0 }
    end
    for i = 0, GetNumMakeupColors() - 1 do
        local r, g, b = GetPedMakeupRgbColor(i)
        makeup[#makeup + 1] = { r or 0, g or 0, b or 0 }
    end
    return { hair = hair, makeup = makeup }
end

-- ── Aplicar al ped ─────────────────────────────────────────────────────
local function setModel(model)
    local hash = joaat(model)
    if GetEntityModel(PlayerPedId()) == hash then return false end
    lib.requestModel(hash, Config.loadingModelsTimeout)
    SetPlayerModel(cache.playerId, hash)
    SetModelAsNoLongerNeeded(hash)
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    ClearPedDecorations(ped)   -- sin tatuajes ni restos del personaje anterior
    return true
end

--- Aplica una apariencia completa (ya saneada) al ped del jugador.
function E.apply(look)
    local changed = setModel(look.model)
    local ped = PlayerPedId()
    if changed and state then
        local s = state.scene
        SetEntityCoords(ped, s.x, s.y, s.z, false, false, false, false)
        SetEntityHeading(ped, state.heading or s.w)
        FreezeEntityPosition(ped, true)
    end
    if illenium() then
        pcall(function() exports['illenium-appearance']:setPedAppearance(ped, look) end)
    end
    return ped, changed
end

-- ── Cámara ─────────────────────────────────────────────────────────────
-- Encuadres relativos al ped (x derecha, y delante, z arriba). El ped mira a la cámara.
E.PRESETS = {
    body  = { cam = vec3(0.0, 2.7, 0.15), at = vec3(0.0, 0.0, -0.05), fov = 40.0 },
    torso = { cam = vec3(0.0, 1.5, 0.35), at = vec3(0.0, 0.0, 0.25), fov = 40.0 },
    face  = { cam = vec3(0.0, 0.72, 0.66), at = vec3(0.0, 0.0, 0.64), fov = 38.0 },
    hair  = { cam = vec3(0.0, 0.95, 0.78), at = vec3(0.0, 0.0, 0.68), fov = 40.0 },
}
E.SECTION_CAMERA = { identity = 'body', heritage = 'face', face = 'face', skin = 'face', hair = 'hair', clothes = 'body' }

local function placeCam(presetName, ms)
    if not state then return end
    local p = E.PRESETS[presetName] or E.PRESETS.body
    local ped = PlayerPedId()
    local z = state.zoom or 1.0
    local from = GetOffsetFromEntityInWorldCoords(ped, p.cam.x * z, p.cam.y * z, p.cam.z)
    local at = GetOffsetFromEntityInWorldCoords(ped, p.at.x, p.at.y, p.at.z)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, p.fov, false, 0)
    PointCamAtCoord(cam, at.x, at.y, at.z)
    local old = state.cam
    if old and DoesCamExist(old) and ms and ms > 0 then
        SetCamActiveWithInterp(cam, old, ms, 1, 1)
        SetTimeout(ms + 200, function() if DoesCamExist(old) then DestroyCam(old, false) end end)
    else
        if old and DoesCamExist(old) then DestroyCam(old, false) end
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    state.cam, state.preset = cam, presetName
end
E.placeCam = placeCam

-- ── Abrir / cerrar ─────────────────────────────────────────────────────
local function hideHud(hide)
    if GetResourceState('pxd_hud') == 'started' then pcall(function() exports.pxd_hud:SetVisible(not hide) end) end
    DisplayRadar(not hide)
end

--- Abre el editor. opts = {
---   mode = 'create' | 'recover' | 'edit', sections = {...}, title, look (apariencia inicial),
---   identity (solo create), scene = vec4, onDone = function(result) end }
--- result = { ok = true, look, identity } o { ok = false, cancelled = true }.
function E.open(opts)
    if state then return false end
    if illenium() then
        -- Por si el editor de illenium estuviera abierto: nunca dos a la vez.
        pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), opts.look) end)
    end
    local s = opts.scene or Config.creator.scene
    state = { mode = opts.mode, sections = opts.sections or L.SECTIONS, onDone = opts.onDone, zoom = 1.0,
        heading = s.w, scene = s, base = L.copy(opts.look) }
    local ped = PlayerPedId()
    SetEntityCoords(ped, s.x, s.y, s.z, false, false, false, false)
    SetEntityHeading(ped, s.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    E.apply(opts.look)
    local look = L.sanitize(opts.look, E.limits(PlayerPedId(), opts.look), opts.mode == 'create') or L.default(0)
    state.look = look
    hideHud(true)
    CreateThread(function()
        while state do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
    placeCam(E.SECTION_CAMERA[state.sections[1]] or 'body', 0)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'editor', data = {
        mode = opts.mode, title = opts.title, sections = state.sections, look = look, base = state.base,
        identity = opts.identity, limits = E.limits(PlayerPedId(), look), palettes = E.palettes(),
        regions = L.REGIONS, features = L.FACE_FEATURES, overlays = L.OVERLAYS, clothes = L.CLOTHES,
        outfits = (Config.starterOutfits or L.STARTER_OUTFITS), price = opts.price,
        defaults = opts.mode == 'create' and { [0] = L.default(0), [1] = L.default(1) } or nil,
    } })
    return true
end

function E.isOpen() return state ~= nil end

local function finish(result)
    local s = state
    if not s then return end
    state = nil
    if s.cam and DoesCamExist(s.cam) then SetCamActive(s.cam, false); DestroyCam(s.cam, false) end
    RenderScriptCams(false, false, 0, true, true)
    SendNUIMessage({ action = 'editorClose' })
    if s.onDone then s.onDone(result) end
end

--- Cierra sin terminar (desconexión, recurso parado…).
function E.close()
    if state then
        SetNuiFocus(false, false)
        finish({ ok = false, cancelled = true })
    end
    hideHud(false)
end
E.restoreHud = function() hideHud(false) end

-- ── Callbacks de la NUI ────────────────────────────────────────────────
--- La NUI manda la apariencia entera tras cada cambio; se sanea con los rangos reales,
--- se aplica y se devuelve (con los rangos de las texturas del drawable elegido).
RegisterNUICallback('editorLook', function(data, cb)
    if not state or type(data) ~= 'table' then return cb({ ok = false }) end
    local wanted = data.look
    if state.mode ~= 'create' and type(wanted) == 'table' then
        wanted = L.restrict(L.sanitize(wanted, nil, false) or state.look, state.look, state.sections)
    end
    if type(wanted) == 'table' and state.mode == 'create' and L.FREEMODE[wanted.model] == nil then
        wanted.model = state.look.model
    end
    -- Primero el modelo (cambia los rangos), luego el saneado con los rangos reales.
    if type(wanted) == 'table' and type(wanted.model) == 'string' and L.FREEMODE[wanted.model] ~= nil then setModel(wanted.model) end
    local ped = PlayerPedId()
    local look = L.sanitize(wanted, E.limits(ped, wanted), state.mode == 'create')
    if not look then return cb({ ok = false, look = state.look }) end
    E.apply(look)
    state.look = look
    cb({ ok = true, look = look, limits = E.limits(PlayerPedId(), look) })
end)

RegisterNUICallback('editorCamera', function(data, cb)
    cb({ ok = true })
    if not state or type(data) ~= 'table' then return end
    if data.preset and E.PRESETS[data.preset] then
        state.zoom = 1.0
        placeCam(data.preset, Config.creator.interpMs)
    elseif data.section and E.SECTION_CAMERA[data.section] then
        state.zoom = 1.0
        placeCam(E.SECTION_CAMERA[data.section], Config.creator.interpMs)
    elseif tonumber(data.rotate) then
        state.heading = ((state.heading or 0) + math.max(-45, math.min(45, tonumber(data.rotate)))) % 360
        SetEntityHeading(PlayerPedId(), state.heading)
        placeCam(state.preset, 0)
    elseif tonumber(data.zoom) then
        state.zoom = math.max(Config.creator.zoomMin, math.min(Config.creator.zoomMax, (state.zoom or 1) + tonumber(data.zoom)))
        placeCam(state.preset, 120)
    elseif data.reset then
        state.zoom, state.heading = 1.0, state.scene.w
        SetEntityHeading(PlayerPedId(), state.heading)
        placeCam(state.preset, Config.creator.interpMs)
    end
end)

--- Retratos de los padres (https://nui-img/<txd>/<textura>): el diccionario debe estar
--- cargado (FiveM: extra-natives-five/NuiTxdSource.cpp). Si no carga, la NUI muestra el nombre.
RegisterNUICallback('editorPortraits', function(_, cb)
    local dict = Config.creator.portraitsDict
    if not dict or dict == '' then return cb({ ok = false }) end
    RequestStreamedTextureDict(dict, false)
    local t = 0
    while not HasStreamedTextureDictLoaded(dict) and t < 3000 do Wait(50); t = t + 50 end
    cb({ ok = HasStreamedTextureDictLoaded(dict), dict = dict })
end)

RegisterNUICallback('editorFinish', function(data, cb)
    if not state or type(data) ~= 'table' then return cb({ ok = false }) end
    if state.busy then return cb({ ok = false, error = 'Guardando…' }) end
    local look = L.sanitize(data.look, E.limits(PlayerPedId(), data.look), state.mode == 'create')
    if not look then return cb({ ok = false, error = 'La apariencia no es válida.' }) end
    if state.mode ~= 'create' then look = L.restrict(look, state.base, state.sections) end
    state.busy = true
    cb({ ok = true })
    -- El que abrió el editor decide qué hacer (crear el personaje, guardar…). Si falla,
    -- llama a E.fail(mensaje) y el editor sigue abierto con lo editado.
    local done = state.onDone
    state.onDone = nil
    done({ ok = true, look = look, identity = data.identity, keepOpen = true })
end)

--- El paso siguiente falló: el editor sigue abierto y avisa (no se pierde nada).
function E.fail(message, field)
    if not state then return end
    state.busy = false
    SendNUIMessage({ action = 'editorError', text = message, field = field })
end

--- Terminado con éxito: cierra el editor (el HUD lo restaura quien llama al final).
function E.done()
    if not state then return end
    SetNuiFocus(false, false)
    finish({ ok = true })
end

--- Reengancha el callback final (para reintentos tras E.fail).
function E.onDone(fn) if state then state.onDone = fn end end

RegisterNUICallback('editorCancel', function(_, cb)
    cb({ ok = true })
    if not state or state.mode == 'create' or state.mode == 'recover' then return end   -- crear/recuperar no se cancela
    local base = state.base
    SetNuiFocus(false, false)
    E.apply(base)
    finish({ ok = false, cancelled = true })
    hideHud(false)
end)
