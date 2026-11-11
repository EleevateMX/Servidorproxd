-- pxd_garage (servidor): taller de personalización con cobro seguro y niveles de mecánico.
-- El cliente solo propone cambios (clave → valor). Aquí se valida la zona, el vehículo y el dueño,
-- se recalcula el precio con lo guardado en qbx_vehicles, se cobra y se guarda. docs/44-vehiculos.md
local G, Store = PXDGarage, PXDGarageStore
local MSG = G.MESSAGES

local ready = false
local sessions = {}     -- [src] = { zone, veh, plate, vehicleId, owner, mode, base, at }
local busy = {}
local lastCall = {}
local repairSeen = {}   -- ['PLATE|pieza'] = { level = último nivel, at = última experiencia }

local function now() return os.time() end
local function started(res) return GetResourceState(res) == 'started' end

local function getPlayer(src)
    if not started('qbx_core') then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function playerByCitizen(cid)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    return ok and p or nil
end

local function fullName(p)
    local c = p and p.PlayerData and p.PlayerData.charinfo or {}
    local n = ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or nil
end

local function notify(src, text, kind)
    if not src or src <= 0 or not started('qbx_core') then return end
    pcall(function() exports.qbx_core:Notify(src, text, kind or 'inform') end)
end

local function money(n) return '$' .. tostring(math.floor(n)) end

local function throttled(src)
    local t = GetGameTimer() / 1000
    if lastCall[src] and t - lastCall[src] < (Config.cooldown or 1.0) then return true end
    lastCall[src] = t
    return false
end

local function audit(action, actor, target, data)
    if not started('pxd_audit') then return end
    pcall(function() exports.pxd_audit:Log({ category = 'taller', action = action, actor = actor, target = target, data = data }) end)
end

-- ── Mecánicos ─────────────────────────────────────────────
local function isMechanic(player)
    local job = player and player.PlayerData and player.PlayerData.job
    return job ~= nil and Config.mechanic.jobs[job.name] == true and job.onduty == true
end

local function mechanicInfo(cid)
    local ok, row = pcall(Store.get, cid)
    local xp = ok and row and tonumber(row.xp) or 0
    local level, name, nextXp = G.levelFor(xp, Config)
    return { level = level, name = name, xp = xp, next = nextXp, jobs = ok and row and tonumber(row.jobs) or 0 }, (ok and row) or nil
end

--- Suma experiencia (con tope diario) y avisa si sube de nivel. Devuelve lo concedido.
local function addXp(player, amount, kind, plate, total, detail)
    if not ready or not player or amount <= 0 then return 0 end
    local cid = player.PlayerData.citizenid
    local before, row = mechanicInfo(cid)
    local day = G.dayKey(now())
    local today = (row and tonumber(row.day) == day) and tonumber(row.day_xp) or 0
    local grant = G.grantable(amount, today, Config)
    if grant <= 0 then return 0 end
    local ok, err = pcall(function()
        Store.add(cid, grant, day, now())
        Store.log(cid, kind, plate, grant, total or 0, detail, now())
    end)
    if not ok then
        print(('[pxd_garage] no se pudo guardar la experiencia de %s: %s'):format(cid, tostring(err)))
        return 0
    end
    local level, name = G.levelFor(before.xp + grant, Config)
    if level > before.level then
        notify(player.PlayerData.source, ('¡Subes a nivel %d de mecánico: %s!'):format(level, name), 'success')
        TriggerEvent('pxd_garage:mechanicLevelUp', cid, level)
    end
    return grant
end

-- ── Sesión de taller ──────────────────────────────────────
--- Vehículo que conduce el jugador dentro de la zona. Devuelve entidad, matrícula o nil, código.
local function locate(src, zone)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, 'vehiculo' end
    local c = GetEntityCoords(ped)
    if not G.inZone(zone, c.x, c.y, c.z, Config.zoneMargin, Config.zoneHeight) then return nil, 'zona' end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil, 'vehiculo' end
    local plate = G.plate(GetVehicleNumberPlateText(veh))
    if not plate then return nil, 'vehiculo' end
    return veh, plate
end

local function ownedVehicle(veh, plate)
    if not started('qbx_vehicles') then return nil end
    local ok, pv, id = pcall(function()
        local vid = Entity(veh).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(plate)
        if not vid then return nil end
        return exports.qbx_vehicles:GetPlayerVehicle(vid), vid
    end)
    if not ok or not pv then return nil end
    return pv, id
end

local function modelPrice(modelName)
    local ok, data = pcall(function() return exports.qbx_core:GetVehiclesByName(modelName) end)
    return ok and type(data) == 'table' and tonumber(data.price) or nil
end

local function open(src, zoneId)
    if not ready then return nil, MSG.sin_servicio end
    local player = getPlayer(src)
    local zone = type(zoneId) == 'string' and G.zoneById(zoneId, Config) or nil
    if not player or not zone then return nil, MSG.zona end
    local veh, plate = locate(src, zone)
    if not veh then return nil, MSG[plate] end
    local pv, vehicleId = ownedVehicle(veh, plate)
    if not pv then
        if Config.requireOwned then return nil, MSG.sin_dueno end
        return nil, MSG.sin_dueno
    end
    local cid = player.PlayerData.citizenid
    local mode
    if zone.job then
        local job = player.PlayerData.job
        if not job or job.name ~= zone.job or not job.onduty then return nil, MSG.trabajo end
        mode = 'mechanic'
    else
        if pv.citizenid ~= cid then return nil, MSG.no_es_tuyo end
        mode = 'self'
    end
    local s = { zone = zone.id, veh = veh, plate = plate, vehicleId = vehicleId, owner = pv.citizenid, mode = mode,
        base = G.base(modelPrice(pv.modelName), Config), at = now() }
    sessions[src] = s
    local owner = (pv.citizenid ~= cid) and playerByCitizen(pv.citizenid) or nil
    return {
        zone = zone.id, zoneLabel = zone.label, mode = mode, plate = plate, model = pv.modelName, base = s.base,
        props = type(pv.props) == 'table' and pv.props or {},
        factor = mode == 'mechanic' and Config.pricing.mechanicFactor or 1,
        methods = Config.paymentMethods, mechanic = mechanicInfo(cid),
        ownsIt = pv.citizenid == cid, ownerName = owner and fullName(owner) or nil,
    }
end

-- ── Cobro ─────────────────────────────────────────────────
--- Cobra `total`. Devuelve una ficha de pago (para poder deshacerlo) o nil, mensaje.
local function charge(src, player, s, zone, total, method, concept)
    if total <= 0 then return { kind = 'free' } end
    local reason = ('pxd-taller-%s'):format(s.plate)
    local ownCar = s.owner == player.PlayerData.citizenid
    if s.mode == 'mechanic' and not ownCar then
        -- Taller de jugadores: factura al dueño (pendiente; la paga con /facturas).
        if not started('pxd_economy') then return nil, MSG.sin_servicio end
        local owner = playerByCitizen(s.owner)
        if not owner then return nil, MSG.dueno_lejos end
        local ok, id, msg = pcall(function() return exports.pxd_economy:IssueInvoice(src, owner.PlayerData.source, total, concept) end)
        if not ok or not id then return nil, (ok and msg) or MSG.dueno_lejos end
        return { kind = 'invoice', id = id, owner = owner.PlayerData.source }
    end
    if type(method) ~= 'string' or not Config.paymentMethods[method] then return nil, MSG.metodo end
    if zone.account and started('pxd_economy') then
        local ok, done, code = pcall(function()
            return exports.pxd_economy:ChargeToAccount(src, method, total, zone.account,
                { reason = reason, title = 'Taller', message = concept, payer = fullName(player) })
        end)
        if not ok or not done then return nil, MSG[code] or MSG.fondos end
        return { kind = 'account', account = zone.account, method = method, reason = reason }
    end
    -- Autoservicio sin cuenta: el dinero sale de circulación (sumidero).
    if (tonumber(player.Functions.GetMoney(method)) or 0) < total then return nil, MSG.fondos end
    if not player.Functions.RemoveMoney(method, total, reason) then return nil, MSG.fondos end
    return { kind = 'direct', method = method, reason = reason }
end

local function refund(player, pay, total)
    if pay.kind == 'direct' then
        pcall(player.Functions.AddMoney, pay.method, total, pay.reason .. '-reembolso')
    elseif pay.kind == 'account' then
        pcall(function() exports['Renewed-Banking']:removeAccountMoney(pay.account, total) end)
        pcall(player.Functions.AddMoney, pay.method, total, pay.reason .. '-reembolso')
    elseif pay.kind == 'invoice' then
        pcall(function() exports.pxd_economy:CancelInvoice(0, pay.id, 'no se pudo guardar el vehículo') end)
    end
end

-- ── Aplicar ───────────────────────────────────────────────
local function apply(src, changes, method)
    if not ready then return nil, MSG.sin_servicio end
    local s = sessions[src]
    local player = getPlayer(src)
    if not s or not player or now() - s.at > Config.sessionTimeout then sessions[src] = nil return nil, MSG.sesion end
    if busy[src] then return nil, MSG.en_curso end
    local zone = G.zoneById(s.zone, Config)
    local veh, plate = locate(src, zone)
    if not veh then return nil, MSG[plate] end
    if veh ~= s.veh or plate ~= s.plate then sessions[src] = nil return nil, MSG.sesion end

    local clean = G.sanitize(changes, Config)
    if not clean then return nil, MSG.cambios end

    busy[src] = true
    local ok, res, err = pcall(function()
        -- Lo guardado manda: se vuelve a leer por si cambió desde que se abrió el taller.
        local pv = ownedVehicle(veh, plate)
        if not pv or pv.citizenid ~= s.owner then return nil, MSG.sesion end
        local current = type(pv.props) == 'table' and pv.props or {}
        local items = G.diff(current, clean)
        if #items == 0 then return nil, MSG.nada end

        local mech = mechanicInfo(player.PlayerData.citizenid)
        local allowed, why = G.capCheck(items, s.mode, mech.level, Config)
        if not allowed then return nil, why end

        local quote = G.quote(items, s.base, Config, s.mode == 'mechanic' and Config.pricing.mechanicFactor or 1)
        local total = quote.total
        local concept = ('Personalización %s (%d cambios)'):format(plate, #items)
        local pay, payErr = charge(src, player, s, zone, total, method, concept)
        if not pay then return nil, payErr end

        local props = G.merge(current, items)
        props.plate = current.plate or plate
        props.engineHealth = math.floor(GetVehicleEngineHealth(veh) + 0.5)
        props.bodyHealth = math.floor(GetVehicleBodyHealth(veh) + 0.5)
        local fuel = Entity(veh).state.fuel
        if type(fuel) == 'number' then props.fuelLevel = math.floor(fuel + 0.5) end

        local saved = pcall(function()
            local done = exports.qbx_vehicles:SaveVehicle(veh, { props = props })
            if not done then error('SaveVehicle devolvió false') end
        end)
        if not saved then
            refund(player, pay, total)
            return nil, MSG.guardar
        end

        local keys, final = {}, {}
        for _, item in ipairs(items) do keys[#keys + 1] = item.key; final[item.key] = item.value end
        local xp = 0
        if s.mode == 'mechanic' and total > 0 then
            xp = addXp(player, G.tuningXp(total, Config), 'tuning', plate, total, table.concat(keys, ','))
        end
        audit('personalizar', player.PlayerData.citizenid, 'veh:' .. plate,
            { total = total, mode = s.mode, zone = s.zone, pay = pay.kind, invoice = pay.id, changes = keys })
        if pay.kind == 'invoice' then
            notify(pay.owner, ('Tu vehículo %s ha sido personalizado. Tienes una factura de %s (/facturas).'):format(plate, money(total)), 'inform')
        end
        return { total = total, lines = quote.lines, changes = final, props = props, pay = pay.kind, xp = xp,
            mechanic = xp > 0 and mechanicInfo(player.PlayerData.citizenid) or nil }
    end)
    busy[src] = nil
    if not ok then
        print(('[pxd_garage] error al aplicar (%s): %s'):format(tostring(s.plate), tostring(res)))
        return nil, MSG.sin_servicio
    end
    return res, err
end

RegisterNetEvent('pxd_garage:server:open', function(zoneId)
    local src = source
    if throttled(src) then return end
    local data, msg = open(src, zoneId)
    TriggerClientEvent('pxd_garage:client:opened', src, data and { ok = true, data = data } or { ok = false, message = msg })
end)

RegisterNetEvent('pxd_garage:server:apply', function(changes, method)
    local src = source
    if throttled(src) then
        return TriggerClientEvent('pxd_garage:client:applied', src, { ok = false, message = MSG.en_curso })
    end
    local res, msg = apply(src, changes, method)
    TriggerClientEvent('pxd_garage:client:applied', src, res and { ok = true, result = res } or { ok = false, message = msg })
end)

RegisterNetEvent('pxd_garage:server:close', function() sessions[source] = nil end)

-- ── Experiencia por reparaciones (qbx_mechanicjob) ────────
-- El banco de trabajo de qbx_mechanicjob lanza «vehiclemod:server:updatePart» con el valor máximo
-- al reparar una pieza. Cuenta si quien lo lanza es mecánico de servicio, la pieza estaba dañada
-- y no se ha contado esa misma pieza hace poco.
local MAX_PART = { engine = 1000, body = 1000, radiator = 100, axle = 100, brakes = 100, clutch = 100, fuel = 100 }

RegisterNetEvent('vehiclemod:server:updatePart', function(plate, part, level)
    local src = source
    if type(plate) ~= 'string' or #plate > 12 or type(part) ~= 'string' or type(level) ~= 'number' then return end
    local max = MAX_PART[part]
    if not max then return end
    local key = plate .. '|' .. part
    local seen = repairSeen[key] or {}
    local was = seen.level
    seen.level = level
    repairSeen[key] = seen
    if level < max or not was or was > max * 0.9 then return end
    local player = getPlayer(src)
    if not isMechanic(player) then return end
    local t = now()
    if seen.at and t - seen.at < Config.mechanic.xp.repairCooldown then return end
    seen.at = t
    addXp(player, Config.mechanic.xp.repairPart, 'repair', plate, 0, part)
end)

-- ── Comandos y exports ────────────────────────────────────
RegisterCommand('mecanico', function(src)
    if src == 0 then return print('[pxd_garage] Uso en consola: pxd_garage_xp <citizenid> <experiencia>') end
    local player = getPlayer(src)
    if not player or not ready then return end
    local m = mechanicInfo(player.PlayerData.citizenid)
    notify(src, ('Mecánico nivel %d · %s · %d XP%s'):format(m.level, m.name, m.xp, m.next and (' (siguiente: %d)'):format(m.next) or ''), 'inform')
end, false)

RegisterCommand('pxd_garage_xp', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.ace.manage) then return end
    local cid, xp = args[1], tonumber(args[2])
    if not ready or type(cid) ~= 'string' or not cid:match('^[%w]+$') or not xp or xp < 0 or xp ~= math.floor(xp) then
        if src == 0 then print('[pxd_garage] Uso: pxd_garage_xp <citizenid> <experiencia>') end
        return
    end
    Store.set(cid, xp, now())
    Store.log(cid, 'ajuste', nil, 0, 0, ('fijado a %d por %s'):format(xp, src == 0 and 'consola' or GetPlayerName(src)), now())
    audit('xp_ajuste', src == 0 and 'console' or (getPlayer(src) and getPlayer(src).PlayerData.citizenid or 'staff'), cid, { xp = xp })
    local text = ('Experiencia de %s fijada a %d (nivel %d).'):format(cid, xp, (G.levelFor(xp, Config)))
    if src == 0 then print('[pxd_garage] ' .. text) else notify(src, text, 'success') end
end, false)

--- Nivel de mecánico de un jugador conectado (id) o de un citizenid. Devuelve nivel, experiencia, nombre.
exports('GetMechanicLevel', function(who)
    if not ready then return 1, 0, Config.mechanic.levels[1].name end
    local cid = who
    if type(who) == 'number' then
        local p = getPlayer(who)
        cid = p and p.PlayerData.citizenid or nil
    end
    if type(cid) ~= 'string' then return 1, 0, Config.mechanic.levels[1].name end
    local m = mechanicInfo(cid)
    return m.level, m.xp, m.name
end)

--- Para otros recursos de Próxima (p. ej. la futura asistencia a domicilio): suma experiencia con el tope diario.
exports('AddMechanicXp', function(src, amount, kind, detail)
    local player = getPlayer(tonumber(src))
    amount = tonumber(amount)
    if not player or not amount or amount < 1 or not isMechanic(player) then return 0 end
    return addXp(player, math.floor(amount), type(kind) == 'string' and kind:sub(1, 20) or 'otro', nil, 0, detail)
end)

AddEventHandler('playerDropped', function()
    local src = source
    sessions[src], busy[src], lastCall[src] = nil, nil, nil
end)

CreateThread(function()
    local ok, err = pcall(Store.init)
    if not ok then
        print('[pxd_garage] ^1No se pudo preparar la base de datos: ' .. tostring(err) .. '^7')
        return
    end
    ready = true
end)

PXDGarageServer = { open = open, apply = apply, addXp = addXp, mechanicInfo = mechanicInfo, sessions = sessions,
    isReady = function() return ready end }   -- para pruebas
