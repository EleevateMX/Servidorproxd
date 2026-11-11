-- Acceso a MariaDB (oxmysql) de pxd_orgs. Todas las consultas están aquí, con parámetros.
-- Solo guarda lo que qbx_core no tiene: la ficha de la organización, quién la fundó y su historial.
-- Los miembros y sus rangos son de qbx_core (player_groups). Fechas como marca de tiempo UNIX (UTC).
PXDOrgStore = {}
local S = PXDOrgStore

local Q = {
    createOrgs = [[
CREATE TABLE IF NOT EXISTS `pxd_orgs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `slug` VARCHAR(40) DEFAULT NULL,
  `name` VARCHAR(64) NOT NULL,
  `name_key` VARCHAR(64) NOT NULL,
  `type` VARCHAR(16) NOT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `leader_citizenid` VARCHAR(64) NOT NULL,
  `color` VARCHAR(7) NOT NULL,
  `font` VARCHAR(24) NOT NULL,
  `motto` VARCHAR(160) DEFAULT NULL,
  `emblem` VARCHAR(3) NOT NULL,
  `reputation` INT UNSIGNED NOT NULL DEFAULT 0,
  `cost_paid` INT UNSIGNED NOT NULL DEFAULT 0,
  `created_by` VARCHAR(64) NOT NULL,
  `created_at` BIGINT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  `decided_by` VARCHAR(128) DEFAULT NULL,
  `decided_at` BIGINT DEFAULT NULL,
  `decision_reason` VARCHAR(200) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`),
  KEY `name_key` (`name_key`),
  KEY `status` (`status`)
)]],
    createFounders = [[
CREATE TABLE IF NOT EXISTS `pxd_org_founders` (
  `org_id` INT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  PRIMARY KEY (`org_id`, `citizenid`)
)]],
    createEvents = [[
CREATE TABLE IF NOT EXISTS `pxd_org_events` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `org_id` INT UNSIGNED NOT NULL,
  `action` VARCHAR(24) NOT NULL,
  `actor_citizenid` VARCHAR(64) DEFAULT NULL,
  `actor_name` VARCHAR(128) DEFAULT NULL,
  `target` VARCHAR(128) DEFAULT NULL,
  `amount` INT DEFAULT NULL,
  `detail` VARCHAR(255) DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `org` (`org_id`)
)]],
    -- Vivas: pendientes y oficiales. Las rechazadas y disueltas se conservan, pero no se cargan.
    loadLive = "SELECT * FROM pxd_orgs WHERE status IN ('pending', 'official')",
    get = 'SELECT * FROM pxd_orgs WHERE id = ?',
    -- El nombre queda libre cuando la organización se rechaza o se disuelve.
    nameTaken = "SELECT id FROM pxd_orgs WHERE name_key = ? AND status IN ('pending', 'official') LIMIT 1",
    lastByCreator = 'SELECT MAX(created_at) FROM pxd_orgs WHERE created_by = ?',
    insert = "INSERT INTO pxd_orgs (name, name_key, type, status, leader_citizenid, color, font, motto, emblem, cost_paid, created_by, created_at, updated_at) VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    setSlug = 'UPDATE pxd_orgs SET slug = ? WHERE id = ? AND slug IS NULL',
    -- Condicionales: solo cambian la fila si sigue en el estado esperado.
    decide = "UPDATE pxd_orgs SET status = ?, decided_by = ?, decided_at = ?, decision_reason = ?, updated_at = ? WHERE id = ? AND status = 'pending'",
    dissolve = "UPDATE pxd_orgs SET status = 'dissolved', decided_by = ?, decided_at = ?, decision_reason = ?, updated_at = ? WHERE id = ? AND status = 'official'",
    setIdentity = "UPDATE pxd_orgs SET color = ?, font = ?, motto = ?, emblem = ?, updated_at = ? WHERE id = ? AND status = 'official'",
    setLeader = "UPDATE pxd_orgs SET leader_citizenid = ?, updated_at = ? WHERE id = ? AND status = 'official'",
    addReputation = "UPDATE pxd_orgs SET reputation = ?, updated_at = ? WHERE id = ? AND status = 'official'",
    addFounder = 'INSERT IGNORE INTO pxd_org_founders (org_id, citizenid, name, created_at) VALUES (?, ?, ?, ?)',
    founders = 'SELECT citizenid, name FROM pxd_org_founders WHERE org_id = ?',
    event = 'INSERT INTO pxd_org_events (org_id, action, actor_citizenid, actor_name, target, amount, detail, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    events = 'SELECT action, actor_name, target, amount, detail, created_at FROM pxd_org_events WHERE org_id = ? ORDER BY id DESC LIMIT ?',
}
S.Q = Q

function S.init()
    MySQL.query.await(Q.createOrgs)
    MySQL.query.await(Q.createFounders)
    MySQL.query.await(Q.createEvents)
end

function S.loadLive() return MySQL.query.await(Q.loadLive) or {} end
function S.get(id) return MySQL.single.await(Q.get, { id }) end
function S.nameTaken(key) return MySQL.scalar.await(Q.nameTaken, { key }) ~= nil end
function S.lastByCreator(cid) return tonumber(MySQL.scalar.await(Q.lastByCreator, { cid })) end

--- Crea la ficha (pendiente) y le asigna su banda de qbx_core: «pxo_<id>».
function S.insert(o, now)
    local id = MySQL.insert.await(Q.insert, { o.name, o.name_key, o.type, o.leader_citizenid, o.color, o.font, o.motto, o.emblem,
        o.cost_paid or 0, o.created_by, now, now })
    if not id then return nil end
    local slug = ('pxo_%d'):format(id)
    MySQL.update.await(Q.setSlug, { slug, id })
    return id, slug
end

function S.decide(id, status, by, reason, now)
    return (MySQL.update.await(Q.decide, { status, by, now, reason, now, id }) or 0) > 0
end
function S.dissolve(id, by, reason, now)
    return (MySQL.update.await(Q.dissolve, { by, now, reason, now, id }) or 0) > 0
end
function S.setIdentity(id, i, now)
    return (MySQL.update.await(Q.setIdentity, { i.color, i.font, i.motto, i.emblem, now, id }) or 0) > 0
end
function S.setLeader(id, cid, now) return (MySQL.update.await(Q.setLeader, { cid, now, id }) or 0) > 0 end
function S.setReputation(id, rep, now) return (MySQL.update.await(Q.addReputation, { rep, now, id }) or 0) > 0 end
function S.addFounder(id, cid, name, now) return MySQL.insert.await(Q.addFounder, { id, cid, name, now }) end
function S.founders(id) return MySQL.query.await(Q.founders, { id }) or {} end
function S.event(id, action, cid, name, target, amount, detail, now)
    return MySQL.insert.await(Q.event, { id, action, cid, name, target, amount, detail, now })
end
function S.events(id, limit) return MySQL.query.await(Q.events, { id, limit }) or {} end
