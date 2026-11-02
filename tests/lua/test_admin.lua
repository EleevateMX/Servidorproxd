-- Pruebas de pxd_admin: lógica pura y servidor con el simulador de FXServer.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_admin/'

PXDAdmin = nil
dofile(DIR .. 'shared/admin.lua')
local A = PXDAdmin

local CATS = {
    { id = 'dm', kind = 'player', label = 'DM' },
    { id = 'duda', kind = 'help', label = 'Duda' },
}

T.describe('pxd_admin (lógica)', function()
    T.it('busca jugadores por ID, nombre, personaje, PROX-ID o trabajo', function()
        local list = {
            { id = 7, name = 'Zeta', charName = 'Bruno Salgado', proxId = 'PROX-7KQ2', job = 'Mecánico' },
            { id = 3, name = 'Edy', charName = 'Valeria Ríos', proxId = 'PROX-3MHA', job = 'EMS' },
        }
        T.eq(#A.filterPlayers(list, ''), 2)
        T.eq(A.filterPlayers(list, '')[1].id, 3, 'ordenados por ID')
        T.eq(A.filterPlayers(list, '7')[1].name, 'Zeta')
        T.eq(A.filterPlayers(list, 'valeria')[1].id, 3)
        T.eq(A.filterPlayers(list, 'prox-7kq2')[1].id, 7)
        T.eq(#A.filterPlayers(list, 'mecán'), 1)
        T.eq(#A.filterPlayers(list, 'nadie'), 0)
    end)

    T.it('resuelve el destino de un reporte por ID o PROX-ID', function()
        local list = { { id = 4, proxId = 'PROX-AB12' } }
        T.eq(A.resolveTarget(list, ' 4 ').id, 4)
        T.eq(A.resolveTarget(list, 'prox-ab12').id, 4)
        T.falsy(A.resolveTarget(list, '9'))
        T.falsy(A.resolveTarget(list, ''))
    end)

    T.it('valida reportes: tipo, categoría del tipo, texto y destino', function()
        T.falsy(A.validateReport(nil, CATS))
        T.falsy(A.validateReport({ kind = 'x', category = 'dm', text = 'hola mundo' }, CATS))
        T.falsy(A.validateReport({ kind = 'help', category = 'dm', text = 'hola mundo' }, CATS), 'categoría de otro tipo')
        T.falsy(A.validateReport({ kind = 'help', category = 'duda', text = 'hey' }, CATS), 'texto corto')
        T.falsy(A.validateReport({ kind = 'player', category = 'dm', text = 'me mató sin rol' }, CATS), 'falta destino')
        local ok = A.validateReport({ kind = 'player', category = 'dm', text = '  me mató sin rol  ', target = '7' }, CATS)
        T.eq(ok.text, 'me mató sin rol'); T.eq(ok.categoryLabel, 'DM'); T.eq(ok.target, '7')
        local long = A.validateReport({ kind = 'help', category = 'duda', text = ('x'):rep(900) }, CATS)
        T.eq(#long.text, A.MAX_TEXT)
    end)

    T.it('ciclo de un reporte: reclamar, responder, cerrar y no reabrir', function()
        local r = A.newReport(1, { kind = 'help', category = 'duda', categoryLabel = 'Duda', text = 'hola mundo' }, { license = 'l1', name = 'Edy' }, 100)
        T.eq(r.state, 'open')
        T.truthy(A.reply(r, 'Isy', 'voy', 110, true))
        T.eq(r.state, 'claimed', 'responder como staff lo reclama')
        T.eq(r.staff, 'Isy')
        T.truthy(A.close(r, 'Isy', 'resuelto', 120))
        T.eq(r.state, 'closed'); T.eq(r.note, 'resuelto')
        T.falsy(A.reply(r, 'Edy', 'otra cosa', 130, false))
        T.falsy(A.claim(r, 'Otro', 140))
        T.falsy(A.close(r, 'Otro', '', 150))
    end)

    T.it('reportes por jugador, abiertos y recorte', function()
        local list = {}
        for i = 1, 6 do
            local r = A.newReport(i, { kind = 'help', category = 'duda', text = 'xxxxx' }, { license = i % 2 == 0 and 'a' or 'b' }, i)
            if i <= 2 then r.state = 'closed' end
            list[#list + 1] = r
        end
        T.eq(A.reportsOf(list, 'a', 2)[1].id, 6)
        T.eq(#A.reportsOf(list, 'a', 2), 2)
        T.eq(A.openCount(list, 'b'), 2)
        A.prune(list, 4)
        T.eq(#list, 4); T.eq(list[1].id, 3, 'se borran primero los cerrados')
    end)

    T.it('límite de frecuencia con ventana deslizante', function()
        local l = A.newLimiter(2, 60)
        T.truthy(A.allow(l, 'x', 0)); T.truthy(A.allow(l, 'x', 10))
        local ok, wait = A.allow(l, 'x', 20)
        T.falsy(ok); T.eq(wait, 40)
        T.truthy(A.allow(l, 'x', 61), 'pasada la ventana vuelve a dejar')
        T.truthy(A.allow(l, 'y', 20), 'cada clave por separado')
    end)

    T.it('permisos: pxd.admin para casi todo, expulsar pide su ACE', function()
        local function aces(set) return function(a) return set[a] == true end end
        T.falsy(A.can('goto', aces({})))
        T.truthy(A.can('goto', aces({ ['pxd.admin'] = true })))
        T.falsy(A.can('kick', aces({ ['pxd.admin'] = true })))
        T.truthy(A.can('kick', aces({ ['pxd.admin'] = true, ['pxd.admin.kick'] = true })))
        T.truthy(A.can('kick', aces({ ['pxd.admin'] = true, ['pxd.admin.all'] = true })))
        T.falsy(A.can('kick', aces({ ['pxd.admin.kick'] = true })), 'sin pxd.admin no hay nada')
        T.falsy(A.can('borrarlotodo', aces({ ['pxd.admin'] = true })))
    end)

    T.it('servicio: casi todo lo pide; duty, mensaje y expulsar no', function()
        T.truthy(A.needsDuty('revive')); T.truthy(A.needsDuty('noclip'))
        T.falsy(A.needsDuty('duty')); T.falsy(A.needsDuty('message')); T.falsy(A.needsDuty('kick'))
    end)

    T.it('comandos: argumento de jugador, uno mismo y modelos', function()
        T.eq(A.commandTarget('revive', nil, 5), 5, 'opcional: sin id, a uno mismo')
        T.eq(A.commandTarget('revive', '12', 5), 12)
        T.falsy(A.commandTarget('goto', nil, 5), 'obligatorio')
        T.eq(A.commandTarget('noclip', '12', 5), 5, 'solo uno mismo')
        T.eq(A.validModel('Sultan'), 'sultan')
        T.falsy(A.validModel('../x')); T.falsy(A.validModel(('a'):rep(40)))
        for _, c in ipairs(A.COMMANDS) do T.truthy(A.ACTIONS[c.action], 'acción de /' .. c.name) end
    end)

    T.it('heridas: lee los state bags de qbx_medical', function()
        local bag = { ['qbx_medical:injuries:LLEG'] = 3, ['qbx_medical:injuries:HEAD'] = 1, ['qbx_medical:bleedLevel'] = 2, ['qbx_medical:deathState'] = 2 }
        local w = A.woundsReport(function(k) return bag[k] end)
        T.eq(#w.parts, 2); T.eq(w.parts[1].part, 'Cabeza'); T.eq(w.parts[1].label, 'Leve')
        T.eq(w.parts[2].label, 'Grave'); T.eq(w.bleed, 2); T.eq(w.state, 'Herido/a en el suelo')
        T.eq(#A.woundsReport(function() return nil end).parts, 0)
    end)
end)

-- ── Servidor ───────────────────────────────────────────────────────────────

local function boot(extra)
    Fx.reset({ resourceName = 'pxd_admin', resourceStates = (extra and extra.states) or {}, exports = (extra and extra.exports) or {} })
    -- Natives que usa pxd_admin y no trae el simulador común.
    Fx.dropped, Fx.frozen, Fx.deleted = {}, {}, {}
    _G.GetPlayerPing = function() return 42 end
    _G.DropPlayer = function(src, reason) Fx.dropped[#Fx.dropped + 1] = { src = src, reason = reason }; Fx.players[src] = nil end
    _G.SetEntityCoords = function(ent, x, y, z) local e = Fx.entities[ent]; e.x, e.y, e.z = x, y, z end
    _G.FreezeEntityPosition = function(ent, on) Fx.frozen[ent] = on end
    _G.NetworkGetEntityFromNetworkId = function(net) return net - 100000 end
    _G.DeleteEntity = function(ent) Fx.deleted[#Fx.deleted + 1] = ent; Fx.entities[ent] = nil end
    PXDAdmin, Config = nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/admin.lua', 'server/main.lua' })
    Fx.addPlayer(1, 'Isy', { x = 0, y = 0, z = 10 }, { ['pxd.admin'] = true }, { license = 'license:staff' })
    Fx.addPlayer(2, 'Edy', { x = 100, y = 50, z = 20 }, {}, { license = 'license:edy' })
    Fx.addPlayer(3, 'Zeta', { x = 300, y = 0, z = 30 }, {}, { license = 'license:zeta' })
end

local function lastToast(target)
    local s = Fx.lastTo(target, 'pxd_admin:client:notify')
    return s and s.args[1].text or ''
end

T.describe('pxd_admin (servidor)', function()
    T.it('un jugador reporta a otro: se guarda, avisa al staff y aparece en «Mis reportes»', function()
        boot()
        Fx.emit('pxd_admin:server:createReport', 2, { kind = 'player', category = 'dm', target = '3', text = 'me atropelló sin rol' })
        local reports = PXDAdmin.server.reports()
        T.eq(#reports, 1)
        T.eq(reports[1].target.id, 3)
        T.eq(reports[1].reporter.license, 'license:edy')
        T.truthy(Fx.lastTo(1, 'pxd_admin:client:staffAlert'), 'aviso al staff')
        T.falsy(Fx.lastTo(3, 'pxd_admin:client:staffAlert'), 'no a quien no es staff')
        local sup = Fx.lastTo(2, 'pxd_admin:client:support').args[1]
        T.eq(#sup.reports, 1)
        T.falsy(sup.reports[1].reporter, 'el jugador no recibe datos internos')
        T.truthy(Fx.files['data/reports.json']:find('me atropelló', 1, true), 'guardado en disco')
    end)

    T.it('rechaza reportes a desconocidos, a uno mismo y por exceso', function()
        boot()
        Fx.emit('pxd_admin:server:createReport', 2, { kind = 'player', category = 'dm', target = '99', text = 'me atropelló sin rol' })
        T.truthy(lastToast(2):find('No encontramos'))
        Fx.emit('pxd_admin:server:createReport', 2, { kind = 'player', category = 'dm', target = '2', text = 'me atropelló sin rol' })
        T.truthy(lastToast(2):find('ti mismo'))
        for _ = 1, 3 do Fx.emit('pxd_admin:server:createReport', 2, { kind = 'help', category = 'duda', text = 'tengo una duda' }) end
        Fx.emit('pxd_admin:server:createReport', 2, { kind = 'help', category = 'duda', text = 'tengo una duda' })
        T.eq(#PXDAdmin.server.reports(), 3)
        T.truthy(lastToast(2):find('abiertos'))
    end)

    T.it('el panel de staff solo se abre con ACE y no muestra licencias a jugadores', function()
        boot()
        Fx.emit('pxd_admin:server:openStaff', 2)
        T.falsy(Fx.lastTo(2, 'pxd_admin:client:staff'))
        Fx.emit('pxd_admin:server:openStaff', 1)
        local data = Fx.lastTo(1, 'pxd_admin:client:staff').args[1]
        T.eq(#data.players, 3)
        T.eq(data.players[2].license, 'license:edy')
        T.eq(data.players[2].ping, 42)
        T.falsy(data.onDuty)
    end)

    T.it('acciones: sin servicio no; con servicio sí, y quedan en el registro', function()
        boot()
        Fx.emit('pxd_admin:server:action', 2, 'goto', 3)
        T.eq(Fx.entities[Fx.players[2].ped].x, 100, 'un jugador normal no puede')
        Fx.emit('pxd_admin:server:action', 1, 'goto', 3)
        T.truthy(lastToast(1):find('/duty'), 'pide servicio')
        T.eq(Fx.entities[Fx.players[1].ped].x, 0)
        Fx.emit('pxd_admin:server:action', 1, 'duty', 1)
        T.eq(Fx.playerStates[1].pxd_staff, true, 'etiqueta STAFF por state bag')
        T.eq(Fx.lastTo(1, 'pxd_admin:client:duty').args[1], true)
        Fx.emit('pxd_admin:server:action', 1, 'goto', 3)
        T.eq(Fx.entities[Fx.players[1].ped].x, 301)
        Fx.emit('pxd_admin:server:action', 1, 'back', 1)
        T.eq(Fx.entities[Fx.players[1].ped].x, 0, 'vuelve a la posición anterior')
        Fx.emit('pxd_admin:server:action', 1, 'freeze', 2)
        T.eq(Fx.frozen[Fx.players[2].ped], true)
        local log = PXDAdmin.server.log()
        T.eq(log[#log].action, 'freeze')
        T.eq(log[#log].staff, 'Isy')
    end)

    T.it('expulsar pide su ACE y motivo; el mensaje no pide servicio', function()
        boot()
        Fx.emit('pxd_admin:server:action', 1, 'kick', 3, { reason = 'DM' })
        T.eq(#Fx.dropped, 0)
        Fx.players[1].aces['pxd.admin.kick'] = true
        Fx.emit('pxd_admin:server:action', 1, 'kick', 3, { reason = 'x' })
        T.eq(#Fx.dropped, 0, 'motivo demasiado corto')
        Fx.emit('pxd_admin:server:action', 1, 'kick', 3, { reason = 'DM reiterado' })
        T.eq(Fx.dropped[1].src, 3)
        T.truthy(Fx.dropped[1].reason:find('DM reiterado'))
        Fx.emit('pxd_admin:server:action', 1, 'message', 2, { text = 'Hola, ¿todo bien?' })
        T.eq(lastToast(2), 'Hola, ¿todo bien?')
    end)

    T.it('reanimar y necesidades usan qbx_medical y qbx_core si están', function()
        local calls = {}
        boot({ states = { qbx_medical = 'started', qbx_core = 'started' }, exports = {
            qbx_medical = { Revive = function(t) calls[#calls + 1] = 'revive:' .. t end, Heal = function(t) calls[#calls + 1] = 'heal:' .. t end },
            qbx_core = { GetPlayer = function() return nil end, SetMetadata = function(t, k, v) calls[#calls + 1] = ('meta:%d:%s=%s'):format(t, k, v) end },
        } })
        Fx.emit('pxd_admin:server:action', 1, 'duty', 1)
        Fx.emit('pxd_admin:server:action', 1, 'revive', 2)
        Fx.emit('pxd_admin:server:action', 1, 'needs', 2)
        table.sort(calls)
        T.eq(table.concat(calls, ','), 'meta:2:hunger=100,meta:2:stress=0,meta:2:thirst=100,revive:2')
        T.truthy(Fx.lastTo(2, 'hud:client:UpdateNeeds'))
    end)

    T.it('comandos de chat: misma validación que el panel', function()
        boot()
        Fx.commands['duty'](3, {})
        T.falsy(Fx.playerStates[3] and Fx.playerStates[3].pxd_staff, 'sin ACE no hace nada')
        Fx.commands['duty'](1, {})
        Fx.commands['traer'](1, { '2' })
        T.eq(Fx.entities[Fx.players[2].ped].x, 1)
        Fx.commands['coche'](1, { 'Sultan' })
        local tool = Fx.lastTo(1, 'pxd_admin:client:tool')
        T.eq(tool.args[1], 'car'); T.eq(tool.args[2], 'sultan')
        Fx.commands['coche'](1, { '../x' })
        T.truthy(lastToast(1):find('Modelo'))
        Fx.commands['anuncio'](1, { 'Evento', 'a', 'las', '21h' })
        T.eq(Fx.lastTo(-1, 'pxd_admin:client:announce').args[1].text, 'Evento a las 21h')
        Fx.commands['ir'](1, {})
        T.truthy(lastToast(1):find('ID'))
        for _, taken in ipairs({ 'tp', 'tpm', 'noclip', 'dv' }) do
            T.falsy(Fx.commands[taken], '/' .. taken .. ' es de qbx_core/qbx_adminmenu')
        end
    end)

    T.it('traer: usa los buckets de Qbox y saca al jugador de su partida', function()
        local calls = { buckets = {}, left = {} }
        boot({ states = { qbx_core = 'started', pxd_gamemodes = 'started' }, exports = {
            qbx_core = { SetPlayerBucket = function(src, b) calls.buckets[#calls.buckets + 1] = src .. ':' .. b; Fx.players[src].bucket = b end },
            pxd_gamemodes = { LeavePlayer = function(src) calls.left[#calls.left + 1] = src
                if src == 2 then Fx.players[2].bucket = 0; return true end
                return false end },
        } })
        Fx.players[2].bucket = 60000                 -- Edy está en una partida
        Fx.commands['duty'](1, {})
        Fx.commands['traer'](1, { '2' })
        T.eq(calls.left[1], 2, 'primero lo saca de la partida')
        T.eq(Fx.players[2].bucket, 0)
        Fx.players[3].bucket = 7
        Fx.commands['ir'](1, { '3' })
        T.eq(calls.buckets[#calls.buckets], '1:7', 'cambia de bucket con SetPlayerBucket de Qbox')
    end)

    T.it('/anuncio: único dueño; consola y ACE pxd.chat.announce sin servicio; avisa a pxd_chat', function()
        boot()
        local seen = {}
        AddEventHandler('pxd_admin:server:announced', function(t) seen[#seen + 1] = t end)
        Fx.commands['anuncio'](3, { 'hola', 'todos' })
        T.eq(#seen, 0, 'sin permiso no anuncia')
        Fx.commands['anuncio'](1, { 'sin', 'servicio' })
        T.eq(#seen, 0, 'el staff necesita /duty')
        Fx.commands['anuncio'](0, { 'Reinicio', 'en', '5', 'min' })
        T.eq(seen[1], 'Reinicio en 5 min', 'la consola puede')
        Fx.addPlayer(4, 'Alcaldía', { x = 0, y = 0, z = 0 }, { ['pxd.chat.announce'] = true }, { license = 'license:gob' })
        Fx.commands['anuncio'](4, { 'Feria', 'mañana' })
        T.eq(seen[2], 'Feria mañana', 'ACE de compatibilidad, sin servicio')
        T.eq(Fx.lastTo(-1, 'pxd_admin:client:announce').args[1].text, 'Feria mañana')
    end)

    T.it('staff atiende un reporte: reclamar, responder y cerrar avisan al jugador', function()
        boot()
        Fx.emit('pxd_admin:server:createReport', 2, { kind = 'help', category = 'duda', text = 'estoy atascado aquí' })
        local id = PXDAdmin.server.reports()[1].id
        Fx.emit('pxd_admin:server:reportAction', 3, 'claim', id)
        T.eq(PXDAdmin.server.reports()[1].state, 'open', 'quien no es staff no puede')
        Fx.emit('pxd_admin:server:reportAction', 1, 'claim', id)
        T.eq(PXDAdmin.server.reports()[1].staff, 'Isy')
        T.truthy(lastToast(2):find('atendiendo'))
        Fx.emit('pxd_admin:server:reportAction', 1, 'reply', id, 'Voy para allá')
        T.eq(lastToast(2), 'Voy para allá')
        Fx.emit('pxd_admin:server:playerReply', 2, id, 'Gracias')
        T.eq(#PXDAdmin.server.reports()[1].messages, 2)
        Fx.emit('pxd_admin:server:reportAction', 1, 'close', id, 'Liberado')
        T.eq(PXDAdmin.server.reports()[1].state, 'closed')
        T.truthy(lastToast(2):find('cerrado'))
    end)

    T.it('/dv solo borra vehículos cercanos y estando de servicio', function()
        boot()
        local veh = CreateVehicle(1, 3, 0, 10, 0)
        Fx.emit('pxd_admin:server:deleteVehicle', 1, veh + 100000)
        T.eq(#Fx.deleted, 0, 'sin servicio')
        Fx.emit('pxd_admin:server:action', 1, 'duty', 1)
        local far = CreateVehicle(1, 500, 0, 10, 0)
        Fx.emit('pxd_admin:server:deleteVehicle', 1, far + 100000)
        T.eq(#Fx.deleted, 0, 'lejos')
        Fx.emit('pxd_admin:server:deleteVehicle', 1, veh + 100000)
        T.eq(Fx.deleted[1], veh)
    end)
end)
