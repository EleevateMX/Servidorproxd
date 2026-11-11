-- Configuración de pxd_orgs (organizaciones y bandas de jugadores). docs/42-organizaciones.md
Config = {}

-- ── Tipos ─────────────────────────────────────────────────────────────────────
-- Todas se apoyan en una banda de qbx_core (miembros y rangos son de qbx_core).
-- creatable = false: reservado. staffOnly = true: solo la crea el staff (pxd.orgs.manage).
Config.types = {
    banda     = { label = 'Banda',          plural = 'Bandas',          creatable = true },
    grupo     = { label = 'Grupo',          plural = 'Grupos',          creatable = true },
    motoclub  = { label = 'Club de motos',  plural = 'Clubes de motos', creatable = true },
    empresa   = { label = 'Empresa',        plural = 'Empresas',        creatable = false }, -- etapa B (negocios)
    gobierno  = { label = 'Gubernamental',  plural = 'Gubernamentales', creatable = true, staffOnly = true },
}

-- ── Crear ─────────────────────────────────────────────────────────────────────
-- 'staff': la solicitud queda «pendiente» hasta que el staff la aprueba (por defecto: las bandas
--          de un servidor de rol se regulan; el coste se devuelve si se rechaza).
-- 'auto' : queda oficial en cuanto se cumplen los requisitos.
Config.approval = 'staff'
Config.create = {
    minLevel = 3,            -- nivel de personaje del fundador (pxd_progress). Sin pxd_progress no se exige.
    cost = 25000,            -- tasa de registro, del banco del fundador (se retira del sistema)
    minFounders = 2,         -- fundadores en total (quien la crea + los que acepten), todos cerca
    founderDistance = 15.0,  -- metros entre quien la crea y cada cofundador
    draftSeconds = 600,      -- tiempo para que los cofundadores acepten
    cooldownSeconds = 3600,  -- espera entre solicitudes del mismo personaje
}
Config.name = { min = 3, max = 28 }
-- Nombres que no se pueden usar (se comparan sin tildes, espacios ni mayúsculas).
Config.blockedNames = { 'policia', 'police', 'lspd', 'bcso', 'sasp', 'ems', 'staff', 'admin', 'administracion',
    'proxima', 'proximarp', 'gobierno', 'ayuntamiento', 'estado' }

-- ── Rangos ────────────────────────────────────────────────────────────────────
-- Son los rangos de la banda en qbx_core (0…4). Permisos: invite (invitar), manage (expulsar y
-- cambiar rangos por debajo del propio), funds (retirar fondos), identity (color, tipografía, lema).
-- Transferir el liderazgo y disolver: solo el rango más alto (isboss).
Config.grades = {
    [0] = { name = 'Aspirante' },
    [1] = { name = 'Miembro' },
    [2] = { name = 'Veterano',     perms = { invite = true } },
    [3] = { name = 'Mano derecha', perms = { invite = true, manage = true, funds = true, identity = true }, bankAuth = true },
    [4] = { name = 'Líder',        perms = { invite = true, manage = true, funds = true, identity = true }, isboss = true, bankAuth = true },
}
-- Nombres de rango distintos por tipo (opcional).
Config.gradeNames = {
    motoclub = { [0] = 'Prospecto', [1] = 'Miembro', [2] = 'Sargento de armas', [3] = 'Vicepresidente', [4] = 'Presidente' },
    gobierno = { [0] = 'Funcionario', [1] = 'Técnico', [2] = 'Director', [3] = 'Secretario', [4] = 'Titular' },
}
Config.founderGrade = 2      -- rango de los cofundadores al hacerse oficial
Config.joinGrade = 0         -- rango al aceptar una invitación

-- ── Invitaciones ──────────────────────────────────────────────────────────────
Config.invite = { distance = 5.0, seconds = 300 }

-- ── Fondos (cuenta de la organización en Renewed-Banking) ─────────────────────
Config.funds = { methods = { cash = true, bank = true }, maxOperation = 1000000 }

-- ── Identidad ─────────────────────────────────────────────────────────────────
-- Paleta cerrada (se valida en el servidor). El primero es el color por defecto.
Config.colors = {
    '#5ce1ff', '#ff4fd8', '#ffc857', '#3fe08f', '#ff5472', '#9b7bff', '#ff8a3d', '#f2f5ff',
    '#2ec4b6', '#e63946', '#8ac926', '#1982c4', '#c77dff', '#b08968', '#adb5bd', '#ffd60a',
}
-- Tipografías incluidas en el recurso (html/ui/orgs-fonts.css, licencias en LICENSES.md).
-- family es el nombre CSS; la oleada 2 (grafitis, mapa) la carga de ese mismo archivo.
Config.fonts = {
    { id = 'sora',     label = 'Próxima',     family = 'Sora' },
    { id = 'bebas',    label = 'Cartel',      family = 'PXO Bebas Neue' },
    { id = 'marker',   label = 'Rotulador',   family = 'PXO Permanent Marker' },
    { id = 'bangers',  label = 'Cómic',       family = 'PXO Bangers' },
    { id = 'russo',    label = 'Industrial',  family = 'PXO Russo One' },
    { id = 'pacifico', label = 'Caligrafía',  family = 'PXO Pacifico' },
    { id = 'blackops', label = 'Plantilla',   family = 'PXO Black Ops One' },
}
Config.motto = { max = 60 }

-- ── Reputación y niveles ──────────────────────────────────────────────────────
-- slots = miembros máximos. (El almacén por nivel llegará con los barrios; aquí solo se reserva.)
Config.levels = {
    { level = 1, rep = 0,     slots = 8 },
    { level = 2, rep = 500,   slots = 12 },
    { level = 3, rep = 1500,  slots = 16 },
    { level = 4, rep = 4000,  slots = 22 },
    { level = 5, rep = 9000,  slots = 30 },
}
Config.maxReputationPerCall = 1000

-- ── Permisos y límites ────────────────────────────────────────────────────────
Config.ace = { manage = 'pxd.orgs.manage' }   -- aprobar, rechazar, crear sin requisitos y disolver cualquiera
Config.cooldown = { read = 0.3, write = 1.0 } -- segundos entre peticiones del mismo jugador
Config.command = 'org'
