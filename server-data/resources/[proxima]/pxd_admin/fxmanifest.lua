fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_admin'
description 'Próxima RP — soporte, reportes y panel de staff'
version '0.1.0'

shared_scripts {
    'config.lua',
    'shared/admin.lua',
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
