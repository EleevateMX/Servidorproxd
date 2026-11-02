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

-- Avisos del carrusel. image = archivo de html/assets/ (si no existe, se usa un degradado).
-- Solo cosas que existen de verdad: nada de promesas ni fechas inventadas.
Config.news = {
    { tag = 'Reglamento', title = 'Lee las normas de la ciudad antes de rolear', image = 'slide-policia.png', url = Config.discord },
    { tag = 'Comunidad', title = 'Únete a nuestro Discord oficial', image = 'slide-barrio.png', url = Config.discord },
    { tag = 'Modos de juego', title = 'Pulsa F7: deathmatch, rey de la colina y carreras', image = 'slide-taller.png' },
    { tag = 'Emergencias', title = 'Policía y EMS: la ciudad siempre alerta', image = 'slide-emergencias.png' },
}
