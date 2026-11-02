-- Configuración de pxd_restart.
Config = {}

Config.serverName = 'PRÓXIMA RP'

-- Minutos antes del reinicio en los que se muestra un aviso pequeño.
-- txAdmin avisa a los 30, 15, 10, 5, 4, 3, 2 y 1 minutos (docs/events.md de txAdmin).
Config.toastMinutes = { 30, 15, 10, 5, 2 }

-- A partir de cuántos segundos se muestra la pantalla completa con cuenta atrás.
Config.screenSeconds = 60

-- Pasos que se enseñan en la pantalla completa.
Config.steps = {
    { icon = 'save', title = 'Guarda lo que hacías', text = 'Termina tu rol en un sitio seguro.' },
    { icon = 'wait', title = 'Espera un minuto', text = 'La ciudad vuelve enseguida.' },
    { icon = 'join', title = 'Vuelve a entrar', text = 'Búscanos en FiveM o en Recientes.' },
}
