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

-- ── Controles: E contextual y B recoger ─────────────────────────────────────
T.describe('pxd_interact (controles, lógica)', function()
    T.it('E cede a otros recursos: textUI, puerta, correr, Mayús, surtidor', function()
        T.falsy(I.shouldYield({}))
        T.falsy(I.shouldYield(nil))
        for _, k in ipairs({ 'textUI', 'door', 'sprinting', 'shift', 'pump' }) do
            T.truthy(I.shouldYield({ [k] = true }), k)
        end
    end)

    T.it('prioridades: invitación > trabajo > NPC > zona > maletero > jugador', function()
        local P = I.PRIORITY
        T.truthy(P.invite > P.job and P.job > P.npc and P.npc > P.zone and P.zone > P.trunk and P.trunk > P.player)
        local withZone = I.flatten({
            { key = 't', dist = 0.5, priority = P.trunk, options = { { label = 'Abrir maletero' } } },
            { key = 'z', dist = 3.0, priority = P.zone, options = { { label = 'Entregar el paquete' } } },
        }, 4)
        T.eq(withZone[1].label, 'Entregar el paquete', 'un punto de trabajo junto al coche gana al maletero')
        T.eq(withZone[2].label, 'Abrir maletero', 'el maletero sigue en la lista (rueda)')
        local list = I.flatten({
            { key = 'p', dist = 0.3, priority = P.player, options = { { label = 'Presentarse' } } },
            { key = 't', dist = 1.2, priority = P.trunk, options = { { label = 'Abrir maletero' } } },
        }, 4)
        T.eq(list[1].label, 'Abrir maletero', 'el maletero gana aunque el jugador esté más cerca')
    end)

    T.it('B: el más cercano; empate → el de enfrente; fuera de alcance → nada', function()
        local pos, fwd = { x = 0, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }
        local a = { id = 'drop-1', x = 0.0, y = -0.8, z = 0 }   -- detrás, 0,8 m
        local b = { id = 'drop-2', x = 0.0, y = 1.2, z = 0 }    -- delante, 1,2 m
        T.eq(I.pickDrop({ a, b }, pos, fwd, 1.6).id, 'drop-1', 'gana el más cercano')
        local c = { id = 'drop-3', x = 0.0, y = 0.85, z = 0 }   -- delante, 0,85 m (empate)
        T.eq(I.pickDrop({ a, c }, pos, fwd, 1.6).id, 'drop-3', 'empate: el de enfrente')
        T.eq(I.pickDrop({ c, a }, pos, fwd, 1.6).id, 'drop-3', 'sin depender del orden')
        T.eq(I.pickDrop({ { id = 'drop-4', x = 3, y = 0, z = 0 } }, pos, fwd, 1.6), nil)
        T.eq(I.pickDrop({}, pos, fwd), nil)
    end)

    T.it('bloqueo por drop con caducidad', function()
        local s = {}
        T.truthy(I.tryLock(s, 'drop-1', 0, 3))
        T.falsy(I.tryLock(s, 'drop-1', 1, 3), 'ocupado')
        T.truthy(I.tryLock(s, 'drop-2', 1, 3), 'otro drop sí')
        T.truthy(I.tryLock(s, 'drop-1', 4, 3), 'caduca')
        I.unlock(s, 'drop-1')
        T.truthy(I.tryLock(s, 'drop-1', 4.5, 3), 'liberado')
    end)

    T.it('validar recogida: id, hueco, estado, existencia, distancia, capacidad', function()
        local inv = { type = 'drop', coords = { x = 1, y = 0, z = 0 }, items = { [2] = { name = 'water', count = 1 } } }
        local base = { dropId = 'drop-123', slot = 2, inv = inv, playerPos = { x = 0, y = 0, z = 0 }, maxDist = 3, canCarry = true }
        local function with(t) local p = {} for k, v in pairs(base) do p[k] = v end for k, v in pairs(t) do p[k] = v end return p end
        local ok, item = I.validatePickup(base)
        T.truthy(ok); T.eq(item.name, 'water')
        T.eq(select(2, I.validatePickup(with({ dropId = 'player-1; rm' }))), 'invalid')
        T.eq(select(2, I.validatePickup(with({ dropId = 7 }))), 'invalid')
        T.eq(select(2, I.validatePickup(with({ slot = 1.5 }))), 'invalid')
        T.eq(select(2, I.validatePickup(with({ dead = true }))), 'state')
        T.eq(select(2, I.validatePickup(with({ inVehicle = true }))), 'state')
        T.eq(select(2, I.validatePickup(with({ slot = 3 }))), 'gone')
        T.eq(select(2, I.validatePickup(with({ inv = { type = 'player', coords = inv.coords, items = inv.items } }))), 'gone')
        T.eq(select(2, I.validatePickup(with({ playerPos = { x = 9, y = 0, z = 0 } }))), 'far')
        T.eq(select(2, I.validatePickup(with({ canCarry = false }))), 'full')
    end)

    T.it('primer hueco y texto del aviso', function()
        T.eq(I.firstSlot({ [5] = { name = 'a', count = 1 }, [2] = { name = 'b', count = 0 }, [3] = { name = 'c', count = 2 } }), 3)
        T.eq(I.firstSlot({}), nil)
        T.eq(I.pickupLabel('botella de agua', 1), 'Recoger botella de agua')
        T.eq(I.pickupLabel('botella de agua', 3), 'Recoger botella de agua ×3')
        T.eq(I.pickupLabel(nil), 'Recoger objeto')
    end)
end)

-- ── Servidor: B recoger con un ox_inventory falso ───────────────────────────
local ox
local function bootPickup(opts)
    opts = opts or {}
    ox = { invs = {}, removed = {}, capacity = opts.capacity or 10, failAdd = opts.failAdd }
    ox.invs['drop-100'] = { type = 'drop', items = {} }
    local function count(inv) local n = 0 for _, it in pairs(inv.items) do n = n + it.count end return n end
    Fx.reset({ resourceName = 'pxd_interact', resourceStates = { pxd_interact = 'started', ox_inventory = 'started' },
        exports = { ox_inventory = {
            GetInventory = function(id) return ox.invs[id] end,
            Items = function(name) return { label = name == 'water' and 'botella de agua' or name } end,
            CanCarryItem = function(src, _, n) return count(ox.invs[src]) + n <= ox.capacity end,
            RemoveItem = function(id, name, n, _, slot)
                local it = ox.invs[id] and ox.invs[id].items[slot]
                if not it or it.name ~= name or it.count < n then return false end
                it.count = it.count - n
                if it.count == 0 then ox.invs[id].items[slot] = nil end
                return true
            end,
            AddItem = function(id, name, n, meta, slot)
                if id ~= 'drop-100' and ox.failAdd then return false end
                local items = ox.invs[id].items
                local s = slot or (#items + 1)
                items[s] = { name = name, count = (items[s] and items[s].count or 0) + n, metadata = meta }
                return true
            end,
            RemoveInventory = function(id) ox.removed[#ox.removed + 1] = id; ox.invs[id] = nil end,
        } } })
    _G.GetVehiclePedIsIn = function() return 0 end
    ox.invs['drop-100'].coords = vector3(1, 0, 0)
    ox.invs['drop-100'].items[1] = { name = 'water', count = 2 }
    ox.invs[1] = { type = 'player', items = {} }
    ox.invs[2] = { type = 'player', items = {} }
    Config = nil; PXDInteract = nil
    Fx.load(DIR, { 'config.lua', 'shared/interact.lua', 'server/pickup.lua' })
    Fx.addPlayer(1, 'edy', { x = 0, y = 0, z = 0 })
    Fx.addPlayer(2, 'nova', { x = 1.5, y = 0, z = 0 })
end

T.describe('pxd_interact (servidor, recoger con B)', function()
    T.it('recoge el hueco entero y elimina el drop vacío', function()
        bootPickup()
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 1)
        T.eq(ox.invs[1].items[1].count, 2)
        T.eq(ox.removed[1], 'drop-100', 'drop vacío eliminado')
        T.truthy(Fx.lastTo(1, 'pxd_interact:pickupResult').args[1])
    end)

    T.it('inventario lleno: no toca el drop y avisa', function()
        bootPickup({ capacity = 1 })
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 1)
        T.eq(ox.invs['drop-100'].items[1].count, 2, 'sigue en el suelo')
        T.eq(Fx.lastTo(1, 'pxd_interact:pickupResult').args[2], 'No te cabe en el inventario.')
    end)

    T.it('si AddItem falla, el objeto vuelve al drop (sin pérdidas ni duplicados)', function()
        bootPickup({ failAdd = true })
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 1)
        T.eq(ox.invs['drop-100'].items[1].count, 2)
        T.eq(#ox.invs[1].items, 0)
        T.falsy(Fx.lastTo(1, 'pxd_interact:pickupResult').args[1])
    end)

    T.it('lejos, hueco vacío o drop inexistente: nada', function()
        bootPickup()
        Fx.movePlayer(1, { x = 10, y = 0, z = 0 })
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 1)
        T.eq(Fx.lastTo(1, 'pxd_interact:pickupResult').args[2], 'Estás demasiado lejos.')
        Fx.movePlayer(1, { x = 0, y = 0, z = 0 })
        Fx.advance(1)
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 7)
        Fx.advance(1)
        Fx.emit('pxd_interact:pickup', 1, 'drop-999', 1)
        Fx.advance(1)
        Fx.emit('pxd_interact:pickup', 1, 'player-2', 1)
        T.eq(ox.invs['drop-100'].items[1].count, 2)
        T.eq(#ox.invs[1].items, 0)
        T.eq(#ox.invs[2].items, 0, 'no se puede vaciar el inventario de otro jugador')
    end)

    T.it('dos jugadores a la vez: solo uno se lo lleva', function()
        bootPickup()
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 1)
        Fx.emit('pxd_interact:pickup', 2, 'drop-100', 1)
        local total = (ox.invs[1].items[1] and ox.invs[1].items[1].count or 0) + (ox.invs[2].items[1] and ox.invs[2].items[1].count or 0)
        T.eq(total, 2, 'no se duplica')
    end)

    T.it('bloqueo activo: el segundo recibe «Alguien lo está recogiendo»', function()
        bootPickup()
        -- Simula una recogida en curso dejando el drop bloqueado desde fuera del flujo normal.
        local orig = PXDInteract.tryLock
        PXDInteract.tryLock = function() return false end
        Fx.emit('pxd_interact:pickup', 2, 'drop-100', 1)
        PXDInteract.tryLock = orig
        T.eq(Fx.lastTo(2, 'pxd_interact:pickupResult').args[2], 'Alguien lo está recogiendo.')
    end)

    T.it('enfriamiento por jugador', function()
        bootPickup()
        ox.invs['drop-100'].items[2] = { name = 'bread', count = 1 }
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 1)
        Fx.emit('pxd_interact:pickup', 1, 'drop-100', 2)
        T.eq(ox.invs['drop-100'].items[2].count, 1, 'la segunda pulsación inmediata se ignora')
    end)

    T.it('peek: devuelve el primer hueco y «Recoger botella de agua ×2»', function()
        bootPickup()
        Fx.emit('pxd_interact:dropPeek', 1, 'drop-100')
        local r = Fx.lastTo(1, 'pxd_interact:dropPeek')
        T.eq(r.args[2], 1); T.eq(r.args[3], 'Recoger botella de agua ×2')
        Fx.advance(1)
        Fx.movePlayer(1, { x = 30, y = 0, z = 0 })
        Fx.clearSent()
        Fx.emit('pxd_interact:dropPeek', 1, 'drop-100')
        T.eq(#Fx.sentTo(1, 'pxd_interact:dropPeek'), 0, 'lejos: no revela nada')
    end)
end)
