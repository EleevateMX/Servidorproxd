# 34 · Auditoría común (`pxd_audit`)

Un único registro de «quién hizo qué, a quién y cuándo» para todos los sistemas de Próxima: hospital, multas y, más adelante, economía, propiedades y organizaciones (docs/31, tarea X-1).

Sustituye a los dos registros que había:
- el JSON de `pxd_compat` (hospital);
- la tabla `pxd_fine_events` (multas).

**No se pierde nada.** Los registros antiguos se copian a la tabla nueva y los originales no se borran ni se modifican.

## 1. Estado

| | Estado |
|---|---|
| `pxd_audit` (tabla, `Log`, `Query`, respaldo JSON, migración) | ✔ código · ✔ pruebas simuladas (`tests/lua/test_audit.lua`) · ⏳ **probar en el juego** |
| `pxd_compat` delega en `pxd_audit` | ✔ código · ✔ pruebas (`test_compat.lua`, `test_audit.lua`) |
| `pxd_justice` audita en `pxd_audit` | ✔ código · ✔ pruebas (`test_justice.lua`, `test_audit.lua`) |
| Consulta desde `pxd_admin` | ⏳ pendiente: puede usar el export `Query` (§4). `pxd_admin` no se ha tocado |

## 2. Tabla `pxd_audit`

Se crea sola con `CREATE TABLE IF NOT EXISTS` y nunca se borra.

| Columna | Uso |
|---|---|
| `id` | Identificador creciente (`AUTO_INCREMENT`) |
| `created_at` | Marca de tiempo UNIX (segundos, UTC) |
| `category` | Sistema: `medical`, `fines`, `economy`, `staff`… (≤ 32, sin espacios) |
| `action` | Qué pasó: `confiscate`, `issue`, `pay`, `cancel`… (≤ 32, sin espacios) |
| `actor` | Quién lo hizo: citizenid, licencia o `'system'` (≤ 64) |
| `target` | A quién o a qué afecta: citizenid, `fine:<id>`… (≤ 64, opcional) |
| `data` | Detalles en texto JSON (≤ 4096 bytes; si se pasa, se guarda `{ "truncated": true, "bytes": n }`) |
| `source` | Módulo que escribe: `pxd_compat`, `pxd_justice`… |
| `legacy_ref` | Solo en los registros migrados: `compat:<id>`, `fine_event:<id>` o `audit_json:<archivo>:<id>`. `UNIQUE`; `NULL` en los nuevos |

Índices: `(category, created_at)`, `target` y `actor`.

## 3. Registrar: `Log`

```lua
-- Servidor, desde un hilo o un manejador de evento (espera a la base de datos)
local id, err = exports.pxd_audit:Log({
    category = 'economy',            -- obligatorio
    action = 'transfer',             -- obligatorio
    actor = 'ABC12345',              -- opcional; por defecto 'system'
    target = 'XYZ67890',             -- opcional
    data = { amount = 500, reason = 'alquiler' },   -- opcional, tabla
    source = 'pxd_bank',             -- opcional; por defecto, el recurso que llama
})
```

- Devuelve el `id`, o `nil` y el campo que falla (`'category'`, `'action'`, `'actor'`, `'target'`, `'data'`, `'source'`).
- `category`, `action` y `source` solo admiten letras, números y `_ . : -`.
- `Log` no deja fijar `legacy_ref`: eso solo lo hace la migración.

## 4. Consultar: `Query` (para `pxd_admin`, MDT o informes)

```lua
local rows, err = exports.pxd_audit:Query({
    category = 'fines',        -- opcionales: category, action, source, target, actor
    target = 'fine:12',
    since = os.time() - 86400, -- desde (UNIX, UTC)
    limit = 50,                -- 1–500 (100 por defecto)
    offset = 0,                -- para paginar (máx. 100000)
})
-- rows: más reciente primero. Cada fila:
--   { id, created_at, category, action, actor, target, data = { … } (ya decodificado), source, legacy_ref }
```

`GetStatus()` devuelve:
- `backend`: `'sql'` o `'json'`;
- `ready`;
- `migrating`;
- `lastMigration`: el informe de la última migración.

**Para `pxd_admin` (pendiente, no tocado).** Una pestaña o comando de staff llamaría a `Query` en el servidor con los filtros que elija el staff. Antes, `pxd_admin` tiene que comprobar su permiso ACE (por ejemplo `pxd.audit.view`). Después envía al cliente solo las filas, y el NUI las pinta siempre con `textContent`.

## 5. Sin oxmysql: respaldo JSON

Si `oxmysql` no está en marcha (o tarda más de `Config.waitForOxmysqlSec`), la consola avisa y todo se guarda en `pxd_audit/data/audit.json`. `Query` también funciona sobre ese archivo.

- **Rotación.** Al pasar de `Config.json.maxEntries` (5000), las más antiguas pasan a `data/audit.1.json`, las de `.1` a `.2`… hasta `rotateFiles` (3). Si ya existía el último archivo, se sobrescribe y la consola lo avisa. `Query` solo consulta el archivo principal.
- **Si una escritura en la base de datos falla,** esa entrada también va al JSON: nunca se pierde.
- **Cuando vuelve la base de datos,** la migración sube a la tabla todo lo del JSON (principal y rotados). Lo que en el JSON ya venía migrado (`compat:<id>`) conserva su `legacy_ref`, así que no se duplica.

## 6. Migración (idempotente y no destructiva)

| Origen | Cómo se lee | `legacy_ref` |
|---|---|---|
| `pxd_compat/data/audit.json` | `LoadResourceFile` (solo lectura) | `compat:<id>` |
| Tabla `pxd_fine_events` | `SELECT` por lotes de `Config.migration.batch` (500). Si existe `pxd_fines`, se añade el citizenid de la persona multada (`LEFT JOIN`) | `fine_event:<id>` |
| Respaldo JSON de `pxd_audit` | Solo con base de datos | `audit_json:<archivo>:<id>` |

Las filas se insertan con `INSERT IGNORE`: si el `legacy_ref` ya está, se omite. Ejecutarla dos veces da el mismo resultado.

Cómo se convierte cada registro:
- **Hospital:**
  - `at` pasa a `created_at`;
  - `resource` pasa a `source`;
  - sin `actor`, queda `'system'`.
- **Multas:**
  - `category = 'fines'`;
  - `target = 'fine:<fine_id>'`;
  - `actor` = `actor_citizenid`, o `'system'` si lo hizo la consola;
  - `data = { fine_id, actor_name, amount, detail, citizenid }`.

**Cuándo se ejecuta:**
- **Al arrancar,** si `Config.migration.onStart = true` (por defecto). Solo inserta lo que falta.
- **A mano, desde la consola del servidor** (los jugadores no pueden):

  ```
  pxd_audit_migrar
  ```

  Ejemplo de salida:

  ```
  [pxd_audit] Migración terminada (almacén: sql). Los originales no se han tocado.
  [pxd_audit]   pxd_compat/data/audit.json: 3 importadas, 0 omitidas (ya estaban), 0 no válidas
  [pxd_audit]   pxd_fine_events: 2 importadas, 0 omitidas (ya estaban), 0 no válidas
  [pxd_audit]   respaldo JSON de pxd_audit: sin archivo
  ```

Si la migración se corta (por ejemplo, se cae la BD), lo ya importado queda y basta con volver a lanzarla.

## 7. Cómo lo usan los demás recursos

- **`pxd_compat`** (`Audit`/`GetAudit` siguen existiendo, docs/29):
  - Con `pxd_audit` en marcha, delegan en `Log` y `Query`. `GetAudit` devuelve la forma de siempre (`at`, `resource`…).
  - Si `pxd_audit` no está o falla, escriben como antes en su JSON, que la migración recoge después.
  - `Config.audit.delegate = false` desactiva la delegación.
- **`pxd_justice`** (docs/30):
  - Cada `issue`, `pay`, `pay_failed`, `edit` y `cancel` va a `pxd_audit` con `category = 'fines'` y `target = 'fine:<id>'`.
  - Si `pxd_audit` no está o falla, se escribe en `pxd_fine_events` como respaldo.
  - `GetFineEvents(id)` une `pxd_audit` con las filas antiguas que aún no se hayan migrado, sin duplicados y en orden cronológico. Lo migrado conserva su `id` antiguo y lo nuevo trae `audit_id`.
  - Con `pxd_audit` en marcha, `pxd_fine_events` queda como histórico de solo lectura.

## 8. Instalación (cfg)

```
ensure oxmysql              # ya está con Qbox
ensure pxd_audit            # ANTES de pxd_compat y pxd_justice
add_filesystem_permission pxd_updater write pxd_audit
```

- **Orden.** El orden no es imprescindible: `pxd_compat` y `pxd_justice` comprueban en cada escritura si `pxd_audit` está en marcha. Arrancarlo antes evita que lo escrito durante el arranque vaya a los respaldos.
- **Sin Qbox (`server.cfg` de pruebas).** Funciona con el respaldo JSON.
- **Además:**
  - entrada `autostart` en `scripts/update-plan.json`;
  - regenerar `update-manifest.json`;
  - añadir `pxd_audit` a los cfg, o a `QBOX_ONLY` en `tests/js/deploy.test.mjs` si solo se va a usar con Qbox.

## 9. Prueba en el juego (pendiente)

1. Arrancar con `oxmysql`. La consola muestra el informe de migración y `SHOW CREATE TABLE pxd_audit` incluye `UNIQUE KEY legacy_ref`.
2. Ejecutar `pxd_audit_migrar` otra vez: todo debe salir como «omitidas».
3. Morir con un arma y reaparecer: `SELECT * FROM pxd_audit WHERE category = 'medical' ORDER BY id DESC` muestra la retirada y `pxd_compat/data/audit.json` **no** crece.
4. Poner una multa y pagarla: filas `fines` con `target = 'fine:<id>'`; `pxd_fine_events` no crece.
5. Detener `pxd_audit` (`stop pxd_audit`) y repetir 3 y 4: vuelven a crecer los respaldos. Arrancarlo y migrar: todo aparece una sola vez.

## 10. Qué no se ha podido verificar desde aquí

- **Comportamiento real en FXServer y MariaDB.** Solo hay pruebas con un simulador de oxmysql que imita `INSERT IGNORE` y `UNIQUE`.
- **Qué pasa sin oxmysql instalado.** El manifiesto incluye `@oxmysql/lib/MySQL.lua` (como `pxd_justice`). Con oxmysql detenido funciona el respaldo JSON. Sin el recurso en el servidor, no está comprobado si FXServer carga el resto de scripts tras fallar esa línea.
- **`affectedRows` de `INSERT IGNORE`.** Según el código de oxmysql (`parseResponse`), `MySQL.update.await` devuelve `affectedRows`: 0 si se omite y 1 si se inserta. No está comprobado contra un MariaDB real.
- **Coste de la migración al arrancar con tablas grandes.** Relee todo cada vez. Si llega a pesar, pon `Config.migration.onStart = false` y migra a mano.
