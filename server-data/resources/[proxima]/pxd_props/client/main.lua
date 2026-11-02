-- Cliente de pxd_props:
--  1) Renderiza los props como objetos LOCALES (no en red) cerca del jugador.
--  2) Editor: /props abre el panel; colocación con fantasma, rejilla y giro.
local layouts = {}        -- [id] = layout (copia del servidor)
local shown = {}          -- [id] = n  (layouts pedidos por otros recursos, p. ej. modos)
local spawned = {}        -- ["layout:propId"] = handle
local entityToProp = {}   -- [handle] = { layout, id }
local canEdit = false
local editorOpen = false
local editorLayout = nil  -- layout que se está editando
local selected = nil      -- { layout, id, kind = 'prop'|'point' }
local placing = false
local pending = {}        -- [reqId] = cb NUI
local reqSeq = 0

local function nui(type, data) SendNUIMessage({ type = type, data = data }) end

-- ── Utilidades ─────────────────────────────────────────────────────────────

local function key(layoutId, propId) return layoutId .. ':' .. propId end

local function loadModel(hash, timeoutMs)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeoutMs or 3000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

local function applyTransform(obj, p)
    SetEntityCoordsNoOffset(obj, p.x, p.y, p.z, false, false, false)
    SetEntityRotation(obj, p.rx or 0.0, p.ry or 0.0, p.rz or 0.0, 2, true)
end

local function spawnProp(layoutId, p)
    local k = key(layoutId, p.id)
    if spawned[k] then return end
    local hash = GetHashKey(p.model)
    if not loadModel(hash) then return end
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if obj == 0 then return end
    applyTransform(obj, p)
    if p.ground then PlaceObjectOnGroundProperly(obj) end
    FreezeEntityPosition(obj, p.frozen ~= false)
    SetEntityCollision(obj, p.collision ~= false, true)
    spawned[k] = obj
    entityToProp[obj] = { layout = layoutId, id = p.id }
end

local function despawn(k)
    local obj = spawned[k]
    if not obj then return end
    entityToProp[obj] = nil
    if DoesEntityExist(obj) then DeleteObject(obj) end
    spawned[k] = nil
end

local function despawnLayout(layoutId)
    local prefix = layoutId .. ':'
    for k in pairs(spawned) do
        if k:sub(1, #prefix) == prefix then despawn(k) end
    end
end

local function isVisible(id)
    local l = layouts[id]
    return l and (l.active or (shown[id] or 0) > 0 or (editorOpen and editorLayout == id))
end

-- Bucle de streaming: crea lo cercano, borra lo lejano.
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local far = Config.streamDistance + 25.0
        for id, l in pairs(layouts) do
            local visible = isVisible(id)
            for _, p in ipairs(l.props) do
                local k = key(id, p.id)
                local d = #(pos - vector3(p.x, p.y, p.z))
                if visible and d <= Config.streamDistance then
                    if not spawned[k] then spawnProp(id, p) end
                elseif spawned[k] and (not visible or d > far) then
                    despawn(k)
                end
            end
        end
        Wait(1000)
    end
end)

-- ── Datos del servidor ─────────────────────────────────────────────────────

RegisterNetEvent('pxd_props:client:sync', function(all, editable)
    for id in pairs(layouts) do despawnLayout(id) end
    layouts = all or {}
    canEdit = editable == true
    if editorOpen then nui('layouts', layouts) end
end)

RegisterNetEvent('pxd_props:client:layout', function(id, layout)
    despawnLayout(id)   -- se recrea en el siguiente ciclo con los datos nuevos
    layouts[id] = layout
    if editorOpen then nui('layout', { id = id, layout = layout }) end
end)

RegisterNetEvent('pxd_props:client:toast', function(message, kind)
    nui('toast', { message = message, kind = kind })
end)

RegisterNetEvent('pxd_props:client:opResult', function(reqId, ok, result)
    local cb = pending[reqId]
    pending[reqId] = nil
    if cb then cb({ ok = ok, result = ok and result or nil, error = not ok and result or nil }) end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('pxd_props:server:sync')
end)

--- Envía una operación al servidor y llama a cb con la respuesta.
local function sendOp(op, payload, cb)
    reqSeq = reqSeq + 1
    pending[reqSeq] = cb or function() end
    TriggerServerEvent('pxd_props:server:op', reqSeq, op, payload)
end

-- ── API para otros recursos ────────────────────────────────────────────────

exports('ShowLayout', function(id) shown[id] = (shown[id] or 0) + 1 end)
exports('HideLayout', function(id)
    shown[id] = math.max(0, (shown[id] or 1) - 1)
    if shown[id] == 0 and not isVisible(id) then despawnLayout(id) end
end)

-- ── Cámara y raycast ───────────────────────────────────────────────────────

local function camDirection()
    local rot = GetGameplayCamRot(2)
    local rz, rx = math.rad(rot.z), math.rad(rot.x)
    local c = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

--- Raycast desde la cámara. Flags 1|16 = mundo + objetos.
local function raycast(dist, ignore)
    local from = GetGameplayCamCoord()
    local to = from + camDirection() * (dist or 40.0)
    local handle = StartShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 17, ignore or 0, 7)
    local status, hit, coords, _, entity = 1, false, nil, nil, 0
    while status == 1 do
        status, hit, coords, _, entity = GetShapeTestResult(handle)
        if status == 1 then Wait(0) end
    end
    return hit == 1 or hit == true, coords, entity
end

local function helpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function snap(v, step)
    if not step or step <= 0 then return v end
    return math.floor(v / step + 0.5) * step
end

-- Controles (IDs de docs.fivem.net/docs/game-references/controls).
local C = {
    WHEEL_NEXT = 14, WHEEL_PREV = 15, SEL_NEXT = 16, SEL_PREV = 17, SPRINT = 21, ATTACK = 24, AIM = 25,
    PICKUP_E = 38, COVER_Q = 44, DETONATE_G = 47, VEH_DUCK_X = 73, MELEE_L = 140, MELEE_H = 141,
    MELEE_A = 142, ENTER = 191, BACKSPACE = 194, ESC = 200, SCROLL_UP = 241, SCROLL_DOWN = 242,
    ATTACK2 = 257, MELEE1 = 263, MELEE2 = 264,
}

local function blockGameControls()
    for _, c in ipairs({ C.WHEEL_NEXT, C.WHEEL_PREV, C.SEL_NEXT, C.SEL_PREV, C.ATTACK, C.AIM, C.PICKUP_E,
        C.COVER_Q, C.DETONATE_G, C.VEH_DUCK_X, C.MELEE_L, C.MELEE_H, C.MELEE_A, C.ESC, C.ATTACK2,
        C.MELEE1, C.MELEE2, C.SCROLL_UP, C.SCROLL_DOWN }) do
        DisableControlAction(0, c, true)
    end
end

-- ── Colocación ─────────────────────────────────────────────────────────────

--- Bucle de colocación. opts = { model, grid, rotStep, ground, rz, continuous }
--- Llama a onPlace(transform) por cada confirmación. Devuelve al cancelar.
local function placementLoop(opts, onPlace)
    local hash = GetHashKey(opts.model)
    if not loadModel(hash, 5000) then
        nui('toast', { kind = 'error', message = ('El modelo "%s" no existe en esta build.'):format(opts.model) })
        return
    end
    local ghost = CreateObjectNoOffset(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    local rz, zOffset = opts.rz or 0.0, 0.0
    local grid, rotStep = opts.grid or 0.0, opts.rotStep or 15.0
    local ground = opts.ground ~= false
    placing = true
    SetNuiFocus(false, false)
    nui('placing', { active = true, model = opts.model, grid = grid, rotStep = rotStep, ground = ground })

    while placing do
        Wait(0)
        blockGameControls()
        local fine = IsDisabledControlPressed(0, C.SPRINT) or IsControlPressed(0, C.SPRINT)
        if IsDisabledControlJustPressed(0, C.SCROLL_UP) then rz = rz + (fine and 1.0 or rotStep) end
        if IsDisabledControlJustPressed(0, C.SCROLL_DOWN) then rz = rz - (fine and 1.0 or rotStep) end
        if IsDisabledControlPressed(0, C.PICKUP_E) then zOffset = zOffset + (fine and 0.002 or 0.02) end
        if IsDisabledControlPressed(0, C.COVER_Q) then zOffset = zOffset - (fine and 0.002 or 0.02) end
        if IsDisabledControlJustPressed(0, C.DETONATE_G) then ground = not ground; zOffset = 0.0 end
        if IsDisabledControlJustPressed(0, C.VEH_DUCK_X) then grid = grid > 0 and 0.0 or (opts.grid ~= 0 and opts.grid or 0.25) end

        local hit, coords = raycast(40.0, ghost)
        if hit and coords then
            local x, y, z = snap(coords.x, grid), snap(coords.y, grid), coords.z
            SetEntityCoordsNoOffset(ghost, x, y, z, false, false, false)
            SetEntityRotation(ghost, 0.0, 0.0, rz, 2, true)
            if ground then PlaceObjectOnGroundProperly(ghost) end
            local c = GetEntityCoords(ghost)
            SetEntityCoordsNoOffset(ghost, c.x, c.y, c.z + zOffset, false, false, false)
        end

        helpText(('~INPUT_ATTACK~ colocar  ~INPUT_AIM~ cancelar~n~Rueda: girar (Shift = fino)  Q/E: altura~n~G: suelo %s  X: rejilla %s')
            :format(ground and 'ON' or 'OFF', grid > 0 and grid .. ' m' or 'OFF'))

        if hit and (IsDisabledControlJustPressed(0, C.ATTACK) or IsDisabledControlJustPressed(0, C.ENTER)) then
            local c = GetEntityCoords(ghost)
            local r = GetEntityRotation(ghost, 2)
            onPlace({ x = c.x, y = c.y, z = c.z, rx = r.x, ry = r.y, rz = r.z })
            if not opts.continuous then placing = false end
        end
        if IsDisabledControlJustPressed(0, C.AIM) or IsDisabledControlJustPressed(0, C.BACKSPACE)
            or IsDisabledControlJustPressed(0, C.ESC) then
            placing = false
        end
    end

    DeleteObject(ghost)
    SetModelAsNoLongerNeeded(hash)
    nui('placing', { active = false })
    if editorOpen then SetNuiFocus(true, true) end
end

-- Seleccionar un prop apuntándolo con la cámara.
local function pickLoop(cb)
    placing = true
    SetNuiFocus(false, false)
    nui('placing', { active = true, picking = true })
    local result = nil
    while placing do
        Wait(0)
        blockGameControls()
        local hit, _, entity = raycast(60.0, PlayerPedId())
        local info = hit and entityToProp[entity]
        if info then
            local c = GetEntityCoords(entity)
            DrawMarker(0, c.x, c.y, c.z + 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.6, 0.6,
                92, 225, 255, 200, true, true, 2, false, nil, nil, false)
        end
        helpText('~INPUT_ATTACK~ seleccionar el prop apuntado  ~INPUT_AIM~ cancelar')
        if info and IsDisabledControlJustPressed(0, C.ATTACK) then result = info; placing = false end
        if IsDisabledControlJustPressed(0, C.AIM) or IsDisabledControlJustPressed(0, C.ESC) then placing = false end
    end
    nui('placing', { active = false })
    if editorOpen then SetNuiFocus(true, true) end
    cb(result)
end

-- Marcadores de puntos y del prop seleccionado mientras el editor está abierto.
local POINT_COLORS = {
    spawn = { 255, 255, 255 }, team1 = { 80, 160, 255 }, team2 = { 255, 90, 90 },
    grid = { 255, 200, 60 }, checkpoint = { 92, 225, 255 }, zone = { 255, 79, 216 },
}
CreateThread(function()
    while true do
        local sleep = 500
        if editorOpen and editorLayout and layouts[editorLayout] then
            sleep = 0
            for _, p in ipairs(layouts[editorLayout].points or {}) do
                local c = POINT_COLORS[p.kind] or { 255, 255, 255 }
                if p.kind == 'zone' then
                    DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, p.radius * 2.0, p.radius * 2.0, 1.5,
                        c[1], c[2], c[3], 70, false, false, 2, false, nil, nil, false)
                else
                    DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.2,
                        c[1], c[2], c[3], 150, false, false, 2, false, nil, nil, false)
                end
            end
            if selected and selected.kind == 'prop' then
                local obj = spawned[key(selected.layout, selected.id)]
                if obj and DoesEntityExist(obj) then
                    local c = GetEntityCoords(obj)
                    DrawMarker(0, c.x, c.y, c.z + 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5,
                        255, 79, 216, 220, true, true, 2, false, nil, nil, false)
                end
            end
        end
        Wait(sleep)
    end
end)

-- ── Panel NUI ──────────────────────────────────────────────────────────────

local function openEditor()
    if not canEdit then
        TriggerServerEvent('pxd_props:server:sync')   -- por si cambió el permiso
        Wait(500)
        if not canEdit then
            nui('toast', { kind = 'error', message = 'No tienes permiso para editar props.' })
            return
        end
    end
    editorOpen = true
    SetNuiFocus(true, true)
    nui('open', { layouts = layouts, gridSizes = Config.gridSizes, rotationSteps = Config.rotationSteps })
end

local function closeEditor()
    editorOpen = false
    placing = false
    selected = nil
    SetNuiFocus(false, false)
    nui('close', {})
end

RegisterCommand('props', function()
    CreateThread(function()
        if editorOpen then closeEditor() else openEditor() end
    end)
end, false)
RegisterKeyMapping('props', 'Abrir el editor de props', 'keyboard', 'F6')

RegisterNUICallback('close', function(_, cb) closeEditor() cb({ ok = true }) end)

-- Reenvía operaciones al servidor (el servidor vuelve a comprobar el permiso).
RegisterNUICallback('op', function(data, cb)
    sendOp(data.op, data.payload, cb)
end)

RegisterNUICallback('focusLayout', function(data, cb)
    if editorLayout and editorLayout ~= data.id and not isVisible(editorLayout) then despawnLayout(editorLayout) end
    editorLayout = data.id
    cb({ ok = true })
end)

RegisterNUICallback('select', function(data, cb)
    selected = data and data.id and { layout = data.layout, id = data.id, kind = data.kind } or nil
    cb({ ok = true })
end)

RegisterNUICallback('place', function(data, cb)
    cb({ ok = true })
    if placing or not data.layout then return end
    CreateThread(function()
        placementLoop({ model = data.model, grid = tonumber(data.grid) or 0.0, rotStep = tonumber(data.rotStep) or 15.0,
            ground = data.ground ~= false, continuous = data.continuous == true, rz = tonumber(data.rz) },
            function(t)
                if data.moveId then
                    sendOp('updateProp', { layout = data.layout, id = data.moveId, patch = t }, function(r)
                        nui('opDone', { op = 'updateProp', response = r, before = data.before })
                    end)
                else
                    t.model = data.model
                    sendOp('addProp', { layout = data.layout, prop = t }, function(r)
                        nui('opDone', { op = 'addProp', response = r })
                    end)
                end
            end)
    end)
end)

RegisterNUICallback('pick', function(_, cb)
    cb({ ok = true })
    if placing then return end
    CreateThread(function()
        pickLoop(function(info) if info then nui('picked', info) end end)
    end)
end)

RegisterNUICallback('teleport', function(data, cb)
    if type(data.x) == 'number' then
        SetEntityCoords(PlayerPedId(), data.x + 1.5, data.y + 1.5, data.z + 0.5, false, false, false, false)
    end
    cb({ ok = true })
end)

RegisterNUICallback('here', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    cb({ x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) })
end)

RegisterNUICallback('checkModels', function(data, cb)
    local out = {}
    for _, m in ipairs(type(data.models) == 'table' and data.models or {}) do
        if type(m) == 'string' then out[m] = IsModelInCdimage(GetHashKey(m)) == true end
    end
    cb(out)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for k in pairs(spawned) do despawn(k) end
    if editorOpen then SetNuiFocus(false, false) end
end)
