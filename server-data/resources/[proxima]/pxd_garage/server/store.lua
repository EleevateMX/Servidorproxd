-- Almacén de pxd_garage (oxmysql): experiencia de mecánicos y registro de trabajos.
-- Los vehículos NO se guardan aquí: su dueño es qbx_vehicles (player_vehicles).
PXDGarageStore = {}
local S = PXDGarageStore

local Q = {
    createStats = [[CREATE TABLE IF NOT EXISTS pxd_mechanic_stats (
        citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
        xp INT UNSIGNED NOT NULL DEFAULT 0,
        jobs INT UNSIGNED NOT NULL DEFAULT 0,
        day INT UNSIGNED NOT NULL DEFAULT 0,
        day_xp INT UNSIGNED NOT NULL DEFAULT 0,
        updated_at INT UNSIGNED NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createLog = [[CREATE TABLE IF NOT EXISTS pxd_mechanic_log (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(50) NOT NULL,
        kind VARCHAR(20) NOT NULL,
        plate VARCHAR(15) NULL,
        xp INT UNSIGNED NOT NULL DEFAULT 0,
        amount INT UNSIGNED NOT NULL DEFAULT 0,
        detail VARCHAR(255) NULL,
        created_at INT UNSIGNED NOT NULL,
        INDEX idx_citizen (citizenid, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    get = 'SELECT citizenid, xp, jobs, day, day_xp FROM pxd_mechanic_stats WHERE citizenid = ?',
    -- Suma experiencia; si cambió el día, el contador diario empieza de cero.
    add = [[INSERT INTO pxd_mechanic_stats (citizenid, xp, jobs, day, day_xp, updated_at) VALUES (?, ?, 1, ?, ?, ?)
        ON DUPLICATE KEY UPDATE xp = xp + VALUES(xp), jobs = jobs + 1,
        day_xp = IF(day = VALUES(day), day_xp + VALUES(day_xp), VALUES(day_xp)), day = VALUES(day), updated_at = VALUES(updated_at)]],
    set = [[INSERT INTO pxd_mechanic_stats (citizenid, xp, jobs, day, day_xp, updated_at) VALUES (?, ?, 0, 0, 0, ?)
        ON DUPLICATE KEY UPDATE xp = VALUES(xp), updated_at = VALUES(updated_at)]],
    log = 'INSERT INTO pxd_mechanic_log (citizenid, kind, plate, xp, amount, detail, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    recent = 'SELECT kind, plate, xp, amount, detail, created_at FROM pxd_mechanic_log WHERE citizenid = ? ORDER BY id DESC LIMIT ?',
}
S.Q = Q

function S.init()
    MySQL.query.await(Q.createStats)
    MySQL.query.await(Q.createLog)
end

function S.get(cid) return MySQL.single.await(Q.get, { cid }) end
function S.add(cid, xp, day, now) return MySQL.update.await(Q.add, { cid, xp, day, xp, now }) end
function S.set(cid, xp, now) return MySQL.update.await(Q.set, { cid, xp, now }) end
function S.log(cid, kind, plate, xp, amount, detail, now)
    return MySQL.insert.await(Q.log, { cid, kind, plate, xp, amount, detail and tostring(detail):sub(1, 255) or nil, now })
end
function S.recent(cid, limit) return MySQL.query.await(Q.recent, { cid, limit }) or {} end
