-- Pruebas de pxd_orgs: organizaciones creadas por jugadores sobre las bandas de qbx_core.
-- MariaDB, qbx_core, Renewed-Banking, pxd_progress y pxd_audit simulados con la MISMA semántica
-- que usan las llamadas reales (verificada en qbx_core v1.24.1 y Renewed-Banking v2.1.4).
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_orgs/'

local db
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
local function live(r) return r.status == 'pending' or r.status == 'official' end

local function fakeMySQL(Q, keep)
    db = keep or { orgs = {}, founders = {}, events = {}, nextId = 1, created = 0 }
    local M = {}
    M.query = { await = function(q, p)
        if q == Q.createOrgs or q == Q.createFounders or q == Q.createEvents then db.created = db.created + 1 return {} end
        if q == Q.loadLive then
            local out = {}
            for _, r in pairs(db.orgs) do if live(r) then out[#out + 1] = copy(r) end end
            return out
        end
        if q == Q.founders then
            local out = {}
            for _, f in ipairs(db.founders) do if f.org_id == p[1] then out[#out + 1] = { citizenid = f.citizenid, name = f.name } end end
            return out
        end
        if q == Q.events then
            local out = {}
            for i = #db.events, 1, -1 do if db.events[i].org_id == p[1] and #out < p[2] then out[#out + 1] = copy(db.events[i]) end end
            return out
        end
        error('consulta no simulada: ' .. q)
    end }
    M.single = { await = function(q, p)
        if q == Q.get then local r = db.orgs[p[1]] return r and copy(r) or nil end
        error('single no simulado: ' .. q)
    end }
    M.scalar = { await = function(q, p)
        if q == Q.nameTaken then
            for _, r in pairs(db.orgs) do if r.name_key == p[1] and live(r) then return r.id end end
            return nil
        end
        if q == Q.lastByCreator then
            local last
            for _, r in pairs(db.orgs) do if r.created_by == p[1] and (not last or r.created_at > last) then last = r.created_at end end
            return last
        end
        error('scalar no simulado: ' .. q)
    end }
    M.insert = { await = function(q, p)
        if q == Q.insert then
            if db.failInsert then error('conexión perdida') end
            local id = db.nextId; db.nextId = id + 1
            db.orgs[id] = { id = id, name = p[1], name_key = p[2], type = p[3], status = 'pending', leader_citizenid = p[4], color = p[5],
                font = p[6], motto = p[7], emblem = p[8], cost_paid = p[9], created_by = p[10], created_at = p[11], updated_at = p[12], reputation = 0 }
            return id
        end
        if q == Q.addFounder then
            for _, f in ipairs(db.founders) do if f.org_id == p[1] and f.citizenid == p[2] then return 0 end end
            db.founders[#db.founders + 1] = { org_id = p[1], citizenid = p[2], name = p[3] }
            return #db.founders
        end
        if q == Q.event then
            db.events[#db.events + 1] = { org_id = p[1], action = p[2], actor_citizenid = p[3], actor_name = p[4], target = p[5], amount = p[6], detail = p[7], created_at = p[8] }
            return #db.events
        end
        error('insert no simulado: ' .. q)
    end }
    M.update = { await = function(q, p)
        if q == Q.setSlug then local r = db.orgs[p[2]]; if r and not r.slug then r.slug = p[1] return 1 end return 0 end
        if q == Q.decide then
            local r = db.orgs[p[6]]
            if not r or r.status ~= 'pending' then return 0 end
            r.status, r.decided_by, r.decision_reason = p[1], p[2], p[4]
            return 1
        end
        if q == Q.dissolve then
            local r = db.orgs[p[5]]
            if not r or r.status ~= 'official' then return 0 end
            r.status, r.decided_by, r.decision_reason = 'dissolved', p[1], p[3]
            return 1
        end
        if q == Q.setIdentity then
            local r = db.orgs[p[6]]
            if not r or r.status ~= 'official' then return 0 end
            r.color, r.font, r.motto, r.emblem = p[1], p[2], p[3], p[4]
            return 1
        end
        if q == Q.setLeader then local r = db.orgs[p[3]]; if not r or r.status ~= 'official' then return 0 end r.leader_citizenid = p[1] return 1 end
        if q == Q.addReputation then local r = db.orgs[p[3]]; if not r or r.status ~= 'official' then return 0 end r.reputation = p[1] return 1 end
        error('update no simulado: ' .. q)
    end }
    return M
end

-- ── qbx_core simulado (bandas en marcha, un máximo de 1 banda por jugador) ──
local players, offline, gangs, groups, notes, committed, accounts, audited, levels, bankOk
local NONE = { name = 'none', label = 'No Gang', isboss = false, grade = { name = 'Unaffiliated', level = 0 } }

local function dataOf(id)
    if type(id) == 'number' then return players[id] and players[id].PlayerData end
    for _, p in pairs(players) do if p.PlayerData.citizenid == id then return p.PlayerData end end
    return offline[id]
end

local function mkPlayer(src, cid, name, bank, cash)
    local first, last = name:match('^(%S+)%s+(.+)$')
    players[src] = { PlayerData = { source = src, citizenid = cid, charinfo = { firstname = first, lastname = last },
        gang = copy(NONE), gangs = {}, money = { bank = bank or 0, cash = cash or 0 } } }
    return players[src]
end

local function fakeCore()
    local C = {}
    C.GetPlayer = function(src) return players[tonumber(src)] end
    C.GetPlayerByCitizenId = function(cid) for _, p in pairs(players) do if p.PlayerData.citizenid == cid then return p end end end
    C.GetOfflinePlayer = function(cid) return offline[cid] and { PlayerData = offline[cid], Offline = true } or nil end
    C.Notify = function(src, text, kind) notes[#notes + 1] = { src = src, text = text, kind = kind } end
    C.GetMoney = function(id, t) local d = dataOf(id) return d and d.money[t] or false end
    C.RemoveMoney = function(id, t, n)
        local d = dataOf(id)
        if not d or d.money[t] - n < 0 then return false end   -- como dontAllowMinus con 'bank'
        d.money[t] = d.money[t] - n
        return true
    end
    C.AddMoney = function(id, t, n)
        local d = dataOf(id)
        if not d then return false end
        d.money[t] = d.money[t] + n
        return true
    end
    C.GetGangs = function() return gangs end
    C.GetGang = function(name) return gangs[name] end
    C.CreateGangs = function(new, commit)
        for name, g in pairs(new) do
            for grade in pairs(g.grades) do if type(grade) ~= 'number' or grade < 0 then return false, 'grado no válido' end end
            gangs[name] = g
            committed[name] = commit == true
        end
        return true
    end
    C.RemoveGang = function(name, commit)
        if not gangs[name] then return false, 'gang_not_exists' end
        gangs[name] = nil
        committed[name] = commit == true and 'removed' or nil
        return true, 'success'
    end
    C.GetGroupMembers = function(group)
        local out = {}
        for cid, grade in pairs(groups[group] or {}) do out[#out + 1] = { citizenid = cid, grade = grade } end
        return out
    end
    C.AddPlayerToGang = function(cid, name, grade)
        local g = gangs[name]
        if not g then return false, { code = 'gang_not_found' } end
        if not g.grades[grade] then return false, { code = 'gang_missing_grade' } end
        local d = dataOf(cid)
        if not d then return false, { code = 'player_not_found' } end
        if next(d.gangs) ~= nil and d.gangs[name] == nil then return false, { code = 'max_gangs' } end
        d.gangs[name] = grade
        groups[name] = groups[name] or {}
        groups[name][cid] = grade
        if d.source then TriggerEvent('qbx_core:server:onGroupUpdate', d.source, name, grade) end
        if d.gang.name == name then C.SetPlayerPrimaryGang(cid, name) end
        return true
    end
    C.SetPlayerPrimaryGang = function(cid, name)
        local d = dataOf(cid)
        local g = gangs[name]
        if not d or not g or d.gangs[name] == nil then return false end
        local grade = d.gangs[name]
        d.gang = { name = name, label = g.label, isboss = g.grades[grade].isboss, bankAuth = g.grades[grade].bankAuth,
            grade = { name = g.grades[grade].name, level = grade } }
        if d.source then TriggerEvent('QBCore:Server:OnGangUpdate', d.source, d.gang) end
        return true
    end
    C.RemovePlayerFromGang = function(cid, name)
        local d = dataOf(cid)
        if not d then return false end
        d.gangs[name] = nil
        if groups[name] then groups[name][cid] = nil end
        if d.gang.name == name then d.gang = copy(NONE) end
        if d.source then TriggerEvent('qbx_core:server:onGroupUpdate', d.source, name) end
        return true
    end
    return C
end

local function fakeBank()
    return {
        CreateJobAccount = function(job, initial)
            if accounts[job.name] == nil then accounts[job.name] = tonumber(initial) or 0 end
            return { id = job.name }
        end,
        getAccountMoney = function(acc) if accounts[acc] == nil then return false end return accounts[acc] end,
        addAccountMoney = function(acc, n)
            if not bankOk or accounts[acc] == nil then return false end
            accounts[acc] = accounts[acc] + n
            return true
        end,
        removeAccountMoney = function(acc, n)
            if accounts[acc] == nil or accounts[acc] < n then return false end
            accounts[acc] = accounts[acc] - n
            return true
        end,
        handleTransaction = function() return {} end,
    }
end

local PATCHED = "        return Player.PlayerData.gang.bankAuth == true -- Próxima\n"

local function boot(opts)
    opts = opts or {}
    if not opts.keep then
        players, offline, gangs, groups, notes, committed, accounts, audited, levels = {}, {}, {}, {}, {}, {}, {}, {}, {}
        gangs.none = { label = 'No Gang', grades = { [0] = { name = 'Unaffiliated' } } }
        gangs.ballas = { label = 'Ballas', grades = { [0] = { name = 'Recruit' }, [1] = { name = 'Boss', isboss = true } } }
    end
    bankOk = true
    local states = { qbx_core = 'started', ['Renewed-Banking'] = 'started', pxd_progress = 'started', pxd_audit = 'started' }
    if opts.economy then states.pxd_economy = 'started' end
    Fx.reset({ resourceName = 'pxd_orgs', resourceStates = states,
        exports = { qbx_core = fakeCore(), ['Renewed-Banking'] = fakeBank(),
            pxd_progress = { GetProfile = function(src) return { level = levels[src] or 1 } end },
            pxd_audit = { Log = function(e) audited[#audited + 1] = e return #audited end },
            pxd_economy = opts.economy and { ChargeToAccount = function(src, method, amount, account)
                local d = dataOf(src)
                if d.money[method] < amount then return false, 'fondos' end
                d.money[method] = d.money[method] - amount
                accounts[account] = accounts[account] + amount
                return true, nil, 'deposited'
            end } or nil },
        files = { ['Renewed-Banking/server/framework.lua'] = opts.unpatched and '-- sin parche' or PATCHED } })
    _G.GetInvokingResource = function() return opts.invoker end
    Config, PXDOrgs, PXDOrgStore, PXDOrgsServer = nil, nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/orgs.lua', 'server/store.lua' })
    MySQL = fakeMySQL(PXDOrgStore.Q, opts.keep and db or nil)
    if opts.config then for k, v in pairs(opts.config) do Config[k] = v end end
    if opts.create then for k, v in pairs(opts.create) do Config.create[k] = v end end
    -- Ana (1) funda; Beto (2) y Caro (3) cerca; Dani (4) lejos; Eva (5) staff cerca; Fede (6) ya en Ballas.
    Fx.addPlayer(1, 'ana', { x = 0, y = 0, z = 0 })
    Fx.addPlayer(2, 'beto', { x = 3, y = 0, z = 0 })
    Fx.addPlayer(3, 'caro', { x = 0, y = 4, z = 0 })
    Fx.addPlayer(4, 'dani', { x = 400, y = 0, z = 0 })
    Fx.addPlayer(5, 'eva', { x = 2, y = 2, z = 0 }, { ['pxd.orgs.manage'] = true })
    Fx.addPlayer(6, 'fede', { x = 1, y = 1, z = 0 })
    if opts.keep then                       -- reinicio del recurso: mismos jugadores y misma base de datos
        for src in pairs(Fx.players) do if not players[src] then Fx.players[src] = nil end end
        Fx.load(DIR, { 'server/main.lua' })
        return
    end
    Fx.load(DIR, { 'server/main.lua' })
    mkPlayer(1, 'ANA1', 'Ana Ríos', 60000, 500); levels[1] = 5
    mkPlayer(2, 'BET2', 'Beto Salas', 1000, 2000); levels[2] = 1
    mkPlayer(3, 'CAR3', 'Caro Lima', 0, 0)
    mkPlayer(4, 'DAN4', 'Dani Paz', 0, 0)
    mkPlayer(5, 'EVA5', 'Eva Staff', 0, 0)
    mkPlayer(6, 'FED6', 'Fede Rojo', 0, 0)
    fakeCore().AddPlayerToGang('FED6', 'ballas', 0); fakeCore().SetPlayerPrimaryGang('FED6', 'ballas')
end

local S
local function srv() S = PXDOrgsServer return S end
local function note(src, pattern) for _, n in ipairs(notes) do if n.src == src and n.text:find(pattern, 1, true) then return n end end end
local FORM = { type = 'banda', name = 'Los Reyes del Sur', color = '#ff4fd8', font = 'marker', motto = 'Sangre y barrio' }
local function form(extra) local f = copy(FORM) for k, v in pairs(extra or {}) do f[k] = v end return f end

--- Funda «Los Reyes del Sur» con Ana y Beto; con approve = true, Eva (staff) la aprueba.
local function found(approve, extra)
    srv()
    local ok, why = S.start(1, form(extra or { founders = { 2 } }))
    T.truthy(ok, tostring(why))
    T.truthy(S.answerFounder(2, 'ANA1', true))
    local ok2, why2 = S.confirm(1)
    T.truthy(ok2, tostring(why2))
    if approve then T.truthy(S.approve(5, 1)) end
    return S.orgs()[1]
end

T.describe('pxd_orgs · lógica pura', function()
    local O
    T.it('nombres: longitud, caracteres permitidos y clave sin tildes ni separadores', function()
        dofile(RES .. 'pxd_orgs/config.lua'); O = dofile(RES .. 'pxd_orgs/shared/orgs.lua')
        T.eq(O.validName('  Los   Reyes del Sur ', Config), 'Los Reyes del Sur')
        T.eq(O.validName('Peña Ñandú & Cía.', Config), 'Peña Ñandú & Cía.')
        T.falsy(O.validName('ab', Config)); T.falsy(O.validName(string.rep('a', 29), Config))
        T.falsy(O.validName("Los 'Reyes'", Config), 'sin comillas')
        T.falsy(O.validName('Reyes <b>', Config)); T.falsy(O.validName('Reyes ☠', Config)); T.falsy(O.validName('12 34', Config))
        T.eq(O.nameKey('Los Reyes del Sur'), O.nameKey('los-reyes.DEL sur'))
        T.eq(O.nameKey('Peña Ñandú'), 'penanandu')
        T.truthy(O.blocked(O.nameKey('La Policía Secreta'), Config.blockedNames))
        T.falsy(O.blocked(O.nameKey('Los Reyes'), Config.blockedNames))
    end)

    T.it('identidad: paleta y tipografías cerradas, emblema por iniciales, lema limpio', function()
        T.eq(O.emblemFrom('Los Reyes del Sur'), 'LRD'); T.eq(O.emblemFrom('Ñandú'), 'N')
        local i = O.identity({ color = '#FF4FD8', font = 'marker', emblem = 'lr', motto = '  Sangre   y barrio ' }, Config, {})
        T.eq(i.color, '#ff4fd8'); T.eq(i.emblem, 'LR'); T.eq(i.motto, 'Sangre y barrio')
        T.eq(select(2, O.identity({ color = '#123456' }, Config, { emblem = 'X' })), 'color')
        T.eq(select(2, O.identity({ font = 'comic-sans' }, Config, { emblem = 'X' })), 'fuente')
        T.eq(select(2, O.identity({ emblem = 'ABCD' }, Config, {})), 'emblema')
        T.eq(select(2, O.identity({ motto = string.rep('x', 61) }, Config, { emblem = 'X' })), 'lema')
        local keep = O.identity({ motto = '' }, Config, { color = '#3fe08f', font = 'bebas', emblem = 'AB', motto = 'viejo' })
        T.eq(keep.color, '#3fe08f'); T.eq(keep.font, 'bebas'); T.falsy(keep.motto, 'lema vacío lo borra')
    end)

    T.it('rangos: formato de qbx_core, permisos y cambios solo por debajo del propio', function()
        local g = O.gradesFor('banda', Config)
        T.eq(g[0].name, 'Aspirante'); T.truthy(g[4].isboss); T.truthy(g[3].bankAuth); T.falsy(g[1].bankAuth)
        T.eq(O.gradesFor('motoclub', Config)[4].name, 'Presidente')
        T.truthy(O.hasPerm(2, 'invite', Config)); T.falsy(O.hasPerm(2, 'manage', Config)); T.falsy(O.hasPerm(1, 'invite', Config))
        T.truthy(O.validGradeChange(4, 1, 3, Config)); T.falsy(O.validGradeChange(4, 1, 4, Config), 'el liderazgo solo se transfiere')
        T.falsy(O.validGradeChange(3, 3, 1, Config), 'no a un igual'); T.falsy(O.validGradeChange(3, 1, 3, Config), 'no a su mismo rango')
        T.falsy(O.validGradeChange(3, 1, 1, Config)); T.falsy(O.validGradeChange(3, 1, 9, Config)); T.falsy(O.validGradeChange(3, 1, 1.5, Config))
    end)

    T.it('nivel por reputación y requisitos para fundar', function()
        T.eq(O.levelFor(0, Config).level, 1); T.eq(O.levelFor(1500, Config).level, 3); T.eq(O.levelFor(99999, Config).level, 5)
        T.eq(select(2, O.levelFor(0, Config)).rep, 500)
        T.eq(O.addReputation(100, 50, Config), 150); T.eq(O.addReputation(10, -50, Config), 0)
        T.falsy(O.addReputation(0, 0, Config)); T.falsy(O.addReputation(0, 1.5, Config)); T.falsy(O.addReputation(0, 99999, Config))
        local list, ok = O.requirements({ level = 1, bank = 100, founders = 1 }, Config)
        T.falsy(ok); T.eq(#list, 3); T.falsy(list[1].ok)
        T.truthy(select(2, O.requirements({ level = 3, bank = 25000, founders = 2 }, Config)))
        T.truthy(select(2, O.requirements({ level = 1, bank = 0, founders = 1, staff = true }, Config)), 'el staff no necesita cumplirlos')
        T.truthy(select(2, O.requirements({ level = nil, bank = 25000, founders = 2 }, Config)), 'sin pxd_progress no se exige nivel')
    end)
end)

T.describe('pxd_orgs · fundar', function()
    T.it('crea sus tablas al arrancar sin borrar nada', function()
        boot()
        T.eq(db.created, 3); T.truthy(srv().isReady())
    end)

    T.it('solicitud con cofundador: cobra la tasa, queda pendiente y aún no existe en qbx_core', function()
        boot()
        local org = found(false)
        T.eq(org.status, 'pending'); T.eq(org.slug, 'pxo_1'); T.eq(org.emblem, 'LRD'); T.eq(org.font, 'marker')
        T.eq(players[1].PlayerData.money.bank, 35000, 'tasa cobrada del banco')
        T.falsy(gangs.pxo_1, 'sin aprobar no hay banda')
        T.eq(#db.founders, 2)
        T.truthy(note(5, 'Nueva solicitud'), 'el staff conectado recibe aviso')
        T.eq(S.view(1).pending.name, 'Los Reyes del Sur')
        T.eq(audited[1].category, 'orgs'); T.eq(audited[1].action, 'requested')
    end)

    T.it('al aprobarla el staff: banda en qbx_core guardada en su archivo, rangos, fundadores y cuenta', function()
        boot()
        local org = found(true)
        T.eq(org.status, 'official')
        T.eq(gangs.pxo_1.label, 'Los Reyes del Sur'); T.truthy(gangs.pxo_1.grades[4].isboss)
        T.eq(committed.pxo_1, true, 'commitToFile = true: sobrevive al reinicio y a cleanPlayerGroups')
        T.eq(groups.pxo_1.ANA1, 4); T.eq(groups.pxo_1.BET2, 2)
        T.eq(players[1].PlayerData.gang.name, 'pxo_1')
        T.eq(accounts.pxo_1, 0, 'cuenta en Renewed-Banking')
        local st = Fx.playerStates[1].pxdOrg
        T.eq(st.name, 'Los Reyes del Sur'); T.eq(st.color, '#ff4fd8'); T.eq(st.grade, 4)
        T.truthy(note(1, 'ya es una organización oficial'))
        T.eq(db.orgs[1].decided_by, 'Eva Staff')
    end)

    T.it('requisitos en el servidor: nivel, dinero, cofundadores, estar libre, tipo y nombre', function()
        boot(); srv()
        levels[1] = 1
        T.eq(select(2, S.start(1, form({ founders = { 2 } }))), PXDOrgs.MESSAGES.requisitos)
        levels[1] = 5; players[1].PlayerData.money.bank = 100
        T.eq(select(2, S.start(1, form({ founders = { 2 } }))), PXDOrgs.MESSAGES.requisitos)
        players[1].PlayerData.money.bank = 60000
        T.eq(select(2, S.start(1, form())), PXDOrgs.MESSAGES.fundadores)
        T.eq(select(2, S.start(1, form({ founders = { 4 } }))), PXDOrgs.MESSAGES.lejos)
        T.eq(select(2, S.start(1, form({ founders = { 6 } }))), PXDOrgs.MESSAGES.fundador_no_valido, 'Fede ya está en una banda')
        T.eq(select(2, S.start(6, form({ founders = { 2 } }))), PXDOrgs.MESSAGES.ya_en_org)
        T.eq(select(2, S.start(1, form({ founders = { 2 }, type = 'gobierno' }))), PXDOrgs.MESSAGES.tipo, 'gubernamental es solo para el staff')
        T.eq(select(2, S.start(1, form({ founders = { 2 }, type = 'empresa' }))), PXDOrgs.MESSAGES.tipo, 'empresa está reservada')
        T.eq(select(2, S.start(1, form({ founders = { 2 }, name = 'Ballas' }))), PXDOrgs.MESSAGES.nombre_usado, 'choca con una banda de qbx_core')
        T.eq(select(2, S.start(1, form({ founders = { 2 }, name = 'La Policía' }))), PXDOrgs.MESSAGES.nombre_bloqueado)
        T.eq(select(2, S.start(1, form({ founders = { 2 }, color = 'red' }))), PXDOrgs.MESSAGES.color)
        T.falsy(next(S.drafts())); T.eq(players[1].PlayerData.money.bank, 60000, 'nada cobrado')
    end)

    T.it('sin la aceptación del cofundador no se puede confirmar; si la base de datos falla, devuelve la tasa', function()
        boot(); srv()
        T.truthy(S.start(1, form({ founders = { 2 } })))
        T.truthy(note(2, 'te propone fundar'))
        T.eq(select(2, S.confirm(1)), PXDOrgs.MESSAGES.fundadores)
        T.truthy(S.answerFounder(2, 'ANA1', true))
        db.failInsert = true
        T.eq(select(2, S.confirm(1)), PXDOrgs.MESSAGES.sin_servicio)
        T.eq(players[1].PlayerData.money.bank, 60000, 'tasa devuelta')
        db.failInsert = nil
        T.truthy(S.confirm(1))
        T.eq(select(2, S.start(1, form({ founders = { 2 }, name = 'Otra Cosa' }))), PXDOrgs.MESSAGES.pendiente)
    end)

    T.it('nombre único entre solicitudes vivas; rechazar devuelve la tasa y libera el nombre', function()
        boot()
        found(false)
        players[3].PlayerData.money.bank = 60000; levels[3] = 5
        T.eq(select(2, S.start(3, form({ founders = { 5 }, name = 'los reyes-del sur' }))), PXDOrgs.MESSAGES.nombre_usado)
        T.eq(select(2, S.reject(5, 1, 'x')), PXDOrgs.MESSAGES.motivo, 'motivo obligatorio')
        T.eq(select(2, S.reject(2, 1, 'nombre ofensivo')), PXDOrgs.MESSAGES.permiso, 'solo el staff')
        T.truthy(S.reject(5, 1, 'ya hay demasiadas bandas en esa zona'))
        T.eq(db.orgs[1].status, 'rejected'); T.eq(players[1].PlayerData.money.bank, 60000, 'tasa devuelta')
        T.falsy(S.orgs()[1]); T.truthy(note(1, 'fue rechazada'))
        T.eq(audited[#audited].action, 'rejected')
        T.eq(select(2, S.approve(5, 1)), PXDOrgs.MESSAGES.no_existe)
        T.eq(select(2, S.start(1, form({ founders = { 2 } }))), PXDOrgs.MESSAGES.espera, 'espera entre solicitudes')
    end)

    T.it('aprobación automática si así se configura; el staff crea sin requisitos (también gubernamental)', function()
        boot({ config = { approval = 'auto' } })
        local org = found(false)
        T.eq(org.status, 'official'); T.truthy(gangs.pxo_1); T.eq(db.orgs[1].decided_by, 'automática')
        boot(); srv()
        T.truthy(S.start(5, { type = 'gobierno', name = 'Ayuntamiento', color = '#5ce1ff', font = 'sora' }))
        T.truthy(S.confirm(5))
        T.eq(S.orgs()[1].status, 'official'); T.eq(players[5].PlayerData.money.bank, 0, 'sin tasa')
        T.eq(gangs.pxo_1.grades[4].name, 'Titular'); T.eq(groups.pxo_1.EVA5, 4)
    end)
end)

T.describe('pxd_orgs · miembros', function()
    T.it('invitar: hace falta rango, cercanía, plaza y que la otra persona esté libre; aceptar la mete de aspirante', function()
        boot(); found(true)
        T.eq(select(2, S.invite(3, 2)), PXDOrgs.MESSAGES.sin_org, 'quien no es miembro no invita')
        T.eq(select(2, S.invite(1, 4)), PXDOrgs.MESSAGES.lejos)
        T.eq(select(2, S.invite(1, 6)), PXDOrgs.MESSAGES.ocupado)
        T.eq(select(2, S.invite(1, 1)), PXDOrgs.MESSAGES.jugador)
        T.truthy(S.invite(1, 3)); T.truthy(note(3, 'te invita a unirte'))
        T.eq(select(2, S.invite(2, 3)), PXDOrgs.MESSAGES.invitado, 'Beto (veterano) también puede invitar, pero ya está invitada')
        T.eq(S.view(3).invites[1].name, 'Los Reyes del Sur')
        T.eq(select(2, S.answerInvite(2, 1, true)), PXDOrgs.MESSAGES.sin_invitacion, 'solo responde la persona invitada')
        T.truthy(S.answerInvite(3, 1, true))
        T.eq(groups.pxo_1.CAR3, 0); T.eq(players[3].PlayerData.gang.name, 'pxo_1')
        T.eq(Fx.playerStates[3].pxdOrg.grade, 0)
        T.eq(select(2, S.answerInvite(3, 1, true)), PXDOrgs.MESSAGES.sin_invitacion, 'una invitación vale una vez')
        T.eq(select(2, S.invite(3, 5)), PXDOrgs.MESSAGES.permiso, 'un aspirante no invita')
    end)

    T.it('las plazas dependen del nivel; rechazar una invitación no cambia nada', function()
        boot({ config = { levels = { { level = 1, rep = 0, slots = 2 }, { level = 2, rep = 100, slots = 3 } } } }); found(true)
        T.eq(select(2, S.invite(1, 3)), PXDOrgs.MESSAGES.llena)
        T.truthy(S.addReputation(1, 100, 'prueba'))
        T.truthy(S.invite(1, 3))
        T.truthy(S.answerInvite(3, 1, false))
        T.falsy(groups.pxo_1.CAR3); T.truthy(note(1, 'rechazó la invitación'))
    end)

    T.it('rangos y expulsión: solo sobre rangos inferiores, nunca a uno mismo ni al rango más alto', function()
        boot(); found(true)
        S.invite(1, 3); S.answerInvite(3, 1, true)
        T.eq(select(2, S.setGrade(2, 'CAR3', 1)), PXDOrgs.MESSAGES.permiso, 'veterano no gestiona')
        T.truthy(S.setGrade(1, 'BET2', 3)); T.eq(groups.pxo_1.BET2, 3)
        T.truthy(S.setGrade(2, 'CAR3', 2)); T.eq(players[3].PlayerData.gang.grade.level, 2)
        T.eq(select(2, S.setGrade(2, 'CAR3', 3)), PXDOrgs.MESSAGES.rango, 'no puede subir a su mismo rango')
        T.eq(select(2, S.setGrade(2, 'ANA1', 0)), PXDOrgs.MESSAGES.rango, 'ni tocar a quien lidera')
        T.eq(select(2, S.setGrade(1, 'BET2', 4)), PXDOrgs.MESSAGES.rango)
        T.eq(select(2, S.setGrade(1, 'ANA1', 2)), PXDOrgs.MESSAGES.propio)
        T.eq(select(2, S.kick(2, 'ANA1')), PXDOrgs.MESSAGES.rango)
        T.eq(select(2, S.kick(1, 'DAN4')), PXDOrgs.MESSAGES.miembro)
        T.eq(select(2, S.kick(1, { 'x' })), PXDOrgs.MESSAGES.miembro, 'datos manipulados')
        T.truthy(S.kick(2, 'CAR3'))
        T.falsy(groups.pxo_1.CAR3); T.eq(players[3].PlayerData.gang.name, 'none'); T.falsy(Fx.playerStates[3].pxdOrg)
        T.truthy(note(3, 'Te han expulsado'))
        T.eq(audited[#audited].action, 'kick'); T.eq(audited[#audited].data.target, 'CAR3')
    end)

    T.it('funciona con miembros desconectados (rango y expulsión por citizenid)', function()
        boot(); found(true)
        offline.BET2 = players[2].PlayerData; offline.BET2.source = nil; players[2] = nil; Fx.players[2] = nil
        local members = S.view(1).org.members
        T.eq(#members, 2); T.eq(members[2].name, 'Beto Salas'); T.falsy(members[2].online)
        T.truthy(S.setGrade(1, 'BET2', 1)); T.eq(groups.pxo_1.BET2, 1)
        T.truthy(S.kick(1, 'BET2')); T.falsy(groups.pxo_1.BET2)
    end)

    T.it('transferir el liderazgo y salir: quien lidera no puede irse sin transferir', function()
        boot(); found(true)
        T.eq(select(2, S.leave(1)), PXDOrgs.MESSAGES.lider)
        T.eq(select(2, S.transfer(2, 'ANA1')), PXDOrgs.MESSAGES.permiso)
        T.eq(select(2, S.transfer(1, 'DAN4')), PXDOrgs.MESSAGES.miembro)
        T.truthy(S.transfer(1, 'BET2'))
        T.eq(groups.pxo_1.BET2, 4); T.eq(groups.pxo_1.ANA1, 3); T.eq(db.orgs[1].leader_citizenid, 'BET2')
        T.truthy(S.leave(1)); T.falsy(groups.pxo_1.ANA1)
        T.eq(select(2, S.leave(1)), PXDOrgs.MESSAGES.sin_org)
    end)
end)

T.describe('pxd_orgs · fondos, identidad y reputación', function()
    T.it('aportar (cualquier miembro) y retirar (solo con permiso), sin saldos negativos', function()
        boot(); found(true)
        T.truthy(S.deposit(2, 1500, 'cash')); T.eq(accounts.pxo_1, 1500); T.eq(players[2].PlayerData.money.cash, 500)
        T.eq(select(2, S.deposit(2, 5000, 'cash')), PXDOrgs.MESSAGES.fondos); T.eq(accounts.pxo_1, 1500)
        T.eq(select(2, S.deposit(2, 10, 'crypto')), PXDOrgs.MESSAGES.metodo)
        T.eq(select(2, S.deposit(2, -5, 'cash')), PXDOrgs.MESSAGES.importe); T.eq(select(2, S.deposit(2, 1.5, 'cash')), PXDOrgs.MESSAGES.importe)
        T.eq(select(2, S.withdraw(2, 100)), PXDOrgs.MESSAGES.permiso, 'veterano no retira')
        T.eq(select(2, S.withdraw(1, 9999)), PXDOrgs.MESSAGES.fondos_org)
        T.truthy(S.withdraw(1, 1000)); T.eq(accounts.pxo_1, 500); T.eq(players[1].PlayerData.money.bank, 36000)
        T.eq(audited[#audited].action, 'withdraw'); T.eq(audited[#audited].data.amount, 1000)
        T.eq(S.view(1).org.funds, 500)
    end)

    T.it('si la cuenta falla al ingresar, se devuelve el dinero; con pxd_economy usa su cobro seguro', function()
        boot(); found(true)
        bankOk = false
        T.eq(select(2, S.deposit(2, 1000, 'cash')), PXDOrgs.MESSAGES.banco)
        T.eq(players[2].PlayerData.money.cash, 2000, 'reembolsado'); T.eq(accounts.pxo_1, 0)
        boot({ economy = true }); found(true)
        T.truthy(S.deposit(2, 700, 'bank')); T.eq(accounts.pxo_1, 700); T.eq(players[2].PlayerData.money.bank, 300)
    end)

    T.it('sin el parche de Renewed-Banking no abre la cuenta en marcha (evita romper su banco) y lo avisa', function()
        boot({ unpatched = true }); found(true)
        T.falsy(accounts.pxo_1); T.falsy(S.view(1).org.funds)
        T.eq(select(2, S.deposit(2, 100, 'cash')), PXDOrgs.MESSAGES.banco); T.eq(players[2].PlayerData.money.cash, 2000)
        local warned = false
        for _, l in ipairs(Fx.logs) do if l:find('no tiene el parche', 1, true) then warned = true end end
        T.truthy(warned)
    end)

    T.it('identidad: solo con permiso y dentro de la paleta; se publica a los miembros y a otros recursos', function()
        boot(); found(true)
        local got
        AddEventHandler('pxd_orgs:identityChanged', function(id, identity) got = identity end)
        T.eq(select(2, S.setIdentity(2, { color = '#3fe08f' })), PXDOrgs.MESSAGES.permiso)
        T.eq(select(2, S.setIdentity(1, { color = '#000000' })), PXDOrgs.MESSAGES.color)
        T.truthy(S.setIdentity(1, { color = '#3fe08f', font = 'bebas', emblem = 'rs', motto = 'El sur manda' }))
        T.eq(db.orgs[1].color, '#3fe08f'); T.eq(db.orgs[1].emblem, 'RS')
        T.eq(Fx.playerStates[2].pxdOrg.color, '#3fe08f'); T.eq(Fx.playerStates[2].pxdOrg.font, 'bebas')
        T.eq(got.fontFamily, 'PXO Bebas Neue'); T.eq(got.motto, 'El sur manda')
        local id = Fx.exports.pxd_orgs.GetIdentity(1)
        T.eq(id.name, 'Los Reyes del Sur'); T.eq(id.emblem, 'RS'); T.eq(Fx.exports.pxd_orgs.GetIdentity('pxo_1').color, '#3fe08f')
    end)

    T.it('reputación: suma con motivo, sube de nivel, avisa y queda auditada', function()
        boot({ invoker = 'pxd_turf' }); found(true)
        local up
        AddEventHandler('pxd_orgs:levelUp', function(id, level) up = level end)
        T.eq(select(2, Fx.exports.pxd_orgs.AddReputation(1, 50)), 'motivo')
        T.eq(select(2, Fx.exports.pxd_orgs.AddReputation(1, 0, 'x')), 'importe')
        T.eq(select(2, Fx.exports.pxd_orgs.AddReputation(99, 10, 'x')), 'no_existe')
        local rep, level = Fx.exports.pxd_orgs.AddReputation('pxo_1', 600, 'grafiti ganado')
        T.eq(rep, 600); T.eq(level, 2); T.eq(up, 2); T.eq(db.orgs[1].reputation, 600)
        T.truthy(note(2, 'sube al nivel 2'))
        T.eq(audited[#audited].action, 'reputation'); T.eq(audited[#audited].data.detail, 'grafiti ganado'); T.eq(audited[#audited].actor, 'pxd_turf')
        T.eq(S.view(1).org.slots, 12)
    end)
end)

T.describe('pxd_orgs · disolver, reinicio y seguridad', function()
    T.it('disolver: pide el nombre, entrega los fondos a quien lidera, saca a todos y conserva la ficha', function()
        boot(); found(true)
        S.deposit(2, 2000, 'cash')
        T.eq(select(2, S.dissolveOwn(2, 'Los Reyes del Sur')), PXDOrgs.MESSAGES.permiso)
        T.eq(select(2, S.dissolveOwn(1, 'Los Reyes')), PXDOrgs.MESSAGES.confirmar)
        T.truthy(S.dissolveOwn(1, 'los reyes del sur'))
        T.eq(db.orgs[1].status, 'dissolved', 'la ficha no se borra')
        T.falsy(gangs.pxo_1); T.eq(committed.pxo_1, 'removed'); T.falsy(next(groups.pxo_1))
        T.eq(players[1].PlayerData.money.bank, 37000, 'fondos a su banco'); T.eq(accounts.pxo_1, 0)
        T.eq(players[2].PlayerData.gang.name, 'none'); T.falsy(Fx.playerStates[2].pxdOrg)
        T.truthy(note(2, 'se ha disuelto')); T.falsy(S.orgs()[1])
        T.eq(audited[#audited].action, 'dissolved'); T.eq(audited[#audited].data.amount, 2000)
        T.falsy(Fx.exports.pxd_orgs.GetOrg(1))
    end)

    T.it('el staff disuelve con motivo; un jugador sin permiso no', function()
        boot(); found(true)
        T.eq(select(2, S.staffDissolve(2, 1, 'porque sí')), PXDOrgs.MESSAGES.permiso)
        T.eq(select(2, S.staffDissolve(5, 1, '')), PXDOrgs.MESSAGES.motivo)
        T.truthy(S.staffDissolve(5, 1, 'incumplimiento reiterado de normas'))
        T.eq(db.orgs[1].decision_reason, 'incumplimiento reiterado de normas')
    end)

    T.it('tras reiniciar: carga las vivas y recrea en qbx_core la banda que falte con su liderazgo', function()
        boot(); found(true)
        gangs.pxo_1, groups.pxo_1 = nil, nil                       -- como si qbx_core hubiera perdido su archivo
        players[1].PlayerData.gang, players[1].PlayerData.gangs = copy(NONE), {}
        boot({ keep = true }); srv()
        T.truthy(S.isReady()); T.eq(S.orgs()[1].status, 'official')
        T.truthy(gangs.pxo_1, 'banda recreada'); T.eq(groups.pxo_1.ANA1, 4, 'liderazgo restaurado')
        T.eq(Fx.playerStates[1].pxdOrg.name, 'Los Reyes del Sur')
    end)

    T.it('tras reiniciar con una solicitud pendiente: sigue pendiente y se puede aprobar', function()
        boot(); found(false)
        boot({ keep = true }); srv()
        T.eq(S.orgs()[1].status, 'pending'); T.eq(#S.orgs()[1].founders, 2)
        T.truthy(S.approve(0, 1)); T.eq(groups.pxo_1.BET2, 2); T.eq(db.orgs[1].decided_by, 'Consola')
    end)

    T.it('peticiones de la interfaz: acción desconocida, datos manipulados, sin permiso y límite de frecuencia', function()
        boot(); found(true)
        local function rpc(src, id, action, payload)
            Fx.clearSent(); Fx.emit('pxd_orgs:server:rpc', src, id, action, payload)
            local s = Fx.lastTo(src, 'pxd_orgs:client:rpc')
            return s and s.args[2], s and s.args[1]
        end
        local res, id = rpc(3, 7, 'view'); T.truthy(res.ok); T.eq(id, 7); T.truthy(res.state.create); T.falsy(res.state.staff)
        Fx.advance(2)
        T.eq(rpc(3, 8, 'borrarTodo').error, 'Acción no válida.')
        Fx.advance(2)
        res = rpc(3, 9, 'approve', { id = 1 }); T.falsy(res.ok); T.eq(res.error, PXDOrgs.MESSAGES.permiso)
        Fx.advance(2)
        res = rpc(3, 10, 'kick', { citizenid = 'BET2' }); T.eq(res.error, PXDOrgs.MESSAGES.sin_org); T.eq(groups.pxo_1.BET2, 2)
        Fx.advance(2)
        res = rpc(3, 11, 'withdraw', 'todo'); T.falsy(res.ok); T.eq(accounts.pxo_1, 0)
        res = rpc(3, 12, 'withdraw', { amount = 1 }); T.eq(res.error, PXDOrgs.MESSAGES.rapido, 'dos cambios seguidos')
        Fx.clearSent(); Fx.emit('pxd_orgs:server:rpc', 3, 'x', 'view'); T.falsy(Fx.lastTo(3, 'pxd_orgs:client:rpc'), 'petición mal formada: se ignora')
        Fx.advance(2)
        res = rpc(5, 13, 'view'); T.truthy(res.state.staff, 'el staff ve las solicitudes')
        Fx.advance(2)
        res = rpc(1, 14, 'view'); T.eq(#res.state.org.members, 2); T.truthy(res.state.org.perms.leader)
    end)

    T.it('exports para otros sistemas', function()
        boot(); found(true)
        local E = Fx.exports.pxd_orgs
        local org, grade = E.GetPlayerOrg(2)
        T.eq(org.name, 'Los Reyes del Sur'); T.eq(grade, 2); T.eq(org.level, 1); T.eq(org.slots, 8); T.eq(org.typeLabel, 'Banda')
        T.eq(E.GetPlayerOrg('ANA1').id, 1); T.falsy(E.GetPlayerOrg(6), 'una banda de qbx_core ajena a pxd_orgs no cuenta')
        T.truthy(E.IsMember(1, 1)); T.truthy(E.IsMember(2, 'pxo_1')); T.falsy(E.IsMember(3, 1))
        T.truthy(E.HasPermission(1, 'leader')); T.truthy(E.HasPermission(2, 'invite')); T.falsy(E.HasPermission(2, 'funds')); T.falsy(E.HasPermission(3, 'invite'))
        T.eq(#E.ListOrgs(), 1); T.eq(#E.ListOrgs({ type = 'motoclub' }), 0); T.eq(#E.ListOrgs({ status = 'pending' }), 0)
        T.eq(#E.GetMembers(1), 2); T.eq(E.GetMembers(1)[1].gradeName, 'Líder')
        T.eq(E.GetOrg('pxo_1').status, 'official')
    end)
end)
