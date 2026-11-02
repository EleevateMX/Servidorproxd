fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_inventory'
description 'Próxima RP — interfaz propia del inventario (React) sobre ox_inventory, cámara del personaje, ropa y datos'
version '0.2.0'

-- Sin página propia: la interfaz está en web/ (compilada desde web/pxd-inventory en la raíz del repo)
-- y pxd_updater la copia a ox_inventory/web/build (plan.overlays). ox_inventory sigue siendo el
-- backend; la interfaz llama a sus callbacks NUI y a los de este recurso (docs/36-inventario.md).
shared_scripts {
    'config.lua',
    'shared/inventory.lua',
}
client_script 'client/main.lua'
