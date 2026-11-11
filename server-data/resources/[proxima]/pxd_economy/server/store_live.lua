-- Almacén de la economía viva (paga, impuestos y mercado). oxmysql; tablas con prefijo pxd_,
-- creadas con CREATE TABLE IF NOT EXISTS; nunca se borran ni se alteran columnas.
PXDLiveStore = {}
local S = PXDLiveStore

local Q = {
    createPayroll = [[CREATE TABLE IF NOT EXISTS pxd_payroll (
        citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
        progress INT UNSIGNED NOT NULL DEFAULT 0,
        last_paid_at INT UNSIGNED NOT NULL DEFAULT 0,
        paid_total BIGINT UNSIGNED NOT NULL DEFAULT 0,
        paid_count INT UNSIGNED NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createTaxes = [[CREATE TABLE IF NOT EXISTS pxd_tax_ledger (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        created_at INT UNSIGNED NOT NULL,
        kind VARCHAR(20) NOT NULL,
        citizenid VARCHAR(50) NULL,
        base BIGINT UNSIGNED NOT NULL,
        amount BIGINT UNSIGNED NOT NULL,
        deposited TINYINT(1) NOT NULL DEFAULT 0,
        detail VARCHAR(120) NULL,
        INDEX idx_time (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createPrices = [[CREATE TABLE IF NOT EXISTS pxd_market_prices (
        good VARCHAR(40) NOT NULL PRIMARY KEY,
        price DECIMAL(12,2) NOT NULL,
        bought DECIMAL(14,2) NOT NULL DEFAULT 0,
        sold DECIMAL(14,2) NOT NULL DEFAULT 0,
        updated_at INT UNSIGNED NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createHistory = [[CREATE TABLE IF NOT EXISTS pxd_market_history (
        good VARCHAR(40) NOT NULL,
        at INT UNSIGNED NOT NULL,
        price DECIMAL(12,2) NOT NULL,
        bought DECIMAL(14,2) NOT NULL DEFAULT 0,
        sold DECIMAL(14,2) NOT NULL DEFAULT 0,
        PRIMARY KEY (good, at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    createNews = [[CREATE TABLE IF NOT EXISTS pxd_market_news (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        at INT UNSIGNED NOT NULL,
        headline VARCHAR(220) NOT NULL,
        kind VARCHAR(20) NOT NULL,
        good VARCHAR(40) NULL,
        category VARCHAR(40) NULL,
        pct DECIMAL(8,4) NOT NULL DEFAULT 0,
        ticks_left INT NOT NULL DEFAULT 0,
        event_id VARCHAR(40) NULL,
        INDEX idx_time (at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    -- Paga
    payrollEnsure = 'INSERT IGNORE INTO pxd_payroll (citizenid) VALUES (?)',
    payrollGet = 'SELECT progress, last_paid_at FROM pxd_payroll WHERE citizenid = ?',
    payrollSave = 'UPDATE pxd_payroll SET progress = ? WHERE citizenid = ?',
    -- Condicional: solo «cobra» si no cobró ya dentro de este ciclo (evita la doble paga).
    payrollClaim = 'UPDATE pxd_payroll SET last_paid_at = ?, progress = 0, paid_total = paid_total + ?, paid_count = paid_count + 1 WHERE citizenid = ? AND last_paid_at <= ?',
    payrollRevert = 'UPDATE pxd_payroll SET last_paid_at = ?, progress = ?, paid_total = paid_total - ?, paid_count = paid_count - 1 WHERE citizenid = ? AND last_paid_at = ? AND paid_total >= ? AND paid_count >= 1',

    -- Impuestos
    taxInsert = 'INSERT INTO pxd_tax_ledger (created_at, kind, citizenid, base, amount, deposited, detail) VALUES (?, ?, ?, ?, ?, ?, ?)',
    taxSince = 'SELECT kind, COALESCE(SUM(amount), 0) AS amount, COUNT(*) AS count FROM pxd_tax_ledger WHERE created_at >= ? GROUP BY kind',

    -- Mercado
    pricesAll = 'SELECT good, price, bought, sold FROM pxd_market_prices',
    priceUpsert = 'INSERT INTO pxd_market_prices (good, price, bought, sold, updated_at) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE price = VALUES(price), bought = VALUES(bought), sold = VALUES(sold), updated_at = VALUES(updated_at)',
    historyInsert = 'INSERT IGNORE INTO pxd_market_history (good, at, price, bought, sold) VALUES (?, ?, ?, ?, ?)',
    historySince = 'SELECT at, price, bought, sold FROM pxd_market_history WHERE good = ? AND at >= ? ORDER BY at ASC LIMIT 2000',
    historyPrune = 'DELETE FROM pxd_market_history WHERE at < ?',
    newsInsert = 'INSERT INTO pxd_market_news (at, headline, kind, good, category, pct, ticks_left, event_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    newsLatest = 'SELECT id, at, headline, kind, good, category, pct FROM pxd_market_news WHERE id > ? ORDER BY id DESC LIMIT ?',
    newsActive = 'SELECT id, at, headline, kind, good, category, pct, ticks_left, event_id FROM pxd_market_news WHERE ticks_left > 0',
    newsTick = 'UPDATE pxd_market_news SET ticks_left = ticks_left - 1 WHERE ticks_left > 0',
}
S.Q = Q

function S.initPayroll() MySQL.query.await(Q.createPayroll) end
function S.initTaxes() MySQL.query.await(Q.createTaxes) end
function S.initMarket()
    MySQL.query.await(Q.createPrices)
    MySQL.query.await(Q.createHistory)
    MySQL.query.await(Q.createNews)
end

-- Paga
function S.payrollLoad(cid)
    MySQL.insert.await(Q.payrollEnsure, { cid })
    return MySQL.single.await(Q.payrollGet, { cid }) or { progress = 0, last_paid_at = 0 }
end
function S.payrollSave(cid, progress) return MySQL.update.await(Q.payrollSave, { progress, cid }) end
function S.payrollClaim(cid, now, amount, notAfter)
    return (MySQL.update.await(Q.payrollClaim, { now, amount, cid, notAfter }) or 0) > 0
end
function S.payrollRevert(cid, prevPaidAt, progress, amount, claimedAt)
    return (MySQL.update.await(Q.payrollRevert, { prevPaidAt, progress, amount, cid, claimedAt, amount }) or 0) > 0
end

-- Impuestos
function S.taxInsert(now, kind, cid, base, amount, deposited, detail)
    return MySQL.insert.await(Q.taxInsert, { now, kind, cid, base, amount, deposited and 1 or 0, detail })
end
function S.taxSince(t) return MySQL.query.await(Q.taxSince, { t }) or {} end

-- Mercado
function S.pricesAll() return MySQL.query.await(Q.pricesAll, {}) or {} end
function S.priceUpsert(good, price, bought, sold, now)
    return MySQL.update.await(Q.priceUpsert, { good, price, bought, sold, now })
end
function S.historyInsert(good, at, price, bought, sold)
    return MySQL.insert.await(Q.historyInsert, { good, at, price, bought, sold })
end
function S.historySince(good, t) return MySQL.query.await(Q.historySince, { good, t }) or {} end
function S.historyPrune(t) return MySQL.update.await(Q.historyPrune, { t }) end
function S.newsInsert(n)
    return MySQL.insert.await(Q.newsInsert, { n.at, n.headline, n.kind or 'evento', n.good, n.category, n.pct or 0, n.left or 0, n.id })
end
function S.newsLatest(sinceId, limit) return MySQL.query.await(Q.newsLatest, { sinceId or 0, limit }) or {} end
function S.newsActive() return MySQL.query.await(Q.newsActive, {}) or {} end
function S.newsTick() return MySQL.update.await(Q.newsTick, {}) end
