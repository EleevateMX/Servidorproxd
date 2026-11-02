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
        'shared/modes/race.lua', 'server/main.lua',
    })
    Fx.addPlayer(1, 'Nova', { x = 10, y = 20, z = 30 })
    Fx.addPlayer(2, 'Lumen', { x = 11, y = 21, z = 30 })
end

T.describe('pxd_gamemodes servidor', function()
    T.it('crear partida mete al jugador en un bucket aislado sin población', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        T.eq(Fx.players[1].bucket, 1000)
        T.eq(Fx.buckets[1000].population, false)
        T.eq(Fx.buckets[1000].lockdown, 'relaxed')
        local joined = Fx.lastTo(1, 'pxd_gm:client:joined')
        T.truthy(joined, 'envía joined')
        T.eq(joined.args[1].mode, 'ffa')
        T.eq(#Fx.sentTo(-1, 'pxd_gm:client:lobby') > 0, true, 'difunde el lobby')
    end)

    T.it('flujo completo: unirse, iniciar, cuenta atrás, bajas, fin y regreso', function()
        boot()
        Fx.emit('pxd_gm:server:create', 1, 'ffa', 'prueba')
        Fx.emit('pxd_gm:server:join', 2, 1)
        T.eq(Fx.players[2].bucket, 1000)

        Fx.emit('pxd_gm:server:start', 2)
        T.truthy(Fx.lastTo(2, 'pxd_gm:client:notify').args[1]:find('anfitrión'), 'solo el anfitrión inicia')

        Fx.emit('pxd_gm:server:start', 1)
        Fx.clearSent()
        Fx.advance(11)  -- termina la cuenta atrás de 10 s
        T.truthy(Fx.lastTo(1, 'pxd_gm:client:spawn'), 'teletransporta al empezar')
        T.truthy(Fx.lastTo(2, 'pxd_gm:client:spawn'))

        for _ = 1, 20 do Fx.emit('baseevents:onPlayerKilled', 2, 1, {}) end
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
        T.eq(Fx.entities[vehEnt].bucket, 1000)

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
end)
