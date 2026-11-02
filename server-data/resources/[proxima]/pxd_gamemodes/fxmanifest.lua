fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_gamemodes'
description 'Próxima RP — modos de juego en routing buckets (FFA, TDM, KOTH, carreras)'
version '0.1.0'

-- Solo la NUI propia puede invocar sus callbacks (por defecto en Enhanced; aquí también en Legacy).
nui_callback_strict_mode 'true'

dependency 'baseevents'

shared_scripts {
    'config.lua',
    'shared/util.lua',
    'shared/modes.lua',
    'shared/match.lua',
    'shared/lobby.lua',
    'shared/arena.lua',
    'shared/modes/*.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
