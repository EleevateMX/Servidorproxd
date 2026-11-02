-- Configuración de pxd_updater.
Config = {}

-- Repositorio público de Próxima RP (raw de GitHub). Ref: 'HEAD' = rama por defecto.
Config.rawBase = 'https://raw.githubusercontent.com/EleevateMX/Servidorproxd/'
Config.refConvar = 'pxd_updater_ref'      -- set pxd_updater_ref "una-rama-o-commit" para fijarlo
Config.defaultRef = 'HEAD'

-- Quién puede ejecutar pxd_update desde el juego (desde la consola de txAdmin siempre se puede).
Config.ace = 'pxd.update'

-- Archivo donde se recuerda qué versión de cada archivo se instaló (para respetar
-- los config.lua que edites a mano).
Config.stateFile = 'data/installed.json'
