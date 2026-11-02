fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_audit'
description 'Próxima RP — auditoría común (tabla pxd_audit, consultas y migración de registros antiguos)'
version '0.1.0'

-- oxmysql no es dependencia obligatoria: si no está en marcha, se usa el respaldo
-- data/audit.json (con aviso en la consola). Arranca antes que pxd_compat y pxd_justice.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'shared/audit.lua',
    'server/store.lua',
    'server/migrate.lua',
    'server/main.lua',
}
