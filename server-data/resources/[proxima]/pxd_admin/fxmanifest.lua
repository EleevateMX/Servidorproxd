fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_admin'
description 'Próxima RP — soporte, reportes y centro de administración (roles, noclip, moderación, vehículos, mundo y economía)'
version '0.2.0'

shared_scripts {
    'config.lua',
    'shared/admin.lua',
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
client_script 'client/main.lua'

ui_page 'html/index.html'
nui_callback_strict_mode 'true'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.svg',
}
