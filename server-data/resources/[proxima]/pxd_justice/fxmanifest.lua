fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_justice'
description 'Próxima RP — multas y deudas pendientes (registro, pagos parciales y auditoría)'
version '0.2.0'

-- Persistencia en MariaDB con oxmysql. Sin qbx_core no hace nada.
-- Auditoría en pxd_audit si está en marcha (arráncalo antes); si no, en pxd_fine_events.
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
