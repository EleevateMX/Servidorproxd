-- Hospital: retirada selectiva al reaparecer (ver config.lua y docs/29-hospital.md).
if not Config.medical.enabled then return end

local recent = {}

local function citizenId(src)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and player and player.PlayerData and player.PlayerData.citizenid or nil
end

local function notify(src, text)
    if not Config.medical.notify or not text then return end
    if GetResourceState('qbx_core') == 'started' then
        pcall(function() exports.qbx_core:Notify(src, text, 'inform') end)
    end
end

--- Retira lo confiscable del inventario de `src`. Servidor autoritativo.
local function confiscate(src, reason)
    if GetResourceState('ox_inventory') ~= 'started' then return {} end
    local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
    if not ok or type(items) ~= 'table' then return {} end
    local cid = citizenId(src)
    local removed = {}
    for _, it in ipairs(PXDMedical.plan(items, Config.medical)) do
        local done = exports.ox_inventory:RemoveItem(src, it.name, it.count, nil, it.slot)
        if done then
            removed[#removed + 1] = it
            PXDAudit.audit({
                category = 'medical', action = 'confiscate', actor = 'hospital', target = cid or ('src:' .. src),
                data = { item = it.name, count = it.count, slot = it.slot, serial = it.serial, reason = reason },
            })
        end
    end
    notify(src, PXDMedical.summary(removed))
    return removed
end

-- Reaparición en el hospital (qbx_medical/server/main.lua: callback de respawn).
-- La reanimación por EMS usa exports.qbx_medical:Revive y no dispara este evento.
AddEventHandler('qbx_medical:server:playerRespawned', function(src)
    src = tonumber(src)
    if not src then return end
    local now = GetGameTimer()
    if recent[src] and now - recent[src] < Config.medical.dedupeMs then return end
    recent[src] = now
    confiscate(src, 'respawn')
end)

AddEventHandler('playerDropped', function() recent[source] = nil end)

-- Aviso si qbx_ambulancejob sigue borrando todo el inventario.
CreateThread(function()
    local cfg = LoadResourceFile('qbx_ambulancejob', 'config/server.lua')
    if cfg and cfg:find('wipeInvOnRespawn%s*=%s*true') then
        print('^3[pxd_compat] qbx_ambulancejob tiene wipeInvOnRespawn = true: borra TODO el inventario al reaparecer. Ponlo en false (docs/29-hospital.md).^0')
    end
end)

PXDMedicalServer = { confiscate = confiscate, recent = recent }   -- para pruebas
