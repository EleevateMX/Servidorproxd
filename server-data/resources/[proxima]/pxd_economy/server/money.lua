-- Dinero seguro (X-4): cobra a un jugador y lo ingresa en una cuenta de Renewed-Banking,
-- con reembolso si falla cualquier paso. Nunca deja saldo negativo.
PXDMoney = {}
local M = PXDMoney

local function started(res) return GetResourceState(res) == 'started' end

--- Ingresa en una cuenta de empresa (Renewed-Banking) y deja el movimiento en su historial.
function M.deposit(account, amount, title, message, issuer)
    if not started('Renewed-Banking') then return false end
    local ok, done = pcall(function() return exports['Renewed-Banking']:addAccountMoney(account, amount) end)
    if not ok or not done then return false end
    pcall(function()
        exports['Renewed-Banking']:handleTransaction(account, tostring(title):sub(1, 50), amount,
            tostring(message or ''):sub(1, 120), tostring(issuer or 'Ciudadano'):sub(1, 50), account, 'deposit')
    end)
    return true
end

--- Cobra `amount` a `player` con `method` ('cash'|'bank') y lo ingresa en `account`.
--- record(): paso intermedio opcional (p. ej. marcar la factura); si devuelve false se reembolsa.
--- undo(): deshace record() si falla el ingreso. Devuelve true o false, código ('fondos'|'cambio'|'banco'|'error'), paso.
function M.chargeToAccount(player, method, amount, account, opts)
    opts = opts or {}
    local reason = opts.reason or 'pxd-cobro'
    local step = 'none'
    local ok, res, code = pcall(function()
        if (tonumber(player.Functions.GetMoney(method)) or 0) < amount then return false, 'fondos' end
        if not player.Functions.RemoveMoney(method, amount, reason) then return false, 'fondos' end
        step = 'charged'
        if opts.record and not opts.record() then
            step = 'none'
            player.Functions.AddMoney(method, amount, reason .. '-reembolso')
            return false, 'cambio'
        end
        step = 'recorded'
        if not M.deposit(account, amount, opts.title or reason, opts.message, opts.payer) then
            if opts.undo then opts.undo() end
            step = 'none'
            player.Functions.AddMoney(method, amount, reason .. '-reembolso')
            return false, 'banco'
        end
        step = 'deposited'
        return true
    end)
    if ok then return res, code, step end
    print(('[pxd_economy] error al cobrar (%s, paso %s): %s'):format(reason, step, tostring(res)))
    if step == 'recorded' and opts.undo then pcall(opts.undo) end
    if step == 'charged' or step == 'recorded' then
        pcall(player.Functions.AddMoney, method, amount, reason .. '-reembolso')
        return false, 'error', step
    end
    -- Ya ingresado: el cobro es válido aunque fallara algo posterior.
    if step == 'deposited' then return true, nil, step end
    return false, 'error', step
end
