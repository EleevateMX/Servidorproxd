-- Mini framework de pruebas (Lua 5.4, sin dependencias). Uso: lua5.4 tests/lua/run.lua
local T = { passed = 0, failed = 0, current = '' }

function T.describe(name, fn)
    T.current = name
    fn()
end

function T.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        T.passed = T.passed + 1
        io.write('  ok   ', T.current, ' › ', name, '\n')
    else
        T.failed = T.failed + 1
        io.write('  FAIL ', T.current, ' › ', name, '\n       ', tostring(err), '\n')
    end
end

local function fmt(v)
    if type(v) == 'string' then return string.format('%q', v) end
    return tostring(v)
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg and (msg .. ': ') or '') .. 'esperado ' .. fmt(expected) .. ', obtenido ' .. fmt(actual), 2)
    end
end

function T.truthy(v, msg)
    if not v then error(msg or 'se esperaba un valor verdadero', 2) end
end

function T.falsy(v, msg)
    if v then error(msg or ('se esperaba falso, obtenido ' .. fmt(v)), 2) end
end

function T.throws(fn, pattern)
    local ok, err = pcall(fn)
    if ok then error('se esperaba un error', 2) end
    if pattern and not tostring(err):find(pattern) then
        error('el error no coincide con ' .. fmt(pattern) .. ': ' .. tostring(err), 2)
    end
end

return T
