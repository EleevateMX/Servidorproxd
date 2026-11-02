-- Configuración de pxd_inventory.
Config = {}

-- Cámara que encuadra al personaje en el hueco izquierdo del inventario.
-- Valores en metros respecto al personaje (+x derecha, +y delante, +z arriba).
Config.camera = {
    enabled = true,
    side = -1.25,      -- desplaza el encuadre: el personaje queda a la izquierda de la pantalla
    distance = 3.1,
    height = 0.15,
    lookHeight = -0.05,
    fov = 40.0,
}

-- Ropa que se puede quitar y poner desde el inventario (solo personajes freemode).
-- kind: 'comp' (SetPedComponentVariation) o 'prop' (SetPedPropIndex).
-- off: cómo queda «sin la prenda» (male/female). Valores de la ropa base de qbx_core.
Config.clothing = {
    { id = 'hat',      label = 'Sombrero',  icon = 'hat',      side = 'left',  kind = 'prop', index = 0 },
    { id = 'mask',     label = 'Máscara',   icon = 'mask',     side = 'left',  kind = 'comp', index = 1, off = { male = { 0, 0 }, female = { 0, 0 } } },
    { id = 'top',      label = 'Torso',     icon = 'top',      side = 'left',  kind = 'comp', index = 11, off = { male = { 15, 0 }, female = { 15, 3 } },
      also = { { index = 8, male = { 15, 0 }, female = { 14, 0 } }, { index = 3, male = { 15, 0 }, female = { 15, 0 } } } },
    { id = 'pants',    label = 'Pantalón',  icon = 'pants',    side = 'left',  kind = 'comp', index = 4, off = { male = { 61, 0 }, female = { 15, 3 } } },
    { id = 'shoes',    label = 'Zapatos',   icon = 'shoes',    side = 'left',  kind = 'comp', index = 6, off = { male = { 34, 0 }, female = { 35, 0 } } },
    { id = 'ears',     label = 'Pendientes', icon = 'ears',    side = 'right', kind = 'prop', index = 2 },
    { id = 'glasses',  label = 'Gafas',     icon = 'glasses',  side = 'right', kind = 'prop', index = 1 },
    { id = 'neck',     label = 'Collar',    icon = 'neck',     side = 'right', kind = 'comp', index = 7, off = { male = { 0, 0 }, female = { 0, 0 } } },
    { id = 'watch',    label = 'Reloj',     icon = 'watch',    side = 'right', kind = 'prop', index = 6 },
    { id = 'bracelet', label = 'Pulsera',   icon = 'bracelet', side = 'right', kind = 'prop', index = 7 },
    -- Fila de abajo
    { id = 'under',    label = 'Camiseta interior', icon = 'under', side = 'bottom', kind = 'comp', index = 8, off = { male = { 15, 0 }, female = { 14, 0 } } },
    { id = 'vest',     label = 'Chaleco',   icon = 'vest',     side = 'bottom', kind = 'comp', index = 9, off = { male = { 0, 0 }, female = { 0, 0 } } },
    { id = 'bag',      label = 'Mochila',   icon = 'bag',      side = 'bottom', kind = 'comp', index = 5, off = { male = { 0, 0 }, female = { 0, 0 } } },
    { id = 'decal',    label = 'Insignia',  icon = 'decal',    side = 'bottom', kind = 'comp', index = 10, off = { male = { 0, 0 }, female = { 0, 0 } } },
}

-- Notificaciones que se guardan para el panel del inventario (las que llegan por
-- los eventos de red ox_lib:notify y QBCore:Notify).
Config.notifyHistory = 20
