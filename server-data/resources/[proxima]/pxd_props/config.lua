-- Configuración de pxd_props (editor y dashboard de props).
Config = {}

-- Permiso ACE para editar (ver server-data/permissions.cfg). Ver props no requiere permiso.
Config.editAce = 'pxd.props.edit'

-- Distancia (m) a la que cada cliente crea/borra los props locales a su alrededor.
Config.streamDistance = 250.0

-- Persistencia: archivo JSON dentro del recurso (se crea solo).
Config.dataFile = 'data/layouts.json'
Config.saveIntervalSec = 2

-- Límite de operaciones por segundo y editor (evita spam accidental o malicioso).
Config.opsPerSecond = 25

-- Dashboard web: http://IP:30120/pxd_props/
-- El token se lee de esta convar. Defínela con `set` (NO `setr`, que la enviaría a
-- los clientes) en secrets.cfg. Si está vacía, la API web queda desactivada.
Config.webTokenConvar = 'pxd_props_webToken'

-- Pasos de rejilla y giro que ofrece el editor.
Config.gridSizes = { 0.05, 0.1, 0.25, 0.5, 1.0, 2.0 }
Config.rotationSteps = { 1, 5, 15, 45, 90 }
