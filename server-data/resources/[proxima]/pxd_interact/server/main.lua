-- Servidor de pxd_interact: ID público por personaje (PROX-XXXX), conocidos y «Presentarse».
-- Con Qbox guarda en la metadata del personaje; sin Qbox, en data/players.json por licencia.
local RES = GetCurrentResourceName()
local INDEX_FILE = 'data/ids.json'
local FALLBACK_FILE = 'data/players.json'

local index = {}       -- [publicId] = citizenid | licencia
local fallback = {}    -- sin Qbox: [license] = { id, known, name }
local pending = {}     -- [target] = { [from] = expira }
local cooldowns = {}

local function now() return GetGameTimer() / 1000 end
local function qbx() return GetResourceState('qbx_core') == 'started' end

local function loadJson(path)
    local raw = LoadResourceFile(RES, path)
    local ok, data = pcall(function() return raw and raw ~= '' and json.decode(raw) end)
    return ok and type(data) == 'table' and data or {}
end
local function saveJson(path, data) SaveResourceFile(RES, path, json.encode(data), -1) end

index = loadJson(INDEX_FILE)
fallback = loadJson(FALLBACK_FILE)

local function license(src) return GetPlayerIdentifierByType(src, 'license') end

-- ── Acceso a datos del personaje ────────────────────────────────────────────
local function getPlayer(src)
    if not qbx() then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function owner(src)
    local p = getPlayer(src)
    if p then return p.PlayerData.citizenid end
    return license(src)
end

local function getMeta(src, key)
    if qbx() then
        local ok, v = pcall(function() return exports.qbx_core:GetMetadata(src, key) end)
        return ok and v or nil
    end
    local lic = license(src)
    return lic and fallback[lic] and fallback[lic][key]
end

local function setMeta(src, key, value)
    if qbx() then
        pcall(function() exports.qbx_core:SetMetadata(src, key, value) end)
        return
    end
    local lic = license(src)
    if not lic then return end
    fallback[lic] = fallback[lic] or {}
    fallback[lic][key] = value
    saveJson(FALLBACK_FILE, fallback)
end

local function charName(src)
    local p = getPlayer(src)
    if p then return PXDInteract.charName(p.PlayerData.charinfo) end
    return GetPlayerName(src)
end

local function loggedIn(src)
    if not qbx() then return GetPlayerName(src) ~= nil end
    return getPlayer(src) ~= nil
end

-- ── ID público ──────────────────────────────────────────────────────────────
local function ensureId(src)
    local id = getMeta(src, Config.metadataId)
    local who = owner(src)
    if not who then return nil end
    if not PXDInteract.isValidId(id, Config.idPrefix, Config.idLength) or (index[id] and index[id] ~= who) then
        id = PXDInteract.uniqueId(function(c) return index[c] ~= nil end, math.random, Config.idPrefix, Config.idLength)
        if not id then return nil end
        setMeta(src, Config.metadataId, id)
    end
    if index[id] ~= who then
        index[id] = who
        saveJson(INDEX_FILE, index)
    end
    Player(src).state:set('pxdId', id, true)   -- replicado: todos ven el ID, no el nombre
    return id
end

local function sendKnown(src)
    local known = getMeta(src, Config.metadataKnown)
    TriggerClientEvent('pxd_interact:known', src, type(known) == 'table' and known or {})
end

local function onLoaded(src)
    if not ensureId(src) then return end
    sendKnown(src)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if src then onLoaded(src) end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    Player(src).state:set('pxdId', nil, true)
    pending[src] = nil
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)

-- Al (re)iniciar el recurso: los que ya estén dentro. Sin Qbox, al pedirlo el cliente.
AddEventHandler('onResourceStart', function(res)
    if res ~= RES then return end
    if qbx() then
        local ok, players = pcall(function() return exports.qbx_core:GetQBPlayers() end)
        if ok and type(players) == 'table' then
            for src in pairs(players) do onLoaded(tonumber(src)) end
        end
    end
end)

RegisterNetEvent('pxd_interact:ready', function()
    local src = source
    if not qbx() or getPlayer(src) then onLoaded(src) end
end)

-- ── Presentarse ─────────────────────────────────────────────────────────────
local function dist(a, b)
    local pa, pb = GetEntityCoords(GetPlayerPed(a)), GetEntityCoords(GetPlayerPed(b))
    return #(pa - pb)
end

RegisterNetEvent('pxd_interact:introduce', function(target)
    local src = source
    target = tonumber(target)
    if not target or target == src or not loggedIn(src) or not loggedIn(target) then return end
    if dist(src, target) > Config.introduce.distance + 1.0 then return end
    if not PXDInteract.cooldown(cooldowns, src .. '>' .. target, now(), Config.introduce.cooldown) then
        return TriggerClientEvent('pxd_interact:notify', src, 'Espera un momento antes de volver a presentarte.')
    end
    local fromId = ensureId(src)
    if not fromId then return end
    pending[target] = pending[target] or {}
    pending[target][src] = now() + Config.introduce.timeout
    TriggerClientEvent('pxd_interact:invite', target, src, fromId, Config.introduce.timeout)
    TriggerClientEvent('pxd_interact:notify', src, 'Te estás presentando…')
end)

RegisterNetEvent('pxd_interact:answer', function(from, accept)
    local src = source
    from = tonumber(from)
    local list = pending[src]
    local expires = list and from and list[from]
    if not expires then return end
    list[from] = nil
    if not accept then
        return TriggerClientEvent('pxd_interact:notify', from, 'No ha aceptado tu presentación.')
    end
    if expires < now() or not loggedIn(from) or dist(src, from) > Config.introduce.acceptDistance then return end
    local fromId = Player(from).state.pxdId or ensureId(from)
    local name = charName(from)
    if not fromId or not name then return end
    local known = getMeta(src, Config.metadataKnown)
    known = PXDInteract.addKnown(type(known) == 'table' and known or {}, fromId, name, os.time(), Config.maxKnown)
    setMeta(src, Config.metadataKnown, known)
    TriggerClientEvent('pxd_interact:known', src, known)
    local myId = Player(src).state.pxdId or '?'
    TriggerClientEvent('pxd_interact:notify', from, ('%s ya sabe tu nombre.'):format(myId))
    TriggerClientEvent('pxd_interact:notify', src, ('Ahora conoces a %s.'):format(name))
end)

-- ── API de servidor ─────────────────────────────────────────────────────────
exports('GetPublicId', function(src) return Player(src).state.pxdId or ensureId(src) end)
exports('GetSourceByPublicId', function(id)
    for _, s in ipairs(GetPlayers()) do
        if Player(tonumber(s)).state.pxdId == id then return tonumber(s) end
    end
    return nil
end)
exports('Knows', function(src, id)
    local known = getMeta(src, Config.metadataKnown)
    return type(known) == 'table' and known[id] ~= nil
end)
