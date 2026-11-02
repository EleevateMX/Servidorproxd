fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_economy'
description 'Próxima RP — economía conectada: facturas, cobros seguros y registro del flujo de dinero (etapa A)'
version '0.1.0'

shared_scripts {
    'config.lua',
    'shared/economy.lua',
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/store.lua',
    'server/money.lua',
    'server/main.lua',
    'server/ledger.lua',
}
client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua',
}

dependencies {
    'oxmysql',
    'qbx_core',
}
