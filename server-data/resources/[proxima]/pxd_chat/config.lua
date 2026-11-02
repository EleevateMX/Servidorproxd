-- Configuración de pxd_chat.
Config = {}

-- Distancias en metros (las comprueba el servidor con la posición de cada jugador).
Config.range = {
    say = 12.0,       -- escribir sin comando: tu personaje habla
    whisper = 3.0,    -- /susurrar
    shout = 30.0,     -- /gritar
    me = 20.0,        -- /me (lo envía qbx_core; aquí solo la línea de chat)
    ['do'] = 20.0,    -- /do
    ooc = 20.0,       -- /b (fuera de personaje, local)
}

-- Longitud máxima de un mensaje y anti-spam: como mucho `max` mensajes cada `window` s.
Config.maxLength = 220
Config.spam = { max = 4, window = 6 }

-- Anuncios a toda la ciudad (/anuncio): permiso ACE.
Config.announceAce = 'pxd.chat.announce'
Config.announceLabel = 'Anuncio de la ciudad'

-- Cómo se ve el nombre de alguien a quien no conoces (pxd_interact).
Config.unknownLabel = 'Desconocido'

-- Mensaje de bienvenida (una vez por sesión, al cargar el personaje).
Config.welcome = 'Bienvenido/a a Próxima RP. Escribe para hablar con quien tengas cerca · TAB abre el panel · /me y /do para describir.'
