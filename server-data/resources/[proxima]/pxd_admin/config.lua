-- Configuración de pxd_admin.
Config = {}

-- Teclas por defecto (cada jugador puede cambiarlas en Ajustes → Asignación de teclas → FiveM).
-- Ojo: qbx_vehicleradio usa F9 para la radio del coche (solo dentro de vehículos).
-- FiveM guarda la tecla de cada comando la primera vez: por eso el panel usa un nombre de
-- comando nuevo (pxd_panel_admin) y no hereda asignaciones antiguas del comando «staff».
Config.keySupport = 'F9'   -- soporte y reportes (todos)
Config.keyStaff = 'F10'    -- panel de administración (permiso pxd.admin.panel)

-- Permisos: matriz de roles en shared/admin.lua (PXDAdmin.ROLES) y docs/37-administracion.md.
-- ¿Hay que estar de servicio (/duty) para usar las herramientas sobre el mundo? false = no.
Config.requireDuty = false

-- Noclip
Config.noclip = {
    invisible = true,                          -- invisible para los demás mientras vuela
    speeds = { 0.2, 0.5, 1.0, 2.0, 4.0, 8.0 }, -- metros por fotograma; la rueda del ratón cambia
    defaultSpeed = 3,                          -- índice en speeds
}

-- Límites de las acciones sensibles
Config.maxMoneyCorrection = 1000000   -- por corrección de dinero
Config.maxBanHours = 87600            -- 10 años; 0 = permanente

-- Categorías. kind = 'player' (reportar a alguien) o 'help' (pedir ayuda).
Config.categories = {
    { id = 'pg', kind = 'player', label = 'Powergaming / antirol' },
    { id = 'dm', kind = 'player', label = 'Ataque sin rol (DM/VDM)' },
    { id = 'mg', kind = 'player', label = 'Metagaming' },
    { id = 'trato', kind = 'player', label = 'Insultos o acoso' },
    { id = 'trampa', kind = 'player', label = 'Trampas o bugs' },
    { id = 'otro_j', kind = 'player', label = 'Otro' },
    { id = 'atascado', kind = 'help', label = 'Estoy atascado/a' },
    { id = 'bug', kind = 'help', label = 'Encontré un fallo' },
    { id = 'duda', kind = 'help', label = 'Tengo una duda' },
    { id = 'otro_a', kind = 'help', label = 'Otro' },
}

-- Límites para jugadores.
Config.reportsPerWindow = 3        -- como mucho 3 reportes…
Config.reportWindowSec = 600       -- …cada 10 minutos
Config.maxOpenPerPlayer = 3        -- reportes abiertos a la vez por jugador
Config.repliesPerMinute = 6        -- respuestas del jugador por minuto

-- Guardado (dentro del propio recurso: data/ no se sube a git).
Config.reportsFile = 'data/reports.json'
Config.logFile = 'data/staff-log.json'
-- Rangos dados con /darrango (se vuelven a aplicar en cada arranque). No se versiona.
Config.rolesFile = 'data/staff-roles.json'
Config.maxReports = 500
Config.maxLog = 1000

-- Atuendo de servicio (/duty) por modelo de personaje. Cada línea: { componente, dibujo, textura }
-- (11 torso, 8 camiseta, 3 brazos, 4 piernas, 6 calzado). Son valores de partida: revísalos
-- en el juego con el editor de ropa y pon los que te gusten. GTA no trae una prenda con el
-- texto «STAFF»; lo que identifica al staff es la etiqueta sobre la cabeza. Si añades al
-- servidor una prenda propia con «STAFF», pon aquí su número. Al salir de servicio se
-- restaura la ropa anterior (con illenium-appearance si está iniciado).
Config.staffOutfit = {
    mp_m_freemode_01 = { { 11, 50, 0 }, { 8, 15, 0 }, { 3, 0, 0 }, { 4, 31, 0 }, { 6, 25, 0 } },
    mp_f_freemode_01 = { { 11, 43, 0 }, { 8, 14, 0 }, { 3, 0, 0 }, { 4, 30, 0 }, { 6, 25, 0 } },
}

-- Baneos: se guardan en la tabla «bans» de qbx_core (la misma que usa qbx_adminmenu), que
-- qbx_core comprueba al conectar. txAdmin sigue teniendo sus propios baneos en su web.
Config.banHint = 'Los baneos usan la lista de Qbox (tabla bans). Los de txAdmin se gestionan en su web.'
