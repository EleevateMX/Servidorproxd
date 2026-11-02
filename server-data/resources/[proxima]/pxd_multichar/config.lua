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

-- ── Aparición (sustituye las pizarras de qbx_spawn y de qbx_properties) ──────
-- true: tras JUGAR se elige dónde aparecer con nuestra pantalla (última ubicación,
-- casas propias y estos puntos). Los personajes sin apartamento eligen antes su
-- apartamento inicial gratis (qbx_properties), también en nuestra pantalla.
Config.spawnPicker = true

-- Puntos de la ciudad. Coordenadas de qbx_spawn (config/client.lua).
Config.spawnPoints = {
    { label = 'Plaza Legion', detail = 'Centro de la ciudad', coords = vec4(195.17, -933.77, 29.7, 144.5), image = 'assets/spawn-centro.jpg' },
    { label = 'Paleto Bay', detail = 'Pueblo del norte, junto al mar', coords = vec4(80.35, 6424.12, 31.67, 45.5), image = 'assets/spawn-paleto.jpg' },
    { label = 'Motel', detail = 'Habitaciones baratas para empezar', coords = vec4(327.56, -205.08, 53.08, 163.5), image = 'assets/spawn-motel.jpg' },
}

-- Cámara de la pantalla de aparición (no se ve la escena de personajes).
-- from/at: vista aérea inicial (Los Santos desde el sur, mirando al centro).
-- optionOffset: desde dónde se mira cada opción al marcarla (m respecto al punto).
Config.spawnCamera = {
    from = vec3(150.0, -1550.0, 240.0),
    at = vec3(-60.0, -800.0, 90.0),
    fov = 50.0,
    optionOffset = vec3(-45.0, -70.0, 55.0),
    optionFov = 45.0,
    interpMs = 1200,
}

-- Imágenes para la última ubicación y las casas propias.
Config.spawnImages = { last = 'assets/spawn-ultima.jpg', property = 'assets/spawn-casa.jpg', apartment = 'assets/spawn-casa.jpg' }

-- Textos en español de los apartamentos iniciales (por «interior» de
-- qbx_properties/config/shared.lua → apartmentOptions). Los que falten usan el suyo.
Config.apartmentTexts = {
    DellPerroHeightsApt4 = { label = 'Del Perro Heights', detail = 'Vistas al mar, lejos del ruido de la playa.' },
    DellPerroHeightsApt7 = { label = 'Del Perro Heights (alto)', detail = 'Planta alta con vistas a toda la costa.' },
    ['4IntegrityWayApt28'] = { label = '4 Integrity Way', detail = 'En pleno centro, rodeado de rascacielos.' },
    ['4IntegrityWayApt30'] = { label = '4 Integrity Way (amplio)', detail = 'El más espacioso del edificio.' },
    RichardMajesticApt2 = { label = 'Richard Majestic', detail = 'Condominio de lujo junto a los estudios de música.' },
    TinselTowersApt42 = { label = 'Tinsel Towers', detail = 'Torre residencial en Rockford Hills.' },
}

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
