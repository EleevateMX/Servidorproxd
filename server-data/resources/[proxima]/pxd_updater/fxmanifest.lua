fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_updater'
description 'Próxima RP — actualiza los recursos pxd_* desde GitHub con un comando (pxd_update)'
version '0.1.0'

server_scripts {
    'config.lua',
    'shared/sha256.lua',
    'shared/base64.lua',
    'server/main.lua',
    'server/assets.js',
}
