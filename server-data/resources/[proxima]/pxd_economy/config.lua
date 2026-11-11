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
    { pattern = '^pxd%-nomina',           id = 'nominas',     label = 'Nóminas' },
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

-- ── Paga cada 30 minutos (docs/41-economia-viva.md) ────────────────────────
-- Un solo dueño de la nómina: pxd_economy. qbx_core deja de pagar con el parche de docs/41
-- (su sendPaycheck comprueba GlobalState.pxdPayroll). Sin el parche, pxd_economy NO paga
-- y sigue pagando qbx_core (nunca los dos).
Config.payroll = {
    enabled = true,
    intervalMinutes = 30,       -- tiempo ACTIVO (conectado, no AFK y con derecho a paga) entre pagas
    tickSeconds = 30,           -- cada cuánto se revisa a cada jugador
    -- Los sueldos de qbx_core (shared/jobs.lua → grades[n].payment) están pensados para 10 minutos:
    -- ×3 mantiene el mismo ingreso por hora con una paga cada 30.
    multiplier = 3,
    unemployedJob = 'unemployed',
    unemployedAid = 30,         -- ayuda por ciclo a quien no tiene trabajo (0 = sin ayuda)
    offDutyAid = 0,             -- ayuda por ciclo a quien tiene trabajo pero está fuera de servicio
    moneyType = 'bank',
    -- Quién paga. Vacío = el Estado (dinero nuevo). [trabajo] = true → la cuenta de la empresa en
    -- Renewed-Banking (A-1 de docs/31); si no tiene fondos, no hay paga y se reintenta.
    society = {},
    societyRetryMinutes = 5,
    afk = {
        enabled = true,
        minutes = 10,           -- sin moverse ni girarse este tiempo = ausente (no acumula)
        minDistance = 2.0,      -- metros entre dos revisiones para contar como movimiento
        minHeading = 15.0,      -- grados de giro para contar como actividad
    },
    saveEveryTicks = 10,        -- guarda el progreso en la base de datos cada N revisiones
    -- Tras arrancar no se paga durante este margen (el tiempo sí cuenta): si qbx_core siguiera
    -- pagando por su cuenta, se detecta antes y no hay doble paga.
    startGraceMinutes = 11,
    audit = true,               -- una entrada en pxd_audit por cada paga
}

-- ── Impuestos (solo la base: 0 = desactivado) ──────────────────────────────
Config.taxes = {
    payroll = 0.0,              -- fracción del sueldo bruto (0.05 = 5 %)
    invoices = 0.0,             -- fracción de cada pago de factura (lo paga el negocio que cobra)
    maxRate = 0.5,              -- tope de seguridad para cualquier tasa
    account = 'estado',         -- cuenta de Renewed-Banking que recibe lo recaudado
    accountLabel = 'Hacienda Pública',
}

-- ── Mercado fluctuante ─────────────────────────────────────────────────────
-- Precios de referencia que se mueven con la oferta y la demanda reales (RecordTrade), vuelven
-- poco a poco a su precio base y reaccionan a noticias. Lo consultan fábricas, negocios y la bolsa.
Config.market = {
    enabled = true,
    tickMinutes = 15,
    historyKeepDays = 0,        -- 0 = conservar todo el historial
    newsKeep = 200,             -- titulares que devuelve como máximo GetNews
    defaults = {
        volatility = 0.004,     -- ruido por tick (±0,4 %)
        reversion = 0.05,       -- cuánto vuelve hacia su precio base cada tick (5 % de la distancia)
        impact = 0.03,          -- variación con presión máxima de compra o venta (±3 %)
        liquidity = 200,        -- unidades netas por tick que dan presión máxima
        maxStep = 0.05,         -- cambio máximo por tick (±5 %)
    },
    newsThreshold = 0.015,      -- una subida o bajada por operaciones desde el 1,5 % sale en las noticias
    eventChance = 0.08,         -- probabilidad por tick de una noticia de mercado automática
    integrations = {
        shops = true,           -- las compras en tiendas de ox_inventory cuentan como demanda
        fuel = true,            -- repostar en ox_fuel cuenta como demanda de combustible
    },
    categories = {
        materias = 'Materias primas', taller = 'Taller', herramientas = 'Herramientas', salud = 'Salud',
        alimentos = 'Alimentos', bebidas = 'Bebidas', energia = 'Energía',
    },
    -- item = nombre del ítem en ox_inventory (data/items.lua de la receta de Qbox). Sin item = bien
    -- de referencia que aún no es un objeto (combustible).
    goods = {
        steel        = { label = 'Acero',              category = 'materias', item = 'steel',       base = 60,  min = 30,  max = 120 },
        iron         = { label = 'Hierro',             category = 'materias', item = 'iron',        base = 45,  min = 22,  max = 90 },
        copper       = { label = 'Cobre',              category = 'materias', item = 'copper',      base = 55,  min = 27,  max = 110 },
        aluminum     = { label = 'Aluminio',           category = 'materias', item = 'aluminum',    base = 50,  min = 25,  max = 100 },
        metalscrap   = { label = 'Chatarra',           category = 'materias', item = 'metalscrap',  base = 25,  min = 12,  max = 50 },
        plastic      = { label = 'Plástico',           category = 'materias', item = 'plastic',     base = 20,  min = 10,  max = 40 },
        rubber       = { label = 'Goma',               category = 'materias', item = 'rubber',      base = 30,  min = 15,  max = 60 },
        glass        = { label = 'Vidrio',             category = 'materias', item = 'glass',       base = 25,  min = 12,  max = 50 },
        repairkit    = { label = 'Kit de reparación',  category = 'taller',   item = 'repairkit',   base = 250, min = 150, max = 450 },
        advancedrepairkit = { label = 'Kit de reparación avanzado', category = 'taller', item = 'advancedrepairkit', base = 500, min = 300, max = 900 },
        cleaningkit  = { label = 'Kit de limpieza',    category = 'taller',   item = 'cleaningkit', base = 120, min = 70,  max = 220 },
        nitrous      = { label = 'Óxido nitroso',      category = 'taller',   item = 'nitrous',     base = 900, min = 500, max = 1600 },
        lockpick     = { label = 'Ganzúa',             category = 'herramientas', item = 'lockpick', base = 40, min = 20, max = 90 },
        screwdriverset = { label = 'Destornilladores', category = 'herramientas', item = 'screwdriverset', base = 180, min = 100, max = 320 },
        drill        = { label = 'Taladro',            category = 'herramientas', item = 'drill',   base = 1500, min = 900, max = 2600 },
        bandage      = { label = 'Venda',              category = 'salud',    item = 'bandage',     base = 25,  min = 12,  max = 50 },
        firstaid     = { label = 'Botiquín',           category = 'salud',    item = 'firstaid',    base = 150, min = 80,  max = 280 },
        painkillers  = { label = 'Analgésicos',        category = 'salud',    item = 'painkillers', base = 60,  min = 30,  max = 120 },
        water        = { label = 'Agua',               category = 'bebidas',  item = 'water',       base = 10,  min = 5,   max = 20 },
        coffee       = { label = 'Café',               category = 'bebidas',  item = 'coffee',      base = 12,  min = 6,   max = 24 },
        beer         = { label = 'Cerveza',            category = 'bebidas',  item = 'beer',        base = 15,  min = 8,   max = 30 },
        burger       = { label = 'Hamburguesa',        category = 'alimentos', item = 'burger',     base = 15,  min = 8,   max = 30 },
        sandwich     = { label = 'Sándwich',           category = 'alimentos', item = 'sandwich',   base = 12,  min = 6,   max = 24 },
        grape        = { label = 'Uva',                category = 'alimentos', item = 'grape',      base = 6,   min = 3,   max = 12 },
        fuel         = { label = 'Combustible',        category = 'energia',  base = 5,   min = 3,   max = 9, liquidity = 2000 },
    },
    -- Bienes de las fábricas que todavía no existen como ítems en ox_inventory: NO están en el
    -- mercado hasta que se creen (no se inventan). Solo para planificación.
    pending = { 'lechuga', 'tomate', 'leche', 'huevos', 'carne', 'harina', 'azúcar', 'aceite', 'medicamentos de farmacia', 'gasolina extra y premium' },
    -- Noticias automáticas. {pct} se sustituye por la variación con signo; target = categoría o bien.
    events = {
        { id = 'reparaciones', weight = 3, category = 'taller', pct = { 0.01, 0.04 }, ticks = 8,
          headline = 'Aumentan las reparaciones en la ciudad: las piezas de taller suben un {pct}' },
        { id = 'chatarra', weight = 2, category = 'materias', pct = { -0.04, -0.01 }, ticks = 8,
          headline = 'Llega un cargamento de metal al puerto: las materias primas bajan un {pct}' },
        { id = 'huelga_puerto', weight = 1, category = 'materias', pct = { 0.03, 0.07 }, ticks = 6,
          headline = 'Retrasos en el puerto: las materias primas suben un {pct}' },
        { id = 'ola_calor', weight = 2, category = 'bebidas', pct = { 0.02, 0.06 }, ticks = 6,
          headline = 'Ola de calor: las bebidas suben un {pct}' },
        { id = 'campana_salud', weight = 2, category = 'salud', pct = { -0.05, -0.02 }, ticks = 8,
          headline = 'Campaña de salud pública: los productos médicos bajan un {pct}' },
        { id = 'gripe', weight = 1, category = 'salud', pct = { 0.03, 0.08 }, ticks = 6,
          headline = 'Brote de gripe: los productos médicos suben un {pct}' },
        { id = 'refineria', weight = 2, good = 'fuel', pct = { 0.03, 0.08 }, ticks = 6,
          headline = 'Avería en la refinería: el combustible sube un {pct}' },
        { id = 'excedente_crudo', weight = 2, good = 'fuel', pct = { -0.06, -0.02 }, ticks = 6,
          headline = 'Excedente de crudo: el combustible baja un {pct}' },
        { id = 'cosecha', weight = 2, category = 'alimentos', pct = { -0.05, -0.02 }, ticks = 8,
          headline = 'Buena cosecha: los alimentos bajan un {pct}' },
        { id = 'obras', weight = 1, category = 'herramientas', pct = { 0.02, 0.05 }, ticks = 8,
          headline = 'Nuevas obras en la ciudad: las herramientas suben un {pct}' },
    },
}
