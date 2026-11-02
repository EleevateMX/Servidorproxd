-- Configuración de pxd_multichar (selección y creación de personaje).
Config = {}

-- Nombre que se muestra en la pantalla.
Config.serverName = 'PRÓXIMA RP'

-- Ranuras bloqueadas que se enseñan además de las permitidas (0 = ninguna).
-- El máximo real de personajes lo decide qbx_core (config/server.lua → characters).
Config.lockedSlotsShown = 2
Config.lockedSlotLabel = 'Ranura Plus'

-- Tienda (Tebex). Vacío = el botón «Desbloquear» no aparece.
Config.storeUrl = ''

-- Permitir que el jugador borre sus personajes (escribiendo su nombre para confirmar).
Config.enableDelete = true

-- Al crear personaje: ¿mostrar la elección de apartamento? Solo si qbx_apartments está iniciado.
Config.startingApartment = false

-- Fechas de nacimiento permitidas (formato AAAA-MM-DD).
Config.dateMin = '1930-01-01'
Config.dateMax = '2006-12-31'

-- Solo nacionalidades de la lista de qbx_core (data/nationalities.lua).
Config.limitNationalities = true
Config.defaultNationality = 'Mexican'

-- Palabras no permitidas en nombre, apellido y nacionalidad (en minúsculas).
Config.profanityWords = {
    ['admin'] = true,
    ['staff'] = true,
}

-- Tiempo máximo esperando modelos (ms).
Config.loadingModelsTimeout = 30000

-- Escenas: el personaje en pedCoords y la cámara en camCoords (se elige una al azar).
-- Coordenadas verificadas de qbx_core (config/client.lua → characters.locations).
Config.scenes = {
    { pedCoords = vec4(969.25, 72.61, 116.18, 276.55),   camCoords = vec4(972.2, 72.9, 116.68, 97.27) },
    { pedCoords = vec4(1104.49, 195.9, -49.44, 44.22),   camCoords = vec4(1102.29, 198.14, -48.86, 225.07) },
    { pedCoords = vec4(-2163.87, 1134.51, -24.37, 310.05), camCoords = vec4(-2161.7, 1136.4, -23.77, 131.52) },
    { pedCoords = vec4(-996.71, -68.07, -99.0, 57.61),   camCoords = vec4(-999.90, -66.30, -98.45, 241.68) },
    { pedCoords = vec4(-1023.45, -418.42, 67.66, 205.69), camCoords = vec4(-1021.8, -421.7, 68.14, 27.11) },
    { pedCoords = vec4(2265.27, 2925.02, -84.8, 267.77), camCoords = vec4(2268.24, 2925.02, -84.36, 90.88) },
    { pedCoords = vec4(-1004.5, -478.51, 50.03, 28.19),  camCoords = vec4(-1006.36, -476.19, 50.50, 210.38) },
}
