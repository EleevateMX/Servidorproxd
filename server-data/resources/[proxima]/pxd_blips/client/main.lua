-- pxd_blips (cliente): pone nombre en español y tamaño común a los blips que crean
-- otros recursos, recorriéndolos por sprite. Natives verificados en citizenfx/natives
-- (HUD): GetFirstBlipInfoId, GetNextBlipInfoId, DoesBlipExist, IsBlipShortRange,
-- GetBlipInfoIdCoord, SetBlipScale, SetBlipColour, SetBlipCategory,
-- BeginTextCommandSetBlipName/AddTextComponentSubstringPlayerName/EndTextCommandSetBlipName;
-- AddTextEntry (FiveM).
local bySprite, sprites = PXDBlips.index(Config.rules)
local applied = {}

for _, msg in ipairs(PXDBlips.validate(Config.rules)) do
    print('^3[pxd_blips] ' .. msg .. '^7')
end

if Config.useCategories then
    for _, c in pairs(Config.categories) do AddTextEntry('BLIP_CAT_' .. c.index, c.label) end
end

local function setName(blip, name)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)
end

local function apply(blip, rule)
    setName(blip, rule.name)
    local scale = rule.scale or Config.scale
    if scale then SetBlipScale(blip, scale + 0.0) end
    if rule.colour then SetBlipColour(blip, rule.colour) end
    if Config.useCategories and rule.category and Config.categories[rule.category] then
        SetBlipCategory(blip, Config.categories[rule.category].index)
    end
end

local function pass(force)
    for _, sprite in ipairs(sprites) do
        local blip = GetFirstBlipInfoId(sprite)
        while DoesBlipExist(blip) do
            local c = GetBlipInfoIdCoord(blip)
            local rule = PXDBlips.match(bySprite, sprite, { x = c.x, y = c.y }, IsBlipShortRange(blip))
            if rule and (force or applied[blip] ~= rule.id) then
                apply(blip, rule)
                applied[blip] = rule.id
            end
            blip = GetNextBlipInfoId(sprite)
        end
    end
end

-- Puntos propios
local own = {}
local function createPoints()
    for _, p in ipairs(Config.points) do
        local b = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
        SetBlipSprite(b, p.sprite)
        SetBlipColour(b, p.colour or 0)
        SetBlipScale(b, (p.scale or Config.scale or 0.75) + 0.0)
        SetBlipAsShortRange(b, true)
        setName(b, p.name)
        own[#own + 1] = b
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(own) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)

CreateThread(function()
    createPoints()
    local n = 0
    while true do
        n = n + 1
        -- Cada 6 pasadas se reaplica todo: un recurso puede recrear su blip con
        -- el mismo identificador y nombre en inglés.
        pass(n % 6 == 0)
        Wait(Config.intervalMs)
    end
end)
