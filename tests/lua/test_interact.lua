-- Pruebas de pxd_interact: lógica pura (ID, opciones, conocidos) y servidor con Qbox falso.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_interact/'

PXDInteract = nil
dofile(DIR .. 'shared/interact.lua')
local I = PXDInteract

-- Azar determinista: devuelve en orden los valores de la lista.
local function seq(values)
    local i = 0
    return function(n) i = i % #values + 1; return math.min(values[i], n) end
end

T.describe('pxd_interact (lógica)', function()
    T.it('ID: formato PROX- y 4 caracteres sin ambiguos (0, O, 1, I)', function()
        local id = I.generateId(seq({ 1, 2, 31, 32 }))
        T.eq(id, 'PROX-AB89')
        T.truthy(I.isValidId(id))
        for _, bad in ipairs({ 'PROX-AB0D', 'PROX-ABOD', 'PROX-AB1D', 'PROX-ABID', 'PROX-ABC', 'XXXX-ABCD', 42 }) do
            T.falsy(I.isValidId(bad), tostring(bad))
        end
        T.falsy(I.ALPHABET:find('[01OI]'), 'el alfabeto no tiene ambiguos')
    end)

    T.it('ID único: evita los ocupados y se rinde si no puede', function()
        local taken = { ['PROX-AAAA'] = true }
        T.eq(I.uniqueId(function(id) return taken[id] end, seq({ 1, 1, 1, 1, 2, 2, 2, 2 })), 'PROX-BBBB')
        T.eq(I.uniqueId(function() return true end, seq({ 1 }), nil, nil, 5), nil)
    end)

    T.it('opciones: prioridad, luego distancia, máximo y ocultas fuera', function()
        local list = I.flatten({
            { key = 'lejos', dist = 2.0, options = { { label = 'Hablar', icon = 'chat' } } },
            { key = 'cerca', dist = 0.5, options = { { label = 'Recoger' }, { label = 'Oculta', hidden = true } } },
            { key = 'inv', dist = 9, priority = 100, options = { { label = 'Aceptar' }, { label = 'Ignorar' } } },
            { key = 'vacio', dist = 0.1, options = {} },
        }, 4)
        local labels = {}
        for i, o in ipairs(list) do labels[i] = o.label end
        T.eq(table.concat(labels, ','), 'Aceptar,Ignorar,Recoger,Hablar')
        T.eq(list[3].icon, 'hand', 'icono por defecto')
        T.eq(#I.flatten({ { key = 'a', dist = 1, options = { { label = '1' }, { label = '2' }, { label = '3' } } } }, 2), 2)
    end)

    T.it('firma cambia solo si cambia la lista; índice circular', function()
        local a = I.flatten({ { key = 'z1', dist = 1, options = { { label = 'Recoger' } } } })
        local b = I.flatten({ { key = 'z1', dist = 0.4, options = { { label = 'Recoger' } } } })
        T.eq(I.signature(a), I.signature(b), 'moverse no reenvía la lista')
        T.eq(I.wrap(0, 3), 3); T.eq(I.wrap(4, 3), 1); T.eq(I.wrap(2, 3), 2)
    end)

    T.it('conocidos: límite olvidando al más antiguo; etiqueta', function()
        local k = {}
        k = I.addKnown(k, 'PROX-AAAA', 'Ana Ríos', 10, 2)
        k = I.addKnown(k, 'PROX-BBBB', 'Beto Paz', 20, 2)
        k = I.addKnown(k, 'PROX-CCCC', 'Caro Luz', 30, 2)
        T.falsy(k['PROX-AAAA'], 'olvida al más antiguo')
        T.eq(k['PROX-CCCC'].name, 'Caro Luz')
        T.eq(I.tagLabel(k, 'PROX-BBBB'), 'Beto Paz · PROX-BBBB')
        T.eq(I.tagLabel(k, 'PROX-ZZZZ'), 'Desconocido · PROX-ZZZZ')
        T.eq(I.charName({ firstname = ' Edy ', lastname = 'Aisjhd' }), 'Edy Aisjhd')
        T.eq(I.charName({}), nil)
    end)

    T.it('enfriamiento', function()
        local s = {}
        T.truthy(I.cooldown(s, 'a', 0, 10)); T.falsy(I.cooldown(s, 'a', 5, 10)); T.truthy(I.cooldown(s, 'a', 11, 10))
    end)
end)

-- ── Servidor ────────────────────────────────────────────────────────────────
local function copy(v) return v == nil and nil or Fx.json.decode(Fx.json.encode(v)) end
local q
local function boot(files)
    q = { meta = {}, players = {} }
    Fx.reset({ resourceName = 'pxd_interact', files = files or {},
        resourceStates = { pxd_interact = 'started', qbx_core = 'started' },
        exports = { qbx_core = {
            GetPlayer = function(src) return q.players[src] end,
            GetQBPlayers = function() return q.players end,
            GetMetadata = function(src, key) return copy((q.meta[src] or {})[key]) end,
            SetMetadata = function(src, key, val) q.meta[src] = q.meta[src] or {}; q.meta[src][key] = copy(val) end,
        } } })
    Config = nil; PXDInteract = nil
    Fx.load(DIR, { 'config.lua', 'shared/interact.lua', 'server/main.lua' })
    Fx.addPlayer(1, 'edy', { x = 0, y = 0, z = 0 })
    Fx.addPlayer(2, 'nova', { x = 1.5, y = 0, z = 0 })
    q.players[1] = { PlayerData = { source = 1, citizenid = 'CID1', charinfo = { firstname = 'Edy', lastname = 'Ríos' } } }
    q.players[2] = { PlayerData = { source = 2, citizenid = 'CID2', charinfo = { firstname = 'Nova', lastname = 'Luz' } } }
end
local function load(src) TriggerEvent('QBCore:Server:PlayerLoaded', q.players[src]) end

T.describe('pxd_interact (servidor)', function()
    T.it('al cargar: crea el ID, lo guarda y lo publica por state bag', function()
        boot()
        load(1)
        local id = q.meta[1].pxd_id
        T.truthy(PXDInteract.isValidId(id))
        T.eq(Fx.playerStates[1].pxdId, id)
        T.eq(Fx.json.decode(Fx.files['data/ids.json'])[id], 'CID1')
        T.truthy(Fx.lastTo(1, 'pxd_interact:known'), 'envía sus conocidos')
        load(1)
        T.eq(q.meta[1].pxd_id, id, 'es estable')
    end)

    T.it('si el ID guardado es de otro personaje, genera uno nuevo', function()
        boot({ ['data/ids.json'] = Fx.json.encode({ ['PROX-AAAA'] = 'OTRO' }) })
        q.meta[1] = { pxd_id = 'PROX-AAAA' }
        load(1)
        T.truthy(q.meta[1].pxd_id ~= 'PROX-AAAA' and PXDInteract.isValidId(q.meta[1].pxd_id))
    end)

    T.it('presentarse: invitación, aceptar y el otro aprende el nombre', function()
        boot()
        load(1); load(2)
        Fx.emit('pxd_interact:introduce', 1, 2)
        local inv = Fx.lastTo(2, 'pxd_interact:invite')
        T.truthy(inv, 'llega la invitación')
        T.eq(inv.args[2], q.meta[1].pxd_id)
        Fx.emit('pxd_interact:answer', 2, 1, true)
        local known = q.meta[2].pxd_known
        T.eq(known[q.meta[1].pxd_id].name, 'Edy Ríos')
        T.falsy(q.meta[1].pxd_known, 'quien se presenta no aprende nada')
        Fx.clearSent()
        Fx.emit('pxd_interact:answer', 2, 1, true)
        T.eq(#Fx.sentTo(2, 'pxd_interact:known'), 0, 'no se puede aceptar dos veces')
    end)

    T.it('el servidor valida distancia, enfriamiento, a uno mismo y caducidad', function()
        boot()
        load(1); load(2)
        Fx.movePlayer(2, { x = 20, y = 0, z = 0 })
        Fx.emit('pxd_interact:introduce', 1, 2)
        T.falsy(Fx.lastTo(2, 'pxd_interact:invite'), 'lejos: nada')
        Fx.movePlayer(2, { x = 1, y = 0, z = 0 })
        Fx.emit('pxd_interact:introduce', 1, 1)
        T.falsy(Fx.lastTo(1, 'pxd_interact:invite'), 'a uno mismo: nada')
        Fx.emit('pxd_interact:introduce', 1, 2)
        Fx.emit('pxd_interact:introduce', 1, 2)
        T.eq(#Fx.sentTo(2, 'pxd_interact:invite'), 1, 'enfriamiento')
        Fx.time = Fx.time + 60
        Fx.emit('pxd_interact:answer', 2, 1, true)
        T.falsy(q.meta[2].pxd_known, 'invitación caducada')
    end)

    T.it('rechazar avisa a quien se presentó', function()
        boot()
        load(1); load(2)
        Fx.emit('pxd_interact:introduce', 1, 2)
        Fx.emit('pxd_interact:answer', 2, 1, false)
        T.truthy(Fx.lastTo(1, 'pxd_interact:notify').args[1]:find('No ha aceptado'))
        T.falsy(q.meta[2].pxd_known)
    end)
end)
