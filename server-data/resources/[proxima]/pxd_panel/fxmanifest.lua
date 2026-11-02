fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_panel'
description 'Próxima RP — panel de la ciudad (perfil, recompensas, logros, eventos, organizaciones, ayuda)'
version '0.1.0'

-- Solo la NUI propia puede invocar sus callbacks.
nui_callback_strict_mode 'true'

shared_scripts {
    'config.lua',
    'shared/rules.lua',
    'shared/panel.lua',
}

server_script 'server/main.lua'
client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/ui/*.css',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.svg',
}
