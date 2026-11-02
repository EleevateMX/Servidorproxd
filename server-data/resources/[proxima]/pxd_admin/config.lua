-- Configuración de pxd_admin.
Config = {}

-- Teclas por defecto (cada jugador puede cambiarlas en Ajustes → Asignación de teclas → FiveM).
-- Ojo: qbx_vehicleradio usa F9 para la radio del coche (solo dentro de vehículos).
Config.keySupport = 'F9'   -- soporte y reportes (todos)
Config.keyStaff = 'F10'    -- panel de staff (solo con ACE pxd.admin)

-- ACE del staff. Expulsar pide además pxd.admin.kick (o pxd.admin.all).
Config.ace = 'pxd.admin'

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

-- Baneos: los gestiona txAdmin (Players → jugador → Ban). Esta URL se muestra en la ficha.
Config.txAdminHint = 'Para banear, usa txAdmin → Players → busca al jugador → Ban.'
