# 11. Servidor de Discord de Próxima RP

Un bot propio (`discord/`) monta el Discord entero con un comando y luego lo mantiene vivo: bienvenida, verificación, roles de avisos, tickets de soporte, anuncios con el estilo de la marca y contadores de jugadores. Estructura inspirada en los Discord de las comunidades de rol grandes, con identidad de Próxima RP: estrellas (✦), paleta noche/estrella/nova/oro y el lema *Tu próxima vida empieza aquí*.

Manual de identidad (colores de roles, anuncios, formatos para redes): [Design System «Próxima RP» en Claude Design](https://claude.ai/artifact/HqEfkGec2JXq61SgRYU6N4) (privado del propietario).

## Qué crea

**Roles** (de arriba abajo):

| Rol | Color | Para qué |
|---|---|---|
| 👑 Fundador | `#ffc857` oro | Administrador |
| 🛡️ Administración | `#ff4fd8` nova | Gestiona servidor, canales, roles y sanciones |
| ⚔️ Moderación | `#ff5a5a` | Expulsar, silenciar, borrar mensajes |
| 💻 Programación | `#5ce1ff` estrella | Equipo técnico |
| 🎟️ Soporte | `#50a0ff` | Atiende tickets (ve los hilos privados) |
| 🎉 Eventos | `#b98cff` | Organiza eventos; puede publicar `/anuncio` de tipo evento |
| 🎥 Creador de contenido | `#ff8fb1` | Streamers y creadores |
| 💎 VIP Próxima | `#ffe3a3` | Recompensa cosmética de Tebex (sin ventajas en el juego) |
| ✦ Ciudadano | `#c9d6ff` | Verificado: ve todo el servidor |
| 🔔 Avisos de eventos / reinicios / directos | — | Cada uno se los pone en #roles |

**Canales** (categorías «✦ NOMBRE», canales «emoji│nombre»):

| Categoría | Canales | Quién la ve |
|---|---|---|
| ✦ BIENVENIDA | 👋 bienvenida · ✅ verificación · 📜 normas · 🎮 cómo-jugar · ⭐ sobre-próxima · 🔗 enlaces · 🎭 roles | Todos (roles: verificados) |
| ✦ ANUNCIOS | 📣 noticias · 🛠️ actualizaciones · 📋 changelog · 🎉 eventos | Verificados; escribe el staff |
| ✦ LA CIUDAD | 🟢 En la ciudad: 12/48 · 👥 Ciudadanos: 361 · 📰 noticias-ic · 🏛️ gobierno · 💬 chat-ciudad | Contadores: todos |
| ✦ SOPORTE | 🎫 soporte (tickets) · ❓ preguntas · 🐞 reportar-bugs · 💡 sugerencias (foros) | Verificados |
| ✦ COMUNIDAD | 💬 general · 📸 media · 🎬 clips · 🔴 directos · 🏆 concursos | Verificados |
| ✦ EXTRAS | 🗨️ off-topic · 🕹️ juegos · 😂 memes · 🎵 música | Verificados |
| ✦ VOZ | Sala general · Esperando rol · Eventos · Soporte por voz | Verificados |
| ✦ STAFF | 📌 staff-avisos · 💬 staff-chat · 📝 registros · Reunión staff | Solo staff |

Y publica los mensajes fijos: normas (las mismas que se aceptan al entrar al juego), cómo jugar, qué es Próxima RP, enlaces, botón de verificación, botones de avisos y botón de tickets.

Toda la plantilla está en `discord/src/template.js`: cambia nombres, colores o canales ahí.

## Ponerlo en marcha

### 1. Crear el bot (una vez)

1. https://discord.com/developers/applications → **New Application** → nombre «Próxima RP».
2. En **Bot**: sube `brand/discord/bot-avatar.png` como icono y `bot-banner.jpg` como banner, pulsa **Reset Token** y guarda el token (es secreto).
3. En **Bot → Privileged Gateway Intents** activa **Server Members Intent** (lo necesita la bienvenida).
4. En **OAuth2 → URL Generator**: marca `bot` y `applications.commands`; en permisos, **Administrator**. Abre la URL y añade el bot a tu servidor.
   El bot necesita Administrador para crear roles con permisos de moderación (Discord no deja dar permisos que uno no tiene).
5. En Discord: Ajustes de usuario → Avanzado → **Modo desarrollador**. Clic derecho en tu servidor → **Copiar ID del servidor**.

### 2. Activar la Comunidad (recomendado, antes del montaje)

Ajustes del servidor → **Habilitar comunidad**. Sin ella, Discord no permite canales de anuncios (el botón «Seguir») ni foros: el bot los crea como canales de texto. Si la activas después, vuelve a ejecutar el montaje y los de anuncios se convierten solos; los foros hay que recrearlos a mano.

### 3. Configurar

```bash
cd discord
```
```bash
cp .env.example .env
```
Rellena `DISCORD_TOKEN`, `DISCORD_GUILD_ID` y, para el contador y el botón de entrar, `FIVEM_URL`, `FIVEM_CONNECT` y `FIVEM_JOIN_URL` (los comentarios del archivo explican cada uno).

### 4. Montar el servidor

```bash
npm install
```
```bash
npm run setup
```
Muestra lo que va a crear sin tocar nada. Si te gusta:
```bash
npm run setup -- --aplicar --icono
```
- Nunca borra nada. Si ya tienes canales con el mismo nombre en la misma categoría, los reutiliza. Los canales antiguos que no estén en la plantilla se quedan; bórralos tú si sobran.
- Se puede ejecutar las veces que quieras: solo crea lo que falte.
- `--permisos` vuelve a poner los permisos de la plantilla en lo que ya existía.
- `--paneles` reescribe los mensajes fijos (por ejemplo, tras cambiar las normas o los enlaces).
- `--icono` pone el icono de Próxima RP al servidor.

Lo que el bot crea lo apunta en `discord/data/state.json` (no se sube a git). No lo borres: si lo pierdes, el bot vuelve a encontrar casi todo por nombre, pero los mensajes fijos se publicarían otra vez.

Después, en Discord, arrastra el rol del bot por encima de **✦ Ciudadano** y de los roles de avisos si no lo está ya (Ajustes del servidor → Roles), o no podrá ponerlos.

### 5. Arrancar el bot

```bash
npm start
```
Tiene que estar encendido siempre para que funcionen los botones, la bienvenida y los contadores. Opciones:

- **VPS con Docker** (junto al servidor de FiveM): rellena `discord/.env` con `FIVEM_URL=http://fxserver:30120` y, desde la raíz del repo:
  ```bash
  docker compose -f deploy/docker-compose.yml --profile discord up -d --build
  ```
  El montaje desde Docker:
  ```bash
  docker compose -f deploy/docker-compose.yml --profile discord run --rm discord-bot node src/setup.js --aplicar --icono
  ```
- **Cualquier hosting de bots con Node 20.12 o superior**: sube la carpeta `discord/` (sin `node_modules`), define las variables de `.env.example` y arranca con `npm start`. Monta antes el servidor con `npm run setup -- --aplicar` (en tu PC o en el hosting).
- **Tu PC**: vale para probar; el bot se apaga al cerrar la terminal.

## Uso diario

| Qué | Cómo |
|---|---|
| Publicar un anuncio | `/anuncio tipo:… mencion:…` → se abre un formulario (titular, texto, imagen https opcional). Se publica en su canal con la franja del color del tipo y, si es canal de anuncios, se envía a los servidores que lo siguen |
| Tipos de anuncio | 📣 Noticia (`#5ce1ff`) · 🛠️ Actualización (`#ffc857`) · 🎉 Evento (`#ff4fd8`) · 🔧 Mantenimiento (`#ff5a5a`, en noticias) |
| Quién puede anunciar | Fundador y Administración, todos; Eventos, solo eventos. @everyone solo quien tenga ese permiso en Discord |
| Estado de la ciudad | `/estado` (respuesta privada con jugadores y botón para entrar) |
| Tickets | Botón en #soporte → hilo privado con el usuario y Soporte. Lo cierran quien lo abrió o el staff. Uno abierto por persona |
| Contadores | Se actualizan cada 10 minutos (Discord no deja renombrar un canal más de 2 veces cada 10 minutos). Sin `FIVEM_URL` solo se actualiza el de ciudadanos |
| Registro | Verificaciones, tickets y anuncios quedan en #📝│registros |

## Seguridad

- El token va solo en `discord/.env` (ignorado por git y por Docker). Si se filtra, **Reset Token** en el portal.
- El bot comprueba los permisos en cada acción, aunque Discord ya oculte el comando: rol del miembro para anunciar, dueño o staff para cerrar tickets, lista cerrada de roles de avisos.
- Los anuncios no mencionan a nadie salvo lo elegido (`allowedMentions`), y las imágenes tienen que ser https.

## Imágenes

Están en `brand/discord/` y se regeneran con `node scripts/build-discord-art.mjs` (usa el key art de la pantalla de carga; descárgalo antes con `node scripts/fetch-brand-assets.mjs`).

| Archivo | Tamaño | Dónde va |
|---|---|---|
| `bot-avatar.png` | 1024×1024 | Portal de desarrolladores → tu aplicación → **General Information → App Icon** y **Bot → Icon** |
| `bot-banner.jpg` | 680×240 | Portal de desarrolladores → **Bot → Banner** (el fondo del perfil del bot) |
| `server-icon.png` | 1024×1024 | Icono del servidor: lo pone `npm run setup -- --aplicar --icono`, o a mano en Ajustes del servidor |
| `server-banner.jpg` | 960×540 | Ajustes del servidor → banner (Discord lo pide con nivel 2 de mejoras) |
| `invite-splash.jpg` | 1920×1080 | Ajustes del servidor → fondo de la invitación (nivel 1 de mejoras) |
| `header-*.jpg` | 1600×500 | Cabeceras de bienvenida, verificación, normas, cómo jugar, sobre Próxima, enlaces, roles y soporte. **El bot las adjunta solo**; para cambiarlas en mensajes ya publicados: `npm run setup -- --aplicar --paneles` |

## Lo que se hace a mano en Discord

- **Banner del servidor** y **fondo de invitación**: necesitan mejoras; las imágenes ya están en `brand/discord/` (ver Imágenes).
- **Bienvenida y Onboarding de Discord** (Ajustes → Incorporación), **etiqueta de servidor** y **emojis propios**: no los gestiona el bot.
- **Vincular roles de Tebex** (VIP Próxima): pendiente; hoy se asigna a mano.

## Pruebas

`npm test` en la raíz incluye `tests/js/discord.test.mjs`: plantilla (permisos válidos de discord.js 14.28, límites de Discord), plan de montaje (crea, reutiliza, nunca borra), accesos, anuncios, contadores y paneles. Las normas se comparan con `pxd_login/config.lua` para que Discord y el juego digan lo mismo.
