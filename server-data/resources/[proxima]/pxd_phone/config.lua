-- Configuración de pxd_phone.
Config = {}

-- Emergencias: tipos de trabajo de Qbox que reciben cada aviso (qbx_core shared/jobs.lua).
Config.emergency = {
    services = {
        police = { label = 'Policía', jobType = 'leo' },
        ems = { label = 'Servicios médicos', jobType = 'ems' },
    },
    cooldownSec = 60,      -- un aviso por jugador cada minuto
    maxText = 140,
    blipSeconds = 180,     -- cuánto dura el punto en el mapa de quien atiende
}

-- Taxi: trabajo de Qbox de los taxistas.
Config.taxi = {
    job = 'taxi',
    cooldownSec = 30,
    requestTtlSec = 600,   -- una petición sin aceptar caduca a los 10 min
    maxText = 100,
}

-- Dynasty 8 (propiedades de qbx_properties).
Config.dynasty = {
    maxRows = 200,
}
