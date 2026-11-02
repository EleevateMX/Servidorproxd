fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_hud'
description 'Próxima RP — interfaz en pantalla (dinero, necesidades, voz, hora y vehículo). Sustituye a qbx_hud'
version '0.1.0'

nui_callback_strict_mode 'true'

shared_scripts {
    'config.lua',
    'shared/hud.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
