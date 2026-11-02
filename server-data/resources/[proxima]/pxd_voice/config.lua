-- Configuración de pxd_voice (voz por proximidad sobre pma-voice).
Config = {}

-- Doble pulsación de la tecla de hablar (N por defecto en FiveM) y mantener = gritar.
-- Ventana máxima entre la primera y la segunda pulsación, en milisegundos.
Config.doubleTapMs = 300

-- Control de «pulsar para hablar» del juego (INPUT_PUSH_TO_TALK). pma-voice simula este
-- mismo control (249) en la radio; así seguimos la tecla que el jugador tenga asignada.
Config.pushToTalkControl = 249

-- Susurrar: pulsar para activar/desactivar (el jugador puede cambiar la tecla en
-- Ajustes → Asignación de teclas → FiveM). J no la usa nada de la receta.
Config.whisperKey = 'J'
-- Nombre técnico del comando de la tecla (no es para escribirlo). `/susurrar <texto>`
-- es del chat de texto (pxd_chat): por eso este no puede llamarse igual.
Config.whisperCommand = 'pxd_voice_whisper'

-- Rangos en unidades de pma-voice. Con voice_useNativeAudio (lo que usa Qbox) el audio
-- nativo suena más lejos que la distancia nominal, así que sus valores son menores
-- (mismo criterio que Cfg.voiceModes de pma-voice). Susurro ≈ 2 m, normal ≈ 8 m, grito ≈ 20 m.
Config.ranges = {
    native   = { whisper = 1.0, normal = 3.0, shout = 8.0 },
    standard = { whisper = 2.0, normal = 8.0, shout = 20.0 },
}

-- Desactiva el ciclo de proximidad de pma-voice (tecla voice_defaultCycle) para que no
-- choque con estos modos. Si lo pones en false, al ciclar se vuelve a aplicar el modo de pxd_voice.
Config.disablePmaCycle = true
