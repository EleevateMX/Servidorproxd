fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_interact'
description 'Próxima RP — controles (E interacción, B recoger, Ctrl agacharse), ID público (PROX-XXXX) y presentarse'
version '0.2.0'

shared_scripts {
    'config.lua',
    'shared/interact.lua',
}
server_scripts {
    'server/main.lua',
    'server/pickup.lua',
}
client_scripts {
    'client/main.lua',
    'client/tags.lua',
    'client/builtin.lua',
    'client/trunk.lua',
    'client/pickup.lua',
    'client/crouch.lua',
}

ui_page 'html/index.html'
nui_callback_strict_mode 'true'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
