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

    T.it('roles: cada uno tiene lo suyo y hereda del anterior', function()
        local function as(role)
            local set = A.rolePerms(role)
            return function(a) local p = a:match('^pxd%.admin%.(.+)$') return p ~= nil and set[p] == true end
        end
        T.truthy(A.can('goto', as('soporte'))); T.falsy(A.can('kick', as('soporte'))); T.falsy(A.can('noclip', as('soporte')))
        T.truthy(A.can('kick', as('moderador'))); T.truthy(A.can('goto', as('moderador')), 'hereda de soporte')
        T.falsy(A.can('ban', as('moderador')))
        T.truthy(A.can('ban', as('administrador'))); T.falsy(A.can('money', as('administrador'))); T.falsy(A.can('vehowner', as('administrador')))
        T.truthy(A.can('money', as('superadministrador'))); T.truthy(A.can('kick', as('superadministrador')))
        T.truthy(A.can('noclip', as('desarrollador'))); T.truthy(A.can('props', as('desarrollador')))
        T.falsy(A.can('kick', as('desarrollador'))); T.falsy(A.can('ban', as('desarrollador')))
        T.falsy(A.can('goto', function() return false end), 'sin permisos nada')
        T.falsy(A.can('borrarlotodo', function() return true end), 'acciones desconocidas no')
        T.truthy(A.can('ban', function(a) return a == 'pxd.admin.panel' or a == 'pxd.admin.all' end), 'pxd.admin.all (antiguo) lo permite todo')
        T.eq(A.roleLabel(as('administrador')), 'Administrador')
        T.eq(A.roleLabel(as('desarrollador')), 'Desarrollador')
        T.eq(A.roleLabel(as('superadministrador')), 'Superadministrador')
    end)

    T.it('las líneas de cfg reproducen la matriz y la herencia', function()
        local lines = table.concat(A.aceLines(), '\n')
        T.truthy(lines:find('add_principal group.mod group.support', 1, true))
        T.truthy(lines:find('add_principal group.superadmin group.admin', 1, true))
        T.truthy(lines:find('add_ace group.support pxd.admin.panel allow', 1, true))
        T.truthy(lines:find('add_ace group.superadmin pxd.admin.economy.correct allow', 1, true))
        T.falsy(lines:find(' pxd.admin allow', 1, true), 'nadie recibe pxd.admin a secas (los ACE son jerárquicos)')
        for _, a in pairs(A.ACTIONS) do T.truthy(A.PERMS[a.perm], 'permiso definido: ' .. a.perm) end
        for _, perm in pairs(A.QUERIES) do T.truthy(A.PERMS[perm], 'permiso de consulta: ' .. perm) end
    end)

    T.it('motivo, dinero, baneo y matrícula se validan', function()
        T.falsy(A.validReason(nil)); T.falsy(A.validReason('  a ')); T.eq(A.validReason('  DM\nreiterado '), 'DM reiterado')
        T.falsy(A.validMoney({ account = 'crypto', amount = 5 })); T.falsy(A.validMoney({ account = 'cash', amount = 0 }))
        T.falsy(A.validMoney({ account = 'bank', amount = 1.5 })); T.falsy(A.validMoney({ account = 'bank', amount = 2000000 }, 1000000))
        T.eq(A.validMoney({ account = 'bank', amount = '-500' }).amount, -500)
        T.eq(A.banExpire(0, 100), A.PERMANENT); T.eq(A.banExpire(24, 100), 100 + 86400)
        T.falsy(A.banExpire(-1, 100)); T.falsy(A.banExpire(1.5, 100)); T.falsy(A.banExpire(999999, 100, 87600))
        T.eq(A.validPlate(' pxd 042 '), 'PXD 042'); T.falsy(A.validPlate('ABCDEFGHI')); T.falsy(A.validPlate("x'--"))
        T.eq(A.validCitizenId('qx81pa2d'), 'QX81PA2D'); T.falsy(A.validCitizenId('a;b'))
    end)

    T.it('servicio: solo si el servidor lo exige, y nunca para moderar o consultar', function()
        T.falsy(A.needsDuty('revive', false))
        T.truthy(A.needsDuty('revive', true)); T.truthy(A.needsDuty('noclip', true))
        T.falsy(A.needsDuty('kick', true)); T.falsy(A.needsDuty('ban', true)); T.falsy(A.needsDuty('money', true))
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

-- Rol → ACE como en FXServer: jerárquicos (pxd.admin permite pxd.admin.kick).
local function roleAces(role)
    local out = {}
    for p in pairs(PXDAdmin.rolePerms(role)) do out['pxd.admin.' .. p] = true end
    return out
end

local audited, db
local function boot(extra)
    extra = extra or {}
    local states = extra.states or {}
    local exports = extra.exports or {}
    audited = {}
    if not extra.noAudit then
        states.pxd_audit = 'started'
        exports.pxd_audit = exports.pxd_audit or {
            Log = function(e) audited[#audited + 1] = e return #audited end,
            Query = function(f)
                local out = {}
                for i = #audited, 1, -1 do
                    local e = audited[i]
                    if (not f.action or e.action == f.action) and (not f.target or e.target == f.target) then
                        out[#out + 1] = { created_at = 1000 + i, action = e.action, actor = e.actor, target = e.target, data = e.data }
                    end
                end
                return out
            end,
        }
    end
    Fx.reset({ resourceName = 'pxd_admin', resourceStates = states, exports = exports })
    -- Natives que usa pxd_admin y no trae el simulador común.
    Fx.dropped, Fx.frozen, Fx.deleted = {}, {}, {}
    _G.GetPlayerPing = function() return 42 end
    _G.DropPlayer = function(src, reason) Fx.dropped[#Fx.dropped + 1] = { src = src, reason = reason }; Fx.players[src] = nil end
    _G.SetEntityCoords = function(ent, x, y, z) local e = Fx.entities[ent]; e.x, e.y, e.z = x, y, z end
    _G.FreezeEntityPosition = function(ent, on) Fx.frozen[ent] = on end
    _G.NetworkGetEntityFromNetworkId = function(net) return net - 100000 end
    _G.DeleteEntity = function(ent) Fx.deleted[#Fx.deleted + 1] = ent; Fx.entities[ent] = nil end
    _G.GetVehicleNumberPlateText = function() return 'PXD 042 ' end
    _G.GetEntityModel = function() return 123 end
    _G.IsPlayerAceAllowed = function(src, ace)
        local p = Fx.players[tonumber(src)]
        if not p then return false end
        local cur = ace
        while cur do
            if p.aces[cur] == true then return true end
            cur = cur:match('^(.*)%.[^%.]+$')
        end
        return false
    end
    db = { bans = {}, nextBan = 1 }
    if extra.mysql then
        states.oxmysql = 'started'
        MySQL = {
            insert = { await = function(q, p)
                if q:find('INSERT INTO bans', 1, true) then
                    local id = db.nextBan; db.nextBan = id + 1
                    db.bans[id] = { id = id, name = p[1], license = p[2], discord = p[3], ip = p[4], reason = p[5], expire = p[6], bannedby = p[7] }
                    return id
                end
                error('insert no simulado: ' .. q)
            end },
            update = { await = function(q, p)
                if q:find('UPDATE bans SET expire', 1, true) then
                    local b = db.bans[p[2]]
                    if not b or b.expire <= p[3] then return 0 end
                    b.expire = p[1]; return 1
                end
                error('update no simulado: ' .. q)
            end },
            query = { await = function(q, p)
                if q:find('FROM bans WHERE expire', 1, true) then
                    local out = {}
                    for _, b in pairs(db.bans) do if b.expire > p[1] then out[#out + 1] = b end end
                    return out
                end
                if q:find('FROM bans WHERE license', 1, true) then
                    local out = {}
                    for _, b in pairs(db.bans) do if b.license == p[1] then out[#out + 1] = b end end
                    return out
                end
                return {}
            end },
            scalar = { await = function(q, p)
                if q:find('FROM players WHERE citizenid', 1, true) then return (p[1] == 'QX81PA2D') and p[1] or nil end
                error('scalar no simulado: ' .. q)
            end },
        }
    else
        MySQL = nil
    end
    PXDAdmin, Config = nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/admin.lua' })
    if extra.config then for k, v in pairs(extra.config) do Config[k] = v end end
    Fx.load(DIR, { 'server/main.lua' })
    Fx.addPlayer(1, 'Isy', { x = 0, y = 0, z = 10 }, extra.staffAces or roleAces('superadministrador'), { license = 'license:staff' })
    Fx.addPlayer(2, 'Edy', { x = 100, y = 50, z = 20 }, {}, { license = 'license:edy', discord = 'discord:9', ip = 'ip:1.2.3.4' })
    Fx.addPlayer(3, 'Zeta', { x = 300, y = 0, z = 30 }, {}, { license = 'license:zeta' })
end

local function lastToast(target)
    local s = Fx.lastTo(target, 'pxd_admin:client:notify')
    return s and s.args[1].text or ''
end

local function qbxFake(players)
    return {
        GetPlayer = function(src)
            local p = players[src]
            if not p then return nil end
            return {
                PlayerData = { citizenid = p.cid, charinfo = { firstname = p.first, lastname = 'Test' }, money = p.money, job = { label = 'Taxi' } },
                Functions = {
                    GetMoney = function(t) return p.money[t] end,
                    AddMoney = function(t, n, why) p.money[t] = p.money[t] + n; p.last = why; return true end,
                    RemoveMoney = function(t, n, why) if p.money[t] < n then return false end p.money[t] = p.money[t] - n; p.last = why; return true end,
                },
            }
        end,
        SetPlayerBucket = function(src, b) Fx.players[src].bucket = b end,
    }
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

    T.it('el panel solo se abre con permiso (F10 o /admin) y explica cómo conseguirlo', function()
        boot()
        Fx.emit('pxd_admin:server:openStaff', 2)
        T.falsy(Fx.lastTo(2, 'pxd_admin:client:staff'))
        T.truthy(lastToast(2):find('pxd.admin.panel', 1, true), 'dice qué permiso falta')
        Fx.commands['admin'](2, {})
        T.falsy(Fx.lastTo(2, 'pxd_admin:client:staff'))
        Fx.commands['admin'](1, {})
        local data = Fx.lastTo(1, 'pxd_admin:client:staff').args[1]
        T.eq(#data.players, 3)
        T.eq(data.players[2].license, 'license:edy')
        T.eq(data.players[2].ip, 'ip:1.2.3.4', 'superadministración ve la IP')
        T.eq(data.role, 'Superadministrador')
        T.truthy(data.perms['economy.correct'])
    end)

    T.it('soporte ve el panel pero sin identificadores ni acciones de moderación', function()
        boot({ staffAces = roleAces('soporte') })
        Fx.commands['admin'](1, {})
        local data = Fx.lastTo(1, 'pxd_admin:client:staff').args[1]
        T.eq(data.role, 'Soporte')
        T.falsy(data.players[2].license, 'sin players.identity no hay licencia')
        T.falsy(data.players[2].ip)
        T.falsy(data.perms['players.kick'])
        Fx.emit('pxd_admin:server:action', 1, 'kick', 3, { reason = 'DM reiterado' })
        T.eq(#Fx.dropped, 0, 'soporte no expulsa')
        Fx.emit('pxd_admin:server:action', 1, 'goto', 3)
        T.eq(Fx.entities[Fx.players[1].ped].x, 301, 'soporte sí puede ir')
    end)

    T.it('eventos manipulados sin permiso no hacen nada ni dejan rastro', function()
        boot({ mysql = true, states = { qbx_core = 'started' }, exports = { qbx_core = qbxFake({ [3] = { cid = 'Z', first = 'Zeta', money = { cash = 10, bank = 10 } } }) } })
        for _, a in ipairs({ 'money', 'ban', 'kick', 'warn', 'freeze', 'goto', 'bring', 'noclip', 'car', 'vehowner', 'announce' }) do
            Fx.emit('pxd_admin:server:action', 2, a, 3, { reason = 'porque sí', account = 'bank', amount = 999999, hours = 0, model = 'adder', text = 'hola hola' })
        end
        Fx.emit('pxd_admin:server:query', 2, 'economy', {})
        Fx.emit('pxd_admin:server:query', 2, 'bans', {})
        Fx.emit('pxd_admin:server:deleteVehicle', 2, 5001 + 100000)
        T.eq(#Fx.dropped, 0); T.eq(next(db.bans), nil); T.eq(#audited, 0)
        T.eq(#PXDAdmin.server.log(), 0)
        T.falsy(Fx.lastTo(2, 'pxd_admin:client:tool')); T.falsy(Fx.lastTo(2, 'pxd_admin:client:result'))
        T.falsy(Fx.lastTo(-1, 'pxd_admin:client:announce'))
    end)

    T.it('motivo obligatorio en las acciones sensibles; la auditoría guarda responsable, objetivo y motivo', function()
        boot()
        Fx.emit('pxd_admin:server:action', 1, 'kick', 3, {})
        T.eq(#Fx.dropped, 0); T.truthy(lastToast(1):find('motivo'))
        Fx.emit('pxd_admin:server:action', 1, 'kick', 3, { reason = 'x' })
        T.eq(#Fx.dropped, 0, 'motivo demasiado corto')
        Fx.emit('pxd_admin:server:action', 1, 'kick', 3, { reason = 'DM reiterado' })
        T.eq(Fx.dropped[1].src, 3); T.truthy(Fx.dropped[1].reason:find('DM reiterado'))
        local e = audited[#audited]
        T.eq(e.category, 'admin'); T.eq(e.action, 'kick')
        T.eq(e.actor, 'license:staff'); T.eq(e.target, 'license:zeta')
        T.eq(e.data.reason, 'DM reiterado'); T.eq(e.data.staff, 'Isy')
        local log = PXDAdmin.server.log()
        T.eq(log[#log].reason, 'DM reiterado')
        Fx.emit('pxd_admin:server:action', 1, 'spectate', 2, {})
        T.falsy(Fx.lastTo(1, 'pxd_admin:client:spectate'), 'espectar también pide motivo')
    end)

    T.it('advertencias: se muestran al jugador y salen en su historial', function()
        boot()
        Fx.emit('pxd_admin:server:action', 1, 'warn', 2, { reason = 'VDM en la plaza' })
        T.eq(Fx.lastTo(2, 'pxd_admin:client:warning').args[1].reason, 'VDM en la plaza')
        Fx.emit('pxd_admin:server:query', 1, 'history', { target = 2 })
        local h = Fx.lastTo(1, 'pxd_admin:client:result')
        T.eq(h.args[1], 'history')
        T.eq(#h.args[2].warnings, 1); T.eq(h.args[2].warnings[1].reason, 'VDM en la plaza')
    end)

    T.it('baneo en la tabla bans de qbx_core y levantarlo sin borrar la fila', function()
        boot({ mysql = true })
        Fx.emit('pxd_admin:server:action', 1, 'ban', 2, { reason = 'Menú de trucos', hours = 0 })
        T.eq(db.bans[1].license, 'license:edy'); T.eq(db.bans[1].expire, PXDAdmin.PERMANENT)
        T.eq(db.bans[1].bannedby, 'Isy'); T.eq(db.bans[1].discord, 'discord:9')
        T.eq(Fx.dropped[1].src, 2); T.truthy(Fx.dropped[1].reason:find('permanente'))
        Fx.emit('pxd_admin:server:query', 1, 'bans', {})
        T.eq(#Fx.lastTo(1, 'pxd_admin:client:result').args[2].rows, 1)
        Fx.emit('pxd_admin:server:action', 1, 'unban', 0, { banId = 1 })
        T.eq(db.bans[1].expire, PXDAdmin.PERMANENT, 'sin motivo no se levanta')
        Fx.emit('pxd_admin:server:action', 1, 'unban', 0, { banId = 1, reason = 'Apelación aceptada' })
        T.truthy(db.bans[1].expire < os.time(), 'fin adelantado, la fila sigue')
        T.eq(audited[#audited].action, 'unban'); T.eq(audited[#audited].target, 'ban:1')
        Fx.emit('pxd_admin:server:action', 1, 'ban', 3, { reason = 'DM', hours = 1.5 })
        T.eq(db.nextBan, 2, 'duración no válida: no banea')
    end)

    T.it('corrección de dinero: motivo, nunca en negativo y queda auditada', function()
        local players = { [2] = { cid = 'QX81PA2D', first = 'Edy', money = { cash = 100, bank = 500 } } }
        boot({ states = { qbx_core = 'started' }, exports = { qbx_core = qbxFake(players) } })
        Fx.emit('pxd_admin:server:action', 1, 'money', 2, { account = 'bank', amount = -900, reason = 'Error del concesionario' })
        T.eq(players[2].money.bank, 500); T.truthy(lastToast(1):find('negativo'))
        Fx.emit('pxd_admin:server:action', 1, 'money', 2, { account = 'bank', amount = 2500, reason = 'Reembolso por fallo' })
        T.eq(players[2].money.bank, 3000); T.eq(players[2].last, 'pxd-admin: Reembolso por fallo')
        T.eq(audited[#audited].action, 'money'); T.eq(audited[#audited].data.detail, 'bank +2500 (500 → 3000)')
        boot({ staffAces = roleAces('administrador'), states = { qbx_core = 'started' }, exports = { qbx_core = qbxFake(players) } })
        Fx.emit('pxd_admin:server:action', 1, 'money', 2, { account = 'cash', amount = 50, reason = 'Prueba' })
        T.eq(players[2].money.cash, 100, 'administración no corrige dinero')
    end)

    T.it('noclip: permiso del servidor, ajustes al cliente y registro de activar y desactivar', function()
        boot({ staffAces = roleAces('soporte') })
        Fx.commands['noclip'](1, {})
        T.falsy(Fx.lastTo(1, 'pxd_admin:client:tool'), 'soporte no tiene noclip')
        boot({ staffAces = roleAces('desarrollador') })
        Fx.commands['noclip'](1, {})
        local t = Fx.lastTo(1, 'pxd_admin:client:tool')
        T.eq(t.args[1], 'noclip'); T.eq(t.args[2].on, true); T.eq(t.args[2].invisible, true)
        T.eq(#t.args[2].speeds, 6)
        T.truthy(PXDAdmin.server.noclip[1])
        T.eq(audited[#audited].action, 'noclip'); T.eq(audited[#audited].data.detail, 'activado')
        Fx.emit('pxd_admin:server:noclipOff', 1)
        T.falsy(PXDAdmin.server.noclip[1]); T.eq(audited[#audited].data.detail, 'desactivado (cliente)')
        local n = #audited
        Fx.emit('pxd_admin:server:noclipOff', 2)
        T.eq(#audited, n, 'quien no lo tenía activado no genera registros')
    end)

    T.it('servicio opcional: con requireDuty las herramientas lo piden; moderar no', function()
        boot({ config = { requireDuty = true } })
        Fx.emit('pxd_admin:server:action', 1, 'goto', 3)
        T.truthy(lastToast(1):find('/duty'))
        T.eq(Fx.entities[Fx.players[1].ped].x, 0)
        Fx.emit('pxd_admin:server:action', 1, 'duty', 1)
        T.eq(Fx.playerStates[1].pxd_staff, true, 'etiqueta STAFF por state bag')
        Fx.emit('pxd_admin:server:action', 1, 'goto', 3)
        T.eq(Fx.entities[Fx.players[1].ped].x, 301)
        Fx.emit('pxd_admin:server:action', 1, 'back', 1)
        T.eq(Fx.entities[Fx.players[1].ped].x, 0, 'vuelve a la posición anterior')
        Fx.emit('pxd_admin:server:action', 1, 'freeze', 2)
        T.eq(Fx.frozen[Fx.players[2].ped], true); T.eq(Fx.playerStates[2].pxd_frozen, true)
    end)

    T.it('reanimar y necesidades usan qbx_medical y qbx_core si están', function()
        local calls = {}
        boot({ states = { qbx_medical = 'started', qbx_core = 'started' }, exports = {
            qbx_medical = { Revive = function(t) calls[#calls + 1] = 'revive:' .. t end, Heal = function(t) calls[#calls + 1] = 'heal:' .. t end },
            qbx_core = { GetPlayer = function() return nil end, SetMetadata = function(t, k, v) calls[#calls + 1] = ('meta:%d:%s=%s'):format(t, k, v) end },
        } })
        Fx.emit('pxd_admin:server:action', 1, 'revive', 2)
        Fx.emit('pxd_admin:server:action', 1, 'needs', 2)
        table.sort(calls)
        T.eq(table.concat(calls, ','), 'meta:2:hunger=100,meta:2:stress=0,meta:2:thirst=100,revive:2')
        T.truthy(Fx.lastTo(2, 'hud:client:UpdateNeeds'))
    end)

    T.it('comandos de chat: misma validación que el panel', function()
        boot()
        Fx.commands['duty'](3, {})
        T.falsy(Fx.playerStates[3] and Fx.playerStates[3].pxd_staff, 'sin permiso no hace nada')
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
        T.truthy(Fx.commands['noclip'] and Fx.commands['admin'], '/noclip y /admin son de pxd_admin (parche de qbx_adminmenu)')
        for _, taken in ipairs({ 'tp', 'tpm', 'dv' }) do
            T.falsy(Fx.commands[taken], '/' .. taken .. ' es de qbx_core')
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
        Fx.commands['traer'](1, { '2' })
        T.eq(calls.left[1], 2, 'primero lo saca de la partida')
        T.eq(Fx.players[2].bucket, 0)
        Fx.players[3].bucket = 7
        Fx.commands['ir'](1, { '3' })
        T.eq(calls.buckets[#calls.buckets], '1:7', 'cambia de bucket con SetPlayerBucket de Qbox')
    end)

    T.it('/anuncio: único dueño; consola y ACE pxd.chat.announce; avisa a pxd_chat', function()
        boot()
        local seen = {}
        AddEventHandler('pxd_admin:server:announced', function(t) seen[#seen + 1] = t end)
        Fx.commands['anuncio'](3, { 'hola', 'todos' })
        T.eq(#seen, 0, 'sin permiso no anuncia')
        Fx.commands['anuncio'](0, { 'Reinicio', 'en', '5', 'min' })
        T.eq(seen[1], 'Reinicio en 5 min', 'la consola puede')
        Fx.addPlayer(4, 'Alcaldía', { x = 0, y = 0, z = 0 }, { ['pxd.chat.announce'] = true }, { license = 'license:gob' })
        Fx.commands['anuncio'](4, { 'Feria', 'mañana' })
        T.eq(seen[2], 'Feria mañana', 'ACE de compatibilidad')
        Fx.commands['anuncio'](1, { 'Staff', 'avisa' })
        T.eq(seen[3], 'Staff avisa', 'moderación o superior anuncia')
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
        T.eq(audited[#audited].action, 'report:close')
    end)

    T.it('borrar vehículo: permiso y distancia en el servidor, y queda registrado', function()
        boot({ staffAces = roleAces('soporte') })
        local veh = CreateVehicle(1, 3, 0, 10, 0)
        Fx.emit('pxd_admin:server:deleteVehicle', 1, veh + 100000)
        T.eq(#Fx.deleted, 0, 'soporte no borra vehículos')
        boot()
        veh = CreateVehicle(1, 3, 0, 10, 0)
        local far = CreateVehicle(1, 500, 0, 10, 0)
        Fx.emit('pxd_admin:server:deleteVehicle', 1, far + 100000)
        T.eq(#Fx.deleted, 0, 'lejos')
        Fx.emit('pxd_admin:server:deleteVehicle', 1, veh + 100000)
        T.eq(Fx.deleted[1], veh)
        T.eq(audited[#audited].target, 'vehicle:PXD 042')
    end)

    T.it('titularidad de vehículo con qbx_vehicles: solo superadministración y con motivo', function()
        local owner = { [18] = 'OLD1' }
        local vehicles = {
            GetVehicleIdByPlate = function(plate) return plate == 'PXD 042' and 18 or nil end,
            GetPlayerVehicle = function(id) return owner[id] and { citizenid = owner[id] } or nil end,
            SetPlayerVehicleOwner = function(id, cid) owner[id] = cid; return true end,
        }
        boot({ mysql = true, staffAces = roleAces('administrador'), states = { qbx_vehicles = 'started' }, exports = { qbx_vehicles = vehicles } })
        Fx.emit('pxd_admin:server:action', 1, 'vehowner', 0, { plate = 'pxd 042', citizenid = 'QX81PA2D', reason = 'Venta entre jugadores' })
        T.eq(owner[18], 'OLD1', 'administración no puede')
        boot({ mysql = true, states = { qbx_vehicles = 'started' }, exports = { qbx_vehicles = vehicles } })
        Fx.emit('pxd_admin:server:action', 1, 'vehowner', 0, { plate = 'pxd 042', citizenid = 'NOEXISTE', reason = 'Venta' })
        T.eq(owner[18], 'OLD1', 'el personaje debe existir')
        Fx.emit('pxd_admin:server:action', 1, 'vehowner', 0, { plate = 'pxd 042', citizenid = 'qx81pa2d', reason = 'Venta entre jugadores' })
        T.eq(owner[18], 'QX81PA2D')
        T.eq(audited[#audited].target, 'vehicle:PXD 042'); T.eq(audited[#audited].data.detail, 'PXD 042: OLD1 → QX81PA2D')
    end)

    T.it('consultas: economía y buckets con su permiso', function()
        boot({ staffAces = roleAces('moderador'), states = { pxd_economy = 'started' },
            exports = { pxd_economy = { GetFlowSummary = function(h) return { hours = h, totalIn = 5, totalOut = 3, net = 2, categories = {} } end } } })
        Fx.emit('pxd_admin:server:query', 1, 'economy', { hours = 24 })
        T.falsy(Fx.lastTo(1, 'pxd_admin:client:result'), 'moderación no ve economía')
        boot({ states = { pxd_economy = 'started' },
            exports = { pxd_economy = { GetFlowSummary = function(h) return { hours = h, totalIn = 5, totalOut = 3, net = 2, categories = {} } end } } })
        Fx.emit('pxd_admin:server:query', 1, 'economy', { hours = 168 })
        local r = Fx.lastTo(1, 'pxd_admin:client:result')
        T.eq(r.args[1], 'economy'); T.eq(r.args[2].summary.hours, 168)
        Fx.players[3].bucket = 7
        Fx.emit('pxd_admin:server:query', 1, 'buckets', {})
        r = Fx.lastTo(1, 'pxd_admin:client:result')
        T.eq(r.args[2][1].bucket, 0); T.eq(r.args[2][2].bucket, 7)
    end)

    T.it('sin pxd_audit el registro propio sigue guardando y respondiendo', function()
        boot({ noAudit = true })
        Fx.emit('pxd_admin:server:action', 1, 'warn', 2, { reason = 'Insultos' })
        T.eq(#audited, 0)
        Fx.emit('pxd_admin:server:query', 1, 'history', { target = 2 })
        T.eq(Fx.lastTo(1, 'pxd_admin:client:result').args[2].warnings[1].reason, 'Insultos')
        T.truthy(Fx.files['data/staff-log.json']:find('Insultos', 1, true))
    end)
end)

T.describe('pxd_admin (rangos desde el juego: /darrango, /quitarrango, /checkas)', function()
    local function cmd(name, src, args) Fx.commands[name](src, args or {}) end
    local function executed(pattern)
        for _, c in ipairs(Fx.executed) do if c:find(pattern, 1, true) then return true end end
        return false
    end

    T.it('el superadministrador da y quita rangos; se aplica con add_principal, se guarda y se audita', function()
        boot()
        cmd('darrango', 1, { '2', 'mod', 'ayuda en reportes' })
        T.truthy(executed('add_principal identifier.license:edy group.mod'))
        T.eq(PXDAdmin.server.grants()['license:edy'].role, 'moderador')
        T.truthy(Fx.files['data/staff-roles.json']:find('moderador', 1, true), 'guardado en data/staff-roles.json')
        T.eq(audited[#audited].action, 'rango_dar'); T.eq(audited[#audited].data.reason, 'ayuda en reportes')
        T.truthy(lastToast(2):find('Moderador', 1, true), 'el jugador recibe aviso')
        cmd('darrango', 1, { '2', 'admin' })
        T.truthy(executed('remove_principal identifier.license:edy group.mod'), 'al cambiar de rango se quita el anterior')
        T.truthy(executed('add_principal identifier.license:edy group.admin'))
        cmd('quitarrango', 1, { '2' })
        T.truthy(executed('remove_principal identifier.license:edy group.admin'))
        T.falsy(PXDAdmin.server.grants()['license:edy'])
        T.eq(audited[#audited].action, 'rango_quitar')
    end)

    T.it('sin staff.manage no se dan rangos; superadministrador solo desde la consola', function()
        boot({ staffAces = roleAces('administrador') })
        cmd('darrango', 1, { '2', 'soporte' })
        T.falsy(PXDAdmin.server.grants()['license:edy']); T.falsy(executed('add_principal'))
        boot()
        cmd('darrango', 1, { '2', 'superadmin' })
        T.falsy(PXDAdmin.server.grants()['license:edy'], 'un superadmin no crea otros superadmins desde el juego')
        cmd('darrango', 0, { '2', 'superadmin' })
        T.eq(PXDAdmin.server.grants()['license:edy'].role, 'superadministrador', 'la consola sí')
        cmd('quitarrango', 1, { '2' })
        T.truthy(PXDAdmin.server.grants()['license:edy'], 'a un superadmin solo lo quita la consola')
    end)

    T.it('rol inválido o jugador desconectado: no hace nada', function()
        boot()
        cmd('darrango', 1, { '2', 'jefazo' })
        cmd('darrango', 1, { '99', 'mod' })
        T.falsy(next(PXDAdmin.server.grants())); T.falsy(executed('add_principal'))
    end)

    T.it('los rangos guardados se vuelven a aplicar al arrancar', function()
        boot()
        Fx.files['data/staff-roles.json'] = '{"license:zeta":{"role":"soporte","name":"Zeta"}}'
        PXDAdmin, Config = nil, nil
        Fx.executed = {}
        Fx.load(DIR, { 'config.lua', 'shared/admin.lua', 'server/main.lua' })
        Fx.advance(2)
        T.truthy(executed('add_principal identifier.license:zeta group.support'))
    end)

    T.it('/checkas: cada uno ve sus permisos; ver los de otro exige ser staff', function()
        boot()
        Fx.clearSent()
        cmd('checkas', 2, {})
        local d = Fx.lastTo(2, 'pxd_admin:client:checkas').args[1]
        T.eq(d.role, 'Sin rango de staff'); T.eq(d.license, 'license:edy', 'su propia licencia sí')
        T.falsy(d.staff, 'la lista de staff solo la ve el staff')
        cmd('checkas', 2, { '1' })
        T.falsy(Fx.lastTo(2, 'pxd_admin:client:checkas').args[1].id == 1, 'no puede mirar a otro')
        cmd('checkas', 1, { '2' })
        local s = Fx.lastTo(1, 'pxd_admin:client:checkas').args[1]
        T.eq(s.id, 2); T.truthy(s.staff); T.eq(#s.perms, 0 + (function() local n = 0 for _ in pairs(PXDAdmin.PERMS) do n = n + 1 end return n end)())
    end)
end)
