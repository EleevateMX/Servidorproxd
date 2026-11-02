# 21. Voz (`pxd_voice`)

Voz por proximidad de Próxima RP, encima de **pma-voice** (no lo modifica).

| Acción | Tecla por defecto | Qué hace |
|---|---|---|
| Hablar | **N** (pulsar para hablar de FiveM) | Voz normal, ≈ 8 m |
| Gritar | **Doble N y mantener** | Mientras mantienes la segunda pulsación, ≈ 20 m. Al soltar vuelve al modo anterior |
| Susurrar | **J** (pulsar para activar/desactivar) | ≈ 2 m hasta que vuelvas a pulsar J. Si gritas mientras susurras, grita y luego vuelve al susurro |

- J se eligió porque no la usa nada de la receta (F1 barra rápida, F2/I inventario, K maletero, M/↑ teléfono, TAB panel, F5 emotes, F6 props, F7 modos, E interacción, B señalar/cinturón, X, G, H, U, Y control de crucero, Z menú radial, R recargar, LCONTROL…). Cada jugador puede cambiarla en *Ajustes → Asignación de teclas → FiveM → «Susurrar»*.
- El susurro es por pulsación (alternar) porque mantener J y N a la vez es incómodo.
- El comando interno de la tecla se llama `pxd_voice_whisper` (no se escribe). `/susurrar <texto>` es del chat de texto (pxd_chat): antes ambos se llamaban igual y el de la voz tapaba al del chat. Quien ya hubiera cambiado la tecla vuelve a tener J por defecto (el nombre de la asignación cambió).
- La doble N sigue la tecla de hablar que tenga cada jugador: se lee el control 249 (pulsar para hablar), el mismo que pma-voice simula en la radio.
- Radio y llamadas siguen igual: mientras hablas por radio (`radioActive` de pma-voice) la doble pulsación no cuenta.

## Rangos

En `pxd_voice/config.lua` (`Config.ranges`). Qbox usa `voice_useNativeAudio true`, con el que el audio nativo suena más lejos que la distancia nominal; por eso hay dos tablas (como `Cfg.voiceModes` de pma-voice):

| Audio | Susurro | Normal | Grito |
|---|---|---|---|
| nativo (Qbox) | 1.0 | 3.0 | 8.0 |
| estándar | 2.0 | 8.0 | 20.0 |

Ajústalos tras probar en el juego.

## Cómo funciona

- Usa los exports de cliente de pma-voice `overrideProximityRange(rango, desactivarCiclo)` y `clearProximityOverride()` (`client/commands.lua`).
- **Ciclo de pma-voice:** con `Config.disablePmaCycle = true` se desactiva su tecla de ciclo (`voice_defaultCycle`, «º» en la receta Qbox) mientras pxd_voice manda. Para quitarla también del todo: `setr voice_enableProximityCycle 0` en el cfg (opcional).
- pma-voice vuelve a su modo al reconectar con mumble; pxd_voice lo comprueba cada segundo y lo reaplica.
- **HUD:** publica el state bag local `pxdVoice` con la misma forma que `proximity` (`{index, mode, distance}`, modos `Whisper/Normal/Shouting`). `pxd_hud` lo lee primero, así que muestra «Susurro / Normal / Gritando» (si pxd_voice no está, sigue leyendo `proximity`).
- Export de cliente: `exports.pxd_voice:getMode()` → `'whisper' | 'normal' | 'shout'`.

## Integración

- `ensure pxd_voice` después de `pma-voice` (`ensure [voice]`).
- En el plan del actualizador: `autostart` y `add_filesystem_permission pxd_updater write pxd_voice`.
- No necesita ACE ni convars propias.

Pendiente de probar en el juego: que la doble pulsación se sienta natural (ventana de 300 ms) y que los rangos con audio nativo correspondan a ≈ 2/8/20 m.
