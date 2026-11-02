-- pxd_interact (cliente): avisos contextuales con E y API para otros recursos.
-- Registros: zonas (coords + radio), entidades locales, modelos y jugadores.
-- Cada opción: { label, icon?, distance?, canInteract?(ctx), onSelect?(ctx), event?, serverEvent?, args? }
-- ctx = { entity?, coords, dist, serverId?, zone? }
local zones, entities, models, playerOpts, temp = {}, {}, {}, {}, {}
local providers = {}   -- internos (maletero…): fn(ped, pos, inVehicle) → candidato o nil
local P = PXDInteract.PRIORITY
local nextId = 0
local disabled = false
local shown, selected, signature = {}, 1, ''
local byKey = {}   -- key → candidato (para ejecutar la opción elegida)

local function newId() nextId = nextId + 1 return nextId end

local function owner() return GetInvokingResource() or GetCurrentResourceName() end

local function normOptions(options)
    if type(options) ~= 'table' then return {} end
    if options.label then return { options } end   -- se aceptó una sola opción
    return options
end

-- ── API (exports) ───────────────────────────────────────────────────────────
local API = {}

--- addZone({ coords = vec3, radius = 1.5, options = {...}, allowVehicle?, priority? }) → id
function API.addZone(data)
    if type(data) ~= 'table' or not data.coords then return nil end
    local id = newId()
    zones[id] = { coords = vector3(data.coords.x, data.coords.y, data.coords.z), radius = tonumber(data.radius) or 1.5,
        options = normOptions(data.options), allowVehicle = data.allowVehicle, priority = data.priority, owner = owner() }
    return id
end
function API.removeZone(id) zones[id] = nil end

--- addLocalEntity(entity, options, distance?) → id
function API.addLocalEntity(entity, options, distance)
    local id = newId()
    entities[id] = { entity = entity, options = normOptions(options), distance = tonumber(distance) or 2.0, owner = owner() }
    return id
end
function API.removeLocalEntity(id) entities[id] = nil end

--- addModel(models, options, distance?) → id   (models: nombre, hash o lista)
function API.addModel(list, options, distance)
    local id = newId()
    local set = {}
    for _, m in ipairs(type(list) == 'table' and list or { list }) do
        set[type(m) == 'string' and joaat(m) or m] = true
    end
    models[id] = { set = set, options = normOptions(options), distance = tonumber(distance) or 2.0, owner = owner() }
    return id
end
function API.removeModel(id) models[id] = nil end

--- addGlobalPlayer(options) → id   (opciones sobre cualquier jugador cercano; ctx.serverId)
function API.addGlobalPlayer(options)
    local id = newId()
    playerOpts[id] = { options = normOptions(options), owner = owner() }
    return id
end
function API.removeGlobalPlayer(id) playerOpts[id] = nil end

--- Opciones temporales que se muestran siempre (p. ej. una invitación), con prioridad.
function API.addTemporary(options, seconds, priority)
    local id = newId()
    temp[id] = { options = normOptions(options), expires = GetGameTimer() + (tonumber(seconds) or 10) * 1000,
        priority = priority or 100, owner = owner() }
    return id
end
function API.removeTemporary(id) temp[id] = nil end

function API.disable(state) disabled = state and true or false end

--- Interno (no exportado): proveedores dinámicos de este recurso, p. ej. el maletero.
function PXDInteractAddProvider(fn) providers[#providers + 1] = fn end
function API.isActive() return #shown > 0 end

for name, fn in pairs(API) do exports(name, fn) end
PXDInteractAPI = API   -- para los scripts de este mismo recurso

-- Limpieza de lo que registró un recurso al pararse.
AddEventHandler('onResourceStop', function(res)
    for _, t in ipairs({ zones, entities, models, playerOpts, temp }) do
        for id, v in pairs(t) do if v.owner == res then t[id] = nil end end
    end
end)

-- ── Candidatos cercanos ─────────────────────────────────────────────────────
local function allowed(opt, ctx)
    if type(opt.canInteract) ~= 'function' and type(opt.canInteract) ~= 'table' then return true end
    local ok, res = pcall(opt.canInteract, ctx)
    return ok and res and true or false
end

local function filter(options, ctx)
    local out = {}
    for _, o in ipairs(options) do
        if (not o.distance or ctx.dist <= o.distance) and allowed(o, ctx) then out[#out + 1] = o end
    end
    return out
end

local modelHits, lastModelScan = {}, 0

local function scanModels(pos)
    if next(models) == nil then modelHits = {} return end
    if GetGameTimer() - lastModelScan < 600 then return end
    lastModelScan = GetGameTimer()
    modelHits = {}
    for _, obj in ipairs(GetGamePool('CObject')) do
        local d = #(pos - GetEntityCoords(obj))
        if d < 3.5 then
            local m = GetEntityModel(obj)
            for id, reg in pairs(models) do
                if reg.set[m] and d <= reg.distance then modelHits[#modelHits + 1] = { id = id, entity = obj } end
            end
        end
    end
end

local function collect()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local list = {}
    byKey = {}
    local function push(key, dist, options, ctx, priority)
        if #options == 0 then return end
        list[#list + 1] = { key = key, dist = dist, options = options, priority = priority }
        byKey[key] = { options = options, ctx = ctx }
    end

    local t = GetGameTimer()
    for id, v in pairs(temp) do
        if v.expires < t then temp[id] = nil
        else
            local ctx = { coords = pos, dist = 0 }
            push('t' .. id, 0, filter(v.options, ctx), ctx, v.priority)
        end
    end
    for id, z in pairs(zones) do
        if not inVehicle or z.allowVehicle then
            local d = #(pos - z.coords)
            if d <= z.radius then
                local ctx = { coords = z.coords, dist = d, zone = id }
                push('z' .. id, d, filter(z.options, ctx), ctx, z.priority or P.zone)
            end
        end
    end
    if not inVehicle then
        for id, e in pairs(entities) do
            if DoesEntityExist(e.entity) then
                local c = GetEntityCoords(e.entity)
                local d = #(pos - c)
                if d <= e.distance then
                    local ctx = { entity = e.entity, coords = c, dist = d }
                    push('e' .. id, d, filter(e.options, ctx), ctx, P.npc)
                end
            end
        end
        scanModels(pos)
        for i, hit in ipairs(modelHits) do
            local reg = models[hit.id]
            if reg and DoesEntityExist(hit.entity) then
                local c = GetEntityCoords(hit.entity)
                local ctx = { entity = hit.entity, coords = c, dist = #(pos - c) }
                push('m' .. hit.id .. ':' .. i, ctx.dist, filter(reg.options, ctx), ctx, P.npc)
            end
        end
        if next(playerOpts) then
            local me = PlayerId()
            for _, p in ipairs(GetActivePlayers()) do
                if p ~= me then
                    local other = GetPlayerPed(p)
                    local c = GetEntityCoords(other)
                    local d = #(pos - c)
                    if d <= 2.5 and IsEntityVisible(other) then
                        local ctx = { entity = other, coords = c, dist = d, serverId = GetPlayerServerId(p) }
                        local opts = {}
                        for _, reg in pairs(playerOpts) do
                            for _, o in ipairs(filter(reg.options, ctx)) do opts[#opts + 1] = o end
                        end
                        push('p' .. ctx.serverId, d, opts, ctx, P.player)
                    end
                end
            end
        end
    end
    for i, fn in ipairs(providers) do
        local ok, c = pcall(fn, ped, pos, inVehicle)
        if ok and c then push(c.key or ('x' .. i), c.dist or 0, filter(c.options, c.ctx), c.ctx, c.priority) end
    end
    return list
end

-- ── Ceder la E a otros recursos ─────────────────────────────────────────────
-- ox_doorlock (puertas), qbx_teleports y otros muestran su aviso con ox_lib textUI y
-- leen la E (control 38) por su cuenta; qbx_tackle usa E al correr; qbx_vehiclepush,
-- Mayús + E; ox_fuel (sin ox_target), E a menos de 3 m de un surtidor. En esos casos
-- pxd_interact no muestra nada ni actúa.
local function nearPump(pos)
    if GetResourceState('ox_fuel') ~= 'started' then return false end
    for _, model in ipairs(Config.fuelPumps or {}) do
        if GetClosestObjectOfType(pos.x, pos.y, pos.z, 3.0, GetHashKey(model), false, false, false) ~= 0 then return true end
    end
    return false
end

local function yieldState(ped)
    local s = { sprinting = IsPedSprinting(ped) or IsPedRunning(ped), shift = IsControlPressed(0, 21) }
    if GetResourceState('ox_lib') == 'started' then
        local ok, open = pcall(function() return exports.ox_lib:isTextUIOpen() end)
        s.textUI = ok and open == true
    end
    if GetResourceState('ox_doorlock') == 'started' then
        local ok, door = pcall(function() return exports.ox_doorlock:getClosestDoor() end)
        s.door = ok and type(door) == 'table' and (door.distance or 99) < (door.maxDistance or 0)
    end
    s.pump = nearPump(GetEntityCoords(ped))
    return s
end
PXDInteractYielding = function() return PXDInteract.shouldYield(yieldState(PlayerPedId())) end

-- ── NUI ─────────────────────────────────────────────────────────────────────
local function render(list)
    local sig = PXDInteract.signature(list)
    if sig == signature then return end
    signature = sig
    shown = list
    if selected > #list then selected = 1 end
    if #list == 0 then
        SendNUIMessage({ action = 'hide' })
    else
        local view = {}
        for i, o in ipairs(list) do view[i] = { label = o.label, icon = o.icon } end
        SendNUIMessage({ action = 'options', list = view, selected = selected, key = Config.keys.interact })
    end
end

local function run(item)
    local cand = item and byKey[item.key]
    local opt = cand and cand.options[item.index]
    if not opt then return end
    local ctx = cand.ctx
    if opt.onSelect then
        local ok, err = pcall(opt.onSelect, ctx)
        if not ok then print(('[pxd_interact] error en «%s»: %s'):format(opt.label, tostring(err))) end
    elseif opt.event then
        TriggerEvent(opt.event, opt.args or ctx)
    elseif opt.serverEvent then
        TriggerServerEvent(opt.serverEvent, opt.args)
    end
    SendNUIMessage({ action = 'pressed' })
end

-- Tecla (cambiable en Ajustes → Asignación de teclas → FiveM).
RegisterCommand('+pxd_interact', function()
    if disabled or IsPauseMenuActive() or IsNuiFocused() then return end
    if #shown == 0 or PXDInteractYielding() then return end
    run(shown[selected])
end, false)
RegisterCommand('-pxd_interact', function() end, false)
RegisterKeyMapping('+pxd_interact', 'Interactuar (Próxima RP)', 'keyboard', Config.keys.interact)

-- Bucle de búsqueda (adaptativo) y bucle de navegación (solo con varias opciones).
CreateThread(function()
    while true do
        local sleep = 250
        local ped = PlayerPedId()
        if disabled or IsPauseMenuActive() or IsNuiFocused() or IsPedDeadOrDying(ped, true) then
            render({})
            sleep = 500
        elseif PXDInteract.shouldYield(yieldState(ped)) then
            render({})
        else
            local list = PXDInteract.flatten(collect(), Config.maxOptions)
            render(list)
            if #list == 0 then sleep = 400 end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if #shown > 1 then
            -- Rueda del ratón (14/15): elegir opción. Sin flechas: la flecha arriba abre el teléfono.
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            local delta = 0
            if IsDisabledControlJustPressed(0, 15) then delta = -1 end
            if IsDisabledControlJustPressed(0, 14) then delta = 1 end
            if delta ~= 0 then
                selected = PXDInteract.wrap(selected + delta, #shown)
                SendNUIMessage({ action = 'select', selected = selected })
            end
            Wait(0)
        else
            selected = 1
            Wait(200)
        end
    end
end)

-- Avisos cortos (los del propio recurso y los que pidan otros).
local function notify(text) SendNUIMessage({ action = 'notify', text = tostring(text) }) end
RegisterNetEvent('pxd_interact:notify', notify)
exports('notify', notify)
