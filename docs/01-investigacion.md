# 1. Investigación: cómo se monta un servidor como GTAHUB

> Fecha: 2 de noviembre de 2026. Fuentes al final. Lo marcado como **(sin verificar)** viene de terceros o de memoria y conviene confirmarlo antes de decidir nada.

## Qué es GTAHUB y en qué plataforma corre

- GTAHUB es una comunidad de rol en español para GTA V con varios servidores (Orion, Andromeda, Pegasus y uno en inglés). Su listado en Discord marca ~158 000 miembros **(dato de un tercero)**.
- Históricamente corría sobre **RAGE:MP** (su foro daba la dirección `mundo1.gtahub.gg:22005`, puerto típico de RAGE:MP).
- En 2026 **Take-Two obligó a cerrar RAGE:MP**: se bloquearon servidores nuevos y la lista pública se vació el 1 de junio de 2026. El propio equipo de RAGE:MP afirmó que **FiveM es la única plataforma autorizada** para multijugador modificado de GTA V, y que Cfx.re ayudaría a migrar.
- Según el propietario, **GTAHUB ya corre en FiveM** (coincide con `packages/core/editorial/general.json` del repo SaaSHUB: «GTA V / FiveM»).

Conclusión: un servidor «como GTAHUB» hoy se monta **en FiveM** (Cfx.re, propiedad de Rockstar desde 2023).

## Qué hace falta (resumen)

| Pieza | Para pruebas (este repo) | Para producción (escala GTAHUB) |
|---|---|---|
| Juego | GTA V legítimo + FiveM | Igual (cada jugador) |
| Servidor | FXServer (build **recomendado**) en tu PC | VPS/dedicado; varios servidores (uno por mundo) |
| Licencia | No hace falta con `sv_lan true` | Clave gratuita de [portal.cfx.re](https://portal.cfx.re); límite de plazas según el nivel |
| Panel | Opcional | txAdmin (incluido en FXServer, puerto 40120) |
| Framework | No (recursos `pxd_*` son independientes) | **Qbox** (`qbx_core` + ox_lib/ox_inventory/oxmysql), recomendado para servidores nuevos en 2026 **(guías de terceros)** |
| Base de datos | No | MariaDB (incluido `docker-compose.yml`) |
| Voz | No | pma-voice o similar **(sin verificar)** |
| Monetización | — | **Solo Tebex** (socio autorizado por Cfx.re) |

### Requisitos de tu PC para el entorno de pruebas (orientativo)

- Windows 10/11 (recomendado: la documentación oficial dice que la versión de Linux es un «port de cortesía»).
- Si juegas y alojas en el mismo PC: lo que pida GTA V + unos 2–4 GB de RAM para FXServer **(estimación)**.
- Git y, opcional, Node.js 20+ (pruebas, comando `pxd`, arte).
- Para FiveM for GTAV Enhanced: Microsoft Visual C++ 2017 Redistributable.

## Legacy o Enhanced

FiveM ya existe en dos sabores ([docs oficiales](https://docs.fivem.net/docs/developers/legacy-vs-enhanced/)):

- **FiveM Legacy**: el clásico; puedes fijar build con `sv_enforceGameBuild` (p. ej. `3751`, «A Safehouse in the Hills»).
- **FiveM for GTAV Enhanced** (acceso anticipado): solo red cliente-servidor (sin P2P), OneSync «big» siempre, *pure mode* siempre activo (sin mods gráficos), `stream_enhanced/` para assets Gen9, `nui_callback_strict_mode` activado por defecto, IDs de jugador reutilizables, ejecutable `cfx-server.exe`.

Los recursos `pxd_*` están escritos para funcionar en ambos: activan `nui_callback_strict_mode`, no dependen de IDs crecientes y no usan P2P.

## Arquitectura de un servidor tipo GTAHUB

```
Jugadores ──► FXServer (OneSync) ──► recursos
                 │                     ├─ framework (Qbox: personajes, trabajos, dinero)
                 │                     ├─ inventario, voz, teléfono, vehículos…
                 │                     ├─ Próxima: login, carga, modos de juego, props
                 │                     └─ anticheat / logs
                 ├─ txAdmin (panel, reinicios, bans)
                 └─ MariaDB (oxmysql)
Web/Discord ◄── Tebex (única vía de monetización permitida)
```

Varios «mundos» (como Orion/Andromeda) = varios FXServer con su propia base de datos o una compartida, cada uno con su licencia y su puerto.

### Modos de juego dentro de un servidor de rol

La pieza clave son los **routing buckets** de OneSync: cada jugador/entidad pertenece a un «cubo» y solo ve lo de su cubo. Así una partida de deathmatch o una carrera ocurre en un mundo aislado sin afectar al rol. Requisitos: `onesync on` (no `legacy`). Natives: `SET_PLAYER_ROUTING_BUCKET`, `SET_ENTITY_ROUTING_BUCKET`, `SET_ROUTING_BUCKET_POPULATION_ENABLED`, `SET_ROUTING_BUCKET_ENTITY_LOCKDOWN_MODE` (verificados en `citizenfx/fivem/ext/native-decls`).

### Props y escenarios

Dos enfoques: entidades de red creadas por el servidor, o **objetos locales en cada cliente** cargados por distancia. Para decorado y arenas el segundo es más ligero (no consume red ni cuenta para el límite de entidades), y es el que usa `pxd_props`.

## Normas que importan (resumen, no es asesoría legal)

- Desde el 12-ene-2026 rige el **Creator Platform License Agreement** de Cfx.re **(según resúmenes de terceros; lee el texto en fivem.net/terms)**.
- **Monetización solo con Tebex**; otros procesadores de pago incumplen el acuerdo **(según guías de terceros)**.
- **Identidad propia**: «Próxima RP» no usa nombre, logos ni materiales de GTAHUB ni de Rockstar. Las imágenes de la marca se generaron con IA a partir de descripciones originales (sin marcas).
- Artefactos al día: los recomendados tienen soporte hasta 6 semanas tras el siguiente; los que tienen más de 3 meses sin soporte dejan de poder unirse desde la lista de servidores ([docs](https://docs.fivem.net/docs/server-manual/end-of-support-end-of-life/)).

## Hoja de ruta propuesta

1. **Ahora (este repo):** entorno local de pruebas + modos de juego + editor de props + login y carga. Sin base de datos.
2. **Base RP:** instalar Qbox con la receta de txAdmin en un servidor aparte; desactivar `Config.welcomeScreen` de `pxd_login` (Qbox trae su propia selección de personaje) y conectar los modos de juego con su sistema de muerte (pendiente: ver docs/03 §Qbox).
3. **Persistencia:** mover layouts y registros de login a MariaDB si el volumen lo pide.
4. **Producción:** VPS, txAdmin, copias de seguridad, Tebex, normas y staff.

## Fuentes

- [Setting up a vanilla FXServer — docs.fivem.net](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/) (leído desde el repo `citizenfx/fivem-docs`, 30-oct-2026)
- [What's changed in FiveM for GTAV Enhanced](https://docs.fivem.net/docs/developers/legacy-vs-enhanced/)
- [Server commands (sv_lan, sv_entityLockdown, sv_enforceGameBuild…)](https://docs.fivem.net/docs/server-manual/server-commands/)
- [Routing buckets — cookbook de Cfx.re](https://forum.cfx.re/t/routing-buckets-split-game-state/1831709)
- [Loading screens](https://docs.fivem.net/docs/scripting-manual/nui-development/loading-screens/) · [playerConnecting y deferrals](https://docs.fivem.net/docs/scripting-reference/events/list/playerConnecting/) · [Adaptive cards en deferrals](https://forum.cfx.re/t/adaptive-cards-in-deferrals/612598)
- [Frameworks recomendados por Cfx.re](https://docs.fivem.net/docs/server-manual/frameworks/) · [Receta de txAdmin de Qbox](https://github.com/Qbox-project/txAdminRecipe)
- [PC Gamer: Take-Two fuerza el cierre de RAGE:MP](https://pcgamer.com/games/grand-theft-auto/take-two-forces-shutdown-of-grand-theft-auto-multiplayer-modding-platform-rage-mp) · [Notebookcheck](https://notebookcheck.net/take-two-shuts-down-gta-v-rp-platform-rage-mp-after-cease-and-desist.1309478.0.html)
- [Foro GTAHUB: errores frecuentes (dirección RAGE:MP)](https://foro.gtahub.gg/post/109738) · [GTAHUB en Discord Bot List](https://discordbotlist.com/servers/gtahub) · [laps4: ¿Qué es GTAHub?](https://www.laps4.com/preguntas-y-respuestas/que-es-gtahub)
- [GameServerKings: monetización en FiveM](https://www.gameserverkings.com/knowledge-base/fivem/server-monetisation/) · [FiveMX: tutorial de monetización](https://fivemx.com/tr/?p=148268)
- [Guía de instalación de Qbox (xgamingserver)](https://xgamingserver.com/blog/how-to-install-qbox-fivem/) · [Migración QBCore→Qbox 2026 (space-node)](https://space-node.net/blog/qbcore-to-qbox-migration-guide-2026)
