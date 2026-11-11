fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_garage'
description 'Próxima RP — taller de personalización (interfaz propia), tuning de motor con estadísticas y niveles de mecánico'
version '0.1.0'

-- Dueños de los datos: propiedad y mods guardados → qbx_vehicles; daño → vehiclehandler / qbx_mechanicjob.
-- La vista previa usa lib.getVehicleProperties / lib.setVehicleProperties (ox_lib). docs/44-vehiculos.md
dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'qbx_vehicles',
}

shared_scripts {
    'config.lua',
    'shared/garage.lua',
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/store.lua',
    'server/main.lua',
}
client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua',
}

ui_page 'html/index.html'
nui_callback_strict_mode 'true'

files {
    'html/index.html',
    'html/assets/app.js',
    'html/assets/app.css',
    'html/ui/*.css',
}
