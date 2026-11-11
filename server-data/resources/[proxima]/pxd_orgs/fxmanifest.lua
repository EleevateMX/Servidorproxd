fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_orgs'
description 'Próxima RP — organizaciones y bandas creadas por jugadores: miembros, rangos, fondos, identidad y reputación'
version '0.1.0'

-- Solo la NUI propia puede invocar sus callbacks.
nui_callback_strict_mode 'true'

dependencies {
    'oxmysql',
    'qbx_core',
}

shared_scripts {
    'config.lua',
    'shared/orgs.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/store.lua',
    'server/main.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'

-- La interfaz es una app React + TypeScript (código en web/orgs, fuera del recurso);
-- aquí solo va su compilación con nombres fijos. Las fuentes van incrustadas en CSS.
files {
    'html/index.html',
    'html/assets/app.js',
    'html/assets/app.css',
    'html/ui/proxima-fonts.css',
    'html/ui/orgs-fonts.css',
}
