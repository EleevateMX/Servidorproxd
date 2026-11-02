-- Configuración de pxd_compat.
Config = {}

-- Desgaste de piezas de qbx_mechanicjob: solo lo guarda en la BD con el evento
-- 'vehiclemod:server:saveStatus' («used in old qb-garages»), que qbx_garages ya no
-- dispara. pxd_compat lo dispara por cada vehículo que haya cambiado.
Config.wear = {
    enabled = true,
    saveIntervalSec = 60,   -- como mucho una escritura por vehículo y minuto
    tickSec = 15,
}

-- Auditoría (server/audit.lua). Otros módulos lo usan con exports.pxd_compat:Audit({ category, action, ... }).
-- Con pxd_audit en marcha delega en él (docs/34-auditoria-comun.md); si no, usa este archivo.
Config.audit = {
    delegate = true,        -- false: no usar pxd_audit aunque esté en marcha
    file = 'data/audit.json',
    maxEntries = 5000,      -- se conservan las más recientes (solo en el archivo de respaldo)
}

-- Hospital (docs/29-hospital.md). Requiere en qbx_ambulancejob
-- `wipeInvOnRespawn = false` (si sigue en true, qbx_ambulancejob borra TODO antes).
--  · Reanimación por EMS (qbx_medical Revive): no se retira nada.
--  · Reaparición en el hospital (`qbx_medical:server:playerRespawned`): solo se
--    retiran los objetos confiscables; lo protegido nunca se toca.
Config.medical = {
    enabled = true,
    -- Ventana para ignorar el mismo evento repetido (qbx_medical ya bloquea 30 s).
    dedupeMs = 30000,

    -- Nunca se retiran (además de `money`, que siempre está protegido): efectivo,
    -- documentos, teléfono, radio y objetos personales o legales.
    protected = {
        'money', 'id_card', 'driver_license', 'weaponlicense', 'lawyerpass',
        'phone', 'radio', 'harness', 'walking_stick', 'binoculars', 'lighter',
        -- Herramientas que ox_inventory trata como arma pero son legales:
        'WEAPON_FLASHLIGHT', 'WEAPON_FIREEXTINGUISHER', 'WEAPON_PETROLCAN',
        'WEAPON_HAZARDCAN', 'WEAPON_FERTILIZERCAN', 'WEAPON_METALDETECTOR',
    },

    -- Se retiran todos los objetos cuyo nombre empiece así (armas y munición de
    -- ox_inventory), salvo los protegidos.
    confiscatePrefixes = { 'WEAPON_', 'ammo-' },

    -- Lista administrativa de objetos ilegales (solo nombres que existen en items.lua
    -- de la receta). Edítala a tu gusto.
    confiscate = {
        'black_money',
        'crack_baggy', 'cokebaggy', 'coke_brick', 'coke_small_brick', 'xtcbaggy', 'meth', 'oxy',
        'weed_ak47', 'weed_skunk', 'weed_amnesia', 'weed_brick', 'joint',
        'thermite', 'gatecrack', 'trojan_usb',
    },

    notify = true,
}
