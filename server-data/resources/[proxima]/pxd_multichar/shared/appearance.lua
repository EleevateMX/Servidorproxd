-- Lógica pura de la apariencia (sin natives): formato de illenium-appearance 5.7.0,
-- límites, saneado y secciones del editor (aleatorio, deshacer y restablecer viven en la NUI). La usan el cliente,
-- el servidor y las pruebas. El formato es EXACTAMENTE el que guarda illenium en
-- playerskins.skin (game/util.lua → getPedAppearance), para que illenium lo cargue tal cual.
PXDLook = {}
local L = PXDLook

L.MODELS = { [0] = 'mp_m_freemode_01', [1] = 'mp_f_freemode_01' }
L.FREEMODE = { mp_m_freemode_01 = 0, mp_f_freemode_01 = 1 }

-- Mismo orden que illenium (constants.FACE_FEATURES): el índice es el de SET_PED_FACE_FEATURE.
L.FACE_FEATURES = {
    { key = 'noseWidth',        label = 'Anchura',              region = 'nose' },     -- 0
    { key = 'nosePeakHigh',     label = 'Altura de la punta',   region = 'nose' },     -- 1
    { key = 'nosePeakSize',     label = 'Largo de la punta',    region = 'nose' },     -- 2
    { key = 'noseBoneHigh',     label = 'Altura del tabique',   region = 'nose' },     -- 3
    { key = 'nosePeakLowering', label = 'Caída de la punta',    region = 'nose' },     -- 4
    { key = 'noseBoneTwist',    label = 'Desviación del tabique', region = 'nose' },   -- 5
    { key = 'eyeBrownHigh',     label = 'Altura',               region = 'brows' },    -- 6
    { key = 'eyeBrownForward',  label = 'Profundidad',          region = 'brows' },    -- 7
    { key = 'cheeksBoneHigh',   label = 'Altura',               region = 'cheekbones' }, -- 8
    { key = 'cheeksBoneWidth',  label = 'Anchura',              region = 'cheekbones' }, -- 9
    { key = 'cheeksWidth',      label = 'Volumen',              region = 'cheeks' },   -- 10
    { key = 'eyesOpening',      label = 'Apertura',             region = 'eyes' },     -- 11
    { key = 'lipsThickness',    label = 'Grosor',               region = 'lips' },     -- 12
    { key = 'jawBoneWidth',     label = 'Anchura',              region = 'jaw' },      -- 13
    { key = 'jawBoneBackSize',  label = 'Forma',                region = 'jaw' },      -- 14
    { key = 'chinBoneLowering', label = 'Altura',               region = 'chin' },     -- 15
    { key = 'chinBoneLenght',   label = 'Largo',                region = 'chin' },     -- 16 (así lo escribe illenium)
    { key = 'chinBoneSize',     label = 'Anchura',              region = 'chin' },     -- 17
    { key = 'chinHole',         label = 'Hoyuelo',              region = 'chin' },     -- 18
    { key = 'neckThickness',    label = 'Grosor',               region = 'neck' },     -- 19
}
L.REGIONS = {
    { id = 'nose', label = 'Nariz' }, { id = 'brows', label = 'Cejas' }, { id = 'cheekbones', label = 'Pómulos' },
    { id = 'cheeks', label = 'Mejillas' }, { id = 'eyes', label = 'Ojos' }, { id = 'lips', label = 'Labios' },
    { id = 'jaw', label = 'Mandíbula' }, { id = 'chin', label = 'Mentón' }, { id = 'neck', label = 'Cuello' },
}

-- Mismo orden que illenium (constants.HEAD_OVERLAYS): índice de SET_PED_HEAD_OVERLAY.
-- colorType: 0 sin color, 1 paleta de pelo, 2 paleta de maquillaje (como illenium: makeUp, blush y lipstick = 2).
L.OVERLAYS = {
    { key = 'blemishes',       label = 'Acné e imperfecciones', colorType = 0, section = 'skin' }, -- 0
    { key = 'beard',           label = 'Barba',                 colorType = 1, section = 'hair' }, -- 1
    { key = 'eyebrows',        label = 'Cejas',                 colorType = 1, section = 'hair' }, -- 2
    { key = 'ageing',          label = 'Arrugas',               colorType = 0, section = 'skin' }, -- 3
    { key = 'makeUp',          label = 'Maquillaje',            colorType = 2, section = 'skin' }, -- 4
    { key = 'blush',           label = 'Colorete',              colorType = 2, section = 'skin' }, -- 5
    { key = 'complexion',      label = 'Tez',                   colorType = 0, section = 'skin' }, -- 6
    { key = 'sunDamage',       label = 'Daño solar',            colorType = 0, section = 'skin' }, -- 7
    { key = 'lipstick',        label = 'Pintalabios',           colorType = 2, section = 'skin' }, -- 8
    { key = 'moleAndFreckles', label = 'Lunares y pecas',       colorType = 0, section = 'skin' }, -- 9
    { key = 'chestHair',       label = 'Vello corporal',        colorType = 1, section = 'hair' }, -- 10
    { key = 'bodyBlemishes',   label = 'Manchas corporales',    colorType = 0, section = 'skin' }, -- 11
}

-- Componentes y props que se editan en «Vestuario» (ids de GTA).
L.CLOTHES = {
    { kind = 'component', id = 11, label = 'Prenda superior' },
    { kind = 'component', id = 8,  label = 'Camiseta interior' },
    { kind = 'component', id = 3,  label = 'Brazos' },
    { kind = 'component', id = 4,  label = 'Pantalón' },
    { kind = 'component', id = 6,  label = 'Calzado' },
    { kind = 'component', id = 7,  label = 'Cuello y cadenas' },
    { kind = 'component', id = 5,  label = 'Bolsa' },
    { kind = 'prop', id = 0, label = 'Sombrero' },
    { kind = 'prop', id = 1, label = 'Gafas' },
    { kind = 'prop', id = 2, label = 'Pendientes' },
    { kind = 'prop', id = 6, label = 'Reloj' },
    { kind = 'prop', id = 7, label = 'Pulsera' },
}
L.COMPONENT_IDS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }   -- illenium PED_COMPONENTS_IDS
L.PROP_IDS = { 0, 1, 2, 6, 7 }                               -- illenium PED_PROPS_IDS
L.EYE_COLORS = 32                                            -- illenium constants.EYE_COLORS (0..31)
L.PARENTS = 46                                               -- ids de cabeza 0..45 de SET_PED_HEAD_BLEND_DATA

-- Secciones del editor y qué partes del formato toca cada una.
L.SECTIONS = { 'identity', 'heritage', 'face', 'skin', 'hair', 'clothes' }
L.SECTION_PARTS = {
    identity = { 'model' },
    heritage = { 'headBlend' },
    face = { 'faceFeatures' },
    skin = { 'eyeColor', 'overlays:skin' },
    hair = { 'hair', 'overlays:hair' },
    clothes = { 'components', 'props' },
}

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function int(v, d) v = tonumber(v); if not v or v ~= v then return d end return math.floor(v + 0.5) end
local function num(v, d) v = tonumber(v); if not v or v ~= v or v == math.huge or v == -math.huge then return d end return v end
local function round1(v) return math.floor(v * 10 + 0.5) / 10 end
local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

--- Límites por defecto (los reales los cuenta el cliente con natives; ver client/editor.lua).
function L.defaultLimits()
    local lim = { overlays = {}, components = {}, props = {}, hairColors = 64, makeupColors = 64 }
    for i = 0, #L.OVERLAYS - 1 do lim.overlays[i] = 30 end
    for _, id in ipairs(L.COMPONENT_IDS) do lim.components[id] = { drawables = 512, textures = 64 } end
    for _, id in ipairs(L.PROP_IDS) do lim.props[id] = { drawables = 256, textures = 64 } end
    return lim
end

--- Apariencia inicial válida de un freemode (los mismos valores que qbx_core para crear).
function L.default(gender)
    gender = gender == 1 and 1 or 0
    local look = {
        model = L.MODELS[gender],
        headBlend = gender == 1
            and { shapeFirst = 45, shapeSecond = 21, shapeThird = 0, skinFirst = 20, skinSecond = 15, skinThird = 0, shapeMix = 0.3, skinMix = 0.1, thirdMix = 0 }
            or { shapeFirst = 0, shapeSecond = 0, shapeThird = 0, skinFirst = 0, skinSecond = 0, skinThird = 0, shapeMix = 0, skinMix = 0, thirdMix = 0 },
        faceFeatures = {},
        headOverlays = {},
        components = {},
        props = {},
        hair = { style = gender == 1 and 15 or 0, color = 0, highlight = 0, texture = 0 },
        eyeColor = 0,
        tattoos = {},
    }
    for _, f in ipairs(L.FACE_FEATURES) do look.faceFeatures[f.key] = 0 end
    for _, o in ipairs(L.OVERLAYS) do look.headOverlays[o.key] = { style = 0, opacity = 0, color = 0, secondColor = 0 } end
    look.headOverlays.eyebrows = { style = 0, opacity = 1, color = 0, secondColor = 0 }
    -- Ropa por defecto de qbx_core al crear (client/character.lua → defaultPeds).
    local outfit = L.STARTER_OUTFITS[gender][1]
    local byId = {}
    for _, c in ipairs(outfit.components) do byId[c.component_id] = c end
    for _, id in ipairs(L.COMPONENT_IDS) do
        local c = byId[id] or { drawable = 0, texture = 0 }
        look.components[#look.components + 1] = { component_id = id, drawable = c.drawable, texture = c.texture }
    end
    for _, id in ipairs(L.PROP_IDS) do look.props[#look.props + 1] = { prop_id = id, drawable = -1, texture = -1 } end
    return look
end

-- Conjuntos iniciales con valores verificados: los de qbx_core (defaultPeds). Ampliable en
-- Config.starterOutfits con valores comprobados en el juego.
L.STARTER_OUTFITS = {
    [0] = { { id = 'basic', label = 'Básico', components = {
        { component_id = 3, drawable = 15, texture = 0 }, { component_id = 4, drawable = 61, texture = 0 },
        { component_id = 6, drawable = 34, texture = 0 }, { component_id = 8, drawable = 15, texture = 0 },
        { component_id = 11, drawable = 15, texture = 0 } } } },
    [1] = { { id = 'basic', label = 'Básico', components = {
        { component_id = 3, drawable = 15, texture = 0 }, { component_id = 4, drawable = 15, texture = 3 },
        { component_id = 6, drawable = 35, texture = 0 }, { component_id = 8, drawable = 14, texture = 0 },
        { component_id = 11, drawable = 15, texture = 3 } } } },
}

local function compList(list, idField, ids)
    local by = {}
    for _, c in ipairs(type(list) == 'table' and list or {}) do
        if type(c) == 'table' and tonumber(c[idField]) then by[int(c[idField])] = c end
    end
    return by
end

--- Sanea una apariencia: estructura completa, tipos y rangos. Si `strictFreemode`, el modelo
--- debe ser freemode (personajes nuevos). Devuelve la apariencia saneada o nil, motivo.
function L.sanitize(look, limits, strictFreemode)
    if type(look) ~= 'table' then return nil, 'apariencia' end
    limits = limits or L.defaultLimits()
    local model = type(look.model) == 'string' and look.model or nil
    if not model or #model > 64 or not model:match('^[%w_]+$') then return nil, 'modelo' end
    local gender = L.FREEMODE[model]
    if strictFreemode and gender == nil then return nil, 'modelo' end
    local base = L.default(gender or 0)
    local out = { model = model, tattoos = type(look.tattoos) == 'table' and look.tattoos or {} }

    local hb = type(look.headBlend) == 'table' and look.headBlend or base.headBlend
    out.headBlend = {}
    for _, k in ipairs({ 'shapeFirst', 'shapeSecond', 'shapeThird', 'skinFirst', 'skinSecond', 'skinThird' }) do
        out.headBlend[k] = clamp(int(hb[k], base.headBlend[k]), 0, L.PARENTS - 1)
    end
    for _, k in ipairs({ 'shapeMix', 'skinMix', 'thirdMix' }) do
        out.headBlend[k] = round2(clamp(num(hb[k], base.headBlend[k]), 0, 1))
    end

    out.faceFeatures = {}
    local ff = type(look.faceFeatures) == 'table' and look.faceFeatures or {}
    for _, f in ipairs(L.FACE_FEATURES) do out.faceFeatures[f.key] = round1(clamp(num(ff[f.key], 0), -1, 1)) end

    out.headOverlays = {}
    local ho = type(look.headOverlays) == 'table' and look.headOverlays or {}
    for i, o in ipairs(L.OVERLAYS) do
        local v = type(ho[o.key]) == 'table' and ho[o.key] or base.headOverlays[o.key]
        local max = (limits.overlays[i - 1] or 1) - 1
        local colors = (o.colorType == 2 and limits.makeupColors or limits.hairColors) - 1
        out.headOverlays[o.key] = {
            style = clamp(int(v.style, 0), 0, math.max(0, max)),
            opacity = round1(clamp(num(v.opacity, 0), 0, 1)),
            color = clamp(int(v.color, 0), 0, math.max(0, colors)),
            secondColor = clamp(int(v.secondColor, 0), 0, math.max(0, colors)),
        }
    end

    local h = type(look.hair) == 'table' and look.hair or base.hair
    local hl = limits.components[2] or { drawables = 1, textures = 1 }
    out.hair = {
        style = clamp(int(h.style, 0), 0, math.max(0, hl.drawables - 1)),
        texture = clamp(int(h.texture, 0), 0, math.max(0, (hl.textures or 1) - 1)),
        color = clamp(int(h.color, 0), 0, math.max(0, limits.hairColors - 1)),
        highlight = clamp(int(h.highlight, 0), 0, math.max(0, limits.hairColors - 1)),
    }
    out.eyeColor = clamp(int(look.eyeColor, 0), 0, L.EYE_COLORS - 1)

    local comps = compList(look.components, 'component_id')
    local baseComps = compList(base.components, 'component_id')
    out.components = {}
    for _, id in ipairs(L.COMPONENT_IDS) do
        local c = comps[id] or baseComps[id]
        local cl = limits.components[id] or { drawables = 1, textures = 1 }
        local drawable = clamp(int(c.drawable, 0), 0, math.max(0, cl.drawables - 1))
        out.components[#out.components + 1] = { component_id = id, drawable = drawable,
            texture = clamp(int(c.texture, 0), 0, math.max(0, ((cl.texturesFor and cl.texturesFor[drawable]) or cl.textures or 1) - 1)) }
    end
    -- El pelo del componente 2 es el de `hair` (illenium lo aplica desde ahí).
    out.components[3].drawable, out.components[3].texture = out.hair.style, out.hair.texture

    local props = compList(look.props, 'prop_id')
    out.props = {}
    for _, id in ipairs(L.PROP_IDS) do
        local p = props[id] or { drawable = -1, texture = -1 }
        local pl = limits.props[id] or { drawables = 0, textures = 0 }
        local drawable = clamp(int(p.drawable, -1), -1, pl.drawables - 1)
        local texture = -1
        if drawable >= 0 then
            texture = clamp(int(p.texture, 0), 0, math.max(0, ((pl.texturesFor and pl.texturesFor[drawable]) or pl.textures or 1) - 1))
        end
        out.props[#out.props + 1] = { prop_id = id, drawable = drawable, texture = texture }
    end
    return out
end

--- Copia profunda (tablas planas de datos).
function L.copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = L.copy(v) end
    return o
end

--- Ids de cabeza de madres (gender 1) o padres (0) del creador de GTA Online.
function L.parentIds(gender)
    local ids = {}
    if gender == 1 then
        for i = 21, 41 do ids[#ids + 1] = i end
        ids[#ids + 1] = 45
    else
        for i = 0, 20 do ids[#ids + 1] = i end
        for i = 42, 44 do ids[#ids + 1] = i end
    end
    return ids
end

--- ¿Qué secciones puede tocar un editor restringido (peluquería, tienda, clínica)?
--- La identidad y el modelo nunca se editan fuera de la creación.
function L.restrict(newLook, oldLook, sections)
    local allowed = {}
    for _, s in ipairs(sections or {}) do allowed[s] = true end
    local out = L.copy(oldLook)
    if allowed.heritage then out.headBlend = L.copy(newLook.headBlend) end
    if allowed.face then out.faceFeatures = L.copy(newLook.faceFeatures) end
    if allowed.skin then out.eyeColor = newLook.eyeColor end
    if allowed.hair then out.hair = L.copy(newLook.hair) end
    for _, o in ipairs(L.OVERLAYS) do
        if allowed[o.section] then out.headOverlays[o.key] = L.copy(newLook.headOverlays[o.key]) end
    end
    if allowed.clothes then out.components = L.copy(newLook.components); out.props = L.copy(newLook.props) end
    -- El componente 2 (pelo) sigue a `hair`.
    for _, c in ipairs(out.components) do
        if c.component_id == 2 then c.drawable, c.texture = out.hair.style, out.hair.texture end
    end
    out.model = oldLook.model
    return out
end

return PXDLook
