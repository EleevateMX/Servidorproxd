fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_justice'
description 'Próxima RP — multas y deudas pendientes (registro, pagos parciales y auditoría)'
version '0.1.0'

-- Persistencia en MariaDB con oxmysql. Sin qbx_core no hace nada.
dependencies {
    'oxmysql',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'shared/fines.lua',
    'server/store.lua',
    'server/main.lua',
}
