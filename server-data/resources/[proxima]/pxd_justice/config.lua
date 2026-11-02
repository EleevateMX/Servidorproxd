-- Configuración de pxd_justice (multas y deudas pendientes). docs/30-multas.md
Config = {}

-- Quién puede multar: trabajos de este tipo en qbx_core, de servicio y con rango mínimo.
Config.issuerJobTypes = { leo = true }
Config.minGrade = 0

-- Importe máximo por multa (mismo valor que qbx_police: sharedConfig.maxFine).
Config.maxFine = 100000
-- Distancia máxima entre agente y multado al emitir (la de qbx_police).
Config.maxDistance = 5.0

-- Cuenta de Renewed-Banking que recibe los pagos (la misma que usaba qbx_police).
Config.society = 'police'

-- Al emitir, ¿cobrar en el acto si el multado tiene saldo en el banco?
-- false (recomendado): la multa queda pendiente y el jugador la paga desde el panel.
-- true: si hay saldo suficiente se cobra al momento; si no, queda como deuda.
Config.autoChargeIfFunds = false

-- Formas de pago permitidas para el jugador.
Config.paymentMethods = { cash = true, bank = true }

-- Importe mínimo de un pago parcial (el último pago puede ser menor si es lo que falta).
Config.minPartialPayment = 1

-- Cuántas multas se muestran en el historial del panel.
Config.historyLimit = 25

-- Permisos ACE.
Config.ace = {
    manage = 'pxd.justice.manage', -- cancelar y corregir multas (staff o mandos)
    view = 'pxd.justice.view',     -- consultar multas de otros sin ser policía de servicio
}

-- Enfriamiento entre peticiones del mismo jugador (segundos).
Config.cooldown = 1.0

-- Radares de qbx_police (docs/30 §6 bis). NO cambia nada todavía:
--   'instant' (actual): qbx_police cobra la multa del radar en el acto, como siempre.
--   'pending': SOLO con el parche de radar de docs/30 aplicado, el radar deja una multa
--              pendiente con exports.pxd_justice:IssueSystemFine. Sin el parche no tiene efecto.
Config.radar = { mode = 'instant' }

-- Multas del sistema (export IssueSystemFine): nombre del emisor que se muestra y espera
-- mínima entre dos multas del mismo origen a la misma persona.
Config.systemFine = {
    issuerName = 'Sistema',
    cooldownSec = 10,
}
