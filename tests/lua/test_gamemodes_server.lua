-- Pruebas de integración de server/main.lua de pxd_gamemodes con el simulador.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_gamemodes/'

local function boot(opts)
    Fx.reset(opts)
    PXD = nil
    Config = nil
    Fx.load(DIR, {
        'config.lua', 'shared/util.lua', 'shared/modes.lua', 'shared/match.lua', 'shared/lobby.lua',
        'shared/arena.lua', 'shared/modes/ffa.lua', 'shared/modes/tdm.lua', 'shared/modes/koth.lua',
        'shared/modes/race.lua', 'server/bridge.lua', 'server/main.lua',
    })
    Fx.addPlayer(1, 'Nova', { x = 10, y = 20, z = 30 })
    Fx.addPlayer(2, 'Lumen', { x = 11, y = 21, z = 30 })
end

T.describe('pxd_gamemodes servidor', function()
    T.it('crear partida mete al jugador en un bucket aislado sin población', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.eq(Fx.players[1].bucket, 60000)
        T.eq(Fx.buckets[60000].population, false)
        T.eq(Fx.buckets[60000].lockdown, 'relaxed')
        local joined = Fx.lastTo(1, 'pxd_gm:client:joined')
        T.truthy(joined, 'envía joined')
        T.eq(joined.args[1].mode, 'ffa')
        T.eq(#Fx.sentTo(-1, 'pxd_gm:client:lobby') > 0, true, 'difunde el lobby')
    end)

    T.it('al terminar cuenta partidas y victorias en pxd_progress', function()
        local calls = {}
        boot({ resourceStates = { pxd_progress = 'started' },
            exports = { pxd_progress = { Track = function(src, key, n) calls[#calls + 1] = src .. ':' .. key .. ':' .. n end } } })
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        for _ = 1, 20 do
            Fx.emit('baseevents:onPlayerKilled', 2, 1, {})
            Fx.time = Fx.time + 3.5
        end
        Fx.advance(1)
        table.sort(calls)
        T.eq(table.concat(calls, ','), '1:gm_play:1,1:gm_win:1,2:gm_play:1')
    end)

    T.it('flujo completo: unirse, iniciar, cuenta atrás, bajas, fin y regreso', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        T.eq(Fx.players[2].bucket, 60000)

        Fx.emit('pxd_gm:server:start', 2)
        T.truthy(Fx.lastTo(2, 'pxd_gm:client:notify').args[1]:find('anfitrión'), 'solo el anfitrión inicia')

        Fx.emit('pxd_gm:server:start', 1)
        Fx.clearSent()
        Fx.advance(11)  -- termina la cuenta atrás de 10 s
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:spawn'), 'teletransporta al empezar')
        T.truthy(Fx.lastTo(2, 'pxd_gm:client:spawn'))

        for _ = 1, 20 do
            Fx.emit('baseevents:onPlayerKilled', 2, 1, {})
            Fx.time = Fx.time + 3.5   -- cada muerte es distinta (no duplicada)
        end
        Fx.advance(1)
        local ended = Fx.lastTo(1, 'pxd_gm:client:ended')
        T.truthy(ended, 'termina por puntos')
        T.eq(ended.args[1].winner.name, 'Nova')

        Fx.advance(13)  -- resultsSec = 12
        T.eq(Fx.players[1].bucket, 0, 'vuelve al mundo')
        local left = Fx.lastTo(1, 'pxd_gm:client:left')
        T.eq(left.args[1].x, 10, 'vuelve a su posición original')
    end)

    T.it('ignora bajas de un asesino lejano (evento falso)', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        Fx.movePlayer(1, { x = 5000, y = 5000, z = 0 })
        Fx.emit('baseevents:onPlayerKilled', 2, 1, {})
        local snap = Fx.lastTo(1, 'pxd_gm:client:match').args[1]
        for _, p in ipairs(snap.playersList) do
            if p.id == 1 then T.eq(p.kills, 0) end
        end
    end)

    T.it('carrera: crea vehículo en el bucket y valida checkpoints por distancia', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'race', 'colinas')
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        local veh = Fx.lastTo(1, 'pxd_gm:client:vehicle')
        T.truthy(veh, 'envía el vehículo')
        local vehEnt = veh.args[1] - 100000
        T.eq(Fx.entities[vehEnt].bucket, 60000)

        local cps = Config.arenas.colinas.checkpoints
        Fx.emit('pxd_gm:server:checkpoint', 1, 1)  -- lejos: rechazado
        T.falsy(Fx.lastTo(1, 'pxd_gm:client:checkpointOk'))
        T.truthy(Fx.logs[#Fx.logs]:find('rechazado'))

        for _ = 1, 2 do
            for i, cp in ipairs(cps) do
                Fx.movePlayer(1, cp)
                Fx.emit('pxd_gm:server:checkpoint', 1, i)
            end
        end
        Fx.advance(1)
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:ended'), 'termina al llegar el único corredor')
    end)

    T.it('al desconectarse se libera la partida y su vehículo', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'race', 'colinas')
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        local vehEnt = Fx.lastTo(1, 'pxd_gm:client:vehicle').args[1] - 100000
        Fx.emit('playerDropped', 1, 'quit')
        T.falsy(Fx.entities[vehEnt], 'borra el vehículo')
        local lobby = Fx.lastTo(-1, 'pxd_gm:client:lobby').args[1]
        T.eq(#lobby.matches, 0)
    end)

    T.it('respeta el permiso ACE para crear si está configurado', function()
        boot()
        Config.createAce = 'pxd.gamemodes.create'
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.eq(Fx.players[1].bucket, 0)
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:notify').args[1]:find('permiso'))
    end)

    T.it('rechaza argumentos con tipos incorrectos', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, { 'x' }, 'prueba')
        Fx.emit('pxd_gm:server:join', 1, 'uno')
        Fx.emit('pxd_gm:server:checkpoint', 1, 'a')
        T.eq(Fx.players[1].bucket, 0)
    end)

    T.it('usa arenas creadas como layout en pxd_props', function()
        boot({
            resourceStates = { pxd_props = 'started' },
            exports = { pxd_props = {
                GetLayout = function(id)
                    return { id = id, name = 'Mi arena', points = {
                        { kind = 'team1', x = 1, y = 1, z = 1 }, { kind = 'team2', x = 2, y = 2, z = 2 },
                        { kind = 'zone', x = 0, y = 0, z = 0, radius = 30 },
                    } }
                end,
                ListLayouts = function() return { { id = 'mi_arena', name = 'Mi arena', points = 3 } } end,
            } },
        })
        Fx.emit('pxd_gm:server:create', 1, 'koth', 'layout:mi_arena')
        local joined = Fx.lastTo(1, 'pxd_gm:client:joined')
        T.truthy(joined, 'crea la partida con el layout')
        T.eq(joined.args[1].arena.layout, 'mi_arena')
        local lobby = Fx.lastTo(-1, 'pxd_gm:client:lobby').args[1]
        local found = false
        for _, a in ipairs(lobby.arenas) do if a.id == 'layout:mi_arena' then found = true end end
        T.truthy(found, 'lista el layout como arena')
    end)

    T.it('no cuenta dos veces la misma muerte (baseevents + aviso del cliente)', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        Fx.emit('baseevents:onPlayerKilled', 2, 1, {})
        Fx.emit('pxd_gm:server:died', 2, 1)
        local snap = Fx.lastTo(1, 'pxd_gm:client:match').args[1]
        for _, p in ipairs(snap.playersList) do
            if p.id == 1 then T.eq(p.kills, 1) end
            if p.id == 2 then T.eq(p.deaths, 1) end
        end
    end)

    T.it('reaparecer: solo si está muerto y tras el tiempo de espera', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        Fx.clearSent()
        Fx.emit('pxd_gm:server:respawnMe', 2)
        T.falsy(Fx.lastTo(2, 'pxd_gm:client:spawn'), 'vivo: no reaparece')
        Fx.emit('baseevents:onPlayerKilled', 2, 1, {})
        Fx.emit('pxd_gm:server:respawnMe', 2)
        T.falsy(Fx.lastTo(2, 'pxd_gm:client:spawn'), 'demasiado pronto')
        Fx.advance(4)
        Fx.emit('pxd_gm:server:respawnMe', 2)
        T.truthy(Fx.lastTo(2, 'pxd_gm:client:spawn'), 'reaparece tras la espera')
        Fx.clearSent()
        Fx.advance(3)
        Fx.emit('pxd_gm:server:respawnMe', 2)
        T.falsy(Fx.lastTo(2, 'pxd_gm:client:spawn'), 'no se repite sin morir otra vez')
    end)
end)

T.describe('pxd_gamemodes · seguridad (P1)', function()
    local given
    local function bootArmed()
        boot()
        given = {}
        _G.RemoveAllPedWeapons = function(ped) given[#given + 1] = 'clear:' .. ped end
        _G.GiveWeaponToPed = function(ped, hash, ammo) given[#given + 1] = 'give:' .. ped .. ':' .. ammo end
        _G.SetPedArmour = function(ped, n) given[#given + 1] = 'armour:' .. ped .. ':' .. n end
    end

    T.it('límites al crear: una partida por anfitrión y espera entre creaciones', function()
        bootArmed()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:leave', 1)
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:notify').args[1]:find('Espera'), 'enfriamiento')
        Fx.advance(Config.createCooldownSec + 1)
        Fx.emit('pxd_gm:server:create', 2, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.clearSent()
        Fx.emit('pxd_gm:server:leave', 1)
        Fx.advance(Config.createCooldownSec + 1)
        Fx.emit('pxd_gm:server:create', 1, 'tdm', 'prueba')
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:joined'), 'tras salir puede volver a crear')
    end)

    T.it('armas: las da el servidor, una vez por cada spawn', function()
        bootArmed()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:loadout', 1)
        T.eq(#given, 0, 'sin spawn no hay armas')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:spawn'))
        Fx.emit('pxd_gm:server:loadout', 1)
        local n = #given
        T.truthy(n >= 2, 'quita y da armas')
        T.truthy(given[1]:find('^clear:'))
        Fx.emit('pxd_gm:server:loadout', 1)
        T.eq(#given, n, 'repetir la petición no da más munición')
    end)

    T.it('export LeavePlayer: saca al jugador y lo devuelve al mundo', function()
        bootArmed()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.eq(Fx.players[1].bucket, 60000)
        local leave = Fx.exports[Fx.resourceName].LeavePlayer
        T.eq(leave(1, 'Te ha sacado el staff.'), true)
        T.eq(Fx.players[1].bucket, 0)
        T.eq(leave(1), false, 'si no está en partida no hace nada')
    end)

    T.it('bajas: rechaza asesinos fuera del bucket, lejos o a ritmo imposible', function()
        bootArmed()
        Fx.addPlayer(3, 'Sol', { x = 12, y = 22, z = 30 })
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:join', 3, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        local function kills(id)
            local snap = Fx.lastTo(1, 'pxd_gm:client:match').args[1]
            for _, p in ipairs(snap.playersList) do if p.id == id then return p.kills end end
        end
        Fx.players[1].bucket = 0                                   -- fuera del bucket
        Fx.emit('baseevents:onPlayerKilled', 2, 1, {})
        T.eq(kills(1), 0, 'fuera del bucket no cuenta')
        Fx.players[1].bucket = 60000
        Fx.advance(4)
        Fx.movePlayer(1, { x = 5000, y = 5000, z = 30 })           -- demasiado lejos
        Fx.emit('baseevents:onPlayerKilled', 3, 1, {})
        T.eq(kills(1), 0, 'lejos no cuenta')
        Fx.movePlayer(1, { x = 10, y = 20, z = 30 })
        Fx.advance(4)
        for _ = 1, 3 do
            Fx.emit('baseevents:onPlayerKilled', 2, 1, {}); Fx.advance(0.1)
            Fx.emit('baseevents:onPlayerKilled', 3, 1, {}); Fx.advance(0.1)
        end
        T.truthy(kills(1) <= Config.killRate.max, 'no más bajas que el ritmo permitido')
        Fx.emit('baseevents:onPlayerKilled', 2, 2, {})
        T.truthy(kills(2) == 0, 'matarse a uno mismo no da baja')
    end)
end)

-- ── Modo Qbox (qbx_core + qbx_medical simulados) ───────────────────────────
local function bootQbox()
    local calls = { buckets = {}, revived = {} }
    boot({
        resourceStates = { qbx_core = 'started', qbx_medical = 'started' },
        exports = {
            qbx_core = {
                SetPlayerBucket = function(src, b) calls.buckets[#calls.buckets + 1] = { src, b }; Fx.players[src].bucket = b end,
                GetPlayer = function(src) return { PlayerData = { metadata = { ishandcuffed = src == 3 } } } end,
            },
            qbx_medical = {
                Revive = function(src) calls.revived[#calls.revived + 1] = src; Player(src).state.isDead = false end,
            },
        },
    })
    for id = 1, 2 do Player(id).state.isLoggedIn = true end
    return calls
end

T.describe('pxd_gamemodes con Qbox', function()
    T.it('usa SetPlayerBucket de Qbox al entrar y al salir', function()
        local calls = bootQbox()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.eq(calls.buckets[1][2], 60000)
        Fx.emit('pxd_gm:server:leave', 1)
        T.eq(calls.buckets[#calls.buckets][2], 0)
    end)

    T.it('no deja entrar sin personaje, herido o esposado', function()
        bootQbox()
        Player(1).state.isLoggedIn = false
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:notify').args[1]:find('personaje'))
        Player(1).state.isLoggedIn = true
        Player(1).state.isDead = true
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:notify').args[1]:find('herido'))
        Fx.addPlayer(3, 'Esposado', { x = 0, y = 0, z = 0 })
        Player(3).state.isLoggedIn = true
        Fx.emit('pxd_gm:server:create', 3, 'ffa', 'prueba')
        T.truthy(Fx.lastTo(3, 'pxd_gm:client:notify').args[1]:find('esposado'))
    end)

    T.it('caído en partida: cuenta la baja, revive con Qbox y reaparece', function()
        local calls = bootQbox()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        Player(2).state.isDead = true                -- Qbox lo deja «caído»
        Fx.emit('pxd_gm:server:died', 2, 1)          -- aviso del cliente
        Fx.advance(4)
        Fx.clearSent()
        Fx.emit('pxd_gm:server:respawnMe', 2)
        T.eq(calls.revived[1], 2, 'revive con qbx_medical')
        T.falsy(Fx.lastTo(2, 'pxd_gm:client:spawn'), 'espera a que Qbox termine')
        Fx.advance(1)
        T.truthy(Fx.lastTo(2, 'pxd_gm:client:spawn'), 'después lo mueve al spawn')
        local snap = Fx.lastTo(1, 'pxd_gm:client:match').args[1]
        for _, p in ipairs(snap.playersList) do if p.id == 1 then T.eq(p.kills, 1) end end
    end)

    T.it('al terminar la partida revive a quien siga caído', function()
        local calls = bootQbox()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        Fx.emit('pxd_gm:server:start', 1)
        Fx.advance(11)
        Player(2).state.isDead = true
        Fx.emit('pxd_gm:server:leave', 2)
        T.eq(calls.revived[1], 2)
        T.eq(Fx.players[2].bucket, 0)
    end)
end)
