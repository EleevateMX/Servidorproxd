-- pxd_update [check|force]
--   check  muestra qué cambiaría, sin tocar nada
--   force  también sobrescribe config.lua que hayas editado a mano
-- Descarga update-manifest.json del repo, baja solo lo que cambió, comprueba el
-- SHA-256 de cada archivo y, si todo está bien, escribe y reinicia los recursos.
local RES = GetCurrentResourceName()
local running = false

local function log(src, msg)
    if src == 0 then print('[pxd_updater] ' .. msg)
    else TriggerClientEvent('chat:addMessage', src, { args = { 'Actualizador', msg } }) end
end

local function encodePath(p)
    return (p:gsub('%[', '%%5B'):gsub('%]', '%%5D'):gsub(' ', '%%20'))
end

local function ref()
    local r = GetConvar(Config.refConvar, '')
    return r ~= '' and r or Config.defaultRef
end

local function fetch(path)
    local p = promise.new()
    local url = Config.rawBase .. encodePath(ref() .. '/' .. path) .. '?t=' .. os.time()
    PerformHttpRequest(url, function(code, body)
        p:resolve({ code = code, body = body })
    end, 'GET', '', {}, { followLocation = true })
    return Citizen.Await(p)
end

local function loadState()
    local raw = LoadResourceFile(RES, Config.stateFile)
    local data = raw and raw ~= '' and json.decode(raw)
    return type(data) == 'table' and data or {}
end

local function run(src, mode)
    if running then return log(src, 'Ya hay una actualización en curso.') end
    running = true
    local ok, err = pcall(function()
        log(src, ('Buscando actualizaciones (%s)…'):format(ref()))
        local r = fetch('update-manifest.json')
        local manifest = r.code == 200 and json.decode(r.body or '')
        if type(manifest) ~= 'table' or manifest.format ~= 1 or type(manifest.files) ~= 'table' then
            return log(src, ('No se pudo leer el manifiesto (HTTP %s).'):format(tostring(r.code)))
        end

        local state = loadState()
        local changes, skipped, missing = {}, {}, {}
        for _, f in ipairs(manifest.files) do
            local key = f.resource .. '/' .. f.path
            if GetResourceState(f.resource) == 'missing' then
                missing[f.resource] = true
            else
                local current = LoadResourceFile(f.resource, f.path)
                local curHash = current and PXDUpdater.sha256(current)
                if curHash ~= f.sha256 then
                    local edited = f.config and current and state[key] and curHash ~= state[key]
                    if edited and mode ~= 'force' then
                        skipped[#skipped + 1] = key
                    else
                        changes[#changes + 1] = f
                    end
                end
            end
        end

        -- Recursos nuevos (aún no existen en el servidor): se instalan enteros.
        local installs = {}
        for _, f in ipairs(manifest.files) do
            if missing[f.resource] and f.resource:match('^pxd_[%w_]+$') then
                if not installs[f.resource] then
                    installs[f.resource] = {}
                    installs[#installs + 1] = f.resource
                end
                local list = installs[f.resource]
                list[#list + 1] = f
            end
        end
        for _, name in ipairs(installs) do
            log(src, (' + recurso nuevo: %s (%d archivos)'):format(name, #installs[name]))
        end
        state.plan = type(manifest.plan) == 'table' and manifest.plan or state.plan
        for _, key in ipairs(skipped) do
            log(src, ('Se respeta %s porque lo editaste (usa «pxd_update force» para sobrescribirlo).'):format(key))
        end
        -- Arte que falte (imágenes/vídeo): solo si no existe ya en el servidor.
        local newAssets = {}
        for _, a in ipairs(type(manifest.assets) == 'table' and manifest.assets or {}) do
            if type(a.url) == 'string' and a.url:match('^https://') and GetResourceState(a.resource) ~= 'missing'
                and not LoadResourceFile(a.resource, a.path) then
                newAssets[#newAssets + 1] = a
            end
        end
        for _, a in ipairs(newAssets) do log(src, ' + arte: ' .. a.resource .. '/' .. a.path) end
        if #changes == 0 and #installs == 0 and mode ~= 'check' then
            SaveResourceFile(RES, Config.stateFile, json.encode(state), -1)
            PXDUpdater.applyPatches(src)
            PXDUpdater.startPlanned(src)
        end
        if #changes == 0 and #installs == 0 and #newAssets == 0 then return log(src, 'Todo está al día.') end
        if #changes == 0 and #installs > 0 then
            if mode == 'check' then
                return log(src, ('%d recurso(s) nuevo(s) por instalar. Ejecuta «pxd_update» para instalarlos.'):format(#installs))
            end
            -- Descarga y verificación en Lua (son archivos de texto); la escritura de
            -- carpetas nuevas la hace server/assets.js, porque SaveResourceFile solo
            -- escribe en recursos que ya existen.
            local packages = {}
            for _, name in ipairs(installs) do
                local files = {}
                for _, f in ipairs(installs[name]) do
                    local d = fetch('server-data/resources/[proxima]/' .. f.resource .. '/' .. f.path)
                    if d.code ~= 200 or type(d.body) ~= 'string' or #d.body ~= f.size or PXDUpdater.sha256(d.body) ~= f.sha256 then
                        return log(src, ('Descarga incorrecta de %s/%s (HTTP %s). No se ha instalado nada.'):format(f.resource, f.path, tostring(d.code)))
                    end
                    files[#files + 1] = { path = f.path, sha256 = f.sha256, body = d.body }
                    state[f.resource .. '/' .. f.path] = f.sha256
                end
                packages[#packages + 1] = { name = name, files = files }
            end
            SaveResourceFile(RES, Config.stateFile, json.encode(state), -1)
            TriggerEvent('pxd_updater:installResources', packages, src)
            return log(src, 'Instalando recursos nuevos… (los resultados aparecerán aquí)')
        end
        if mode == 'check' and #changes == 0 then
            return log(src, ('%d archivo(s) de arte por descargar. Ejecuta «pxd_update» para aplicarlos.'):format(#newAssets))
        end
        if #changes == 0 then
            -- La descarga binaria la hace server/assets.js (Node.js).
            TriggerEvent('pxd_updater:downloadAssets', newAssets, src)
            return log(src, 'Descargando arte… (los resultados aparecerán aquí)')
        end
        for _, f in ipairs(changes) do log(src, ' · ' .. f.resource .. '/' .. f.path) end
        if mode == 'check' then return log(src, ('%d archivo(s) por actualizar. Ejecuta «pxd_update» para aplicarlos.'):format(#changes)) end

        -- 1) Descarga y verificación de todo; 2) escritura solo si todo es correcto.
        local staged = {}
        for _, f in ipairs(changes) do
            local d = fetch('server-data/resources/[proxima]/' .. f.resource .. '/' .. f.path)
            if d.code ~= 200 or type(d.body) ~= 'string' or #d.body ~= f.size or PXDUpdater.sha256(d.body) ~= f.sha256 then
                return log(src, ('Descarga incorrecta de %s/%s (HTTP %s). No se ha cambiado nada.'):format(f.resource, f.path, tostring(d.code)))
            end
            staged[#staged + 1] = { f = f, body = d.body }
        end
        local touched, order = {}, {}
        for _, s in ipairs(staged) do
            if not SaveResourceFile(s.f.resource, s.f.path, s.body, #s.body) then
                return log(src, ('No se pudo escribir %s/%s.'):format(s.f.resource, s.f.path))
            end
            state[s.f.resource .. '/' .. s.f.path] = s.f.sha256
            if not touched[s.f.resource] then touched[s.f.resource] = true; order[#order + 1] = s.f.resource end
        end
        SaveResourceFile(RES, Config.stateFile, json.encode(state), -1)

        -- Reinicio de los recursos tocados (el propio actualizador, al final).
        -- `ensure` ejecuta stop/start con los permisos de quien lo llama (ACE command.stop
        -- y command.start); los natives StopResource/StartResource no los piden, pero no
        -- permiten pararse a uno mismo. Por eso el propio actualizador usa `ensure`.
        ExecuteCommand('refresh')
        local self = false
        for _, res in ipairs(order) do
            if res == RES then self = true
            elseif GetResourceState(res) == 'started' then
                StopResource(res)
                if not StartResource(res) then
                    log(src, ('No se pudo reiniciar %s: escribe «ensure %s» en la consola.'):format(res, res))
                end
            end
        end
        log(src, ('Listo: %d archivo(s) en %d recurso(s).'):format(#staged, #order))
        if #installs > 0 then log(src, 'Hay recursos nuevos por instalar: vuelve a ejecutar «pxd_update».') end
        if #newAssets > 0 then log(src, 'Hay arte nuevo por descargar: vuelve a ejecutar «pxd_update».') end
        if self then
            log(src, 'El actualizador también cambió: se reinicia ahora.')
            ExecuteCommand('ensure ' .. RES)
            -- Si se reinició, este temporizador ya no existe. Si sigue aquí, faltan permisos.
            SetTimeout(2000, function()
                log(src, ('No pude reiniciarme solo. Escribe «ensure %s» en la consola y luego «pxd_update».'):format(RES))
                log(src, ('Para que no vuelva a pasar, añade al server.cfg: add_ace resource.%s command.stop allow  y  add_ace resource.%s command.start allow'):format(RES, RES))
            end)
        end
    end)
    running = false
    if not ok then log(src, 'Error: ' .. tostring(err)) end
end

AddEventHandler('pxd_updater:assetLog', function(src, msg)
    log(tonumber(src) or 0, tostring(msg))
end)

--- Arranca los recursos del plan (manifest.plan.autostart, en orden) que no estén
--- iniciados, y para los que sustituyen (plan.replaces). Así no hace falta tocar el
--- server.cfg al añadir un recurso nuevo. StartResource/StopResource no piden ACE.
function PXDUpdater.startPlanned(src)
    local plan = (loadState().plan) or {}
    local replaces = type(plan.replaces) == 'table' and plan.replaces or {}
    for _, name in ipairs(type(plan.autostart) == 'table' and plan.autostart or {}) do
        local st = GetResourceState(name)
        if st ~= 'missing' then
            for _, old in ipairs(type(replaces[name]) == 'table' and replaces[name] or {}) do
                if GetResourceState(old) == 'started' then
                    StopResource(old)
                    log(src, ('%s sustituye a %s: %s detenido.'):format(name, old, old))
                end
            end
            if st ~= 'started' and st ~= 'starting' then
                if StartResource(name) then log(src, 'Iniciado ' .. name .. '.')
                else log(src, ('No se pudo iniciar %s: revisa la consola.'):format(name)) end
            end
        end
    end
end

--- Cambios de configuración en recursos de terceros (plan.patches): texto exacto
--- a sustituir, solo si el recurso que lo necesita está instalado. Requieren reiniciar
--- el servidor para aplicarse, porque el recurso parcheado ya está en marcha.
function PXDUpdater.applyPatches(src)
    local plan = (loadState().plan) or {}
    for _, p in ipairs(type(plan.patches) == 'table' and plan.patches or {}) do
        if type(p.resource) == 'string' and type(p.path) == 'string' and type(p.find) == 'string' and type(p.replace) == 'string'
            and GetResourceState(p.requires or p.resource) ~= 'missing' and GetResourceState(p.resource) ~= 'missing' then
            local text = LoadResourceFile(p.resource, p.path)
            if text and not text:find(p.replace, 1, true) then
                local i, j = text:find(p.find, 1, true)
                if i then
                    text = text:sub(1, i - 1) .. p.replace .. text:sub(j + 1)
                    if SaveResourceFile(p.resource, p.path, text, #text) then
                        log(src, ('Ajustado %s/%s (%s). Reinicia el servidor para aplicarlo.'):format(p.resource, p.path, p.why or 'configuración'))
                    end
                end
            end
        end
    end
end

AddEventHandler('pxd_updater:installDone', function(src, results)
    src = tonumber(src) or 0
    ExecuteCommand('refresh')
    local ok = 0
    for _, r in ipairs(type(results) == 'table' and results or {}) do
        if r.ok then ok = ok + 1 else log(src, ('No se pudo instalar %s: %s'):format(tostring(r.name), tostring(r.message))) end
    end
    log(src, ('Recursos nuevos instalados: %d.'):format(ok))
    PXDUpdater.applyPatches(src)
    PXDUpdater.startPlanned(src)
end)

-- Al encender el servidor: arranca lo que el plan diga (con un pequeño margen para
-- que termine de leer el server.cfg).
AddEventHandler('onResourceStart', function(name)
    if name ~= RES then return end
    SetTimeout(3000, function() PXDUpdater.startPlanned(0) end)
end)

RegisterCommand('pxd_update', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.ace) then return end
    local mode = args[1]
    CreateThread(function() run(src, mode) end)
end, false)

PXDUpdater.run = run   -- para pruebas
