-- Almacén de pxd_economy (oxmysql). Tablas con prefijo pxd_, nunca se borran ni se alteran columnas.
PXDEconomyStore = {}
local S = PXDEconomyStore

local Q = {
    createInvoices = [[CREATE TABLE IF NOT EXISTS pxd_invoices (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        job VARCHAR(50) NOT NULL,
        job_label VARCHAR(80) NULL,
        account VARCHAR(50) NOT NULL,
        issuer_citizenid VARCHAR(50) NULL,
        issuer_name VARCHAR(100) NULL,
        citizenid VARCHAR(50) NOT NULL,
        client_name VARCHAR(100) NULL,
        concept VARCHAR(120) NOT NULL,
        amount INT UNSIGNED NOT NULL,
        paid INT UNSIGNED NOT NULL DEFAULT 0,
        status ENUM('pending','partial','paid','cancelled') NOT NULL DEFAULT 'pending',
        issued_at INT UNSIGNED NOT NULL,
        updated_at INT UNSIGNED NOT NULL,
        INDEX idx_client (citizenid, status),
        INDEX idx_job (job, status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createEvents = [[CREATE TABLE IF NOT EXISTS pxd_invoice_events (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        invoice_id INT UNSIGNED NOT NULL,
        action VARCHAR(20) NOT NULL,
        actor_citizenid VARCHAR(50) NULL,
        actor_name VARCHAR(100) NULL,
        amount INT UNSIGNED NULL,
        detail VARCHAR(255) NULL,
        created_at INT UNSIGNED NOT NULL,
        INDEX idx_invoice (invoice_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createFlow = [[CREATE TABLE IF NOT EXISTS pxd_money_flow (
        hour INT UNSIGNED NOT NULL,
        reason VARCHAR(64) NOT NULL,
        money_type VARCHAR(20) NOT NULL,
        direction ENUM('in','out') NOT NULL,
        total BIGINT UNSIGNED NOT NULL DEFAULT 0,
        count INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (hour, reason, money_type, direction)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createLarge = [[CREATE TABLE IF NOT EXISTS pxd_money_large (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        created_at INT UNSIGNED NOT NULL,
        citizenid VARCHAR(50) NULL,
        reason VARCHAR(64) NOT NULL,
        money_type VARCHAR(20) NOT NULL,
        direction ENUM('in','out') NOT NULL,
        amount BIGINT UNSIGNED NOT NULL,
        INDEX idx_time (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    insert = 'INSERT INTO pxd_invoices (job, job_label, account, issuer_citizenid, issuer_name, citizenid, client_name, concept, amount, issued_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    event = 'INSERT INTO pxd_invoice_events (invoice_id, action, actor_citizenid, actor_name, amount, detail, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    get = 'SELECT * FROM pxd_invoices WHERE id = ?',
    listClient = "SELECT * FROM pxd_invoices WHERE citizenid = ? ORDER BY (status IN ('pending','partial')) DESC, id DESC LIMIT ?",
    listJob = "SELECT * FROM pxd_invoices WHERE job = ? ORDER BY (status IN ('pending','partial')) DESC, id DESC LIMIT ?",
    countOpen = "SELECT COUNT(*) FROM pxd_invoices WHERE citizenid = ? AND job = ? AND status IN ('pending','partial')",
    outstanding = "SELECT COALESCE(SUM(amount - paid), 0) FROM pxd_invoices WHERE citizenid = ? AND status IN ('pending','partial')",
    -- Condicionales: solo cambian la fila si sigue abierta y le queda al menos lo que se paga.
    pay = "UPDATE pxd_invoices SET status = IF(paid + ? >= amount, 'paid', 'partial'), paid = paid + ?, updated_at = ? WHERE id = ? AND status IN ('pending','partial') AND amount - paid >= ?",
    unpay = "UPDATE pxd_invoices SET status = IF(paid - ? <= 0, 'pending', 'partial'), paid = paid - ?, updated_at = ? WHERE id = ? AND paid >= ?",
    cancel = "UPDATE pxd_invoices SET status = 'cancelled', updated_at = ? WHERE id = ? AND status IN ('pending','partial')",

    flowUpsert = 'INSERT INTO pxd_money_flow (hour, reason, money_type, direction, total, count) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE total = total + VALUES(total), count = count + VALUES(count)',
    flowSince = 'SELECT reason, money_type, direction, SUM(total) AS total, SUM(count) AS count FROM pxd_money_flow WHERE hour >= ? GROUP BY reason, money_type, direction',
    largeInsert = 'INSERT INTO pxd_money_large (created_at, citizenid, reason, money_type, direction, amount) VALUES (?, ?, ?, ?, ?, ?)',
    largeSince = 'SELECT * FROM pxd_money_large WHERE created_at >= ? ORDER BY amount DESC LIMIT ?',
    -- Dinero de los personajes según el último guardado de qbx_core (aproximado).
    circulation = "SELECT COALESCE(SUM(CAST(JSON_VALUE(money, '$.cash') AS DECIMAL(20,0))), 0) AS cash, COALESCE(SUM(CAST(JSON_VALUE(money, '$.bank') AS DECIMAL(20,0))), 0) AS bank FROM players",
}
S.Q = Q

function S.init()
    MySQL.query.await(Q.createInvoices)
    MySQL.query.await(Q.createEvents)
    MySQL.query.await(Q.createFlow)
    MySQL.query.await(Q.createLarge)
end

function S.insert(r, now)
    return MySQL.insert.await(Q.insert, { r.job, r.job_label, r.account, r.issuer_citizenid, r.issuer_name, r.citizenid,
        r.client_name, r.concept, r.amount, now, now })
end

function S.event(id, action, cid, name, amount, detail, now)
    return MySQL.insert.await(Q.event, { id, action, cid, name, amount, detail, now })
end

function S.get(id) return MySQL.single.await(Q.get, { id }) end
function S.listClient(cid, limit) return MySQL.query.await(Q.listClient, { cid, limit }) or {} end
function S.listJob(job, limit) return MySQL.query.await(Q.listJob, { job, limit }) or {} end
function S.countOpen(cid, job) return tonumber(MySQL.scalar.await(Q.countOpen, { cid, job })) or 0 end
function S.outstanding(cid) return tonumber(MySQL.scalar.await(Q.outstanding, { cid })) or 0 end
function S.pay(id, amount, now) return (MySQL.update.await(Q.pay, { amount, amount, now, id, amount }) or 0) > 0 end
function S.unpay(id, amount, now) return (MySQL.update.await(Q.unpay, { amount, amount, now, id, amount }) or 0) > 0 end
function S.cancel(id, now) return (MySQL.update.await(Q.cancel, { now, id }) or 0) > 0 end

function S.flowUpsert(rows)
    for _, r in ipairs(rows) do
        MySQL.update.await(Q.flowUpsert, { r.hour, r.reason, r.money_type, r.direction, r.total, r.count })
    end
end
function S.flowSince(hour) return MySQL.query.await(Q.flowSince, { hour }) or {} end
function S.largeInsert(now, cid, reason, moneyType, direction, amount)
    return MySQL.insert.await(Q.largeInsert, { now, cid, reason, moneyType, direction, amount })
end
function S.largeSince(t, limit) return MySQL.query.await(Q.largeSince, { t, limit }) or {} end
function S.circulation() return MySQL.single.await(Q.circulation, {}) end
