-- Pruebas de pxd_voice (lógica pura).
dofile(RES .. 'pxd_voice/shared/voice.lua')
local V = PXDVoice

T.describe('pxd_voice', function()
    T.it('doble pulsación dentro de la ventana = gritar; fuera de ella no', function()
        local tap = V.newTap()
        T.falsy(V.press(tap, 1000, 300))
        T.truthy(V.press(tap, 1250, 300), '250 ms: doble')
        local tap2 = V.newTap()
        T.falsy(V.press(tap2, 1000, 300))
        T.falsy(V.press(tap2, 1400, 300), '400 ms: no')
        T.truthy(V.press(tap2, 1600, 300), 'cuenta desde la última pulsación')
    end)

    T.it('una tercera pulsación seguida no vuelve a contar como doble', function()
        local tap = V.newTap()
        V.press(tap, 0, 300)
        T.truthy(V.press(tap, 100, 300))
        T.falsy(V.press(tap, 200, 300))
    end)

    T.it('reloj que retrocede no da falsos positivos', function()
        local tap = V.newTap()
        V.press(tap, 5000, 300)
        T.falsy(V.press(tap, 4900, 300))
    end)

    T.it('gritar manda sobre el susurro; el susurro se alterna', function()
        T.eq(V.effective('normal', false), 'normal')
        T.eq(V.effective('whisper', false), 'whisper')
        T.eq(V.effective('whisper', true), 'shout')
        T.eq(V.toggleWhisper('normal'), 'whisper')
        T.eq(V.toggleWhisper('whisper'), 'normal')
    end)

    T.it('rangos según el audio de pma-voice y estado con forma de proximity', function()
        local cfg = { native = { whisper = 1, normal = 3, shout = 8 }, standard = { whisper = 2, normal = 8, shout = 20 } }
        local r = V.ranges(false, cfg)
        T.eq(r.shout, 20)
        T.eq(V.ranges(true, cfg).normal, 3)
        local s = V.state('shout', r)
        T.eq(s.index, 3); T.eq(s.mode, 'Shouting'); T.eq(s.distance, 20.0); T.eq(s.pxd, 'shout')
        T.eq(V.state('rara', r).mode, 'Normal')
    end)

    T.it('reaplica si pma-voice cambió la distancia', function()
        local want = { distance = 8.0 }
        T.falsy(V.needsReapply({ distance = 8.0 }, want))
        T.truthy(V.needsReapply({ distance = 3.0 }, want))
        T.truthy(V.needsReapply(nil, want))
    end)
end)
