-- Lógica pura: qué matrículas tienen cambios pendientes de guardar.
PXDWear = {}

function PXDWear.new(interval)
    return { dirty = {}, last = {}, interval = interval or 60 }
end

--- Marca una matrícula como cambiada. Devuelve false si no es válida.
function PXDWear.mark(st, plate)
    if type(plate) ~= 'string' or #plate == 0 or #plate > 16 then return false end
    st.dirty[plate] = true
    return true
end

--- Matrículas que toca guardar ya (respetando el intervalo por vehículo).
function PXDWear.due(st, now, all)
    local out = {}
    for plate in pairs(st.dirty) do
        local last = st.last[plate]
        if all or not last or now - last >= st.interval then out[#out + 1] = plate end
    end
    table.sort(out)
    return out
end

function PXDWear.saved(st, plate, now)
    st.dirty[plate] = nil
    st.last[plate] = now
end

return PXDWear
