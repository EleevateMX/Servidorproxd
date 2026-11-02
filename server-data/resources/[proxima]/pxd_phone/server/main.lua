-- pxd_phone (servidor): datos de las apps del teléfono. Todo se valida aquí: quién llama,
-- su posición (la del servidor, no la que mande el cliente), su trabajo y la frecuencia.
local taxi = PXDPhone.Taxi.new(Config.taxi.requestTtlSec)
local sosBook, taxiBook = {}, {}

local clock = os.time
local function now() return clock() end
--- Para pruebas: reloj inyectable.
function PXDPhone.setClock(fn) clock = fn end

local function qbx() return GetResourceState('qbx_core') == 'started' end

local function player(src)
    if not qbx() then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

local function notify(src, text, kind)
    if qbx() then
        pcall(function() exports.qbx_core:Notify(src, text, kind or 'inform') end)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'Teléfono', text } })
    end
end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
end

local function onDuty(kind, value)
    if not qbx() then return {} end
    local ok, _, list = pcall(function()
        if kind == 'type' then return exports.qbx_core:GetDutyCountType(value) end
        return exports.qbx_core:GetDutyCountJob(value)
    end)
    return ok and type(list) == 'table' and list or {}
end

local function isTaxiOnDuty(src)
    local p = player(src)
    local job = p and p.PlayerData and p.PlayerData.job
    return job ~= nil and job.name == Config.taxi.job and job.onduty == true
end

local function charName(src)
    local p = player(src)
    local ci = p and p.PlayerData and p.PlayerData.charinfo
    if ci and ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
    return GetPlayerName(src) or ('#' .. src)
end

-- ── Acciones ────────────────────────────────────────────────────────────────
local actions = {}

function actions.d8_list(src)
    if GetResourceState('oxmysql') ~= 'started' or not MySQL then
        return { error = 'La inmobiliaria no está disponible ahora mismo.' }
    end
    local p = player(src)
    local cid = p and p.PlayerData and p.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT id, property_name, price, owner, rent_interval, keyholders FROM properties') or {}
    return PXDPhone.splitProperties(rows, cid, Config.dynasty.maxRows)
end

function actions.d8_mark(src, data)
    local id = tonumber(data and data.id)
    if not id or GetResourceState('oxmysql') ~= 'started' or not MySQL then return { error = 'Propiedad no válida.' } end
    local row = MySQL.single.await('SELECT coords FROM properties WHERE id = ?', { id })
    local c = row and json.decode(row.coords or '')
    if type(c) ~= 'table' or not tonumber(c.x) or not tonumber(c.y) then return { error = 'Propiedad no válida.' } end
    return { x = tonumber(c.x), y = tonumber(c.y) }
end

function actions.sos_send(src, data)
    local service = Config.emergency.services[data and data.service or '']
    if not service then return { error = 'Elige un servicio.' } end
    local ok, wait = PXDPhone.allow(sosBook, src, now(), Config.emergency.cooldownSec)
    if not ok then return { error = ('Espera %d s para enviar otro aviso.'):format(wait) } end
    local coords = coordsOf(src)
    if not coords then return { error = 'No se pudo obtener tu ubicación.' } end
    local text = PXDPhone.cleanText(data.text, Config.emergency.maxText)
    local targets = onDuty('type', service.jobType)
    for _, t in ipairs(targets) do
        TriggerClientEvent('pxd_phone:client:alert', t, {
            kind = 'sos', title = 'Aviso: ' .. service.label, text = text ~= '' and text or 'Sin descripción',
            coords = coords, seconds = Config.emergency.blipSeconds,
        })
        notify(t, ('Aviso al %s: %s'):format(service.label, text ~= '' and text or 'sin descripción'), 'warning')
    end
    if #targets == 0 then
        return { ok = true, sent = 0, message = ('Ahora no hay nadie de %s de servicio. Tu aviso no llegó a nadie.'):format(service.label) }
    end
    return { ok = true, sent = #targets, message = ('Aviso enviado a %d persona(s) de servicio.'):format(#targets) }
end

local function taxiState(src)
    local t = now()
    local mine = taxi:openFor(src)
    local state = { driver = isTaxiOnDuty(src), drivers = #onDuty('job', Config.taxi.job) }
    if mine then
        state.request = { id = mine.id, status = mine.status, driverName = mine.driver and charName(mine.driver) or nil }
    end
    if state.driver then state.pending = taxi:pending(t) end
    return state
end

function actions.taxi_state(src) return taxiState(src) end

function actions.taxi_request(src, data)
    local ok, wait = PXDPhone.allow(taxiBook, src, now(), Config.taxi.cooldownSec)
    if not ok then return { error = ('Espera %d s para pedir otro taxi.'):format(wait) } end
    local drivers = onDuty('job', Config.taxi.job)
    if #drivers == 0 then
        taxiBook[src] = nil
        return { error = 'No hay taxistas de servicio ahora mismo.' }
    end
    local coords = coordsOf(src)
    if not coords then return { error = 'No se pudo obtener tu ubicación.' } end
    local r, err = taxi:request(src, now(), PXDPhone.cleanText(data and data.text, Config.taxi.maxText), coords)
    if not r then return { error = err } end
    for _, d in ipairs(drivers) do
        if d ~= src then notify(d, 'Nuevo cliente de taxi: abre la app Taxi del teléfono.', 'inform') end
    end
    return taxiState(src)
end

function actions.taxi_cancel(src)
    local r = taxi:cancel(src)
    if r and r.driver then notify(r.driver, 'El cliente canceló el taxi.', 'error') end
    return taxiState(src)
end

function actions.taxi_accept(src, data)
    if not isTaxiOnDuty(src) then return { error = 'Tienes que estar de servicio como taxista.' } end
    local r, err = taxi:accept(tonumber(data and data.id) or -1, src, now())
    if not r then return { error = err } end
    notify(r.customer, ('Tu taxi va en camino: %s.'):format(charName(src)), 'success')
    TriggerClientEvent('pxd_phone:client:alert', src, {
        kind = 'taxi', title = 'Cliente de taxi', text = r.text ~= '' and r.text or 'Recoger al cliente',
        coords = r.coords, seconds = Config.taxi.requestTtlSec,
    })
    local state = taxiState(src)
    state.waypoint = { x = r.coords.x, y = r.coords.y }
    return state
end

-- ── Petición / respuesta con el cliente ─────────────────────────────────────
RegisterNetEvent('pxd_phone:server:req', function(reqId, action, data)
    local src = source
    local fn = type(action) == 'string' and actions[action]
    if type(reqId) ~= 'number' then return end
    if not fn then return TriggerClientEvent('pxd_phone:client:res', src, reqId, { error = 'Acción desconocida.' }) end
    local ok, result = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('[pxd_phone] error en %s: %s'):format(action, tostring(result)))
        result = { error = 'Algo salió mal. Inténtalo de nuevo.' }
    end
    TriggerClientEvent('pxd_phone:client:res', src, reqId, result)
end)

AddEventHandler('playerDropped', function()
    local src = source
    sosBook[src], taxiBook[src] = nil, nil
    for _, r in ipairs(taxi:dropPlayer(src)) do
        notify(r.customer, 'Tu taxista se desconectó; tu petición vuelve a estar pendiente.', 'error')
    end
end)

PXDPhone.actions = actions   -- para pruebas
