fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_economy'
description 'Próxima RP — economía conectada: facturas, cobros seguros, flujo de dinero, paga cada 30 min, impuestos y mercado fluctuante'
version '0.2.0'

shared_scripts {
    'config.lua',
    'shared/economy.lua',
    'shared/payroll.lua',
    'shared/market.lua',
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/store.lua',
    'server/money.lua',
    'server/main.lua',
    'server/ledger.lua',
    'server/store_live.lua',
    'server/taxes.lua',
    'server/payroll.lua',
    'server/market.lua',
}
client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua',
}

dependencies {
    'oxmysql',
    'qbx_core',
}
