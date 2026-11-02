# 4. Editor de props y dashboard (`pxd_props`)

Coloca objetos (barreras, rampas, contenedores…) agrupados en **layouts**, y define puntos para modos de juego. Tres formas de trabajar sobre los mismos datos:

1. **En el juego** (F6 o `/props`, permiso `pxd.props.edit`): colocar con la cámara.
2. **Dashboard web** (`http://IP:30120/pxd_props/`): mapa cenital para ajustar con precisión.
3. **Por comandos** (`node scripts/pxd.mjs`): tú describes una idea, Claude escribe un *blueprint* y lo inyecta. Aparece en vivo en el juego.

Los cambios se guardan en `pxd_props/data/layouts.json` y llegan al instante a todos los jugadores.

## 1. En el juego

| Pestaña | Para qué |
|---|---|
| Layouts | Crear, renombrar, hacer visible para todos, exportar/importar JSON, borrar |
| Mapa | Vista cenital: arrastra props y puntos |
| Catálogo | Modelos por categoría (los que no existen en tu build salen tachados) o escribe cualquier nombre |
| Edición | X/Y/Z y giros exactos, botones de 1 cm a 1 m, duplicar, nivelar, recolocar, ir, borrar |
| Puntos | Spawns, equipos, parrilla, checkpoints y zona en tu posición actual |

**Colocando** (el panel se atenúa y vuelve al terminar):

| Tecla | Acción |
|---|---|
| Clic izq. / Enter | Colocar |
| Clic der. / Retroceso / Esc | Cancelar |
| Rueda | Girar (Shift = 1°) |
| E / Q | Subir / bajar (Shift = fino) |
| G | Ajustar al suelo sí/no |
| X | Rejilla sí/no |

«Seleccionar apuntando»: apunta a un prop y haz clic para editarlo.

## 2. Dashboard web

Con el servidor encendido, abre `http://localhost:30120/pxd_props/` e introduce el token de `pxd_props_webToken` (está en `server-data/secrets.cfg`).

- Arrastra en el mapa para mover (respeta la rejilla elegida).
- Teclado: flechas (Shift ×10), RePág/AvPág para altura, Q/E para girar, Supr para borrar, Ctrl+Z / Ctrl+Y.
- La altura de un prop nuevo desde la web es la del elemento más cercano: ajústala en «Edición» o marca «suelo» al colocar en el juego.
- Vista previa sin servidor: abre `html/index.html?demo=1`.

**Seguridad:** la API exige el token (comparación en tiempo constante), bloquea una IP tras 10 fallos por minuto, limita a 25 operaciones/segundo y valida cada dato (modelo, coordenadas dentro del mapa, límites de cantidad). El puerto 30120 es público si tu servidor lo es: usa un token largo y no lo compartas.

## 3. De la idea al juego con blueprints

1. En el juego, ponte donde quieras construir y mira hacia donde será «delante»:
   ```
   /ancla plaza
   ```
2. Describe la idea (a Claude o a quien sea): *«en la plaza, un circuito de conos con 4 checkpoints y la salida delante de mí»*.
3. Se escribe un blueprint en `blueprints/` (formas relativas al ancla) y se inyecta:
   ```bash
   node scripts/pxd.mjs apply blueprints/circuito-conos.json
   ```
   ```bash
   node scripts/pxd.mjs activate circuito_conos
   ```
4. Ajusta lo que quieras en el editor o en el dashboard. Para regenerar: `apply … --overwrite`.

Otros comandos: `anchors`, `list`, `get <id>`, `compile <archivo>` (sin tocar el servidor), `apply … --dry-run`, `remove <id>`. Configuración en `.env` (`PXD_URL`, `PXD_TOKEN`).

### Formato del blueprint

Marco del ancla: **+x a tu derecha, +y hacia delante, +z arriba** (metros). Con `"frame": "world"`, +x = este y +y = norte. Ángulos en grados; `rz` gira el prop sobre sí mismo.

```json
{
  "id": "mi_layout", "name": "Nombre visible", "anchor": "plaza", "active": false,
  "items": [
    { "type": "prop",  "model": "prop_bench_01a", "at": [0, 5, 0], "rz": 90, "ground": true },
    { "type": "line",  "model": "prop_mp_cone_02", "from": [-5, 0], "to": [-5, 40], "spacing": 5 },
    { "type": "ring",  "model": "prop_tyre_wall_01", "center": [0, 20], "radius": 12, "count": 10, "face": "center", "arc": [-90, 90] },
    { "type": "grid",  "model": "prop_box_wood02a", "origin": [-4, 10], "rows": 2, "cols": 3, "spacing": [2, 3] },
    { "type": "point", "kind": "zone", "at": [0, 20], "radius": 10 },
    { "type": "route", "kind": "checkpoint", "path": [[0, 30], [15, 45], [30, 30]] }
  ]
}
```

| Tipo | Campos | Notas |
|---|---|---|
| `prop` | `model`, `at` | Un objeto |
| `line` | `from`, `to`, `spacing` o `count` | Orientados a lo largo de la línea (`align: false` para no girarlos) |
| `ring` | `radius`, `count`, `center`, `arc`, `face` | `face`: `center`, `out`, `tangent`, `fixed`; 0° = delante, sentido horario |
| `grid` | `rows`, `cols`, `spacing` (número o `[x, y]`), `origin` | |
| `point` | `kind`, `at`, `h`, `radius` (zona) | `spawn`, `team1`, `team2`, `grid`, `checkpoint`, `zone` |
| `route` | `kind`, `path` | Varios puntos seguidos; los checkpoints se numeran en orden |

Comunes a props: `rx`, `ry`, `rz`, `frozen` (por defecto sí), `collision` (sí), `ground` (apoyar en el suelo al crearlo). Límites: 1500 props y 200 puntos por layout; una sola zona.

Ejemplos listos: `blueprints/circuito-conos.json` y `blueprints/arena-rey-colina.json`.

## Rendimiento

Cada jugador crea **objetos locales** (no de red) solo a menos de 250 m (`Config.streamDistance`) y los borra al alejarse. Así cientos de props no cargan la red ni el límite de entidades.
