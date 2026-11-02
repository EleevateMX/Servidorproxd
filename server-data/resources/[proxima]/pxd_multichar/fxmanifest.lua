fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_multichar'
description 'Próxima RP — selección y creación de personaje (sustituye la de qbx_core)'
version '0.1.0'

-- Solo la NUI propia puede invocar sus callbacks.
nui_callback_strict_mode 'true'

-- Requiere en qbx_core/config/client.lua: characters.useExternalCharacters = true
dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/multichar.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/ui/*.css',
    'html/assets/*.jpg',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.svg',
}
