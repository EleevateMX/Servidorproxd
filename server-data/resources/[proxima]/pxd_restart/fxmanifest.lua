fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_restart'
description 'Próxima RP — avisos y pantalla de reinicio (eventos de txAdmin)'
version '0.1.0'

shared_scripts {
    'config.lua',
    'shared/restart.lua',
}
server_script 'server/main.lua'
client_script 'client/main.lua'

ui_page 'html/index.html'
nui_callback_strict_mode 'true'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.svg',
}
