fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_interact'
description 'Próxima RP — interacción con E, ID público (PROX-XXXX) y presentarse'
version '0.1.0'

shared_scripts {
    'config.lua',
    'shared/interact.lua',
}
server_script 'server/main.lua'
client_scripts {
    'client/main.lua',
    'client/tags.lua',
    'client/builtin.lua',
}

ui_page 'html/index.html'
nui_callback_strict_mode 'true'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
