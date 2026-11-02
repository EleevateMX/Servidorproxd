-- Pruebas de pxd_updater: GitHub simulado, archivos de otros recursos y reinicios.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_updater/'
local BASE = 'https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/'
local function fileUrl(res, path) return BASE .. 'server-data/resources/%5Bproxima%5D/' .. res .. '/' .. path end

local sha
local function boot(remote, localFiles, states, extra)
    Fx.reset({ resourceName = 'pxd_updater', resourceStates = states or { pxd_login = 'started', pxd_props = 'started', pxd_updater = 'started' } })
    PXDUpdater = nil
    Config = nil
    Fx.load(DIR, { 'config.lua', 'shared/sha256.lua', 'shared/base64.lua', 'server/main.lua' })
    sha = PXDUpdater.sha256
    for k, v in pairs(localFiles or {}) do Fx.files[k] = v end
    local files = {}
    for _, f in ipairs(remote) do
        files[#files + 1] = { resource = f[1], path = f[2], size = #f[3], sha256 = sha(f[3]), config = f[2] == 'config.lua' or nil }
        Fx.http[fileUrl(f[1], f[2])] = { 200, f[3] }
    end
    local manifest = { format = 1, files = files }
    for k, v in pairs(extra or {}) do manifest[k] = v end
    Fx.http[BASE .. 'update-manifest.json'] = { 200, Fx.json.encode(manifest) }
end

local function run(mode)
    Fx.commands['pxd_update'](0, { mode })
    for _ = 1, 3 do Fx.advance(0) end
end

local function logged(pattern)
    for _, l in ipairs(Fx.logs) do if l:find(pattern) then return true end end
    return false
end

T.describe('pxd_updater', function()
    T.it('la huella SHA-256 coincide con la de Node', function()
        boot({})
        T.eq(sha('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
    end)

    T.it('check: lista cambios sin escribir nada', function()
        boot({ { 'pxd_login', 'server/main.lua', 'nuevo' } }, { ['pxd_login/server/main.lua'] = 'viejo' })
        run('check')
        T.eq(Fx.files['pxd_login/server/main.lua'], 'viejo')
        T.truthy(logged('1 archivo%(s%) por actualizar'))
    end)

    T.it('aplica: descarga, verifica, escribe y reinicia solo lo tocado', function()
        boot({
            { 'pxd_login', 'server/main.lua', 'nuevo login' },
            { 'pxd_props', 'client/main.lua', 'igual' },
        }, { ['pxd_login/server/main.lua'] = 'viejo', ['pxd_props/client/main.lua'] = 'igual' })
        run()
        T.eq(Fx.files['pxd_login/server/main.lua'], 'nuevo login')
        T.eq(Fx.executed[1], 'refresh')
        T.eq(#Fx.executed, 1, 'los demás recursos se reinician con natives, sin comandos')
        T.eq(table.concat(Fx.restarted, ','), 'stop pxd_login,start pxd_login', 'pxd_props no cambió: no se reinicia')
        local state = Fx.json.decode(Fx.files['data/installed.json'])
        T.eq(state['pxd_login/server/main.lua'], sha('nuevo login'))
    end)

    T.it('si una descarga no coincide con la huella, no cambia nada', function()
        boot({
            { 'pxd_login', 'a.lua', 'A2' },
            { 'pxd_login', 'b.lua', 'B2' },
        }, { ['pxd_login/a.lua'] = 'A1', ['pxd_login/b.lua'] = 'B1' })
        Fx.http[fileUrl('pxd_login', 'b.lua')] = { 200, 'B2-corrupto' }
        run()
        T.eq(Fx.files['pxd_login/a.lua'], 'A1', 'tampoco escribe el que sí estaba bien')
        T.truthy(logged('Descarga incorrecta'))
        T.eq(#Fx.executed, 0)
    end)

    T.it('respeta un config.lua editado a mano salvo con force', function()
        boot({ { 'pxd_login', 'config.lua', 'config v2' } }, {
            ['pxd_login/config.lua'] = 'config editado',
            ['data/installed.json'] = Fx.json.encode({ ['pxd_login/config.lua'] = 'hash-de-la-v1' }),
        })
        run()
        T.eq(Fx.files['pxd_login/config.lua'], 'config editado')
        T.truthy(logged('lo editaste'))
        run('force')
        T.eq(Fx.files['pxd_login/config.lua'], 'config v2')
    end)

    T.it('manifiesto ilegible: no hace nada', function()
        boot({})
        Fx.http[BASE .. 'update-manifest.json'] = { 500, 'error' }
        run()
        T.truthy(logged('No se pudo leer el manifiesto'))
        T.eq(#Fx.executed, 0)
    end)

    T.it('si cambia el propio actualizador, se reinicia al final', function()
        boot({ { 'pxd_updater', 'server/main.lua', 'v2' }, { 'pxd_login', 'x.lua', 'y' } }, {})
        run()
        T.eq(Fx.executed[#Fx.executed], 'ensure pxd_updater')
        T.truthy(logged('Escribe «ensure pxd_updater»'), 'si sigue vivo, explica qué hacer')
    end)

    T.it('pide a assets.js el arte que falte (y no el que ya existe)', function()
        boot({}, { ['pxd_loadscreen/html/assets/keyart.png'] = 'ya-estaba' }, { pxd_loadscreen = 'started', pxd_updater = 'started' })
        local asked
        AddEventHandler('pxd_updater:downloadAssets', function(list) asked = list end)
        Fx.http[BASE .. 'update-manifest.json'] = { 200, Fx.json.encode({ format = 1, files = {}, assets = {
            { resource = 'pxd_loadscreen', path = 'html/assets/ciudad-1.png', url = 'https://cdn.example/ciudad.png' },
            { resource = 'pxd_loadscreen', path = 'html/assets/keyart.png', url = 'https://cdn.example/keyart.png' },
        } }) }
        run('check')
        T.falsy(asked, 'check no descarga')
        run()
        T.eq(#asked, 1); T.eq(asked[1].path, 'html/assets/ciudad-1.png')
        TriggerEvent('pxd_updater:assetLog', 0, 'Arte descargado: 1 de 1.')
        T.truthy(logged('Arte descargado: 1 de 1'))
    end)

    T.it('recursos nuevos o de terceros que falten: avisa de que vienen en el paquete', function()
        boot({ { 'pxd_nuevo', 'fxmanifest.lua', 'fx' } }, {}, { pxd_updater = 'started' },
            { plan = { external = { { name = 'qbx_taxijob', repo = 'qbox-project/qbx_taxijob' } } } })
        run()
        T.truthy(logged('Falta el recurso nuevo «pxd_nuevo»: viene en el paquete'))
        T.truthy(logged('Falta «qbx_taxijob»'))
    end)

    T.it('si FXServer no deja escribir en otro recurso, dice qué permiso falta', function()
        boot({ { 'pxd_login', 'server/main.lua', 'nuevo' } }, { ['pxd_login/server/main.lua'] = 'viejo' })
        Fx.readOnly = { ['pxd_login/server/main.lua'] = true }
        run()
        T.truthy(logged('add_filesystem_permission pxd_updater write pxd_login'))
        T.eq(Fx.files['pxd_login/server/main.lua'], 'viejo')
    end)

    T.it('guarda el arte que llega en base64 desde assets.js (con bytes nulos)', function()
        boot({}, {}, { pxd_updater = 'started', pxd_loadscreen = 'started' })
        -- "\0\1\2PNG\255" en base64
        TriggerEvent('pxd_updater:writeAsset', 0, 'pxd_loadscreen', 'html/assets/a.png', 'AAECUE5H/w==', 1, 1)
        Fx.advance(0)
        T.eq(Fx.files['pxd_loadscreen/html/assets/a.png'], '\0\1\2PNG\255')
        T.truthy(logged('Arte: terminado'))
        TriggerEvent('pxd_updater:writeAsset', 0, 'pxd_loadscreen', '../server.lua', 'AAEC', 1, 1)
        Fx.advance(0)
        T.falsy(Fx.files['pxd_loadscreen/../server.lua'], 'ruta fuera de html/assets: no se escribe')
    end)

    T.it('base64: decodifica igual que Node (con y sin relleno)', function()
        boot({})
        T.eq(PXDUpdater.base64decode('aG9sYSDDsQ=='), 'hola ñ')
        T.eq(PXDUpdater.base64decode('YWJj'), 'abc')
        T.eq(PXDUpdater.base64decode('YWI='), 'ab')
    end)

    T.it('arranca lo del plan, parando lo que sustituye', function()
        boot({}, {}, { pxd_updater = 'started', pxd_nuevo = 'stopped', qbx_hud = 'started' },
            { plan = { autostart = { 'pxd_nuevo' }, replaces = { pxd_nuevo = { 'qbx_hud' } }, patches = {} } })
        run()   -- nada que actualizar: guarda el plan y lo aplica
        T.eq(table.concat(Fx.restarted, ','), 'stop qbx_hud,start pxd_nuevo')
    end)

    T.it('ajusta la configuración de terceros solo si hace falta', function()
        local patch = { resource = 'qbx_core', path = 'config/client.lua', find = 'useExternalCharacters = false',
            replace = 'useExternalCharacters = true', requires = 'pxd_multichar' }
        local cfg = 'characters = {\n    useExternalCharacters = false, -- comentario\n}'
        boot({}, { ['qbx_core/config/client.lua'] = cfg }, { pxd_updater = 'started', qbx_core = 'started' },
            { plan = { autostart = {}, replaces = {}, patches = { patch } } })
        run()
        T.eq(Fx.files['qbx_core/config/client.lua'], cfg, 'sin pxd_multichar no se toca')
        boot({}, { ['qbx_core/config/client.lua'] = cfg }, { pxd_updater = 'started', qbx_core = 'started', pxd_multichar = 'started' },
            { plan = { autostart = {}, replaces = {}, patches = { patch } } })
        run()
        T.truthy(Fx.files['qbx_core/config/client.lua']:find('useExternalCharacters = true, %-%- comentario'))
        T.truthy(logged('Reinicia el servidor'))
    end)

end)
