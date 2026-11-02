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

        for res in pairs(missing) do
            log(src, ('Recurso nuevo «%s»: súbelo una vez a resources/[proxima]/ y añade ensure %s.'):format(res, res))
        end
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
        if #changes == 0 and #newAssets == 0 then return log(src, 'Todo está al día.') end
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
        ExecuteCommand('refresh')
        local self = false
        for _, res in ipairs(order) do
            if res == RES then self = true
            elseif GetResourceState(res) == 'started' then ExecuteCommand('ensure ' .. res) end
        end
        log(src, ('Listo: %d archivo(s) en %d recurso(s).'):format(#staged, #order))
        if #newAssets > 0 then log(src, 'Hay arte nuevo por descargar: vuelve a ejecutar «pxd_update».') end
        if self then
            log(src, 'El actualizador también cambió: se reinicia ahora.')
            ExecuteCommand('ensure ' .. RES)
        end
    end)
    running = false
    if not ok then log(src, 'Error: ' .. tostring(err)) end
end

AddEventHandler('pxd_updater:assetLog', function(src, msg)
    log(tonumber(src) or 0, tostring(msg))
end)

RegisterCommand('pxd_update', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.ace) then return end
    local mode = args[1]
    CreateThread(function() run(src, mode) end)
end, false)

PXDUpdater.run = run   -- para pruebas
