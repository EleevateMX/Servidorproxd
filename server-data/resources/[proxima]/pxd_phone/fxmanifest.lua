fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_phone'
description 'Próxima RP — diseño del teléfono (npwd) y apps Dynasty 8, Emergencias y Taxi'
version '0.1.0'

-- Sin página NUI propia a propósito: este recurso solo sirve archivos (https://cfx-nui-pxd_phone/…)
-- a la página de npwd y atiende sus llamadas (https://pxd_phone/…). Ver docs/23-telefono.md.

shared_scripts {
    'config.lua',
    'shared/phone.lua',
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
client_script 'client/main.lua'

files {
    'html/phone.css',
    'html/phone.js',
    'html/img/*',
}
