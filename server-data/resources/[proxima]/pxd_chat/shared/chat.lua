-- Lógica pura de pxd_chat (sin natives): limpiar texto, anti-spam, nombres y destinatarios.
PXDChat = {}

--- Quita códigos de color (^1, ~r~), espacios de sobra y recorta. nil si queda vacío.
function PXDChat.clean(text, maxLen)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('%^%d', ''):gsub('~%a~', ''):gsub('[%c]', ' '):gsub('%s+', ' ')
    text = text:match('^%s*(.-)%s*$')
    if text == '' then return nil end
    if maxLen and #text > maxLen then
        -- recorta sin partir un carácter UTF-8
        local cut = maxLen
        while cut > 0 and (text:byte(cut + 1) or 0) >= 0x80 and (text:byte(cut + 1) or 0) < 0xC0 do cut = cut - 1 end
        text = text:sub(1, cut) .. '…'
    end
    return text
end

--- Anti-spam por jugador: como mucho `max` mensajes en `window` segundos.
function PXDChat.newLimiter(max, window)
    local hits = {}
    return {
        allow = function(src, now)
            local list = hits[src] or {}
            local fresh = {}
            for _, t in ipairs(list) do if now - t < window then fresh[#fresh + 1] = t end end
            if #fresh >= max then hits[src] = fresh; return false end
            fresh[#fresh + 1] = now
            hits[src] = fresh
            return true
        end,
        forget = function(src) hits[src] = nil end,
    }
end

--- Nombre que ve quien lee: el del personaje si lo conoce (o es él mismo), si no
--- «Desconocido · PROX-XXXX».
function PXDChat.label(opts)
    if opts.self or opts.knows then return opts.name or opts.publicId or opts.unknown end
    if opts.publicId then return ('%s · %s'):format(opts.unknown, opts.publicId) end
    return opts.unknown
end

--- Jugadores dentro del radio. players: { { src = n, x = , y = , z = } }
function PXDChat.inRange(origin, players, range)
    local out = {}
    for _, p in ipairs(players) do
        local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
        if dx * dx + dy * dy + dz * dz <= range * range then out[#out + 1] = p.src end
    end
    return out
end

--- Texto escrito sin comando → ¿es un comando desconocido?
function PXDChat.isCommand(text)
    return type(text) == 'string' and text:sub(1, 1) == '/'
end

return PXDChat
