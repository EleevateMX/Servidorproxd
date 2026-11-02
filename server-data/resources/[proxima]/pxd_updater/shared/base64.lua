-- Decodificador base64 en Lua puro (para el arte que descarga server/assets.js).
PXDUpdater = PXDUpdater or {}

local ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local VAL = {}
for i = 1, #ALPHA do VAL[ALPHA:sub(i, i)] = i - 1 end

local char = string.char

local function quad(s)
    local a, b, c, d = VAL[s:sub(1, 1)], VAL[s:sub(2, 2)], VAL[s:sub(3, 3)], VAL[s:sub(4, 4)]
    if not a or not b then return '' end
    local n = a << 18 | b << 12 | (c or 0) << 6 | (d or 0)
    if not c then return char(n >> 16 & 255) end
    if not d then return char(n >> 16 & 255, n >> 8 & 255) end
    return char(n >> 16 & 255, n >> 8 & 255, n & 255)
end

--- Decodifica `s`. Si se pasa `yield`, lo llama entre trozos (p. ej. Wait(0)) para no
--- congelar el servidor con archivos grandes.
function PXDUpdater.base64decode(s, yield)
    s = s:gsub('[^%w%+/=]', ''):gsub('=', '')
    local full = #s - #s % 4
    local out, CHUNK = {}, 65536   -- múltiplo de 4
    for i = 1, full, CHUNK do
        out[#out + 1] = (s:sub(i, math.min(i + CHUNK - 1, full)):gsub('....', quad))
        if yield then yield() end
    end
    if full < #s then out[#out + 1] = quad(s:sub(full + 1)) end
    return table.concat(out)
end

return PXDUpdater
