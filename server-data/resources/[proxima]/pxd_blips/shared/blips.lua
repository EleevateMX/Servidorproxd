-- Lógica pura de pxd_blips: qué regla aplicar a un blip según su sprite, si es de
-- corto alcance y dónde está. Sin natives (se prueba con Lua 5.4).
PXDBlips = {}

local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

--- Indexa las reglas por sprite y les pone un id estable.
function PXDBlips.index(rules)
    local bySprite, sprites = {}, {}
    for i, r in ipairs(rules) do
        r.id = r.id or i
        local list = bySprite[r.sprite]
        if not list then
            list = {}
            bySprite[r.sprite] = list
            sprites[#sprites + 1] = r.sprite
        end
        list[#list + 1] = r
    end
    table.sort(sprites)
    return bySprite, sprites
end

--- Devuelve la regla para un blip, o nil si no hay que tocarlo.
--- - Solo blips de corto alcance (los de la ciudad), salvo regla con longRange = true:
---   así no se tocan avisos de policía/EMS, rutas de trabajo ni jugadores.
--- - Una regla con `near = {x, y, r}` gana a la genérica si el blip está dentro; si
---   hay varias, la más cercana. Una regla con `skip = true` deja el blip como está.
function PXDBlips.match(bySprite, sprite, coords, shortRange)
    local list = bySprite[sprite]
    if not list then return nil end
    local best, bestD, generic
    for _, r in ipairs(list) do
        if shortRange or r.longRange then
            if r.near then
                if coords then
                    local d = dist2(coords, r.near)
                    if d <= r.near.r * r.near.r and (not bestD or d < bestD) then best, bestD = r, d end
                end
            elseif not generic then
                generic = r
            end
        end
    end
    local r = best or generic
    if r and r.skip then return nil end
    return r
end

--- Comprueba la configuración: avisa de reglas mal escritas (para la consola).
function PXDBlips.validate(rules)
    local problems = {}
    for i, r in ipairs(rules) do
        if type(r.sprite) ~= 'number' then problems[#problems + 1] = ('regla %d: falta sprite'):format(i) end
        if not r.skip and (type(r.name) ~= 'string' or r.name == '') then problems[#problems + 1] = ('regla %d: falta nombre'):format(i) end
        if r.near and not (type(r.near.x) == 'number' and type(r.near.y) == 'number' and type(r.near.r) == 'number') then
            problems[#problems + 1] = ('regla %d: near necesita x, y y r'):format(i)
        end
    end
    return problems
end

return PXDBlips
