-- Carga los scripts compartidos de pxd_gamemodes en un entorno limpio.
return function()
    PXD = nil
    local base = RES .. 'pxd_gamemodes/shared/'
    for _, f in ipairs({ 'util.lua', 'modes.lua', 'match.lua', 'lobby.lua',
        'modes/ffa.lua', 'modes/tdm.lua', 'modes/koth.lua', 'modes/race.lua' }) do
        dofile(base .. f)
    end
    return PXD
end
