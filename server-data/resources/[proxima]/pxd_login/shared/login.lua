-- Lógica pura del login: qué paso toca, tarjetas adaptativas y registro de jugadores.
PXDLogin = PXDLogin or {}
local Login = {}
PXDLogin.Login = Login

--- Comparación en tiempo constante.
function Login.safeEquals(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' or #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do diff = diff | (a:byte(i) ~ b:byte(i)) end
    return diff == 0
end

--- Siguiente paso para un jugador: 'code', 'rules' o 'done'.
function Login.nextStep(record, opts)
    record = record or {}
    -- codeHash guarda un hash del código aceptado: si el código cambia, se vuelve a pedir.
    if opts.accessCode and opts.accessCode ~= '' and record.codeHash ~= opts.codeHash then return 'code' end
    if (record.rulesVersion or 0) < opts.rulesVersion then return 'rules' end
    return 'done'
end

local function header(serverName, subtitle)
    return {
        { type = 'TextBlock', text = serverName, size = 'ExtraLarge', weight = 'Bolder', color = 'Accent' },
        { type = 'TextBlock', text = subtitle, wrap = true, isSubtle = true },
    }
end

function Login.codeCard(serverName, errorText, attemptsLeft)
    local body = header(serverName, 'Servidor privado de pruebas. Introduce el código de acceso.')
    if errorText then
        body[#body + 1] = { type = 'TextBlock', text = errorText .. (' Intentos restantes: %d.'):format(attemptsLeft),
            color = 'Attention', wrap = true }
    end
    body[#body + 1] = { type = 'Input.Text', id = 'code', placeholder = 'Código de acceso' }
    return {
        type = 'AdaptiveCard', version = '1.0',
        ['$schema'] = 'http://adaptivecards.io/schemas/adaptive-card.json',
        body = body,
        actions = { { type = 'Action.Submit', title = 'Entrar', id = 'submit' } },
    }
end

function Login.rulesCard(serverName, rules, name)
    local body = header(serverName, ('Hola, %s. Antes de entrar, acepta las normas de la ciudad:'):format(name or 'jugador'))
    for i, r in ipairs(rules) do
        body[#body + 1] = { type = 'TextBlock', text = ('%d. %s'):format(i, r), wrap = true }
    end
    return {
        type = 'AdaptiveCard', version = '1.0',
        ['$schema'] = 'http://adaptivecards.io/schemas/adaptive-card.json',
        body = body,
        actions = {
            { type = 'Action.Submit', title = 'Acepto las normas', id = 'accept' },
            { type = 'Action.Submit', title = 'No acepto', id = 'decline' },
        },
    }
end

--- Normaliza el registro de un jugador cargado de disco.
function Login.cleanRecord(r)
    if type(r) ~= 'table' then return nil end
    return {
        name = type(r.name) == 'string' and r.name:sub(1, 64) or nil,
        codeHash = math.tointeger(r.codeHash),
        rulesVersion = math.tointeger(r.rulesVersion) or 0,
        firstSeen = math.tointeger(r.firstSeen),
        lastSeen = math.tointeger(r.lastSeen),
        visits = math.tointeger(r.visits) or 0,
    }
end

return Login
