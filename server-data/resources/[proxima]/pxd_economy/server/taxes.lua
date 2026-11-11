-- Impuestos (solo la base): tasas configurables (0 = desactivado), registro propio de lo recaudado
-- (pxd_tax_ledger) e ingreso en la cuenta «estado» de Renewed-Banking cuando existe.
PXDTax = {}
local T = PXDTax
local Store, Money = PXDLiveStore, PXDMoney

local ready, accountState = false, nil   -- accountState: nil sin comprobar · true existe · false no disponible

local function now() return (PXDEconomyClock and PXDEconomyClock()) or os.time() end
local function started(res) return GetResourceState(res) == 'started' end

--- Tasa de un impuesto ('payroll' | 'invoices'), acotada a [0, maxRate].
function T.rate(kind)
    local cfg = Config.taxes or {}
    return math.max(0, math.min(tonumber(cfg[kind]) or 0, tonumber(cfg.maxRate) or 0.5))
end

--- Importe del impuesto sobre `amount` (entero, redondeo hacia abajo).
function T.amount(kind, amount)
    return PXDPayroll.tax(amount, T.rate(kind), (Config.taxes or {}).maxRate)
end

local function accountExists(account)
    local ok, balance = pcall(function() return exports['Renewed-Banking']:getAccountMoney(account) end)
    return ok and type(balance) == 'number'
end

--- ¿Existe la cuenta del Estado? La primera vez intenta crearla con el export CreateJobAccount de
--- Renewed-Banking 2.1.4 (admite cualquier id, no solo trabajos). Si no queda disponible en esta
--- sesión, lo recaudado se sigue registrando en pxd_tax_ledger con deposited = 0.
function T.ensureAccount()
    if accountState ~= nil then return accountState end
    local cfg = Config.taxes or {}
    if not started('Renewed-Banking') or type(cfg.account) ~= 'string' then accountState = false return false end
    if accountExists(cfg.account) then accountState = true return true end
    pcall(function()
        exports['Renewed-Banking']:CreateJobAccount({ name = cfg.account, label = cfg.accountLabel or cfg.account }, 0)
    end)
    accountState = accountExists(cfg.account)
    if not accountState then
        print(('[pxd_economy] ^3La cuenta «%s» de Renewed-Banking no está disponible en esta sesión: lo recaudado se registra en pxd_tax_ledger y se ingresará cuando exista (suele bastar con reiniciar el servidor).^7'):format(cfg.account))
    end
    return accountState
end

--- Registra un impuesto ya retenido. Devuelve true si además quedó ingresado en la cuenta del Estado.
function T.collect(kind, citizenid, base, amount, detail)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local deposited = false
    if T.ensureAccount() then
        deposited = Money.deposit(Config.taxes.account, amount, 'Impuesto', detail or kind, 'Hacienda') == true
    end
    if ready then
        local ok, err = pcall(Store.taxInsert, now(), kind, citizenid, math.floor(tonumber(base) or 0), amount, deposited, detail and tostring(detail):sub(1, 120) or nil)
        if not ok then print('[pxd_economy] no se pudo registrar el impuesto: ' .. tostring(err)) end
    end
    return deposited
end

--- Recaudación por tipo en las últimas `hours` horas: { payroll = { amount, count }, … }.
function T.summary(hours)
    local out = {}
    if not ready then return out end
    hours = math.max(1, math.min(24 * 30, math.floor(tonumber(hours) or 24)))
    for _, r in ipairs(Store.taxSince(now() - hours * 3600)) do
        out[r.kind] = { amount = tonumber(r.amount) or 0, count = tonumber(r.count) or 0 }
    end
    return out
end

exports('GetTaxRate', function(kind) return T.rate(kind) end)
exports('GetTaxSummary', function(hours) return T.summary(hours) end)

CreateThread(function()
    local ok, err = pcall(Store.initTaxes)
    if not ok then return print('[pxd_economy] ^1No se pudo preparar la tabla de impuestos: ' .. tostring(err) .. '^7') end
    ready = true
end)

T.isReady = function() return ready end
T.resetAccount = function() accountState = nil end   -- para pruebas
