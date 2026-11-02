fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_props'
description 'Próxima RP — editor de props, dashboard web y API para blueprints'
version '0.1.0'

-- Solo la NUI propia puede invocar sus callbacks (por defecto en Enhanced; aquí también en Legacy).
nui_callback_strict_mode 'true'

shared_scripts {
    'config.lua',
    'shared/layouts.lua',
}

server_script 'server/main.lua'
client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/catalog.json',
}
