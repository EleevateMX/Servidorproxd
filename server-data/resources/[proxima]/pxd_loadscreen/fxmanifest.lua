fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_loadscreen'
description 'Próxima RP — pantalla de carga'
version '0.1.0'

loadscreen 'html/index.html'
-- La cierra pxd_login (o este mismo recurso si pxd_login no está iniciado).
loadscreen_manual_shutdown 'yes'
-- Cursor visible: los avisos, la radio y los botones de redes son clicables.
loadscreen_cursor 'yes'

client_script 'client.lua'
server_scripts {
    'config.lua',
    'server.lua',
}

files {
    'html/ui/*.css',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.svg',
    -- Opcionales: se descargan con scripts/fetch-brand-assets.* (si no están, hay fondo CSS).
    'html/assets/*',
}
