# 12. Progreso: nivel, horas, recompensas diarias y logros (`pxd_progress`)

Recurso **solo de servidor**, sin interfaz. Lo usan el menú TAB (`pxd_panel`) y la pantalla de personajes (`pxd_multichar`); otros scripts le avisan de lo que hace el jugador con `Track`.

## Dónde se guarda

- **Con Qbox:** en la metadata de cada personaje, clave `pxd_progress` (`exports.qbx_core:GetMetadata` / `SetMetadata`). Viaja con el personaje y se guarda en la base de datos de Qbox.
- **Sin Qbox** (pruebas): `pxd_progress/data/progress.json`, por licencia.
- **Plus** es por cuenta (licencia de Rockstar), no por personaje: `data/plus.json`.

Forma: `{ v, xp, playtime, today = { day, seconds, counters }, counters, windows, daily, achievements }`.

## Qué cuenta solo

Cada minuto, para cada jugador con personaje cargado:

- `playtime` y «jugado hoy» (+60 s) y el contador `playtime_min`.
- `duty_min` si está de servicio en un trabajo (`PlayerData.job.onduty` de Qbox; `unemployed` no cuenta).

«Hoy» es el día natural de `Config.utcOffsetHours` (por defecto **-6, Ciudad de México**; cámbialo si tu comunidad está en otra zona).

## Exports (servidor)

| Export | Devuelve |
|---|---|
| `GetProfile(src)` | `{ level, xp, xpLevel, xpNext, playtime, playtimeToday, plus }` o `nil` sin personaje |
| `AddXP(src, cantidad, motivo)` | nivel nuevo |
| `Track(src, clave, cantidad)` | `true` si la clave es válida. Claves: `playtime_min`, `duty_min`, `job_task`, `gm_play`, `gm_win`, `event_join` |
| `GetDaily(src)` | estado de la pista: temporada, día, `days[]` (`claimed`/`available`/`locked`/`missed`), misión del día, `canClaim`, `plus`, `lost` (días perdidos por no reclamar) |
| `ClaimDaily(src)` | `ok, mensaje` |
| `GetAchievements(src)` | categorías con logros, progreso y si están reclamados |
| `ClaimAchievement(src, id)` | `ok, mensaje` |
| `SummaryFromMetadata(metadata)` | `{ level, playtime }` (para la lista de personajes; acepta la metadata entera) |

Ejemplo desde un script de trabajo: `exports.pxd_progress:Track(source, 'job_task', 1)`.

Eventos: `pxd_progress:levelUp` (servidor, `src, nivel`) y `pxd_progress:notify` (cliente, `{ title, text }`), que pinta el panel.

## Recompensas diarias

- Una temporada (`Config.daily.season`, fechas UTC) con una pista de días: **Gratis** y **Plus**.
- Cada día natural se puede reclamar **un** día, y solo si se cumplió la **misión del día** (rota de `Config.daily.missions`; cada misión acepta varias opciones, basta una).
- `missedDayPenalty = true`: por cada día natural sin reclamar, se retrocede un día en la pista.
- Recompensas: `money` (`cash`/`bank`, con `exports.qbx_core:AddMoney`), `item` (ox_inventory; se comprueba el espacio antes de entregar **nada**) y `xp`.
- No hay «comprar día».

La pista Plus la decide el dueño. Por las reglas de monetización de Tebex/Cfx, nada que dé una ventaja fuerte pagando: los valores por defecto son modestos (comida, poco dinero, XP).

### Plus desde Tebex

Comando **solo de consola**: `pxd_plus <id-jugador|licencia> <días>`. En Tebex, pon como comando del paquete `pxd_plus {id} 30` (se ejecuta con el jugador conectado). Suma días desde el vencimiento actual.

## Logros

`Config.achievements`: categorías con logros (`key`, `goal`, `rewardXp` y opcional `rewardMoney`). Además de las claves de `Track`, hay derivadas: `level`, `playtime_h`, `days_claimed`.

- `goal = 'season'`: la meta es el número de días de la pista (`#Config.daily.days`). Lo usa «Temporada completa», que antes pedía 28 días con una pista de 14.
- `disabled = true`: el logro no se muestra ni se puede reclamar. «Estuve ahí» (`event_join`) está desactivado porque todavía no hay sistema de eventos que llame a `Track(src, 'event_join', 1)`; quita `disabled` cuando exista.

Categorías **limitadas** (`limited = true`, `startsAt`, `endsAt`): solo se ven y cuentan en esas fechas (lo de antes no cuenta). Si participaste, siguen visibles después, pero ya no se pueden reclamar.

## Instalación

```
ensure pxd_progress   # después de qbx_core y ox_inventory, antes de pxd_panel y pxd_multichar
```

No necesita convars ni permisos ACE (el comando `pxd_plus` solo funciona desde la consola).
