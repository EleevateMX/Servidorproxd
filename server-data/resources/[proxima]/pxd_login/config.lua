-- Configuración de pxd_login.
Config = {}

Config.serverName = 'PRÓXIMA RP'

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
-- Desactívala si tu framework ya trae selección de personaje (p. ej. Qbox).
Config.welcomeScreen = true

Config.dataFile = 'data/players.json'
