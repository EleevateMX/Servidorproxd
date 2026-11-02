-- Acceso a MariaDB (oxmysql). Todas las consultas están aquí, con parámetros.
-- Fechas como marca de tiempo UNIX (UTC).
PXDFineStore = {}

local Q = {
    createFines = [[
CREATE TABLE IF NOT EXISTS `pxd_fines` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(64) NOT NULL,
  `officer_citizenid` VARCHAR(64) DEFAULT NULL,
  `officer_name` VARCHAR(128) DEFAULT NULL,
  `reason` VARCHAR(200) NOT NULL,
  `notes` TEXT DEFAULT NULL,
  `amount` INT UNSIGNED NOT NULL,
  `paid` INT UNSIGNED NOT NULL DEFAULT 0,
  `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `society` VARCHAR(64) NOT NULL DEFAULT 'police',
  `record_ref` VARCHAR(64) DEFAULT NULL,
  `issued_at` BIGINT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `citizen_status` (`citizenid`, `status`)
)]],
    createEvents = [[
CREATE TABLE IF NOT EXISTS `pxd_fine_events` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `fine_id` INT UNSIGNED NOT NULL,
  `action` VARCHAR(16) NOT NULL,
  `actor_citizenid` VARCHAR(64) DEFAULT NULL,
  `actor_name` VARCHAR(128) DEFAULT NULL,
  `amount` INT DEFAULT NULL,
  `detail` VARCHAR(255) DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fine` (`fine_id`)
)]],
    insert = 'INSERT INTO pxd_fines (citizenid, officer_citizenid, officer_name, reason, notes, amount, paid, status, society, record_ref, issued_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, \'pending\', ?, ?, ?, ?)',
    get = 'SELECT * FROM pxd_fines WHERE id = ?',
    -- Las abiertas se listan todas (son deuda); el historial, solo las últimas.
    listOpen = 'SELECT * FROM pxd_fines WHERE citizenid = ? AND status IN (\'pending\', \'partial\') ORDER BY id DESC',
    listClosed = 'SELECT * FROM pxd_fines WHERE citizenid = ? AND status IN (\'paid\', \'cancelled\') ORDER BY id DESC LIMIT ?',
    outstanding = 'SELECT COALESCE(SUM(amount - paid), 0) FROM pxd_fines WHERE citizenid = ? AND status IN (\'pending\', \'partial\')',
    -- `status` se calcula ANTES de sumar `paid` (vale con y sin SIMULTANEOUS_ASSIGNMENT).
    pay = 'UPDATE pxd_fines SET status = CASE WHEN paid + ? >= amount THEN \'paid\' ELSE \'partial\' END, paid = paid + ?, updated_at = ? WHERE id = ? AND status IN (\'pending\', \'partial\') AND amount - paid >= ?',
    unpay = 'UPDATE pxd_fines SET status = CASE WHEN paid - ? <= 0 THEN \'pending\' ELSE \'partial\' END, paid = paid - ?, updated_at = ? WHERE id = ? AND paid >= ?',
    cancel = 'UPDATE pxd_fines SET status = \'cancelled\', updated_at = ? WHERE id = ? AND status IN (\'pending\', \'partial\')',
    edit = 'UPDATE pxd_fines SET status = CASE WHEN paid >= ? THEN \'paid\' WHEN paid > 0 THEN \'partial\' ELSE \'pending\' END, amount = ?, updated_at = ? WHERE id = ? AND status IN (\'pending\', \'partial\') AND paid <= ?',
    event = 'INSERT INTO pxd_fine_events (fine_id, action, actor_citizenid, actor_name, amount, detail, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    events = 'SELECT * FROM pxd_fine_events WHERE fine_id = ? ORDER BY id ASC',
}
PXDFineStore.Q = Q

function PXDFineStore.init()
    MySQL.query.await(Q.createFines)
    MySQL.query.await(Q.createEvents)
end

function PXDFineStore.insert(f, now)
    return MySQL.insert.await(Q.insert, {
        f.citizenid, f.officer_citizenid, f.officer_name, f.reason, f.notes, f.amount,
        f.society, f.record_ref, now, now,
    })
end

function PXDFineStore.get(id) return MySQL.single.await(Q.get, { id }) end

function PXDFineStore.list(citizenid, limit)
    local rows = MySQL.query.await(Q.listOpen, { citizenid }) or {}
    for _, r in ipairs(MySQL.query.await(Q.listClosed, { citizenid, limit or 25 }) or {}) do rows[#rows + 1] = r end
    return rows
end

function PXDFineStore.outstanding(citizenid)
    return tonumber(MySQL.scalar.await(Q.outstanding, { citizenid })) or 0
end

--- Suma `amount` a lo pagado solo si la multa sigue abierta y debe al menos eso. true si se aplicó.
function PXDFineStore.pay(id, amount, now)
    return (MySQL.update.await(Q.pay, { amount, amount, now, id, amount }) or 0) == 1
end

function PXDFineStore.unpay(id, amount, now)
    return (MySQL.update.await(Q.unpay, { amount, amount, now, id, amount }) or 0) == 1
end

function PXDFineStore.cancel(id, now)
    return (MySQL.update.await(Q.cancel, { now, id }) or 0) == 1
end

--- Cambia el importe (nunca por debajo de lo ya pagado).
function PXDFineStore.edit(id, amount, now)
    return (MySQL.update.await(Q.edit, { amount, amount, now, id, amount }) or 0) == 1
end

function PXDFineStore.event(fineId, action, actorCid, actorName, amount, detail, now)
    MySQL.insert.await(Q.event, { fineId, action, actorCid, actorName, amount, detail, now })
end

function PXDFineStore.events(fineId) return MySQL.query.await(Q.events, { fineId }) or {} end

return PXDFineStore
