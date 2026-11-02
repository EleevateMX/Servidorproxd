-- pxd_phone (cliente): puente entre la página de npwd (html/phone.js, inyectado en npwd)
-- y el servidor. Sin ui_page: las llamadas llegan a https://pxd_phone/<accion>.
local pending, seq = {}, 0
local ACTIONS = { 'd8_list', 'd8_mark', 'sos_send', 'taxi_state', 'taxi_request', 'taxi_cancel', 'taxi_accept' }

local function ask(action, data)
    seq = seq + 1
    local id = seq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('pxd_phone:server:req', id, action, data)
    SetTimeout(10000, function()
        if pending[id] then pending[id] = nil; p:resolve({ error = 'El servidor no respondió.' }) end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('pxd_phone:client:res', function(id, result)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve(result)
end)

local function waypoint(t)
    if type(t) == 'table' and tonumber(t.x) and tonumber(t.y) then SetNewWaypoint(t.x + 0.0, t.y + 0.0) end
end

for _, action in ipairs(ACTIONS) do
    RegisterNUICallback(action, function(data, cb)
        CreateThread(function()
            local result = ask(action, type(data) == 'table' and data or {}) or {}
            if action == 'd8_mark' and not result.error then waypoint(result); result = { ok = true } end
            if action == 'taxi_accept' and result.waypoint then waypoint(result.waypoint) end
            cb(result)
        end)
    end)
end

-- Avisos para quien atiende (policía, EMS, taxista): punto en el mapa con ruta.
RegisterNetEvent('pxd_phone:client:alert', function(a)
    if GetInvokingResource() or type(a) ~= 'table' or type(a.coords) ~= 'table' then return end
    local c = a.coords
    local blip = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(blip, a.kind == 'taxi' and 198 or 161)
    SetBlipColour(blip, a.kind == 'taxi' and 5 or 1)
    SetBlipScale(blip, 1.0)
    SetBlipFlashes(blip, a.kind ~= 'taxi')
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(tostring(a.title or 'Aviso'))
    EndTextCommandSetBlipName(blip)
    SetTimeout(math.max(30, math.min(tonumber(a.seconds) or 180, 900)) * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)
