-- pxd_garage (cliente): zonas de taller, vista previa en el vehículo real, cámara y estadísticas.
-- Solo propone cambios: el servidor valida, cobra y guarda. La vista previa usa
-- lib.getVehicleProperties / lib.setVehicleProperties (ox_lib 3.42.0).
-- Natives verificados en natives.json / natives_cfx.json: GetNumVehicleMods, GetModTextLabel,
-- DoesTextLabelExist, GetVehicleLiveryCount, GetNumVehicleWindowTints, GetNumberOfVehicleNumberPlates,
-- DoesExtraExist, IsVehicleExtraTurnedOn, GetVehicleEstimatedMaxSpeed, GetVehicleAcceleration,
-- GetVehicleMaxBraking, GetVehicleMaxTraction, GetModelDimensions, GetOffsetFromEntityInWorldCoords,
-- CreateCamWithParams, SetCamCoord, PointCamAtCoord, SetCamFov, RenderScriptCams, DestroyCam,
-- FreezeEntityPosition, SetVehicleDoorOpen, SetVehicleDoorsShut, SetVehicleLights, SetVehicleModKit,
-- GetDisplayNameFromVehicleModel, AddBlipForCoord. GetLabelText es el nombre clásico de
-- GET_FILENAME_FOR_AUDIO_CONVERSATION (lo usan qbx_customs 0.1.0 y ox_lib).
local G = PXDGarage

local zoneId            -- zona en la que está el jugador
local ed                -- estado del editor abierto (nil = cerrado)
local waitingOpen = false

local function nui(msg) SendNUIMessage(msg) end

local function hud(show)
    if GetResourceState('pxd_hud') == 'started' then pcall(function() exports.pxd_hud:SetVisible(show) end) end
    DisplayRadar(show)
end

local function toast(text, kind)
    if GetResourceState('qbx_core') == 'started' then pcall(function() exports.qbx_core:Notify(text, kind or 'inform') end) end
end

-- ── Catálogo real del vehículo ────────────────────────────
local function modName(veh, modType, index)
    local label = GetModTextLabel(veh, modType, index)
    if label and label ~= '' and DoesTextLabelExist(label) then
        local text = GetLabelText(label)
        if text and text ~= '' and text ~= 'NULL' then return text end
    end
    return ('Opción %d'):format(index + 1)
end

--- Opciones disponibles de una entrada para ESTE vehículo (nil = no se ofrece).
local function optionsFor(veh, entry)
    if entry.kind == 'level' then
        local n = math.min(GetNumVehicleMods(veh, entry.mod), #Config.pricing.performance[entry.key])
        if n <= 0 then return nil end
        return { count = n }
    elseif entry.kind == 'mod' then
        local n = GetNumVehicleMods(veh, entry.mod)
        if n <= 0 then return nil end
        n = math.min(n, Config.limits[entry.limit or 'mod'] + 1)
        local names = {}
        for i = 0, n - 1 do names[i + 1] = modName(veh, entry.mod, i) end
        return { count = n, names = names }
    elseif entry.kind == 'index' then
        if entry.key == 'windowTint' then return { count = math.min(GetNumVehicleWindowTints(), Config.limits.windowTint + 1) } end
        if entry.key == 'plateIndex' then return { count = math.min(GetNumberOfVehicleNumberPlates(), Config.limits.plateIndex + 1) } end
        if entry.key == 'livery' then
            local n = GetVehicleLiveryCount(veh)
            if n <= 0 then return nil end
            return { count = math.min(n, Config.limits.livery + 1) }
        end
        return { count = (Config.limits[entry.limit] or 0) + 1 }
    elseif entry.kind == 'extras' then
        local ids = {}
        for i = 1, 15 do if DoesExtraExist(veh, i) then ids[#ids + 1] = i end end
        if #ids == 0 then return nil end
        return { ids = ids }
    end
    return {}
end

local function buildCatalog(veh)
    local out = {}
    for _, entry in ipairs(G.CATALOG) do
        local opts = optionsFor(veh, entry)
        if opts then
            out[#out + 1] = { key = entry.key, kind = entry.kind, section = entry.section, label = entry.label,
                min = entry.min, count = opts.count, names = opts.names, ids = opts.ids, camera = entry.camera }
        end
    end
    return out
end

local function stats(veh)
    return {
        speed = GetVehicleEstimatedMaxSpeed(veh),
        acceleration = GetVehicleAcceleration(veh),
        braking = GetVehicleMaxBraking(veh),
        traction = GetVehicleMaxTraction(veh),
    }
end

--- Valores actuales (los del vehículo real) de las claves del catálogo.
local function currentValues(props)
    local out = {}
    for _, entry in ipairs(G.CATALOG) do out[entry.key] = props[entry.key] end
    return out
end

-- ── Presupuesto (el servidor lo recalcula al aplicar) ─────
local function quote()
    local items = G.diff(ed.stored, ed.changes)
    local q = G.quote(items, ed.base, Config, ed.factor)
    local ok, why = G.capCheck(items, ed.mode, ed.mechanic.level, Config)
    q.blocked = (not ok) and why or nil
    q.count = #items
    return q
end

-- ── Cámara ────────────────────────────────────────────────
-- Órbita alrededor del vehículo: ángulo (0 = de frente), altura y distancia relativas a su tamaño.
local VIEWS = {
    front = { angle = 35.0, height = 0.55, dist = 1.0, look = 0.25 },
    rear = { angle = 215.0, height = 0.6, dist = 1.0, look = 0.25 },
    side = { angle = 90.0, height = 0.45, dist = 1.0, look = 0.2 },
    top = { angle = 30.0, height = 1.9, dist = 0.9, look = 0.3 },
    wheel = { angle = 65.0, height = 0.05, dist = 0.62, look = -0.1 },
    engine = { angle = 15.0, height = 1.2, dist = 0.7, look = 0.35, hood = true },
    interior = { inside = true },
}

local function setView(name)
    local v = VIEWS[name] or VIEWS.front
    ed.view = name
    ed.cam.inside = v.inside == true
    if not v.inside then
        ed.cam.angle, ed.cam.height, ed.cam.dist, ed.cam.look = v.angle, v.height, v.dist, v.look
    end
    if v.hood then SetVehicleDoorOpen(ed.veh, 4, false, false) else SetVehicleDoorsShut(ed.veh, false) end
end

local function camTarget()
    local veh, c = ed.veh, ed.cam
    if c.inside then
        -- Desde el asiento trasero central hacia el salpicadero.
        local from = GetOffsetFromEntityInWorldCoords(veh, 0.0, -0.75, ed.size.z * 0.42)
        local at = GetOffsetFromEntityInWorldCoords(veh, 0.0, 1.2, ed.size.z * 0.2)
        return from, at, 65.0
    end
    local radius = (math.max(ed.size.x, ed.size.y) * 0.75 + 2.2) * c.dist * c.zoom
    local rad = math.rad(c.angle)
    local from = GetOffsetFromEntityInWorldCoords(veh, math.sin(rad) * radius, math.cos(rad) * radius, c.height * ed.size.z + 0.25)
    local at = GetOffsetFromEntityInWorldCoords(veh, 0.0, 0.0, c.look * ed.size.z)
    return from, at, 42.0
end

local function startCamera()
    local min, max = GetModelDimensions(GetEntityModel(ed.veh))
    ed.size = { x = max.x - min.x, y = max.y - min.y, z = max.z - min.z }
    ed.cam = { angle = 35.0, height = 0.55, dist = 1.0, look = 0.25, zoom = 1.0, inside = false }
    local from, at, fov = camTarget()
    ed.cam.handle = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, fov, true, 2)
    PointCamAtCoord(ed.cam.handle, at.x, at.y, at.z)
    RenderScriptCams(true, true, 600, true, false)
    ed.cam.pos, ed.cam.at, ed.cam.fov = from, at, fov
    CreateThread(function()
        while ed and ed.cam and ed.cam.handle do
            local to, at2, fov2 = camTarget()
            local c = ed.cam
            -- Suavizado: cada fotograma se acerca un 18 % al destino.
            c.pos = c.pos + (to - c.pos) * 0.18
            c.at = c.at + (at2 - c.at) * 0.18
            c.fov = c.fov + (fov2 - c.fov) * 0.18
            SetCamCoord(c.handle, c.pos.x, c.pos.y, c.pos.z)
            PointCamAtCoord(c.handle, c.at.x, c.at.y, c.at.z)
            SetCamFov(c.handle, c.fov)
            Wait(0)
        end
    end)
end

local function stopCamera()
    if ed and ed.cam and ed.cam.handle then
        local h = ed.cam.handle
        ed.cam.handle = nil
        RenderScriptCams(false, true, 400, true, false)
        DestroyCam(h, false)
    end
end

-- ── Abrir y cerrar ────────────────────────────────────────
local function closeEditor(restore)
    if not ed then return end
    local veh = ed.veh
    if restore and DoesEntityExist(veh) and next(ed.changes) then
        lib.setVehicleProperties(veh, ed.original)   -- cancelar = exactamente como estaba
    end
    stopCamera()
    if DoesEntityExist(veh) then
        SetVehicleDoorsShut(veh, false)
        SetVehicleLights(veh, 0)
        FreezeEntityPosition(veh, false)
    end
    ed = nil
    SetNuiFocus(false, false)
    nui({ action = 'close' })
    hud(true)
    TriggerServerEvent('pxd_garage:server:close')
end

local function openEditor(data)
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then return toast(G.MESSAGES.vehiculo, 'error') end
    SetVehicleModKit(veh, 0)
    SetEntityVelocity(veh, 0.0, 0.0, 0.0)
    FreezeEntityPosition(veh, true)
    local original = lib.getVehicleProperties(veh)
    ed = {
        veh = veh, original = original, stored = data.props or {}, changes = {},
        base = data.base, factor = data.factor or 1, mode = data.mode, mechanic = data.mechanic or { level = 1 },
        statsBefore = stats(veh),
    }
    hud(false)
    startCamera()
    SetNuiFocus(true, true)
    local label = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local name = (label and DoesTextLabelExist(label)) and GetLabelText(label) or label or data.model
    nui({
        action = 'open',
        vehicle = { name = name, plate = data.plate, base = data.base },
        zone = data.zoneLabel, mode = data.mode, ownsIt = data.ownsIt, ownerName = data.ownerName,
        methods = data.methods, mechanic = data.mechanic, factor = data.factor,
        sections = G.SECTIONS, catalog = buildCatalog(veh), values = currentValues(original),
        performance = Config.performance, levels = Config.mechanic.levels,
        stats = { before = ed.statsBefore, now = ed.statsBefore, scale = Config.stats },
        quote = quote(),
    })
end

RegisterNetEvent('pxd_garage:client:opened', function(res)
    waitingOpen = false
    if type(res) ~= 'table' then return end
    if not res.ok then return toast(res.message or G.MESSAGES.sin_servicio, 'error') end
    if ed then return end
    openEditor(res.data)
end)

RegisterNetEvent('pxd_garage:client:applied', function(res)
    if not ed or type(res) ~= 'table' then return end
    if res.ok then
        local r = res.result
        -- Lo aplicado pasa a ser el estado «original»: cerrar ya no deshace nada.
        ed.original = lib.getVehicleProperties(ed.veh)
        ed.stored = r.props or ed.stored
        ed.changes = {}
        ed.statsBefore = stats(ed.veh)
        if r.mechanic then ed.mechanic = r.mechanic end
        nui({ action = 'applied', ok = true, total = r.total, pay = r.pay, xp = r.xp, mechanic = r.mechanic,
            values = currentValues(ed.original), quote = quote(),
            stats = { before = ed.statsBefore, now = ed.statsBefore, scale = Config.stats } })
    else
        nui({ action = 'applied', ok = false, message = res.message })
    end
end)

-- ── Callbacks de la interfaz ──────────────────────────────
RegisterNUICallback('set', function(body, cb)
    if not ed or type(body) ~= 'table' then return cb({ ok = false }) end
    local entry = G.byKey[body.key]
    local value = entry and G.clean(entry, body.value, Config)
    if value == nil then return cb({ ok = false }) end
    local props = { [entry.key] = value }
    -- El acabado solo se aplica junto a un color RGB (así lo hace ox_lib).
    if entry.key == 'paintType1' then props.color1 = ed.changes.color1 or ed.original.color1 end
    if entry.key == 'paintType2' then props.color2 = ed.changes.color2 or ed.original.color2 end
    if entry.key == 'color1' and type(value) == 'table' then props.paintType1 = ed.changes.paintType1 or ed.original.paintType1 end
    if entry.key == 'color2' and type(value) == 'table' then props.paintType2 = ed.changes.paintType2 or ed.original.paintType2 end
    lib.setVehicleProperties(ed.veh, props)
    if G.same(ed.original[entry.key], value) then ed.changes[entry.key] = nil else ed.changes[entry.key] = value end
    if entry.section == 'lights' then SetVehicleLights(ed.veh, 2) end
    local refresh
    if entry.key == 'wheels' then
        -- Cada tipo de llanta tiene su propia lista.
        refresh = {}
        for _, k in ipairs({ 'modFrontWheels', 'modBackWheels' }) do
            local opts = optionsFor(ed.veh, G.byKey[k])
            refresh[k] = opts and { count = opts.count, names = opts.names } or { count = 0, names = {} }
        end
    end
    cb({ ok = true, quote = quote(), stats = stats(ed.veh), refresh = refresh })
end)

RegisterNUICallback('reset', function(_, cb)
    if not ed then return cb({ ok = false }) end
    lib.setVehicleProperties(ed.veh, ed.original)
    ed.changes = {}
    cb({ ok = true, values = currentValues(ed.original), quote = quote(), stats = stats(ed.veh) })
end)

RegisterNUICallback('camera', function(body, cb)
    if ed and type(body) == 'table' and type(body.view) == 'string' and VIEWS[body.view] then setView(body.view) end
    cb({ ok = true })
end)

RegisterNUICallback('orbit', function(body, cb)
    if ed and ed.cam and type(body) == 'table' and not ed.cam.inside then
        local dx, dy, dz = tonumber(body.dx) or 0, tonumber(body.dy) or 0, tonumber(body.zoom) or 0
        ed.cam.angle = (ed.cam.angle + math.max(-40, math.min(40, dx)) * 0.35) % 360
        ed.cam.height = math.max(0.0, math.min(2.2, ed.cam.height + math.max(-40, math.min(40, dy)) * 0.006))
        ed.cam.zoom = math.max(0.55, math.min(1.6, ed.cam.zoom + math.max(-1, math.min(1, dz)) * 0.08))
    end
    cb({ ok = true })
end)

RegisterNUICallback('apply', function(body, cb)
    if not ed or not next(ed.changes) then return cb({ ok = false, message = G.MESSAGES.nada }) end
    TriggerServerEvent('pxd_garage:server:apply', ed.changes, type(body) == 'table' and body.method or nil)
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeEditor(true)
    cb({ ok = true })
end)

-- ── Zonas ─────────────────────────────────────────────────
local function hint(show, zone)
    if show then
        lib.showTextUI(('[E] %s'):format(zone.job and 'Abrir el taller' or 'Personalizar vehículo'), { position = 'left-center', icon = 'wrench' })
    else
        lib.hideTextUI()
    end
end

CreateThread(function()
    for _, zone in ipairs(Config.zones) do
        local pts = {}
        for i, p in ipairs(zone.points) do pts[i] = vec3(p[1], p[2], zone.z) end
        lib.zones.poly({
            points = pts, thickness = Config.zoneHeight * 2,
            onEnter = function() zoneId = zone.id end,
            onExit = function()
                if zoneId == zone.id then zoneId = nil end
                hint(false)
                if ed then closeEditor(true) end
            end,
            inside = function()
                if ed or waitingOpen then return end
                local driving = cache.vehicle and cache.seat == -1
                if driving then
                    if not lib.isTextUIOpen() then hint(true, zone) end
                    if IsControlJustPressed(0, Config.key) then
                        hint(false)
                        waitingOpen = true
                        TriggerServerEvent('pxd_garage:server:open', zone.id)
                        SetTimeout(4000, function() waitingOpen = false end)
                    end
                elseif lib.isTextUIOpen() then
                    hint(false)
                end
            end,
        })
        local x, y, z = G.zoneCenter(zone)
        local blip = AddBlipForCoord(x, y, z)
        SetBlipSprite(blip, Config.blip.sprite)
        SetBlipColour(blip, Config.blip.colour)
        SetBlipScale(blip, Config.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(zone.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- Si baja del vehículo, muere o se para el recurso: se deshace la vista previa.
lib.onCache('vehicle', function(vehicle)
    if ed and vehicle ~= ed.veh then closeEditor(true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and ed then closeEditor(true) end
end)

TriggerEvent('chat:addSuggestion', '/mecanico', 'Ver tu nivel y experiencia de mecánico')
