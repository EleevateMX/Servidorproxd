# 5. Login, pantalla de carga e identidad de Próxima RP

## La marca

- **Nombre:** PRÓXIMA RP. Próxima Centauri es la estrella más cercana al Sol: «tu próxima vida empieza aquí». Encaja con la temática estelar de servidores como Orion o Andromeda sin copiarlos.
- **Lema:** *Tu próxima vida empieza aquí.*
- **Logo:** `brand/logo.svg` (destello de cuatro puntas + «PRÓXIMA» + pastilla «RP»).
- **Colores:** noche `#05070f`/`#121a33`, estrella `#5ce1ff`, nova `#ff4fd8`, oro `#ffc857`; equipos azul `#50a0ff` y rojo `#ff5a5a`.

### Arte generado con conectores

| Pieza | Herramienta | Dónde |
|---|---|---|
| Key art 16:9 (2 variantes) | Kling `kling-image-v3_0_omni`, 2K | Biblioteca de Higgsfield → `node scripts/fetch-brand-assets.mjs` |
| Vídeo de fondo 10 s 1080p | Kling `kling-video-v3_0_turbo` (desde la variante A) | Igual |
| Voz «Bienvenido a Próxima RP. Tu próxima vida empieza aquí.» | ElevenLabs `eleven_v4`, voz «Andres - Deep Narrator» | `pxd_loadscreen/html/assets/bienvenida.mp3` (en el repo) |

Las imágenes y el vídeo no se suben a git por tamaño; los enlaces están en `scripts/brand-assets.json`. Sin ellos, la pantalla de carga usa un cielo estrellado animado por CSS.

## Pantalla de carga (`pxd_loadscreen`)

Estilo «póster de ciudad» (inspirado en las pantallas de servidores grandes, con identidad propia):

- **Fondo:** vídeo y carrusel de imágenes a pantalla completa con zoom lento (key art, «ciudad épica» con Eleevate e IsyConta, policía, emergencias, taller, barrio). Sin imágenes: cielo estrellado animado.
- **Arriba a la izquierda:** logo y titular «Tu próxima vida empieza aquí.» con saludo al jugador.
- **Abajo a la izquierda:** jugadores en línea, **carrusel de avisos** (clicables: normas, Discord, modos de juego…), **radio PRÓXIMA FM** (play/pausa y volumen; suena `assets/music.mp3` si existe, si no la voz de bienvenida), botón de **Discord** y redes.
- **Abajo a la derecha:** progreso circular real, estado de carga, aviso de #media y consejos.
- **Al cerrar:** transición con la estrella girando sobre una cuadrícula.

Todo se configura en el servidor, en `pxd_loadscreen/config.lua` (Discord, redes, avisos, nombre de la radio, texto de #media). Cursor visible (`loadscreen_cursor`) para poder hacer clic.

Vista previa: `html/index.html?demo=1` (y `&transition=1`).

## Login (`pxd_login`)

Al conectar (`playerConnecting` + `deferrals.presentCard`). Las tarjetas llevan el icono y el lema, se vuelven a mostrar mientras otros recursos (Qbox) envían mensajes de progreso que las taparían, tienen tiempo máximo y nunca dejan la conexión colgada:

1. Sin licencia de Rockstar → no entra.
2. **Código de acceso** opcional (`set pxd_login_accessCode "…"` en `secrets.cfg`): 3 intentos. Se recuerda por licencia; si cambias el código se vuelve a pedir.
3. **Normas** (`Config.rules`): «Acepto» o «No acepto». Sube `Config.rulesVersion` para que todos las acepten de nuevo.
4. Pasa a la pantalla de carga con `handover({ name, firstTime })`.

Dentro del juego, la **bienvenida** ofrece: entrar a la ciudad, modos de juego (abre F7) y editor de props (solo staff). `/bienvenida` la vuelve a abrir. Desactívala con `Config.welcomeScreen = false` si tu framework trae selección de personaje (Qbox).

Registros en `pxd_login/data/players.json` (fuera de git): nombre, primera y última visita, visitas, versión de normas aceptada y hash del código.
