-- Configuración de la pantalla de carga (se envía al jugador al conectar).
-- Deja una URL vacía ('') para ocultar su botón.
Config = {}

Config.discord = 'https://discord.gg/qUcD5gCf6v'
Config.socials = {
    web = '',
    instagram = '',
    youtube = '',
    tiktok = '',
}

-- Nombre de la «radio» del reproductor. Suena assets/music.mp3 si existe;
-- si no, la voz de bienvenida.
Config.radioName = 'PRÓXIMA FM'

-- Texto de la esquina inferior derecha (vacío = oculto).
Config.mediaHint = 'Comparte tus fotos en #media de nuestro Discord'

-- Avisos que rotan junto a las normas en el «Código de la ciudad» (las normas
-- vienen de pxd_login/config.lua). url opcional: el aviso se vuelve clicable.
-- Solo cosas que existen de verdad: nada de promesas ni fechas inventadas.
Config.news = {
    { tag = 'Comunidad', title = 'Únete a nuestro Discord oficial', url = Config.discord },
    { tag = 'Modos de juego', title = 'Pulsa F7: deathmatch, rey de la colina y carreras' },
}
