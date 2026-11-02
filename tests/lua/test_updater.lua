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
    Fx.load(DIR, { 'config.lua', 'shared/sha256.lua', 'shared/base64.lua', 'server/backup.lua', 'server/main.lua' })
    sha = PXDUpdater.sha256
    for k, v in pairs(localFiles or {}) do Fx.files[k] = v end
    local files = {}
    for _, f in ipairs(remote) do
        local o = f[4] or {}
        files[#files + 1] = { resource = f[1], path = f[2], size = #f[3], sha256 = sha(f[3]),
            config = (f[2] == 'config.lua' or o.config) or nil, known = o.known }
        Fx.http[fileUrl(f[1], f[2])] = { 200, f[3] }
    end
    local manifest = { format = 1, files = files }
    for k, v in pairs(extra or {}) do manifest[k] = v end
    Fx.http[BASE .. 'update-manifest.json'] = { 200, Fx.json.encode(manifest) }
end

local function run(mode, ...)
    Fx.readOnlyKeep = nil
    Fx.commands['pxd_update'](0, { mode, ... })
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


    T.it('overlays: copia la capa a ox_inventory solo con la versión correcta', function()
        local css = 'body{}'
        local overlay = { resource = 'ox_inventory', path = 'web/build/assets/pxd.css', requiresVersion = '2.48.1',
            from = { resource = 'pxd_inventory', path = 'overlay/ox_inventory/pxd.css' }, size = #css }
        local files = { ['pxd_inventory/overlay/ox_inventory/pxd.css'] = css,
            ['ox_inventory/fxmanifest.lua'] = "fx_version 'cerulean'\nname 'ox_inventory'\nversion '2.48.1'\n" }
        local states = { pxd_updater = 'started', ox_inventory = 'started', pxd_inventory = 'started' }
        boot({}, files, states, { overlays = { overlay } })
        overlay.sha256 = sha(css)
        Fx.http[BASE .. 'update-manifest.json'] = { 200, Fx.json.encode({ format = 1, files = {}, overlays = { overlay } }) }
        run()
        T.eq(Fx.files['ox_inventory/web/build/assets/pxd.css'], css)
        T.truthy(logged('Capa visual aplicada %(1'))
        -- otra versión de ox_inventory: no se toca
        files['ox_inventory/fxmanifest.lua'] = "fx_version 'cerulean'\nversion '2.49.0'\n"
        boot({}, files, states)
        Fx.http[BASE .. 'update-manifest.json'] = { 200, Fx.json.encode({ format = 1, files = {}, overlays = { overlay } }) }
        run()
        T.falsy(Fx.files['ox_inventory/web/build/assets/pxd.css'])
        T.truthy(logged('versión 2.49.0'))
        -- sin permiso de escritura: dice qué línea falta
        files['ox_inventory/fxmanifest.lua'] = "fx_version 'cerulean'\nversion '2.48.1'\n"
        boot({}, files, states)
        Fx.readOnly = { ['ox_inventory/web/build/assets/pxd.css'] = true }
        Fx.http[BASE .. 'update-manifest.json'] = { 200, Fx.json.encode({ format = 1, files = {}, overlays = { overlay } }) }
        run()
        T.truthy(logged('add_filesystem_permission pxd_updater write ox_inventory'))
    end)

    -- ── Copias de seguridad, vuelta atrás y archivos protegidos ─────────────────

    local function index(id) return Fx.json.decode(Fx.files['data/bk_' .. id .. '.json']) end
    local function lastId()
        local l = Fx.json.decode(Fx.files['data/backups.json'])
        return l.ids[#l.ids], l.ids
    end

    T.it('guarda copia antes de escribir y «rollback» la restaura (y el estado instalado)', function()
        boot({ { 'pxd_login', 'server/main.lua', 'nuevo' }, { 'pxd_login', 'shared/x.lua', 'creado' } },
            { ['pxd_login/server/main.lua'] = 'viejo' })
        Fx.readOnly = nil
        run()
        T.eq(Fx.files['pxd_login/server/main.lua'], 'nuevo')
        local id = lastId()
        local idx = index(id)
        T.eq(idx.estado, 'aplicada'); T.eq(idx.motivo, 'update'); T.eq(#idx.archivos, 2)
        local a = idx.archivos[1]
        T.eq(a.resource, 'pxd_login'); T.eq(a.sha256Antes, sha('viejo')); T.eq(a.sha256Despues, sha('nuevo')); T.eq(a.existia, true)
        T.eq(Fx.files['data/bk_' .. id .. '_' .. a.copia], 'viejo')
        T.eq(idx.archivos[2].existia, false)
        T.truthy(logged('Copia de seguridad: ' .. id:gsub('%-', '%%-')))
        Fx.restarted = {}
        run('rollback')
        T.eq(Fx.files['pxd_login/server/main.lua'], 'viejo')
        T.eq(Fx.files['pxd_login/shared/x.lua'], '', 'lo que no existía se vacía (no se puede borrar)')
        T.truthy(logged('no existía antes'))
        T.eq(index(id).estado, 'restaurada')
        local state = Fx.json.decode(Fx.files['data/installed.json'])
        T.eq(state['pxd_login/server/main.lua'], sha('viejo'))
        T.eq(table.concat(Fx.restarted, ','), 'stop pxd_login,start pxd_login')
        local newest, ids = lastId()
        T.eq(index(newest).motivo, 'rollback', 'el rollback también deja copia (se puede deshacer)')
        T.eq(#ids, 2)
    end)

    T.it('escritura transaccional: si falla una, deshace las anteriores y no toca installed.json', function()
        boot({ { 'pxd_login', 'a.lua', 'A2' }, { 'pxd_login', 'b.lua', 'B2' } },
            { ['pxd_login/a.lua'] = 'A1', ['pxd_login/b.lua'] = 'B1' })
        Fx.readOnly = { ['pxd_login/b.lua'] = true }
        run()
        Fx.readOnly = nil
        T.eq(Fx.files['pxd_login/a.lua'], 'A1', 'se restauró la que sí se escribió')
        T.eq(Fx.files['pxd_login/b.lua'], 'B1')
        T.falsy(Fx.files['data/installed.json'])
        T.truthy(logged('Actualización cancelada: se han restaurado 1'))
        T.falsy(Fx.files['data/backups.json'], 'una sesión deshecha no queda como copia aplicable')
        T.eq(#Fx.executed, 0, 'no reinicia nada')
    end)

    T.it('si no se puede guardar la copia, no escribe nada', function()
        boot({ { 'pxd_login', 'a.lua', 'A2' } }, { ['pxd_login/a.lua'] = 'A1' })
        Fx.readOnly = setmetatable({}, { __index = function(_, k) return k:find('^data/bk_') ~= nil end })
        run()
        Fx.readOnly = nil
        T.eq(Fx.files['pxd_login/a.lua'], 'A1')
        T.truthy(logged('No se pudo guardar la copia de seguridad'))
    end)

    T.it('archivos editables sin versión instalada conocida: se respetan salvo versión publicada o force', function()
        local remote = { { 'pxd_panel', 'shared/rules.lua', 'reglas v3', { config = true, known = { sha('reglas v1'), sha('reglas v2') } } } }
        local st = { pxd_panel = 'started', pxd_login = 'started', pxd_updater = 'started' }
        -- 1) editado por el dueño y sin installed.json (paquete/receta): se respeta
        boot(remote, { ['pxd_panel/shared/rules.lua'] = 'mis reglas' }, st)
        Fx.readOnly = nil
        run()
        T.eq(Fx.files['pxd_panel/shared/rules.lua'], 'mis reglas')
        T.truthy(logged('Se respeta tu versión de pxd_panel/shared/rules.lua'))
        run('check')
        T.truthy(logged('Se respeta tu versión'))
        -- 2) es una versión publicada antes (sin editar): se actualiza
        boot(remote, { ['pxd_panel/shared/rules.lua'] = 'reglas v2' }, st)
        run()
        T.eq(Fx.files['pxd_panel/shared/rules.lua'], 'reglas v3')
        -- 3) force con ruta: solo ese archivo, con copia
        boot({ remote[1], { 'pxd_login', 'config.lua', 'cfg nuevo' } },
            { ['pxd_panel/shared/rules.lua'] = 'mis reglas', ['pxd_login/config.lua'] = 'cfg mio' }, st)
        run('force', 'pxd_panel/shared/rules.lua')
        T.eq(Fx.files['pxd_panel/shared/rules.lua'], 'reglas v3')
        T.eq(Fx.files['pxd_login/config.lua'], 'cfg mio', 'el otro editable sigue protegido')
        local idx = index(lastId())
        T.eq(Fx.files['data/bk_' .. idx.id .. '_' .. idx.archivos[1].copia], 'mis reglas')
    end)

    T.it('rollback omite archivos cambiados después (salvo force) y lista las copias', function()
        boot({ { 'pxd_login', 'a.lua', 'A2' } }, { ['pxd_login/a.lua'] = 'A1' })
        run()
        Fx.files['pxd_login/a.lua'] = 'A3 editado a mano'
        run('rollback')
        T.eq(Fx.files['pxd_login/a.lua'], 'A3 editado a mano')
        T.truthy(logged('Se omite pxd_login/a.lua'))
        local id = lastId()
        run('rollback', id, 'force')
        T.eq(Fx.files['pxd_login/a.lua'], 'A1')
        Fx.logs = {}
        run('backups')
        T.truthy(logged('Copias de seguridad: 2'))
        T.truthy(logged('restaurada'))
        run('rollback', 'no-existe')
        T.truthy(logged('No existe la copia no%-existe'))
    end)

    T.it('poda: guarda solo las últimas copias (Config.backupKeep)', function()
        boot({}, {})
        Config.backupKeep = 2
        for i = 1, 3 do
            local s = PXDUpdater.Backup.new('ref' .. i, 'update')
            T.truthy(s:write('pxd_login', 'f.lua', 'v' .. i))
            s:commit(Config.backupKeep)
        end
        local _, ids = lastId()
        T.eq(#ids, 2)
        local first = ids[1]
        T.truthy(first:find('ref2'), 'la más antigua se podó')
    end)

    T.it('parches: copia antes de ajustar, aviso si no encuentra el texto y requiresVersion', function()
        local patch = { resource = 'qbx_core', path = 'config/server.lua', find = "dontAllowMinus = { 'cash', 'crypto' }",
            replace = "dontAllowMinus = { 'cash', 'crypto', 'bank' }", requires = 'qbx_core', requiresVersion = '1.24.1', why = 'banco sin negativo' }
        local cfg = "money = {\n  dontAllowMinus = { 'cash', 'crypto' },\n}"
        local fx = "fx_version 'cerulean'\nversion '1.24.1'\n"
        local states = { pxd_updater = 'started', qbx_core = 'started' }
        boot({}, { ['qbx_core/config/server.lua'] = cfg, ['qbx_core/fxmanifest.lua'] = fx }, states, { plan = { patches = { patch } } })
        Fx.readOnly = nil
        run('check')
        T.eq(Fx.files['qbx_core/config/server.lua'], cfg, 'check no toca')
        T.truthy(logged('ajuste pendiente: qbx_core/config/server.lua'))
        run()
        T.truthy(Fx.files['qbx_core/config/server.lua']:find("'bank'"))
        local id = lastId()
        T.eq(index(id).motivo, 'terceros')
        run('rollback')
        T.eq(Fx.files['qbx_core/config/server.lua'], cfg, 'la vuelta atrás deshace el parche')
        T.truthy(logged('reinicia el servidor'))
        -- otra versión: no se aplica y avisa
        boot({}, { ['qbx_core/config/server.lua'] = cfg, ['qbx_core/fxmanifest.lua'] = "fx_version 'cerulean'\nversion '1.25.0'\n" },
            states, { plan = { patches = { patch } } })
        run()
        T.eq(Fx.files['qbx_core/config/server.lua'], cfg)
        T.truthy(logged('versión 1.25.0'))
        -- texto no encontrado: aviso claro
        boot({}, { ['qbx_core/config/server.lua'] = 'otra cosa', ['qbx_core/fxmanifest.lua'] = fx }, states, { plan = { patches = { patch } } })
        run()
        T.truthy(logged('AVISO: en qbx_core/config/server.lua no está el texto esperado'))
    end)
end)
