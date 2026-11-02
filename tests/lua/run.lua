-- Ejecuta todas las pruebas de Lua. Desde la raíz del repo: lua5.4 tests/lua/run.lua
local root = arg[0]:gsub('tests/lua/run%.lua$', '')
if root == '' then root = './' end
package.path = root .. 'tests/lua/?.lua;' .. package.path
ROOT = root
RES = root .. 'server-data/resources/[proxima]/'

local T = require('runner')
_G.T = T

local suites = {
    'test_gamemodes', 'test_gamemodes_server', 'test_props', 'test_props_server', 'test_login', 'test_updater',
    'test_restart',
    'test_progress', 'test_progress_server',
    'test_multichar',
    'test_jobs',
    'test_panel',
    'test_hud',
    'test_interact',
    'test_chat',
    'test_multichar_client',
    'test_voice',
    'test_admin',
}
for _, s in ipairs(suites) do
    io.write('\n# ', s, '\n')
    local f = io.open(root .. 'tests/lua/' .. s .. '.lua')
    if f then
        f:close()
        dofile(root .. 'tests/lua/' .. s .. '.lua')
    else
        io.write('  (sin archivo)\n')
    end
end

io.write(('\n%d correctas, %d fallidas\n'):format(T.passed, T.failed))
os.exit(T.failed == 0 and 0 or 1)
