-- Configuración de pxd_economy (etapa A: economía conectada). docs/35-economia.md
Config = {}

-- ── Facturas (A-3, A-4) ───────────────────────────────────
-- Trabajos de qbx_core que pueden facturar. El cobro entra en la cuenta de Renewed-Banking
-- indicada (por defecto, la del propio trabajo). La policía no factura: multa (pxd_justice).
Config.invoiceJobs = {
    mechanic   = { account = 'mechanic' },
    tow        = { account = 'tow' },
    taxi       = { account = 'taxi' },
    ambulance  = { account = 'ambulance' },
    realestate = { account = 'realestate' },
    cardealer  = { account = 'cardealer' },
    lawyer     = { account = 'lawyer' },
}
Config.invoiceMinGrade = 0          -- rango mínimo para emitir
Config.invoiceRequireDuty = true    -- solo de servicio
Config.maxInvoice = 50000           -- importe máximo por factura
Config.maxOpenPerClient = 5         -- facturas abiertas de un mismo trabajo a un mismo cliente
Config.maxDistance = 5.0            -- metros entre quien factura y el cliente
Config.paymentMethods = { cash = true, bank = true }
Config.minPartialPayment = 1
Config.historyLimit = 25
Config.cooldown = 1.0               -- segundos entre peticiones del mismo jugador

-- Permisos ACE
Config.ace = {
    manage = 'pxd.economy.manage',  -- cancelar cualquier factura
    view = 'pxd.economy.view',      -- ver el resumen económico (/economia)
}

-- ── Registro del flujo de dinero (A-8) ────────────────────
Config.ledger = {
    enabled = true,
    flushSeconds = 60,              -- cada cuánto se guarda el acumulado en la base de datos
    largeAmount = 25000,            -- movimientos individuales desde este importe se guardan aparte y avisan en consola
    summaryHours = 24,              -- periodo por defecto de /economia
    maxReasonLength = 64,
}

-- Motivos de qbx_core agrupados por categoría (patrones Lua, en orden; el primero que coincide gana).
-- Los motivos reales salen de cada recurso; lo que no encaje queda como «otros».
Config.categories = {
    { pattern = '^#nomina$',              id = 'nominas',     label = 'Nóminas' },
    { pattern = '^pxd%-multa',            id = 'multas',      label = 'Multas' },
    { pattern = '^pxd%-factura',          id = 'facturas',    label = 'Facturas' },
    { pattern = '^Sync cash with inventory', id = 'efectivo', label = 'Efectivo del inventario (tiendas, entregas…)' },
    { pattern = 'transfer',               id = 'transferencias', label = 'Transferencias' },
    { pattern = 'vehicle',                id = 'vehiculos',   label = 'Vehículos' },
    { pattern = 'propert',                id = 'propiedades', label = 'Propiedades' },
    { pattern = '^pxd%-',                 id = 'proxima',     label = 'Sistemas de Próxima' },
    { pattern = '^$',                     id = 'sin_motivo',  label = 'Sin motivo indicado' },
}
Config.otherCategory = { id = 'otros', label = 'Otros' }
