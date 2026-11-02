-- Etiquetas sobre la cabeza: «Desconocido · PROX-7KQ2» o el nombre si se ha presentado.
-- El ID público llega por state bag (Player(id).state.pxdId); los nombres conocidos,
-- solo los del propio jugador, desde el servidor.
local known = {}
local nearby = {}
local enabled = Config.tags.enabled

RegisterNetEvent('pxd_interact:known', function(list)
    known = type(list) == 'table' and list or {}
end)

exports('setTagsEnabled', function(state) enabled = state and true or false end)

local function draw(x, y, z, text, scale, r, g, b)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Quién está cerca y a la vista (cada medio segundo).
CreateThread(function()
    while true do
        local list = {}
        if enabled and not IsPauseMenuActive() then
            local me, myPed = PlayerId(), PlayerPedId()
            local pos = GetEntityCoords(myPed)
            for _, p in ipairs(GetActivePlayers()) do
                if p ~= me then
                    local ped = GetPlayerPed(p)
                    local d = #(pos - GetEntityCoords(ped))
                    if d <= Config.tags.distance and IsEntityVisible(ped) and HasEntityClearLosToEntity(myPed, ped, 17) then
                        local id = Player(GetPlayerServerId(p)).state.pxdId
                        if id then list[#list + 1] = { player = p, ped = ped, id = id, dist = d } end
                    end
                end
            end
        end
        nearby = list
        Wait(500)
    end
end)

-- Dibujo (solo cuando hay alguien cerca).
CreateThread(function()
    while true do
        if #nearby == 0 then
            Wait(300)
        else
            for _, n in ipairs(nearby) do
                if DoesEntityExist(n.ped) then
                    local c = GetOffsetFromEntityInWorldCoords(n.ped, 0.0, 0.0, 1.05)
                    local scale = math.max(0.26, 0.38 - n.dist * 0.012)
                    local text = PXDInteract.tagLabel(known, n.id, Config.tags.unknown)
                    if MumbleIsPlayerTalking(n.player) then
                        draw(c.x, c.y, c.z, text, scale, 92, 225, 255)   -- habla: cian
                    else
                        draw(c.x, c.y, c.z, text, scale, 238, 242, 255)
                    end
                end
            end
            Wait(0)
        end
    end
end)
