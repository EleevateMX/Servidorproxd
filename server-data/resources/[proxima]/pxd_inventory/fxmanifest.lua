fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_inventory'
description 'Próxima RP — capa del inventario (ox_inventory): cámara del personaje, ropa y datos para la interfaz'
version '0.1.0'

-- Sin página propia: la interfaz es la de ox_inventory con la capa de
-- overlay/ox_inventory (pxd.css + pxd.js), que llama a los callbacks NUI de este recurso.
shared_scripts {
    'config.lua',
    'shared/inventory.lua',
}
client_script 'client/main.lua'
