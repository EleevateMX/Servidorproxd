# 16. Ficha del servidor en FiveM

Lo que se ve al abrir Próxima RP en el navegador de servidores de FiveM.

## Qué sale de dónde

| Parte de la ficha | De dónde sale |
|---|---|
| Nombre, descripción, idioma, etiquetas, icono y banners | [portal.cfx.re](https://portal.cfx.re) → tu servidor → *Listing* |
| Enlaces de «Details» (Discord…) | Variables `sets` del `server.cfg` (p. ej. `sets Discord "discord.gg/qUcD5gCf6v"`) |
| Publicaciones con imágenes («Feed») | Una cuenta de Mastodon enlazada con `sets activitypubFeed "usuario@instancia"` |
| Número de recursos | Automático |

Las variables `sets` aparecen en la ficha como pares nombre/valor. Que FiveM las muestre como enlace clicable depende del cliente: compruébalo tras reiniciar y, si no se ve como quieres, usa los campos del portal.

## Publicaciones (Feed)

1. Crea una cuenta en [fivem.social](https://fivem.social), la instancia de Mastodon pensada para servidores de FiveM. Nombre sugerido: `proximarp`. Usa el mismo icono que en el portal.
2. Publica con estas imágenes (están en `brand/feed/`):
   - `01-proxima-ya-en-fivem.jpg`: «¡Próxima RP ya está en FiveM! Tu próxima vida empieza aquí.»
   - `02-unete-discord.jpg`: «Únete a nuestro Discord: https://discord.gg/qUcD5gCf6v»
   - `03-tu-proxima-vida.jpg`: «Trabajos, negocios, eventos y modos de juego. Te esperamos.»
3. En txAdmin → *CFG Editor*, quita el `#` de `sets activitypubFeed` y pon tu usuario.
4. Reinicia. La pestaña de publicaciones puede tardar hasta unos 20 minutos en aparecer.

Fuentes (comunidad, no documentación oficial): [Cfx.re Forum](https://forum.cfx.re/t/how-to-add-this/1242998), [guía de fivem.social](https://gist.github.com/spacevx).

Pósters generados con Kling (modelo `gemini-3-pro-image`) a petición del propietario.
