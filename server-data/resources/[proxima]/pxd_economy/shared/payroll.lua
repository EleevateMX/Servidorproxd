-- Lógica pura de la paga (sin natives ni base de datos). La usan el servidor y las pruebas.
PXDPayroll = {}
local P = PXDPayroll

--- Marca que debe llevar qbx_core/config/server.lua (parche de docs/41) para que deje de pagar.
P.PATCH_MARK = 'if GlobalState.pxdPayroll then return end'

local function int(n) n = tonumber(n) return n and math.floor(n) or 0 end

--- Sueldo bruto del ciclo según el trabajo del personaje.
--- job = PlayerData.job de qbx_core; jobDef = exports.qbx_core:GetJob(job.name) (puede faltar).
--- Devuelve bruto (entero ≥ 0) y tipo: 'sueldo', 'ayuda' (sin trabajo) o 'fuera' (fuera de servicio).
function P.gross(job, jobDef, cfg)
    if type(job) ~= 'table' or not job.name then return 0, 'ayuda' end
    if job.name == cfg.unemployedJob then return math.max(0, int(cfg.unemployedAid)), 'ayuda' end
    local level = type(job.grade) == 'table' and tonumber(job.grade.level) or 0
    local grade = jobDef and type(jobDef.grades) == 'table' and jobDef.grades[level] or nil
    local payment = tonumber(grade and grade.payment) or tonumber(job.payment) or 0
    local offDutyPay = jobDef and jobDef.offDutyPay == true
    if not job.onduty and not offDutyPay then return math.max(0, int(cfg.offDutyAid)), 'fuera' end
    return math.max(0, int(payment * (tonumber(cfg.multiplier) or 1))), 'sueldo'
end

--- Impuesto sobre un importe: tasa acotada entre 0 y maxRate, redondeo hacia abajo.
function P.tax(amount, rate, maxRate)
    rate = math.max(0, math.min(tonumber(rate) or 0, tonumber(maxRate) or 0.5))
    return math.max(0, math.min(int(amount), int(amount * rate)))
end

--- Estado de un personaje en el ciclo de paga.
function P.newState(progress, now)
    return { progress = math.max(0, int(progress)), lastMove = now, busy = false }
end

--- Registra la posición y el giro; devuelve true si lleva ausente más del umbral.
--- pos = { x, y, z }, heading en grados, now en segundos. Sin posición (ped no creado) no cuenta como actividad.
function P.activity(st, pos, heading, now, afk)
    if not afk or not afk.enabled then st.lastMove = now return false end
    if pos then
        local moved = false
        if st.pos then
            local dx, dy, dz = pos.x - st.pos.x, pos.y - st.pos.y, pos.z - st.pos.z
            if dx * dx + dy * dy + dz * dz >= (afk.minDistance or 2.0) ^ 2 then moved = true end
            if heading and st.heading then
                local d = math.abs(heading - st.heading) % 360
                if d > 180 then d = 360 - d end
                if d >= (afk.minHeading or 15.0) then moved = true end
            end
        end
        if moved or not st.pos then
            if moved then st.lastMove = now end
            st.pos, st.heading = { x = pos.x, y = pos.y, z = pos.z }, heading
        end
    end
    return (now - (st.lastMove or now)) >= (afk.minutes or 10) * 60
end

--- Otra señal de actividad (chat, interacción…): reinicia el contador de ausencia.
function P.touch(st, now) st.lastMove = now end

--- Suma tiempo al ciclo. `elapsed` se limita a dos revisiones para que un parón del servidor
--- no regale tiempo. Devuelve true cuando toca pagar.
function P.accumulate(st, elapsed, eligible, afk, cfg)
    local interval = (cfg.intervalMinutes or 30) * 60
    if eligible and not afk then
        elapsed = math.max(0, math.min(tonumber(elapsed) or 0, (cfg.tickSeconds or 30) * 2))
        st.progress = math.min(interval, st.progress + elapsed)
    end
    return st.progress >= interval
end

--- Segundos de tiempo activo que faltan para la siguiente paga.
function P.remaining(st, cfg)
    return math.max(0, (cfg.intervalMinutes or 30) * 60 - (st.progress or 0))
end

--- Desglose que se enseña al jugador.
function P.breakdown(gross, tax, kind, jobLabel, pending)
    return { gross = gross, tax = tax, net = gross - tax, kind = kind, job = jobLabel,
        fines = pending and pending.fines or 0, invoices = pending and pending.invoices or 0 }
end

return PXDPayroll
