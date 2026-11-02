-- Cliente de pxd_jobs: blips, puntos de interacción (ox_target si está; si no, marcador + E)
-- y la animación de la tarea. Todo se valida en el servidor.
local base = json.decode(json.encode(Config.jobs)) -- copia limpia para reaplicar puntos extra
local jobs = Config.jobs
local blips, zones, route = {}, {}, nil
local busy = false
local useTarget = false

local INPUT_CONTEXT = 38 -- tecla E

local function helpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function addBlip(pt, sprite, color, label)
    local b = AddBlipForCoord(pt.x, pt.y, pt.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, color)
    SetBlipScale(b, 0.8)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    blips[#blips + 1] = b
end

-- Lista de interacciones: { pt, radius, label, action = function() }
local function interactions()
    local list = {}
    for name, job in pairs(jobs) do
        list[#list + 1] = { pt = job.signOn, radius = 2.0, label = ('Darse de alta: %s'):format(job.label),
            action = function() TriggerServerEvent('pxd_jobs:signOn', name) end }
        list[#list + 1] = { pt = job.signOn, radius = 2.0, label = ('Dejar el trabajo de %s'):format(job.label), secondary = true,
            action = function() TriggerServerEvent('pxd_jobs:signOff', name) end }
        if job.kind == 'gather' then
            for i, pt in ipairs(job.work.points) do
                list[#list + 1] = { pt = pt, radius = job.work.radius, label = job.work.label,
                    action = function() if not busy then TriggerServerEvent('pxd_jobs:start', name, i) end end }
            end
            list[#list + 1] = { pt = job.sell.point, radius = job.sell.radius, label = job.sell.label,
                action = function() TriggerServerEvent('pxd_jobs:sell', name) end }
        else
            list[#list + 1] = { pt = job.depot.point, radius = job.depot.radius, label = job.depot.label,
                action = function() TriggerServerEvent('pxd_jobs:pickup', name) end }
        end
    end
    return list
end

local current = {}

local function rebuild()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    if useTarget then
        for _, id in ipairs(zones) do pcall(function() exports.ox_target:removeZone(id) end) end
        zones = {}
    end
    for _, job in pairs(jobs) do
        addBlip(job.signOn, job.blip.sprite, job.blip.color, job.label)
        if job.kind == 'gather' then addBlip(job.sell.point, job.blip.sprite, job.blip.color, job.sell.label) end
    end
    current = interactions()
    if useTarget then
        -- Agrupa las opciones que comparten punto (alta y baja).
        local byPoint = {}
        for _, it in ipairs(current) do
            local key = ('%.2f:%.2f:%.2f'):format(it.pt.x, it.pt.y, it.pt.z)
            byPoint[key] = byPoint[key] or { pt = it.pt, radius = it.radius, options = {} }
            local g = byPoint[key]
            g.options[#g.options + 1] = { label = it.label, icon = 'fa-solid fa-briefcase', distance = 2.5, onSelect = it.action }
        end
        for _, g in pairs(byPoint) do
            local ok, id = pcall(function()
                return exports.ox_target:addSphereZone({
                    coords = vector3(g.pt.x, g.pt.y, g.pt.z), radius = math.max(1.5, g.radius), options = g.options,
                })
            end)
            if ok then zones[#zones + 1] = id end
        end
    end
end

RegisterNetEvent('pxd_jobs:points', function(extra)
    jobs = json.decode(json.encode(base))
    PXDJobs.applyExtra(jobs, extra)
    rebuild()
end)

RegisterNetEvent('pxd_jobs:notify', function(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(text))
    EndTextCommandThefeedPostTicker(false, true)
end)

RegisterNetEvent('pxd_jobs:started', function(name, seconds, scenario)
    if busy then return end
    busy = true
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, scenario, 0, true)
    local start = GetGameTimer()
    local origin = GetEntityCoords(ped)
    local cancelled = false
    while GetGameTimer() - start < seconds * 1000 do
        Wait(200)
        if #(GetEntityCoords(ped) - origin) > 3.0 then cancelled = true break end
    end
    ClearPedTasks(ped)
    busy = false
    if cancelled then
        TriggerServerEvent('pxd_jobs:cancel')
    else
        TriggerServerEvent('pxd_jobs:finish', name)
    end
end)

RegisterNetEvent('pxd_jobs:route', function(name, pt)
    if route then
        if DoesBlipExist(route.blip) then RemoveBlip(route.blip) end
        route = nil
    end
    if not name or not pt then return end
    local b = AddBlipForCoord(pt.x, pt.y, pt.z)
    SetBlipRoute(b, true)
    route = { name = name, pt = pt, blip = b }
end)

-- Bucle: entrega del repartidor (siempre por tecla) y, sin ox_target, marcadores + E.
CreateThread(function()
    useTarget = GetResourceState('ox_target') == 'started'
    rebuild()
    TriggerServerEvent('pxd_jobs:ready')
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local here = GetEntityCoords(ped)
        if route and not busy then
            local d = #(here - vector3(route.pt.x, route.pt.y, route.pt.z))
            if d < 40.0 then
                sleep = 0
                DrawMarker(1, route.pt.x, route.pt.y, route.pt.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    2.0, 2.0, 0.6, 92, 225, 255, 120, false, false, 2, false, nil, nil, false)
                if d < 6.0 then
                    helpText('Pulsa ~INPUT_CONTEXT~ para entregar el paquete')
                    if IsControlJustReleased(0, INPUT_CONTEXT) then TriggerServerEvent('pxd_jobs:deliver', route.name) end
                end
            end
        end
        if not useTarget and not busy then
            for _, it in ipairs(current) do
                if not it.secondary then
                    local d = #(here - vector3(it.pt.x, it.pt.y, it.pt.z))
                    if d < 25.0 then
                        sleep = 0
                        DrawMarker(1, it.pt.x, it.pt.y, it.pt.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            1.2, 1.2, 0.4, 255, 79, 216, 110, false, false, 2, false, nil, nil, false)
                        if d < math.max(1.5, it.radius) then
                            helpText(('Pulsa ~INPUT_CONTEXT~: %s'):format(it.label))
                            if IsControlJustReleased(0, INPUT_CONTEXT) then it.action() end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Sin ox_target, dejar el trabajo con comando.
RegisterCommand('dejartrabajo', function()
    local here = GetEntityCoords(PlayerPedId())
    for name, job in pairs(jobs) do
        if #(here - vector3(job.signOn.x, job.signOn.y, job.signOn.z)) < 5.0 then
            return TriggerServerEvent('pxd_jobs:signOff', name)
        end
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if route and DoesBlipExist(route.blip) then RemoveBlip(route.blip) end
end)
