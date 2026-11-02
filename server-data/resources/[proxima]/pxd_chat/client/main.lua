-- pxd_chat (cliente): ayudas de los comandos en el chat.
local SUGGESTIONS = {
    { '/me', 'Describe lo que hace tu personaje (lo ve la gente cerca)', { { name = 'acción', help = 'p. ej. se ajusta la chaqueta' } } },
    { '/do', 'Describe el entorno o el resultado de una acción', { { name = 'descripción', help = 'p. ej. la puerta está cerrada con llave' } } },
    { '/susurrar', 'Habla en voz baja (solo muy cerca)', { { name = 'mensaje' } } },
    { '/gritar', 'Habla en voz alta (llega más lejos)', { { name = 'mensaje' } } },
    { '/b', 'Fuera de personaje, solo a quien esté cerca', { { name = 'mensaje' } } },
}

CreateThread(function()
    for _, s in ipairs(SUGGESTIONS) do TriggerEvent('chat:addSuggestion', s[1], s[2], s[3]) end
end)

-- Bienvenida una sola vez por sesión (sustituye al motd de qbx_core, que se repetía
-- porque QBCore:Client:OnPlayerLoaded puede llegar más de una vez).
local welcomed = false
local function welcome()
    if welcomed then return end
    welcomed = true
    TriggerEvent('chat:addMessage', { templateId = 'pxd_system', args = { Config.welcome } })
end
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', welcome)
