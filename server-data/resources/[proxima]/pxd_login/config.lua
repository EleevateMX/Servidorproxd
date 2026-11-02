-- Configuración de pxd_login.
Config = {}

Config.serverName = 'PRÓXIMA RP'
Config.tagline = 'Tu próxima vida empieza aquí'
-- Icono de las tarjetas al conectar (URL pública). Vacío = sin imagen.
Config.cardIcon = 'https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/brand/portal/proxima-rp-icono-512.png'

-- Tarjetas al conectar: otros recursos (p. ej. Qbox) envían mensajes de progreso que
-- tapan la tarjeta; se vuelve a mostrar cada 1,5 s durante estos segundos.
Config.cardRefreshSec = 20
-- Tiempo máximo para responder una tarjeta antes de cancelar la conexión.
Config.cardTimeoutSec = 300

-- Código de acceso para servidores de pruebas privados. Se lee de esta convar:
--   set pxd_login_accessCode "algo-largo"   (en secrets.cfg, con `set`, nunca `setr`)
-- Vacío = sin código. Los jugadores que lo aciertan quedan recordados por licencia.
Config.accessCodeConvar = 'pxd_login_accessCode'
Config.maxCodeAttempts = 3

-- Normas que se aceptan al entrar. Si las cambias, sube rulesVersion para que
-- todos vuelvan a aceptarlas.
Config.rulesVersion = 1
Config.rules = {
    'Rol ante todo: actúa como lo haría tu personaje.',
    'Nada de metagaming: lo que sabes fuera del personaje no lo sabe tu personaje.',
    'Nada de powergaming: da opciones de reacción a los demás.',
    'Prohibido usar trampas, mods de ventaja o fallos del juego.',
    'Respeto a la comunidad y al staff, dentro y fuera del rol.',
}

-- Pantalla de bienvenida en el juego (elegir ciudad o modos de juego).
-- 'auto': se muestra sin framework y se desactiva sola con Qbox (que trae su propia
-- selección de personaje y cierra la pantalla de carga). true / false para forzarlo.
Config.welcomeScreen = 'auto'

Config.dataFile = 'data/players.json'
