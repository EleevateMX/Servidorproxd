-- Puente con Qbox (qbx_core + qbx_medical). Si no están iniciados, todo funciona
-- en modo «vanilla». APIs verificadas en el código fuente de Qbox (octubre 2026):
--   exports.qbx_core:SetPlayerBucket(src, bucket)   (actualiza el state 'instance')
--   exports.qbx_core:GetPlayer(src).PlayerData.metadata.ishandcuffed
--   exports.qbx_medical:Revive(src)                  (dispara qbx_medical:client:playerRevived)
--   Player(src).state.isLoggedIn / .isDead           (state bags de Qbox)
Bridge = {}

local function started(name)
    return GetResourceState(name) == 'started'
end

function Bridge.isQbox()
    return started('qbx_core')
end

function Bridge.setBucket(src, bucket)
    if Bridge.isQbox() then
        exports.qbx_core:SetPlayerBucket(src, bucket)
    else
        SetPlayerRoutingBucket(src, bucket)
    end
end

--- ¿Puede entrar a una partida? Con Qbox: personaje cargado, no herido ni esposado.
function Bridge.canJoin(src)
    if not Bridge.isQbox() then return true end
    local state = Player(src).state
    if not state.isLoggedIn then return false, 'Elige tu personaje antes de entrar a una partida.' end
    if state.isDead then return false, 'No puedes entrar a una partida estando herido.' end
    local player = exports.qbx_core:GetPlayer(src)
    local meta = player and player.PlayerData and player.PlayerData.metadata
    if meta and meta.ishandcuffed then return false, 'No puedes entrar a una partida esposado.' end
    return true
end

function Bridge.isDowned(src)
    return Bridge.isQbox() and Player(src).state.isDead == true
end

--- Saca al jugador del estado de herido/muerto de Qbox.
function Bridge.revive(src)
    if started('qbx_medical') then
        exports.qbx_medical:Revive(src)
        return true
    end
    return false
end
