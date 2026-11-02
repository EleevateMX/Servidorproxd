# 3. Modos de juego (`pxd_gamemodes`)

Partidas aisladas dentro del servidor de rol. Cada partida tiene su **routing bucket** (mundo propio, sin tráfico ni peatones); al terminar, cada jugador vuelve a su bucket y posición anteriores.

## Uso

| Acción | Cómo |
|---|---|
| Abrir el menú | **F7** o `/modos` |
| Crear | Elige modo + arena → «Crear partida» (te une como anfitrión) |
| Unirse | «Unirse» en la lista de partidas abiertas |
| Iniciar | El anfitrión (o un admin) pulsa «Iniciar» → cuenta atrás de 10 s |
| Salir | `/salirmodo` o «Salir» en el menú |
| Admin | `gm list` · `gm terminar <id>` (consola o jugadores con `pxd.gamemodes.admin`) |

## Modos incluidos

| id | Modo | Gana | Detalles |
|---|---|---|---|
| `ffa` | Todos contra todos | 20 bajas o líder a los 10 min | Suicidio −1 |
| `tdm` | Deathmatch por equipos | 40 puntos de equipo o líder a los 10 min | Fuego amigo −1 |
| `koth` | Rey de la colina | 150 puntos o líder a los 8 min | +1/s al equipo que controla la zona en solitario; disputada = nadie puntúa |
| `race` | Carrera | Primero en completar 2 vueltas | Vehículo `sultan` creado por el servidor; 45 s de gracia tras el primero |

Armas (`WEAPON_PISTOL`, `WEAPON_SMG`, `WEAPON_PUMPSHOTGUN`, `WEAPON_CARBINERIFLE`, `WEAPON_ASSAULTRIFLE`) y vehículo verificados en las referencias oficiales de docs.fivem.net.

## Arenas

- **De ejemplo** (`config.lua`): `prueba` y `colinas`, con coordenadas tomadas de los spawnpoints oficiales de `cfx-server-data`. Son puntos válidos del mapa pero **no están diseñadas** como escenario: sirven para probar el flujo.
- **Reales**: créalas con el editor de props (pestaña «Puntos») o con un blueprint (docs/04). Aparecen en el menú como `«nombre» (layout)`. Tipos de punto:
  - `spawn` (todos contra todos), `team1`/`team2` (equipos), `grid` (salida de carrera), `checkpoint` (en orden), `zone` (rey de la colina).
  - Los props del layout se muestran solo a los jugadores de esa partida.

## Seguridad y autoridad

El servidor decide todo: puntos, checkpoints (valida la distancia real del jugador), inicio y fin. Los clientes solo informan. Las bajas llegan por `baseevents` desde el cliente de la víctima; el servidor descarta las de un asesino que no esté en la partida o esté a más de 600 m. Para un servidor público conviene reforzarlo con eventos de daño del servidor (pendiente).

## Añadir un modo nuevo

1. Crea `shared/modes/<id>.lua`:
   ```lua
   PXD.Modes.register({
       id = 'sniper', label = 'Francotiradores', kind = 'combat', teams = 2,
       minPlayers = 2, maxPlayers = 12, durationSec = 480, scoreLimit = 25,
       scoring = { kill = 1, teamkill = -2, suicide = -1 },
       loadout = { { weapon = 'WEAPON_SNIPERRIFLE', ammo = 60 } },
       -- onTick = function(match, ctx, now, events) ... end,  -- lógica por segundo (opcional)
   })
   ```
   `kind`: `combat` (bajas), `zone` (necesita `zone` y equipos) o `race` (necesita `laps`, `grid` y `checkpoints`). El registro valida todo y da errores claros. Comprueba en las referencias oficiales que el nombre del arma existe.
2. Si necesita lógica nueva (p. ej. capturar la bandera), añade el método a `shared/match.lua` y sus pruebas en `tests/lua/test_gamemodes.lua`.
3. `npm test`.

## Estructura

| Archivo | Qué hace |
|---|---|
| `shared/match.lua` | Máquina de estados de una partida (lobby → cuenta atrás → en curso → terminada), puntos, clasificación. Sin natives: se prueba con Lua puro. |
| `shared/lobby.lua` | Crea partidas, reparte buckets, une/saca jugadores |
| `shared/arena.lua` | Convierte layouts de `pxd_props` en arenas |
| `server/main.lua` | Eventos de red, buckets, vehículos, bucle de 1 Hz |
| `client/main.lua` | Menú, HUD, respawn, checkpoints (marcadores) |
| `html/` | Menú y HUD (vista previa en navegador: `html/index.html?demo=1&hud=1`) |

## Con Qbox (fase RP) — pendiente

Qbox gestiona la muerte (laststand/hospital) y el inventario (ox_inventory). Dentro de una partida habría que desactivar su muerte y no tocar el inventario RP (las armas del modo son armas nativas del juego). Está por integrar y probar en un servidor con Qbox.
