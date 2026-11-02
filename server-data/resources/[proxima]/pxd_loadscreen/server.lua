-- Envía a la pantalla de carga los datos del servidor (window.nuiHandoverData.pxd).
-- FXServer combina los datos de handover por clave, así que no choca con pxd_login.
AddEventHandler('playerConnecting', function(_, _, deferrals)
    deferrals.handover({
        pxd = {
            players = GetNumPlayerIndices(),
            maxPlayers = GetConvarInt('sv_maxclients', 48),
            discord = Config.discord,
            socials = Config.socials,
            radioName = Config.radioName,
            mediaHint = Config.mediaHint,
            news = Config.news,
        },
    })
end)
