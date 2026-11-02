-- pxd_economy (cliente): menús de facturas y resumen económico con ox_lib (tema de Próxima).
-- Solo muestra y pide: toda comprobación se hace en el servidor.
-- API de ox_lib usada: lib.registerContext, lib.showContext, lib.inputDialog, lib.alertDialog.

local function money(n) return ('$%s'):format(math.floor(tonumber(n) or 0)) end

local METHOD_LABEL = { cash = 'Efectivo', bank = 'Banco' }

local function payDialog(inv, methods)
    local opts = {}
    for _, m in ipairs({ 'bank', 'cash' }) do
        if methods[m] then opts[#opts + 1] = { value = m, label = METHOD_LABEL[m] } end
    end
    local input = lib.inputDialog(('Pagar factura #%d'):format(inv.id), {
        { type = 'number', label = 'Importe', description = ('Pendiente: %s'):format(money(inv.outstanding)),
          default = inv.outstanding, min = 1, max = inv.outstanding, required = true },
        { type = 'select', label = 'Forma de pago', options = opts, default = opts[1] and opts[1].value, required = true },
    })
    if not input then return end
    TriggerServerEvent('pxd_economy:server:pay', inv.id, tonumber(input[1]), input[2])
end

local function invoiceOption(inv, methods)
    local desc = ('%s · %s · %s'):format(inv.jobLabel or inv.job, inv.concept, inv.statusLabel)
    if inv.outstanding > 0 and inv.paid > 0 then desc = desc .. (' · pagado %s'):format(money(inv.paid)) end
    return {
        title = ('#%d · %s'):format(inv.id, inv.outstanding > 0 and money(inv.outstanding) or money(inv.amount)),
        description = desc,
        icon = inv.outstanding > 0 and 'file-invoice-dollar' or 'check',
        disabled = inv.outstanding <= 0,
        onSelect = inv.outstanding > 0 and function() payDialog(inv, methods) end or nil,
    }
end

RegisterNetEvent('pxd_economy:client:invoices', function(view, jobView, refreshOnly)
    if type(view) ~= 'table' then return end
    local options = {}
    if #view.open == 0 then
        options[#options + 1] = { title = 'No tienes facturas pendientes', icon = 'circle-check', disabled = true }
    end
    for _, inv in ipairs(view.open) do options[#options + 1] = invoiceOption(inv, view.methods or {}) end
    if #view.closed > 0 then
        options[#options + 1] = { title = 'Historial', icon = 'clock-rotate-left', menu = 'pxd_invoices_history' }
        local hist = {}
        for _, inv in ipairs(view.closed) do hist[#hist + 1] = invoiceOption(inv, {}) end
        lib.registerContext({ id = 'pxd_invoices_history', title = 'Facturas cerradas', menu = 'pxd_invoices', options = hist })
    end
    if type(jobView) == 'table' then
        options[#options + 1] = { title = ('Facturas de %s'):format(jobView.job), icon = 'briefcase', menu = 'pxd_invoices_job',
            description = ('%d abiertas · %s por cobrar'):format(#jobView.open, money(jobView.total)) }
        local jobOpts = { { title = 'Nueva factura', icon = 'plus', onSelect = function() ExecuteCommand('factura') end } }
        for _, inv in ipairs(jobView.open) do
            jobOpts[#jobOpts + 1] = {
                title = ('#%d · %s · %s'):format(inv.id, inv.client or 'Cliente', money(inv.outstanding)),
                description = ('%s · %s'):format(inv.concept, inv.statusLabel), icon = 'file-invoice',
                onSelect = function()
                    local r = lib.alertDialog({ header = ('Cancelar factura #%d'):format(inv.id),
                        content = 'Solo quien la emitió o un jefe puede cancelarla. Lo ya pagado no se devuelve.',
                        centered = true, cancel = true, labels = { confirm = 'Cancelar factura', cancel = 'Volver' } })
                    if r == 'confirm' then TriggerServerEvent('pxd_economy:server:cancel', inv.id) end
                end,
            }
        end
        lib.registerContext({ id = 'pxd_invoices_job', title = ('Facturas de %s'):format(jobView.job), menu = 'pxd_invoices', options = jobOpts })
    end
    lib.registerContext({ id = 'pxd_invoices', title = ('Mis facturas · %s pendiente'):format(money(view.total)), options = options })
    if refreshOnly and not lib.getOpenContextMenu() then return end
    lib.showContext('pxd_invoices')
end)

RegisterNetEvent('pxd_economy:client:issueForm', function(maxAmount)
    local input = lib.inputDialog('Nueva factura', {
        { type = 'number', label = 'ID del cliente', description = 'El número de servidor de la persona (debe estar cerca)', min = 1, required = true },
        { type = 'number', label = 'Importe', min = 1, max = maxAmount, required = true },
        { type = 'input', label = 'Concepto', placeholder = 'Reparación de motor', min = 1, max = 120, required = true },
    })
    if not input then return end
    TriggerServerEvent('pxd_economy:server:issue', tonumber(input[1]), tonumber(input[2]), input[3])
end)

RegisterNetEvent('pxd_economy:client:summary', function(s)
    if type(s) ~= 'table' then return end
    local sign = s.net >= 0 and '+' or '−'
    local options = {
        { title = ('Entra %s · Sale %s'):format(money(s.totalIn), money(s.totalOut)),
          description = ('Neto %s%s: dinero creado (+) o retirado (−) en %d h'):format(sign, money(math.abs(s.net)), s.hours),
          icon = 'scale-balanced', readOnly = true },
    }
    if s.circulation then
        options[#options + 1] = { title = ('En circulación: %s'):format(money(s.circulation.cash + s.circulation.bank)),
            description = ('Efectivo %s · Banco %s (último guardado de personajes)'):format(money(s.circulation.cash), money(s.circulation.bank)),
            icon = 'coins', readOnly = true }
    end
    for _, c in ipairs(s.categories or {}) do
        local lines = {}
        for _, r in ipairs(c.reasons or {}) do lines[#lines + 1] = ('%s: %s'):format(r.reason ~= '' and r.reason or 'sin motivo', money(r.total)) end
        options[#options + 1] = { title = c.label, icon = 'chart-column', readOnly = true,
            description = ('+%s · −%s · %d mov.'):format(money(c['in']), money(c.out), c.count),
            metadata = lines }
    end
    for _, l in ipairs(s.large or {}) do
        options[#options + 1] = { title = ('Grande: %s%s %s'):format(l.direction == 'in' and '+' or '−', money(l.amount), l.money_type),
            description = ('%s · %s'):format(l.reason ~= '' and l.reason or 'sin motivo', l.citizenid or '¿?'), icon = 'triangle-exclamation', readOnly = true }
    end
    lib.registerContext({ id = 'pxd_economy_summary', title = ('Economía · últimas %d h'):format(s.hours), options = options })
    lib.showContext('pxd_economy_summary')
end)

TriggerEvent('chat:addSuggestion', '/facturas', 'Ver y pagar tus facturas')
TriggerEvent('chat:addSuggestion', '/factura', 'Emitir una factura (trabajo de servicio)', {
    { name = 'id', help = 'ID del cliente (opcional: sin argumentos abre el formulario)' },
    { name = 'importe', help = 'Importe' }, { name = 'concepto', help = 'Concepto' },
})
