# 13. Panel de la ciudad (`pxd_panel`)

Menú que el jugador abre con **TAB** (o `/panel`): perfil, recompensas, logros, eventos, organizaciones, ayuda con el reglamento, novedades y configuración. Estilo Próxima: cristal oscuro, estrella cian y nova magenta.

Vista previa sin el juego: `html/index.html?demo=1` (añade `&view=recompensas`, `logros`, `eventos`, `organizaciones`, `ayuda&tab=reglas`, `novedades`, `ajustes`).

## Secciones

| Sección | Qué muestra | De dónde salen los datos |
|---|---|---|
| Perfil | Nombre, ID, trabajo y rango (de servicio o no), banda, efectivo, banco, nivel/XP, tiempo jugado total y de hoy | `qbx_core` (`GetPlayer`) + `pxd_progress` (`GetProfile`) |
| Recompensas | Temporada, misión del día, pista Gratis/Plus, reclamar | `pxd_progress` (`GetDaily`, `ClaimDaily`) |
| Logros | Categorías con progreso, logros limitados con cuenta atrás, reclamar XP | `pxd_progress` (`GetAchievements`, `ClaimAchievement`) |
| Eventos | Carrusel con cuenta atrás, lugar, cómo apuntarse y pasos | `Config.events` (fechas en UTC) |
| Organizaciones | Gubernamentales, Empresas y Grupos; a cuáles perteneces, tu rango y cuántos hay de servicio | `qbx_core` (`GetJobs`, `GetGangs`, `GetDutyCountJob`, `PlayerData.jobs/gangs`) |
| Ayuda | Cómo pedir soporte y el **reglamento completo**, con buscador (sin tildes) | `Config.support` y `shared/rules.lua` |
| Novedades | Cambios recientes | `Config.news` |
| Configuración | Tamaño del texto, sonidos, reducir animaciones, cómo cambiar la tecla, cambiar personaje | Guardado en el PC del jugador (KVP del recurso) |

Si `pxd_progress` no está iniciado, Recompensas y Logros no aparecen. Sin Qbox, el panel muestra lo básico (nombre de FiveM, eventos, ayuda, novedades).

## Seguridad

- El servidor arma todos los datos del jugador; la NUI solo pide «abrir», «reclamar» o «cambiar personaje».
- Las reclamaciones las decide `pxd_progress`; el panel solo reenvía y muestra la respuesta.
- Anti-spam por jugador (`Config.requestCooldown`) y «cambiar personaje» como máximo una vez cada 10 s.
- `nui_callback_strict_mode`, todo el texto con `textContent` y las URL solo `https://` (se abren con la confirmación de FiveM).

## Configurar (`config.lua`)

- `Config.key`: tecla por defecto (`TAB`). Cada jugador la puede cambiar en Ajustes de FiveM → Asignación de teclas → FiveM → «Abrir el panel de la ciudad».
- **Choque con ox_inventory:** ox_inventory usa TAB para la barra rápida (tercera tecla de la convar `inventory:keys`, por defecto `["F2","K","TAB"]`). Con las dos en TAB, al abrir el panel también parpadea la barra rápida. Para dejar TAB solo al panel, mueve la barra rápida a otra tecla libre en el `server.cfg`, por ejemplo: `setr inventory:keys '["F2","K","F3"]'` (comprueba antes que esa tecla no la use otro recurso).
- `Config.storeUrl`: enlace de Tebex (`https://…`). Vacío = sin botón de tienda.
- `Config.timeZone`: zona IANA para mostrar fechas (p. ej. `America/Mexico_City`). `nil` = la del PC del jugador. Las fechas de `Config.events` se escriben siempre en UTC (`AAAA-MM-DDTHH:MM:SSZ`).
- `Config.governmentTypes`: tipos de trabajo de Qbox que cuentan como gubernamentales (Qbox trae `leo` y `ems`).
- `Config.support`, `Config.events`, `Config.news`: textos editables.
- Reglamento: `shared/rules.lua` (título, texto y puntos de cada norma).

## Para otros recursos

- Avisos en pantalla (aunque el panel esté cerrado): `TriggerClientEvent('pxd_progress:notify', src, { title = '…', text = '…' })`.
- «Cambiar personaje» usa el export `Logout` de `qbx_core`, que guarda el personaje y vuelve a la selección.

## Pruebas

`tests/lua/test_panel.lua`: tiempos, fechas UTC, eventos, organizaciones, búsqueda de reglas, ajustes, perfil y el servidor con Qbox y `pxd_progress` simulados.
