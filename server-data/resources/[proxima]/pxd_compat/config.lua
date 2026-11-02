-- Configuración de pxd_compat.
Config = {}

-- Desgaste de piezas de qbx_mechanicjob: solo lo guarda en la BD con el evento
-- 'vehiclemod:server:saveStatus' («used in old qb-garages»), que qbx_garages ya no
-- dispara. pxd_compat lo dispara por cada vehículo que haya cambiado.
Config.wear = {
    enabled = true,
    saveIntervalSec = 60,   -- como mucho una escritura por vehículo y minuto
    tickSec = 15,
}
