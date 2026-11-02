-- Pruebas de pxd_restart (lógica pura).
dofile(RES .. 'pxd_restart/shared/restart.lua')

T.describe('pxd_restart', function()
    local toasts, screen = { 30, 15, 10, 5, 2 }, 60

    T.it('pantalla completa en el último minuto', function()
        T.eq(PXDRestart.view(60, toasts, screen), 'screen')
        T.eq(PXDRestart.view(0, toasts, screen), 'screen')
    end)

    T.it('avisos pequeños solo en los minutos configurados', function()
        T.eq(PXDRestart.view(300, toasts, screen), 'toast')
        T.eq(PXDRestart.view(1800, toasts, screen), 'toast')
        T.eq(PXDRestart.view(240, toasts, screen), nil, '4 minutos no está en la lista')
    end)

    T.it('datos raros no muestran nada', function()
        T.eq(PXDRestart.view(nil, toasts, screen), nil)
        T.eq(PXDRestart.view(-5, toasts, screen), nil)
        T.eq(PXDRestart.view('x', toasts, screen), nil)
    end)

    T.it('texto del aviso', function()
        T.eq(PXDRestart.toastText(300), 'La ciudad se reinicia en 5 minutos.')
        T.eq(PXDRestart.toastText(60), 'La ciudad se reinicia en 1 minuto.')
    end)
end)
