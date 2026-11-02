fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_login'
description 'Próxima RP — login al conectar (código de acceso y normas) y pantalla de bienvenida'
version '0.1.0'

nui_callback_strict_mode 'true'

shared_scripts {
    'config.lua',
    'shared/login.lua',
}
server_script 'server/main.lua'
client_script 'client/main.lua'

ui_page 'html/index.html'
files {
    'html/ui/*.css',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
