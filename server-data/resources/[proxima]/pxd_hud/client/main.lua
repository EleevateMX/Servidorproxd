-- pxd_hud (cliente): lee el estado del jugador y lo manda a la NUI solo cuando cambia.
-- Fuentes (verificadas en el código de cada recurso):
--   qbx_core   → state bags hunger/thirst/stress/isLoggedIn, export GetPlayerData,
--                eventos QBCore:Player:SetPlayerData y hud:client:OnMoneyChange
--   pma-voice  → state bag proximity {index, distance, mode} y radioChannel
--   pxd_voice  → state bag pxdVoice (misma forma; tiene prioridad sobre proximity)
--   qbx_seatbelt → state bags seatbelt y harness
--   qbx_cruise (qbx_smallresources) → evento seatbelt:client:ToggleCruise
--   ox_fuel    → nivel de combustible del vehículo (GetVehicleFuelLevel)
--   ox_inventory → evento ox_inventory:currentWeapon (estrés al disparar)
local H = PXDHud
local state = LocalPlayer.state

local playerData = {}
local visible = true          -- lo apaga el inventario u otro recurso (export SetVisible)
local cruiseOn = false
local last = {}               -- último estado enviado a la NUI
local lastAnchorKey = nil

local function nui(msg) SendNUIMessage(msg) end

local function refreshPlayerData()
    if GetResourceState('qbx_core') ~= 'started' then return end
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    if ok and type(data) == 'table' then playerData = data end
end

local function money()
    local m = playerData.money or {}
    return m.cash or 0, m.bank or 0
end

local function isLoggedIn()
    if GetResourceState('qbx_core') ~= 'started' then return true end -- sin Qbox: siempre visible
    return state.isLoggedIn == true
end

local function isDead()
    local meta = playerData.metadata or {}
    return IsEntityDead(PlayerPedId()) or meta.isdead == true or meta.inlaststand == true
end

-- ── Minimapa ──────────────────────────────────────────────
-- Se usa el minimapa del juego tal cual; la NUI se coloca alrededor según su rectángulo.
local function sendAnchor()
    local resX, resY = GetActiveScreenResolution()
    local safezone, aspect = GetSafeZoneSize(), GetAspectRatio(false)
    local key = ('%d:%d:%.3f:%.3f'):format(resX, resY, safezone, aspect)
    if key == lastAnchorKey then return end
    lastAnchorKey = key
    nui({ action = 'anchor', anchor = H.minimapAnchor(safezone, aspect, resX, resY) })
end

-- ── Eventos ───────────────────────────────────────────────
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
    last = {}
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerData = {}
    nui({ action = 'hide' })
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if type(data) == 'table' then playerData = data end
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(moneyType, amount, isMinus)
    refreshPlayerData()
    local cash, bank = money()
    nui({ action = 'money', cash = cash, bank = bank, changed = moneyType, amount = amount, minus = isMinus == true })
end)

RegisterNetEvent('seatbelt:client:ToggleCruise', function()
    cruiseOn = not cruiseOn
end)

RegisterNetEvent('pxd_hud:client:visible', function(show)
    visible = show == true
    last = {}
end)

exports('SetVisible', function(show)
    visible = show == true
    last = {}
end)

-- La NUI avisa cuando está lista; entonces recibe la configuración y el estado completo.
RegisterNUICallback('ready', function(_, cb)
    refreshPlayerData()
    last, lastAnchorKey = {}, nil
    nui({ action = 'config', speedUnit = Config.speedUnit, warn = Config.warn, lowFuel = Config.lowFuel, minimapOnFoot = Config.minimapOnFoot })
    cb({})
end)

-- ── Bucle principal ───────────────────────────────────────
local street, streetTick = '', 0

CreateThread(function()
    local wasInVehicle = false
    while true do
        Wait(Config.tickMs)
        local show = visible and isLoggedIn() and not IsPauseMenuActive() and not IsHudHidden()
        if not show then
            if last.show ~= false then nui({ action = 'hide' }); last = { show = false } end
            DisplayRadar(false)
            goto continue
        end

        do
            local ped, pid = PlayerPedId(), PlayerId()
            local veh = GetVehiclePedIsIn(ped, false)
            local inVehicle = veh ~= 0 and not IsThisModelABicycle(GetEntityModel(veh))
            DisplayRadar(inVehicle or Config.minimapOnFoot)
            sendAnchor()

            local cash, bank = money()
            -- pxd_voice publica su modo (susurro/normal/grito) con la misma forma; si no está, pma-voice.
            local proximity = state.pxdVoice or state.proximity
            local inWater = IsEntityInWater(ped)
            local now = {
                show = true,
                cash = cash,
                bank = bank,
                health = H.healthPercent(GetEntityHealth(ped), GetEntityMaxHealth(ped)),
                armor = H.clamp(GetPedArmour(ped), 0, 100),
                hunger = math.floor(H.clamp(state.hunger or 100, 0, 100)),
                thirst = math.floor(H.clamp(state.thirst or 100, 0, 100)),
                stress = math.floor(H.clamp(state.stress or 0, 0, 100)),
                oxygen = inWater and math.floor(H.clamp(GetPlayerUnderwaterTimeRemaining(pid) * 10, 0, 100)) or -1,
                dead = isDead(),
                talking = NetworkIsPlayerTalking(pid),
                voice = H.voiceLabel(proximity),
                voiceIndex = type(proximity) == 'table' and proximity.index or 2,
                radio = tonumber(state.radioChannel) or 0,
                -- Deuda de multas pendientes (state bag replicado por pxd_justice; 0 si no está).
                fines = math.max(0, math.floor(tonumber(state.pxdFines) or 0)),
                clock = H.clock(GetClockHours(), GetClockMinutes()),
                vehicle = inVehicle,
            }
            if inVehicle then
                now.speed = H.speed(GetEntitySpeed(veh), Config.speedUnit)
                now.fuel = math.floor(H.clamp(GetVehicleFuelLevel(veh), 0, 100))
                now.engine = math.floor(H.clamp(GetVehicleEngineHealth(veh) / 10, 0, 100))
                now.seatbelt = state.seatbelt == true
                now.harness = state.harness == true
                now.cruise = cruiseOn
                if GetGameTimer() - streetTick > 1500 then
                    streetTick = GetGameTimer()
                    local c = GetEntityCoords(ped)
                    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
                    local a, b = GetStreetNameFromHashKey(s1), s2 ~= 0 and GetStreetNameFromHashKey(s2) or ''
                    street = (b ~= '' and (a .. ' · ' .. b)) or a
                end
                now.street = street
            elseif wasInVehicle then
                cruiseOn = false
            end
            wasInVehicle = inVehicle

            local changes = H.diff(last, now)
            if changes then
                for k, v in pairs(changes) do last[k] = v end
                changes.action = 'tick'
                nui(changes)
            end
        end
        ::continue::
    end
end)

-- ── Estrés (mismo comportamiento que qbx_hud) ─────────────
if Config.stress.enabled then
    local noStress = {}
    for _, name in ipairs(Config.stress.whitelistedWeapons) do noStress[GetHashKey(name)] = true end

    CreateThread(function() -- velocidad
        while true do
            Wait(10000)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if isLoggedIn() and veh ~= 0 then
                local class = GetVehicleClass(veh)
                -- 13 bicis, 14 barcos, 15 helicópteros, 16 aviones, 21 trenes: sin estrés por velocidad
                if class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16 and class ~= 21 then
                    local limit = (state.seatbelt or state.harness) and Config.stress.minSpeedBuckled or Config.stress.minSpeed
                    if class == 8 then limit = Config.stress.minSpeedBuckled end -- motos: como qbx_hud
                    if H.speed(GetEntitySpeed(veh), Config.speedUnit) >= limit then
                        TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                    end
                end
            end
        end
    end)

    local armed = false
    AddEventHandler('ox_inventory:currentWeapon', function(weapon)
        armed = false
        Wait(0)
        if not weapon or noStress[weapon.hash] then return end
        armed = true
        CreateThread(function()
            while armed do
                if IsPedShooting(PlayerPedId()) and math.random() <= Config.stress.chance then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 5))
                end
                Wait(0)
            end
        end)
    end)

    CreateThread(function() -- efectos en pantalla
        while true do
            local stress = state.stress or 0
            local interval = H.band(Config.stress.effectInterval, stress, 'timeout', 60000)
            if stress >= Config.stress.minForShaking then
                local blur = H.band(Config.stress.blurIntensity, stress, 'intensity', 1500)
                TriggerScreenblurFadeIn(1000.0)
                Wait(blur)
                TriggerScreenblurFadeOut(1000.0)
                local ped = PlayerPedId()
                if stress >= 100 and not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                    local fwd = GetEntityForwardVector(ped)
                    local t = math.random(2, 4) * 1750
                    SetPedToRagdollWithFall(ped, t, t, 1, fwd.x, fwd.y, fwd.z, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                end
            end
            Wait(interval)
        end
    end)
end
