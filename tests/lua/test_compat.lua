-- Pruebas de pxd_compat: guardado del desgaste de piezas de qbx_mechanicjob.
local T = _G.T
local Fx = dofile(ROOT .. 'tests/lua/fx_stub.lua')
local DIR = RES .. 'pxd_compat/'

local saves
local function boot(states)
    Fx.reset({ resourceName = 'pxd_compat', resourceStates = states or { qbx_mechanicjob = 'started' } })
    Config, PXDWear, PXDCompat = nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/wear.lua', 'server/wear.lua' })
    saves = {}
    AddEventHandler('vehiclemod:server:saveStatus', function(plate) saves[#saves + 1] = plate end)
end

T.describe('pxd_compat · desgaste de vehículos', function()
    T.it('lógica: matrículas válidas, intervalo por vehículo y vaciado total', function()
        dofile(RES .. 'pxd_compat/shared/wear.lua')
        local st = PXDWear.new(60)
        T.truthy(PXDWear.mark(st, 'ABC 123'))
        T.falsy(PXDWear.mark(st, ''))
        T.falsy(PXDWear.mark(st, 123))
        T.falsy(PXDWear.mark(st, string.rep('X', 17)))
        T.eq(#PXDWear.due(st, 0), 1)
        PXDWear.saved(st, 'ABC 123', 0)
        PXDWear.mark(st, 'ABC 123')
        T.eq(#PXDWear.due(st, 30), 0, 'aún no toca')
        T.eq(#PXDWear.due(st, 30, true), 1, 'al apagar se guarda todo')
        T.eq(#PXDWear.due(st, 60), 1)
    end)

    T.it('guarda los vehículos con cambios de piezas, uno por minuto como mucho', function()
        boot()
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 001', 'engine', 50)
        Fx.emit('vehiclemod:server:fixEverything', 1, 'PXD 002')
        Fx.advance(16)
        T.eq(table.concat(saves, ','), 'PXD 001,PXD 002')
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 001', 'engine', 40)
        Fx.advance(16)
        T.eq(#saves, 2, 'dentro del minuto no repite')
        Fx.advance(60)
        T.eq(saves[3], 'PXD 001')
    end)

    T.it('al parar qbx_mechanicjob o el servidor guarda lo pendiente', function()
        boot()
        Fx.emit('qb-vehicletuning:server:SetPartLevel', 1, 'PXD 009', 'brakes', 3)
        TriggerEvent('onResourceStop', 'qbx_mechanicjob')
        T.eq(saves[1], 'PXD 009')
    end)

    T.it('sin qbx_mechanicjob no hace nada', function()
        boot({})
        Fx.emit('vehiclemod:server:updatePart', 1, 'PXD 001', 'engine', 50)
        Fx.advance(120)
        T.eq(#saves, 0)
    end)
end)

-- ── Hospital y auditoría ────────────────────────────────────────────────────
local inv, notified
local function bootMedical(states, cfgFile, extraExports)
    inv = {
        [1] = { slot = 1, name = 'money', label = 'Dinero', count = 500 },
        [2] = { slot = 2, name = 'phone', label = 'Teléfono', count = 1 },
        [3] = { slot = 3, name = 'WEAPON_PISTOL', label = 'Pistola', count = 1, metadata = { serial = 'ABC123' } },
        [4] = { slot = 4, name = 'ammo-9', label = 'Munición 9mm', count = 24 },
        [5] = { slot = 5, name = 'cokebaggy', label = 'Bolsa de coca', count = 3 },
        [6] = { slot = 6, name = 'id_card', label = 'DNI', count = 1 },
        [7] = { slot = 7, name = 'WEAPON_FLASHLIGHT', label = 'Linterna', count = 1 },
        [8] = { slot = 8, name = 'water', label = 'Agua', count = 2 },
    }
    notified = {}
    Fx.reset({
        resourceName = 'pxd_compat',
        resourceStates = states or { ox_inventory = 'started', qbx_core = 'started' },
        files = cfgFile and { ['qbx_ambulancejob/config/server.lua'] = cfgFile } or nil,
        exports = {
            ox_inventory = {
                GetInventoryItems = function() return inv end,
                RemoveItem = function(_, name, count, _, slot)
                    local it = inv[slot]
                    if not it or it.name ~= name or it.count < count then return false end
                    it.count = it.count - count
                    if it.count == 0 then inv[slot] = nil end
                    return true
                end,
            },
            qbx_core = {
                GetPlayer = function(src) return { PlayerData = { citizenid = 'CID' .. src, source = src } } end,
                Notify = function(src, text) notified[#notified + 1] = text end,
            },
        },
    })
    for k, v in pairs(extraExports or {}) do Fx.exports[k] = v end
    Config, PXDMedical, PXDAudit, PXDMedicalServer = nil, nil, nil, nil
    Fx.load(DIR, { 'config.lua', 'shared/medical.lua', 'server/audit.lua', 'server/medical.lua' })
end

local function names()
    local out = {}
    for slot = 1, 8 do if inv[slot] then out[#out + 1] = inv[slot].name end end
    return table.concat(out, ',')
end

T.describe('pxd_compat · hospital', function()
    T.it('lógica: protegidos ganan, prefijos de armas y munición, lista de ilegales', function()
        dofile(RES .. 'pxd_compat/config.lua')
        dofile(RES .. 'pxd_compat/shared/medical.lua')
        local c = Config.medical
        T.eq(PXDMedical.classify('money', c), 'protected')
        T.eq(PXDMedical.classify('money', { confiscate = { 'money' } }), 'protected', 'el efectivo nunca se retira')
        T.eq(PXDMedical.classify('WEAPON_PISTOL', c), 'confiscate')
        T.eq(PXDMedical.classify('WEAPON_FLASHLIGHT', c), 'protected')
        T.eq(PXDMedical.classify('ammo-rifle', c), 'confiscate')
        T.eq(PXDMedical.classify('meth', c), 'confiscate')
        T.eq(PXDMedical.classify('water', c), nil)
        T.eq(PXDMedical.classify(nil, c), nil)
    end)

    T.it('reaparecer retira solo lo confiscable y conserva dinero, documentos y teléfono', function()
        bootMedical()
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        T.eq(names(), 'money,phone,id_card,WEAPON_FLASHLIGHT,water')
        T.eq(inv[1].count, 500, 'el efectivo queda intacto')
        T.truthy(notified[1]:find('Pistola'), 'avisa al jugador')
    end)

    T.it('auditoría: una entrada por retirada, con serial, y consultable por personaje', function()
        bootMedical()
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        local list = PXDAudit.get({ category = 'medical', target = 'CID7' })
        T.eq(#list, 3)
        T.eq(list[3].data.item, 'WEAPON_PISTOL')
        T.eq(list[3].data.serial, 'ABC123')
        T.eq(list[1].action, 'confiscate')
        local saved = Fx.json.decode(Fx.files['data/audit.json'])
        T.eq(#saved.entries, 3)
    end)

    T.it('el mismo evento repetido no retira dos veces (idempotente)', function()
        bootMedical()
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        inv[9] = { slot = 9, name = 'WEAPON_KNIFE', label = 'Cuchillo', count = 1 }
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        T.truthy(inv[9], 'dentro de la ventana no vuelve a retirar')
        Fx.time = Fx.time + 31
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        T.falsy(inv[9], 'otra reaparición más tarde sí')
    end)

    T.it('la reanimación por EMS no retira nada', function()
        bootMedical()
        -- qbx_medical Revive dispara en el cliente 'qbx_medical:client:playerRevived', nunca playerRespawned.
        TriggerEvent('qbx_medical:client:playerRevived', 7)
        T.eq(names(), 'money,phone,WEAPON_PISTOL,ammo-9,cokebaggy,id_card,WEAPON_FLASHLIGHT,water')
        T.eq(#PXDAudit.get({}), 0)
    end)

    T.it('sin ox_inventory no hace nada; avisa si qbx_ambulancejob sigue borrando todo', function()
        bootMedical({ qbx_core = 'started' }, 'return {\n    wipeInvOnRespawn = true,\n}')
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        T.eq(inv[3].name, 'WEAPON_PISTOL')
        local warned = false
        for _, l in ipairs(Fx.logs) do if l:find('wipeInvOnRespawn = true') then warned = true end end
        T.truthy(warned)
    end)

    T.it('auditoría: rechaza entradas sin categoría o acción y recorta al máximo', function()
        bootMedical()
        T.eq(PXDAudit.audit({ action = 'x' }), nil)
        Config.audit.maxEntries = 2
        for i = 1, 4 do PXDAudit.audit({ category = 'fines', action = 'paid', target = 'CID1', data = { n = i } }) end
        local all = PXDAudit.get({ limit = 10 })
        T.eq(#all, 2)
        T.eq(all[1].data.n, 4)
        T.eq(all[1].id, 4, 'los ids siguen creciendo')
    end)
end)

-- ── Delegación en la auditoría común (pxd_audit, docs/34) ───────────────────
T.describe('pxd_compat · auditoría delegada en pxd_audit', function()
    local logs, failLog
    local fakeAudit = {
        Log = function(e)
            if failLog then error('pxd_audit caído') end
            logs[#logs + 1] = e
            return 100 + #logs
        end,
        Query = function(f)
            local out = {}
            for i = #logs, 1, -1 do
                local e = logs[i]
                if (not f.category or e.category == f.category) and (not f.target or e.target == f.target) then
                    out[#out + 1] = { id = 100 + i, created_at = 1234, category = e.category, action = e.action,
                        actor = e.actor or 'system', target = e.target, data = e.data, source = e.source }
                end
                if #out >= f.limit then break end
            end
            return out
        end,
    }
    local function bootDelegated()
        logs, failLog = {}, false
        bootMedical({ ox_inventory = 'started', qbx_core = 'started', pxd_audit = 'started' }, nil, { pxd_audit = fakeAudit })
    end

    T.it('con pxd_audit en marcha, Audit escribe allí y no en su JSON', function()
        bootDelegated()
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        T.eq(#logs, 3)
        T.eq(logs[1].category, 'medical'); T.eq(logs[1].target, 'CID7'); T.eq(logs[1].source, 'pxd_compat')
        T.eq(logs[1].data.item, 'WEAPON_PISTOL'); T.eq(logs[1].data.serial, 'ABC123')
        T.falsy(Fx.files['data/audit.json'])
    end)

    T.it('GetAudit lee de pxd_audit con la forma de siempre (at, resource)', function()
        bootDelegated()
        TriggerEvent('qbx_medical:server:playerRespawned', 7)
        local list = PXDAudit.get({ category = 'medical', target = 'CID7', limit = 2 })
        T.eq(#list, 2)
        T.eq(list[1].at, 1234); T.eq(list[1].resource, 'pxd_compat'); T.eq(list[1].id, 103)
        T.eq(list[2].data.item, 'ammo-9')
    end)

    T.it('si pxd_audit falla, guarda en su JSON y avisa; sin pxd_audit, como antes', function()
        bootDelegated()
        failLog = true
        T.eq(PXDAudit.audit({ category = 'medical', action = 'confiscate', target = 'CID1' }), 1)
        T.eq(#Fx.json.decode(Fx.files['data/audit.json']).entries, 1)
        local warned = false
        for _, l in ipairs(Fx.logs) do if l:find('pxd_audit no aceptó') then warned = true end end
        T.truthy(warned)
        bootMedical(nil, nil, { pxd_audit = fakeAudit })   -- exportado pero sin arrancar
        logs = {}
        PXDAudit.audit({ category = 'medical', action = 'confiscate', target = 'CID1' })
        T.eq(#logs, 0); T.truthy(Fx.files['data/audit.json'])
    end)

    T.it('Config.audit.delegate = false mantiene el JSON aunque pxd_audit esté en marcha', function()
        bootDelegated()
        Config.audit.delegate = false
        PXDAudit.audit({ category = 'medical', action = 'confiscate', target = 'CID1' })
        T.eq(#logs, 0); T.truthy(Fx.files['data/audit.json'])
    end)
end)
