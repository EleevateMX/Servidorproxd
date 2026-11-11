fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_hud'
description 'Próxima RP — HUD 2.0 (constantes, dinero, voz, brújula, lugar y vehículo). Sustituye a qbx_hud'
version '0.2.0'

nui_callback_strict_mode 'true'

shared_scripts {
    'config.lua',
    'shared/hud.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'
files {
    'html/ui/*.css',
    'html/index.html',
    'html/assets/app.js',
    'html/assets/app.css',
}
