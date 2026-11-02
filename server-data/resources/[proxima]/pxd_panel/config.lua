-- Configuración de pxd_panel (el panel de la ciudad).
Config = {}

-- Tecla por defecto. Cada jugador puede cambiarla en Ajustes de FiveM → Asignación de teclas → FiveM.
-- OJO: ox_inventory usa TAB para la barra rápida (convar inventory:keys, 3.ª tecla). Si quieres el
-- panel en TAB, mueve la barra rápida: setr inventory:keys '["F2","K","F3"]' en el server.cfg.
Config.key = 'TAB'
Config.command = 'panel'           -- también se abre con /panel

Config.serverName = 'PRÓXIMA RP'
Config.storeUrl = ''               -- tienda Tebex (https://…). Vacío: el botón no aparece.
Config.discord = 'https://discord.gg/qUcD5gCf6v'

-- Zona horaria para mostrar fechas (IANA, p. ej. 'America/Mexico_City'). nil = la del jugador.
-- Las fechas de los eventos se escriben SIEMPRE en UTC.
Config.timeZone = nil

-- Organizaciones: tipos de trabajo de Qbox que cuentan como gubernamentales.
-- (Qbox trae 'leo' en la policía y 'ems' en ambulancia; añade los tuyos si creas otros.)
Config.governmentTypes = { leo = true, ems = true, doj = true, gov = true }
Config.hiddenJobs = { unemployed = true }
Config.hiddenGangs = { none = true }

-- Ayuda: cómo pedir soporte. Solo comandos que existen en el servidor.
Config.support = {
    { title = 'Soporte del staff', text = 'Pulsa F9 en el juego para pedir ayuda al staff. También puedes abrir un ticket en Discord.', link = 'https://discord.gg/qUcD5gCf6v' },
    { title = 'Reportar a un jugador', text = 'Pulsa F9 → «Reportar a un jugador», con su ID (/id te dice el tuyo) y lo que pasó.' },
    { title = 'Hablar fuera de personaje', text = 'Usa /b (o /ooc) para mensajes fuera de rol a los que están cerca. Úsalo poco y con respeto.' },
    { title = 'Acciones de tu personaje', text = 'Usa /me para describir lo que hace tu personaje.' },
}

-- Eventos: fechas en UTC (AAAA-MM-DDTHH:MM:SSZ). image es opcional (URL https o archivo del recurso).
Config.events = {
    -- Ejemplo de evento con fecha (descoméntalo y edítalo):
    -- {
    --     id = 'bienvenida',
    --     title = 'Noche de bienvenida',
    --     description = 'Recorrido por la ciudad con el staff.',
    --     startsAt = '2026-11-14T02:00:00Z',   -- UTC
    --     place = 'Ayuntamiento',
    --     howTo = 'Preséntate 10 minutos antes.',
    -- },
    {
        id = 'propio',
        title = 'Crea tu propio evento',
        description = 'Fiestas, carreras, torneos o quedadas: propón el tuyo y el staff te ayuda a montarlo.',
        place = 'Discord',
        howTo = 'Abre un ticket «Evento» en Discord con nombre, fecha y descripción.',
        steps = { 'Abre un ticket en Discord', 'Cuéntanos nombre, fecha y descripción', 'Diseñamos el escenario contigo', 'El staff lo revisa y lo anuncia' },
    },
}

-- Novedades (lo más reciente primero).
Config.news = {
    { date = '2026-11-02', title = 'Panel de la ciudad', items = { 'Nuevo panel con perfil, recompensas, logros, eventos y reglamento.' } },
    { date = '2026-10-30', title = 'Pantalla de carga renovada', items = { 'Código de la ciudad, radio PRÓXIMA FM y fondo de la ciudad.' } },
}

-- Segundos mínimos entre peticiones de un mismo jugador (anti-spam).
Config.requestCooldown = 1.0
