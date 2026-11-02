-- pxd_update [check | force [recurso/ruta] | backups | rollback [id] [force]]
--   check     muestra qué cambiaría, sin tocar nada (también copias y configs protegidas)
--   force     también sobrescribe archivos editables (config.lua, reglas…) que tengas
--             distintos; con «recurso/ruta» solo ese archivo
--   backups   lista las copias de seguridad
--   rollback  deshace una actualización (sin id: la última) usando su copia
-- Descarga update-manifest.json del repo, baja solo lo que cambió, comprueba el
-- SHA-256 de cada archivo y, si todo está bien, guarda una copia de lo que va a
-- cambiar, escribe (todo o nada) y reinicia los recursos.
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

local function run(src, mode, target)
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
                    local protect = f.config and current and PXDUpdater.isProtected(f, curHash, state[key])
                    local forced = mode == 'force' and (target == nil or target == key)
                    if protect and not forced then
                        skipped[#skipped + 1] = { key = key, why = protect }
                    else
                        changes[#changes + 1] = f
                    end
                end
            end
        end
        if mode == 'force' and target then
            local filtered = {}
            for _, f in ipairs(changes) do
                if not f.config or (f.resource .. '/' .. f.path) == target then filtered[#filtered + 1] = f end
            end
            changes = filtered
        end

        -- Recursos nuevos: FXServer no deja a un recurso crear carpetas de otros,
        -- así que se suben una vez con el paquete de instalación (docs/07).
        local installs = {}
        for name in pairs(missing) do
            if name:match('^pxd_[%w_]+$') then installs[#installs + 1] = name end
        end
        table.sort(installs)
        for _, name in ipairs(installs) do
            log(src, ('Falta el recurso nuevo «%s»: viene en el paquete de instalación (docs/07).'):format(name))
        end
        state.plan = type(manifest.plan) == 'table' and manifest.plan or state.plan
        state.overlays = type(manifest.overlays) == 'table' and manifest.overlays or state.overlays
        for _, sk in ipairs(skipped) do
            if sk.why == 'editado' then
                log(src, ('Se respeta %s porque lo editaste (usa «pxd_update force %s» para reemplazarlo; se guarda copia).'):format(sk.key, sk.key))
            else
                log(src, ('Se respeta tu versión de %s (no consta qué versión se instaló). Usa «pxd_update force %s» para reemplazarla; se guarda copia.'):format(sk.key, sk.key))
            end
        end
        if mode == 'check' then PXDUpdater.describeBackups(src) end
        -- Arte que falte (imágenes/vídeo): solo si no existe ya en el servidor.
        local newAssets = {}
        for _, a in ipairs(type(manifest.assets) == 'table' and manifest.assets or {}) do
            if type(a.url) == 'string' and a.url:match('^https://') and GetResourceState(a.resource) ~= 'missing'
                and not LoadResourceFile(a.resource, a.path) then
                newAssets[#newAssets + 1] = a
            end
        end
        for _, a in ipairs(newAssets) do log(src, ' + arte: ' .. a.resource .. '/' .. a.path) end
        -- Recursos de terceros del plan (trabajos de Qbox…) que aún no estén.
        local plan = type(manifest.plan) == 'table' and manifest.plan or {}
        for _, e in ipairs(type(plan.external) == 'table' and plan.external or {}) do
            if type(e) == 'table' and type(e.name) == 'string' and GetResourceState(e.name) == 'missing' then
                log(src, ('Falta «%s» (%s): viene en el paquete de instalación (docs/07).'):format(e.name, tostring(e.repo)))
            end
        end
        if #changes == 0 and mode ~= 'check' then
            SaveResourceFile(RES, Config.stateFile, json.encode(state), -1)
            local session = PXDUpdater.Backup.new(ref(), 'terceros')
            PXDUpdater.applyOverlays(src, session)
            PXDUpdater.applyPatches(src, session)
            local id = session:commit(Config.backupKeep)
            if id then log(src, ('Copia de seguridad de los cambios en terceros: %s («pxd_update rollback %s» para deshacerlos).'):format(id, id)) end
            PXDUpdater.startPlanned(src)
        elseif mode == 'check' then
            PXDUpdater.applyPatches(src, nil, true, plan)
        end
        if #changes == 0 and #newAssets == 0 then
            return log(src, #installs > 0 and 'Lo demás está al día.' or 'Todo está al día.')
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
        -- 3) Copia de seguridad + escritura transaccional: si una escritura falla, se
        --    deshacen las anteriores y no se toca installed.json.
        local session = PXDUpdater.Backup.new(ref(), 'update')
        local touched, order = {}, {}
        for _, s in ipairs(staged) do
            local okWrite, why = session:write(s.f.resource, s.f.path, s.body)
            if not okWrite then
                local restored, bad = session:revert()
                if why == 'copia' then
                    log(src, ('No se pudo guardar la copia de seguridad de %s/%s: no se escribe nada.'):format(s.f.resource, s.f.path))
                else
                    PXDUpdater.writeDenied(src, s.f.resource, s.f.path)
                end
                log(src, ('Actualización cancelada: se han restaurado %d archivo(s) ya escritos%s. No ha cambiado nada.'):format(
                    restored, bad > 0 and (' (%d no se pudieron restaurar: revisa la consola)'):format(bad) or ''))
                return
            end
            if not touched[s.f.resource] then touched[s.f.resource] = true; order[#order + 1] = s.f.resource end
        end
        for _, s in ipairs(staged) do state[s.f.resource .. '/' .. s.f.path] = s.f.sha256 end
        SaveResourceFile(RES, Config.stateFile, json.encode(state), -1)
        local id = session:commit(Config.backupKeep)

        log(src, ('Listo: %d archivo(s) en %d recurso(s). Copia de seguridad: %s («pxd_update rollback» para deshacer).'):format(#staged, #order, tostring(id)))
        if #newAssets > 0 then log(src, 'Hay arte nuevo por descargar: vuelve a ejecutar «pxd_update».') end
        PXDUpdater.restartTouched(src, order)
    end)
    running = false
    if not ok then log(src, 'Error: ' .. tostring(err)) end
end

AddEventHandler('pxd_updater:assetLog', function(src, msg)
    log(tonumber(src) or 0, tostring(msg))
end)

--- Reinicia los recursos pxd_* tocados (el propio actualizador, al final).
--- `ensure` ejecuta stop/start con los permisos de quien lo llama (ACE command.stop
--- y command.start); los natives StopResource/StartResource no los piden, pero no
--- permiten pararse a uno mismo. Por eso el propio actualizador usa `ensure`.
function PXDUpdater.restartTouched(src, order)
    ExecuteCommand('refresh')
    local self, third = false, {}
    for _, res in ipairs(order) do
        if res == RES then self = true
        elseif not res:match('^pxd_') then third[#third + 1] = res
        elseif GetResourceState(res) == 'started' then
            StopResource(res)
            if not StartResource(res) then
                log(src, ('No se pudo reiniciar %s: escribe «ensure %s» en la consola.'):format(res, res))
            end
        end
    end
    if #third > 0 then
        log(src, ('Cambiaron archivos de %s: reinicia el servidor (sin jugadores) para aplicarlos.'):format(table.concat(third, ', ')))
    end
    if self then
        log(src, 'El actualizador también cambió: se reinicia ahora.')
        ExecuteCommand('ensure ' .. RES)
        -- Si se reinició, este temporizador ya no existe. Si sigue aquí, faltan permisos.
        SetTimeout(2000, function()
            log(src, ('No pude reiniciarme solo. Escribe «ensure %s» en la consola y luego «pxd_update».'):format(RES))
            log(src, ('Para que no vuelva a pasar, añade al server.cfg: add_ace resource.%s command.stop allow  y  add_ace resource.%s command.start allow'):format(RES, RES))
        end)
    end
end

--- ¿Se debe respetar un archivo editable (config.lua, reglas…) con hash `curHash`?
--- Devuelve nil (se puede actualizar), 'editado' o 'desconocido'.
---  · Hay hash instalado y coincide → no lo tocaste → se actualiza.
---  · Hay hash instalado y no coincide → lo editaste → se respeta.
---  · No hay hash instalado (primera vez, paquete o receta): solo se actualiza si
---    coincide con una versión publicada antes (f.known); si no, se respeta.
function PXDUpdater.isProtected(f, curHash, installedHash)
    if installedHash then
        return curHash ~= installedHash and 'editado' or nil
    end
    for _, h in ipairs(type(f.known) == 'table' and f.known or {}) do
        if h == curHash then return nil end
    end
    return 'desconocido'
end

--- Resumen de copias de seguridad (para «check» y «backups»).
function PXDUpdater.describeBackups(src, full)
    local ids = PXDUpdater.Backup.list()
    if #ids == 0 then return log(src, 'Copias de seguridad: ninguna todavía.') end
    log(src, ('Copias de seguridad: %d (la última: %s). «pxd_update rollback» deshace la última.'):format(#ids, ids[#ids]))
    if not full then return end
    for i = #ids, 1, -1 do
        local idx = PXDUpdater.Backup.read(ids[i])
        if idx then
            log(src, (' · %s — %s, %s, %d archivo(s), %s'):format(idx.id, idx.fecha or '?', idx.motivo or '?', #(idx.archivos or {}), idx.estado or '?'))
        end
    end
end

--- Deshace una copia (sin id: la última aplicada). Valida que cada archivo siga como lo
--- dejó la actualización; si alguien lo cambió después, lo omite salvo con force.
--- Lo restaurado se guarda a su vez en una copia nueva (se puede deshacer el rollback).
function PXDUpdater.rollback(src, id, force)
    local ids = PXDUpdater.Backup.list()
    if not id then
        for i = #ids, 1, -1 do
            local idx = PXDUpdater.Backup.read(ids[i])
            if idx and (idx.estado == 'aplicada' or idx.estado == 'parcial') and idx.motivo ~= 'rollback' then id = ids[i]; break end
        end
    end
    local idx = id and PXDUpdater.Backup.read(id)
    if not idx then return log(src, ('No existe la copia %s. Usa «pxd_update backups» para verlas.'):format(tostring(id))) end
    if idx.estado ~= 'aplicada' and idx.estado ~= 'parcial' then
        return log(src, ('La copia %s está «%s»: no se puede restaurar.'):format(id, tostring(idx.estado)))
    end
    local session = PXDUpdater.Backup.new('rollback-' .. id, 'rollback')
    local state = loadState()
    local touched, order, restored, omitted = {}, {}, 0, 0
    for i = #idx.archivos, 1, -1 do
        local e = idx.archivos[i]
        if not e.fallo then
            local current = LoadResourceFile(e.resource, e.path)
            local curHash = current and PXDUpdater.sha256(current)
            if curHash ~= e.sha256Despues and not force then
                omitted = omitted + 1
                log(src, ('Se omite %s/%s: cambió después de la actualización (usa «pxd_update rollback %s force»).'):format(e.resource, e.path, id))
            else
                local prev = PXDUpdater.Backup.content(id, e)
                if e.existia and not prev then
                    omitted = omitted + 1
                    log(src, ('Falta la copia de %s/%s: no se puede restaurar.'):format(e.resource, e.path))
                else
                    local okWrite, why = session:write(e.resource, e.path, prev or '')
                    if not okWrite then
                        local back = session:revert()
                        if why == 'escritura' then PXDUpdater.writeDenied(src, e.resource, e.path) end
                        return log(src, ('Vuelta atrás cancelada: se dejaron %d archivo(s) como estaban.'):format(back))
                    end
                    if not e.existia then
                        log(src, ('%s/%s no existía antes: se ha vaciado (FXServer no deja borrarlo; puedes eliminarlo a mano).'):format(e.resource, e.path))
                    end
                    if e.resource:match('^pxd_') then
                        state[e.resource .. '/' .. e.path] = e.sha256Antes
                    end
                    restored = restored + 1
                    if not touched[e.resource] then touched[e.resource] = true; order[#order + 1] = e.resource end
                end
            end
        end
    end
    SaveResourceFile(RES, Config.stateFile, json.encode(state), -1)
    local newId = session:commit(Config.backupKeep)
    -- Si se omitió algo, queda «parcial» (se puede repetir con force); si no, «restaurada».
    if restored > 0 or omitted == 0 then idx.estado = omitted > 0 and 'parcial' or 'restaurada' end
    local text = json.encode(idx)
    SaveResourceFile(RES, PXDUpdater.backupPaths.index(id), text, #text)
    log(src, ('Vuelta atrás de %s: %d archivo(s) restaurados, %d omitidos. Copia de lo deshecho: %s.'):format(id, restored, omitted, tostring(newId)))
    if restored > 0 then PXDUpdater.restartTouched(src, order) end
end

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
function PXDUpdater.applyPatches(src, session, dryRun, planOverride)
    local plan = planOverride or (loadState().plan) or {}
    for _, p in ipairs(type(plan.patches) == 'table' and plan.patches or {}) do
        if type(p.resource) == 'string' and type(p.path) == 'string' and type(p.find) == 'string' and type(p.replace) == 'string'
            and GetResourceState(p.requires or p.resource) ~= 'missing' and GetResourceState(p.resource) ~= 'missing' then
            local version = PXDUpdater.resourceVersion(p.resource)
            local text = LoadResourceFile(p.resource, p.path)
            if p.requiresVersion and version ~= p.requiresVersion then
                log(src, ('%s está en la versión %s y el ajuste «%s» es para la %s: no se aplica.'):format(
                    p.resource, tostring(version), p.why or p.path, p.requiresVersion))
            elseif not text then
                log(src, ('No se encuentra %s/%s: el ajuste «%s» no se aplica.'):format(p.resource, p.path, p.why or p.path))
            elseif not text:find(p.replace, 1, true) then
                local i, j = text:find(p.find, 1, true)
                if not i then
                    log(src, ('AVISO: en %s/%s no está el texto esperado para «%s»: probablemente es otra versión. No se aplica.'):format(
                        p.resource, p.path, p.why or 'ajuste'))
                elseif dryRun then
                    log(src, (' ~ ajuste pendiente: %s/%s (%s)'):format(p.resource, p.path, p.why or 'configuración'))
                else
                    text = text:sub(1, i - 1) .. p.replace .. text:sub(j + 1)
                    local okWrite, why
                    if session then okWrite, why = session:write(p.resource, p.path, text)
                    else okWrite = SaveResourceFile(p.resource, p.path, text, #text) end
                    if okWrite then
                        log(src, ('Ajustado %s/%s (%s). Reinicia el servidor para aplicarlo.'):format(p.resource, p.path, p.why or 'configuración'))
                    elseif why == 'copia' then
                        log(src, ('No se pudo guardar la copia de %s/%s: el ajuste no se aplica.'):format(p.resource, p.path))
                    else
                        PXDUpdater.writeDenied(src, p.resource, p.path)
                    end
                end
            end
        end
    end
end

--- Versión declarada en el fxmanifest.lua de un recurso (version '1.2.3').
function PXDUpdater.resourceVersion(res)
    local text = LoadResourceFile(res, 'fxmanifest.lua')
    return text and text:match("\nversion%s*['\"]([^'\"]+)['\"]") or nil
end

local function safePath(p)
    return type(p) == 'string' and p:match('^[%w_%-%./]+$') ~= nil and not p:find('%.%.') and p:sub(1, 1) ~= '/'
end

--- Overlays: archivos de un recurso pxd_* (ya actualizado en el servidor) que se copian
--- a un recurso de terceros (p. ej. la capa visual del inventario en ox_inventory).
--- Solo si la versión instalada coincide y la copia local tiene la huella esperada.
--- No reinicia el recurso de terceros: eso lo hace el reinicio del servidor.
function PXDUpdater.applyOverlays(src, session)
    local overlays = loadState().overlays
    local written, warned = 0, {}
    for _, o in ipairs(type(overlays) == 'table' and overlays or {}) do
        local from = type(o.from) == 'table' and o.from or {}
        if type(o.resource) == 'string' and safePath(o.path) and type(from.resource) == 'string'
            and from.resource:match('^pxd_[%w_]+$') and safePath(from.path) and type(o.sha256) == 'string'
            and GetResourceState(o.resource) ~= 'missing' and GetResourceState(from.resource) ~= 'missing' then
            local version = PXDUpdater.resourceVersion(o.resource)
            if o.requiresVersion and version ~= o.requiresVersion then
                if not warned[o.resource] then
                    warned[o.resource] = true
                    log(src, ('%s está en la versión %s y la capa de Próxima es para la %s: no se aplica.'):format(o.resource, tostring(version), o.requiresVersion))
                end
            else
                local body = LoadResourceFile(from.resource, from.path)
                local current = LoadResourceFile(o.resource, o.path)
                if not body or PXDUpdater.sha256(body) ~= o.sha256 then
                    log(src, ('%s/%s aún no está al día: ejecuta «pxd_update» otra vez.'):format(from.resource, from.path))
                elseif not current or PXDUpdater.sha256(current) ~= o.sha256 then
                    local okWrite, why
                    if session then okWrite, why = session:write(o.resource, o.path, body)
                    else okWrite = SaveResourceFile(o.resource, o.path, body, #body) end
                    if okWrite then
                        written = written + 1
                    elseif why == 'copia' then
                        log(src, ('No se pudo guardar la copia de %s/%s: la capa no se aplica.'):format(o.resource, o.path))
                    else
                        PXDUpdater.writeDenied(src, o.resource, o.path)
                    end
                end
            end
        end
    end
    if written > 0 then
        log(src, ('Capa visual aplicada (%d archivo(s)). Reinicia el servidor para verla (ox_inventory solo recarga su interfaz al arrancar).'):format(written))
    end
    return written
end

--- FXServer solo deja a un recurso escribir en otro si el server.cfg lo permite
--- (add_filesystem_permission, solo se puede poner antes de que termine de arrancar).
function PXDUpdater.writeDenied(src, res, path)
    log(src, ('No se pudo escribir %s/%s: falta el permiso. Añade al server.cfg y reinicia:'):format(res, path))
    log(src, ('  add_filesystem_permission %s write %s'):format(RES, res))
end

-- Arte descargado por server/assets.js (base64): se escribe aquí con SaveResourceFile.
AddEventHandler('pxd_updater:writeAsset', function(src, res, path, b64, total, index)
    src = tonumber(src) or 0
    if type(res) ~= 'string' or not res:match('^pxd_[%w_]+$') or type(path) ~= 'string'
        or not path:match('^html/assets/[%w%._%-]+$') or type(b64) ~= 'string' then return end
    CreateThread(function()
        local data = PXDUpdater.base64decode(b64, function() Wait(0) end)
        if SaveResourceFile(res, path, data, #data) then
            log(src, ('Arte guardado: %s (%d KB).'):format(path, #data // 1024))
        else
            PXDUpdater.writeDenied(src, res, path)
        end
        if index == total then log(src, 'Arte: terminado. Se verá al reconectar.') end
    end)
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
    if mode == 'backups' then return PXDUpdater.describeBackups(src, true) end
    if mode == 'rollback' then
        if running then return log(src, 'Ya hay una actualización en curso.') end
        local id, force = args[2], args[3] == 'force'
        if id == 'force' then id, force = nil, true end
        running = true
        CreateThread(function()
            local ok, err = pcall(PXDUpdater.rollback, src, id, force)
            running = false
            if not ok then log(src, 'Error: ' .. tostring(err)) end
        end)
        return
    end
    local target = mode == 'force' and args[2] or nil
    CreateThread(function() run(src, mode, target) end)
end, false)

PXDUpdater.run = run   -- para pruebas
