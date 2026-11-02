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

-- Cabecera con el icono de la marca (columna izquierda) y nombre + lema.
local function header(opts, subtitle)
    local brand = {
        { type = 'TextBlock', text = opts.serverName, size = 'ExtraLarge', weight = 'Bolder', color = 'Accent' },
        { type = 'TextBlock', text = opts.tagline or '', isSubtle = true, spacing = 'None' },
    }
    local head
    if opts.icon and opts.icon ~= '' then
        head = { type = 'ColumnSet', columns = {
            { type = 'Column', width = 'auto', items = { { type = 'Image', url = opts.icon, size = 'Medium', altText = opts.serverName } } },
            { type = 'Column', width = 'stretch', verticalContentAlignment = 'Center', items = brand },
        } }
    else
        head = { type = 'Container', items = brand }
    end
    return { head, { type = 'TextBlock', text = subtitle, wrap = true, spacing = 'Large' } }
end

local function card(body, actions)
    return {
        type = 'AdaptiveCard', version = '1.0',
        ['$schema'] = 'http://adaptivecards.io/schemas/adaptive-card.json',
        body = body, actions = actions,
    }
end

--- opts = { serverName, tagline, icon }
function Login.codeCard(opts, errorText, attemptsLeft)
    local body = header(opts, 'Estamos en pruebas privadas. Escribe el código de acceso que te dio el staff.')
    if errorText then
        body[#body + 1] = { type = 'TextBlock', text = errorText .. (' Intentos restantes: %d.'):format(attemptsLeft),
            color = 'Attention', wrap = true }
    end
    body[#body + 1] = { type = 'Input.Text', id = 'code', placeholder = 'Código de acceso' }
    return card(body, { { type = 'Action.Submit', title = 'Entrar', id = 'submit' } })
end

function Login.rulesCard(opts, rules, name)
    local body = header(opts, ('¡Hola, %s! Antes de entrar a la ciudad, lee y acepta las normas:'):format(name or 'jugador'))
    for _, r in ipairs(rules) do
        body[#body + 1] = { type = 'TextBlock', text = '✦  ' .. r, wrap = true, spacing = 'Small' }
    end
    body[#body + 1] = { type = 'TextBlock', text = 'Al aceptar te comprometes a respetarlas dentro y fuera del rol.',
        isSubtle = true, wrap = true, spacing = 'Medium', size = 'Small' }
    return card(body, {
        { type = 'Action.Submit', title = 'Acepto las normas', id = 'accept' },
        { type = 'Action.Submit', title = 'No acepto', id = 'decline' },
    })
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
