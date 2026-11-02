-- Configuración de pxd_audit (auditoría común de Próxima). docs/34-auditoria-comun.md
Config = {}

-- Respaldo cuando oxmysql no está disponible (o una escritura en la BD falla):
-- se guarda en este archivo del recurso. Al pasar de `maxEntries`, las más antiguas se
-- mueven a data/audit.1.json (y las de .1 a .2…, hasta `rotateFiles` archivos).
Config.json = {
    file = 'data/audit.json',
    maxEntries = 5000,
    keepAfterRotate = 2500,   -- cuántas se quedan en el archivo principal tras rotar
    rotateFiles = 3,
}

-- Migración de los registros antiguos (nunca borra ni modifica los originales):
--   · pxd_compat/data/audit.json  → legacy_ref 'compat:<id>'
--   · tabla pxd_fine_events       → legacy_ref 'fine_event:<id>'
--   · respaldo JSON de pxd_audit  → legacy_ref 'audit_json:<archivo>:<id>'
-- Es idempotente: lo ya migrado se omite. También a mano: `pxd_audit_migrar` (consola).
Config.migration = {
    onStart = true,
    compat = { resource = 'pxd_compat', file = 'data/audit.json' },
    fineEvents = true,
    batch = 500,
}

-- Límites de cada entrada y de las consultas.
Config.limits = {
    category = 32, action = 32, actor = 64, target = 64, source = 64, legacyRef = 64,
    data = 4096,        -- bytes del JSON de `data`; si se pasa, se guarda { truncated = true, bytes = n }
    queryMax = 500, queryDefault = 100, offsetMax = 100000,
}

-- Espera máxima a que oxmysql termine de arrancar antes de usar el respaldo JSON.
Config.waitForOxmysqlSec = 15
