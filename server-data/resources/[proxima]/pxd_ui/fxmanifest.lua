fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_ui'
description 'Próxima RP — interfaz común: avisos, indicaciones de tecla, progreso y diálogos (sustituye la parte visual de ox_lib)'
version '0.1.0'

-- Solo la NUI propia puede invocar sus callbacks.
nui_callback_strict_mode 'true'

shared_scripts {
    'config.lua',
    'shared/ui.lua',
}
client_script 'client/main.lua'

ui_page 'html/index.html'
files {
    'html/ui/*.css',
    'html/index.html',
    'html/assets/app.js',
    'html/assets/app.css',
}
