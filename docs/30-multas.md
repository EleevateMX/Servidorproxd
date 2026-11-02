# 30 · Multas y deudas pendientes (`pxd_justice`)

Las multas dejan de ser un cobro instantáneo: quedan guardadas, se pagan completas o por partes y, si el jugador no tiene dinero, se convierten en deuda pendiente. Nunca hay saldo negativo, intereses, embargos ni sanciones automáticas (pendiente de definir las reglas de la economía).

| Pieza | Qué hace |
|---|---|
| `pxd_justice` (nuevo) | Tablas, emisión, pago seguro, consultas, cancelación/corrección y auditoría (en `pxd_audit`, docs/34) |
| `pxd_panel` → pestaña **Multas** | Deuda pendiente, multas abiertas con «Pagar con banco / en efectivo» e importe, historial y búsqueda para autoridades |
| `pxd_hud` | Indicador discreto arriba a la derecha «Multas: $X» (solo si hay deuda) |
| `qbx_police` (tercero) | Parche de una línea para que `/fine` lo atienda `pxd_justice` (ver §6) |

## 1. Estado

| | Estado |
|---|---|
| Lógica, tablas, pagos, permisos, panel y HUD | ✔ código · ✔ pruebas simuladas (`tests/lua/test_justice.lua`) · ⏳ **probar en el juego** |
| Parche de `qbx_police` | ⏳ lo aplica el updater/receta (sin el parche `pxd_justice` **no** atiende `/fine`, ver §6) |
| Radar de `qbx_police` | Sigue cobrando en el acto (`Config.radar.mode = 'instant'`). Preparado, **no aplicado**: parche de §6 bis y export `IssueSystemFine` |
| `BillPlayer` de `qbx_police` | Sigue como está (§7) |
| Auditoría en `pxd_audit` | ✔ código · ✔ pruebas simuladas (`test_justice.lua`, `test_audit.lua`) · ⏳ probar en el juego |
| MDT y app bancaria del teléfono | ⏳ pendientes: los exports de §5 ya sirven para integrarlos |

Nada de esto está verificado todavía en un servidor real: no lo marques como terminado hasta probar §9.

## 2. Tablas (se crean solas, `CREATE TABLE IF NOT EXISTS`, nunca se borran)

**`pxd_fines`** — una fila por multa.

| Columna | Uso |
|---|---|
| `id` | Identificador único (`AUTO_INCREMENT`) |
| `citizenid` | Personaje sancionado |
| `officer_citizenid`, `officer_name` | Agente responsable (`NULL` si la emite la consola o un recurso) |
| `reason`, `notes` | Motivo (≤ 200) y notas internas (≤ 1000, solo las ven las autoridades) |
| `amount` | Importe original (o corregido, ver §4) |
| `paid` | Cantidad pagada. **Saldo pendiente = `amount - paid`** (derivado, no se guarda) |
| `status` | `pending` · `partial` · `paid` · `cancelled` |
| `society` | Cuenta de Renewed-Banking que cobra (por defecto `police`) |
| `record_ref` | Referencia al expediente cuando exista (reservado para el MDT; hoy `NULL`) |
| `issued_at`, `updated_at` | Marca de tiempo UNIX (UTC) |

**`pxd_fine_events`** — auditoría **antigua**. Columnas:
- `fine_id`;
- `action`: `issue`, `pay`, `pay_failed`, `edit` o `cancel`;
- autor: `actor_citizenid` y `actor_name` (la consola = `NULL` / «consola»);
- `amount`;
- `detail`: motivo o forma de pago;
- `created_at`.

**Auditoría común (docs/34).** Con `pxd_audit` en marcha, cada acción se registra allí:
- `category = 'fines'`;
- `target = 'fine:<id>'`;
- `actor`: citizenid del autor, o `'system'` si fue la consola o el sistema;
- `data = { fine_id, actor_name, amount, detail, citizenid }`, donde `citizenid` es la persona multada.

Entonces `pxd_fine_events` queda como **histórico de solo lectura**:
- Sus filas se copian a `pxd_audit` con `legacy_ref = 'fine_event:<id>'` (al arrancar o con `pxd_audit_migrar`). No se borran.
- Si `pxd_audit` no está en marcha o falla, se sigue escribiendo aquí como respaldo, y la migración lo recoge después.

## 3. Pago seguro

Cada pago (`PayFine`, botón del panel) sigue estos pasos:

1. **Bloqueo por multa**: si ya hay una operación con esa multa, la segunda se rechaza («Ya hay una operación en curso»).
2. Se lee la multa y se valida: es del jugador, está abierta, forma de pago permitida, importe entero ≥ `minPartialPayment`. Si pide más de lo que falta, se cobra solo lo que falta.
3. Se comprueba el saldo (`GetMoney`) y se cobra con `RemoveMoney`; si devuelve `false`, no se toca nada. Con la receta, `qbx_core` tampoco deja el banco en negativo (`dontAllowMinus` con `bank`); `pxd_justice` lo comprueba igualmente por si ese parche faltara.
4. Se suma el pago con un `UPDATE … WHERE id = ? AND status IN ('pending','partial') AND amount - paid >= ?` y se comprueba que cambió **una** fila. Si no (otra operación la cambió), se reembolsa.
5. Se ingresa en la sociedad con `Renewed-Banking:addAccountMoney`. Si falla, se deshace el pago en la tabla, se reembolsa al jugador y se audita `pay_failed`.
6. Si algo lanza un error a mitad (por ejemplo, se cae la base de datos), se deshace lo hecho hasta ese paso y se reembolsa.

No se crea dinero: el jugador pierde exactamente lo que gana la sociedad, o nada.

## 4. Permisos, comandos y configuración

**ACE** (en `server.cfg` o `permissions.cfg`):

```
add_ace group.admin pxd.justice.manage allow   # cancelar y corregir multas
# opcional: consultar multas ajenas sin ser policía de servicio
# add_ace group.admin pxd.justice.view allow
```

- **Multar**: trabajos de tipo `leo` de servicio (`Config.issuerJobTypes`, `Config.minGrade`), a ≤ 5 m y en el mismo bucket (como `qbx_police`).
- **Consultar a otros**: policía de servicio o ACE `pxd.justice.view`/`pxd.justice.manage`. Búsqueda por ID de servidor, `PROX-XXXX` (`pxd_interact`, opcional) o citizenid.
- **Cancelar / corregir** (ACE `pxd.justice.manage` o consola), siempre con motivo y auditado:
  - `multa_cancelar <id> <motivo>`
  - `multa_corregir <id> <importe> <motivo>` — nunca por debajo de lo ya pagado (si queda igual a lo pagado, pasa a `paid`).
  - Cancelar no devuelve lo ya pagado (no hay reglas de reembolso todavía).

`config.lua`: `maxFine` (100000, como `qbx_police`), `maxDistance`, `society`, `autoChargeIfFunds` (**false**: la multa queda pendiente; `true`: si hay saldo en el banco se cobra al emitirla, si no queda como deuda), `paymentMethods`, `minPartialPayment`, `historyLimit` (las multas abiertas se muestran **todas**; el límite es solo para el historial), `cooldown`.

## 5. Exports y eventos (para MDT, teléfono u otros recursos)

| Export (servidor) | Devuelve |
|---|---|
| `IssueFine(officerSrc, targetSrc, reason, amount, notes, opts)` | `id` o `nil, mensaje`. `officerSrc = 0` para consola/recurso. `opts`: `skipDistance`, `issuerName`, `society`, `recordRef` |
| `PayFine(src, fineId, amount, method)` | `ok, mensaje` (`method`: `'cash'` o `'bank'`) |
| `GetOutstanding(citizenid)` | Deuda pendiente total |
| `ListFines(citizenid, { limit, withNotes })` | `{ outstanding, pending = {…}, history = {…} }` |
| `GetPlayerView(src)` / `SearchFines(src, query)` | Lo que muestra el panel (con permisos) |
| `CancelFine(src, id, motivo)` / `EditFine(src, id, importe, motivo)` | `ok, mensaje` (con permisos) |
| `GetFineEvents(fineId)` | Historial de una multa en orden cronológico: une `pxd_audit` y las filas de `pxd_fine_events` aún no migradas, sin duplicados. Lo migrado conserva su `id`; lo nuevo trae `audit_id` |
| `IssueSystemFine(citizenid, reason, amount, meta)` | `id, pendiente` o `nil, mensaje`. Multa **pendiente** sin agente (autor `'system'`). Ver abajo |
| `GetRadarMode()` | `'instant'` (por defecto) o `'pending'` (`Config.radar.mode`) |

**`IssueSystemFine`.** Para radares, peajes u otros automatismos del servidor. Hoy no la usa nada.
- **Valida:**
  - `citizenid`: letras, números, `_` y `-`; ≤ 64;
  - motivo e importe: como `/fine` (entero de 1 a `maxFine`);
  - `meta.notes` ≤ 1000;
  - `meta.source`: el origen, `'radar'`, `'peaje'`…; letras, números, `_` y `-`; ≤ 32; por defecto `'system'`.
- **Enfriamiento:** como mucho una multa por persona y origen cada `Config.systemFine.cooldownSec` (10 s), porque el radar lo dispara el cliente.
- **Emisor:** `officer_name` = `meta.issuerName` o `Config.systemFine.issuerName` («Sistema»); `officer_citizenid = NULL`.
- **Qué hace:** no cobra nada. Avisa a la persona si está conectada, actualiza `pxdFines` y dispara `pxd_justice:fineChanged`. También funciona con personajes desconectados.
- **Auditoría:** autor `'system'`, con `data.origin` y `data.system = true`.

- Evento de servidor `pxd_justice:fineChanged(citizenid, fineId, action, outstanding)` en cada emisión, pago, corrección o cancelación.
- State bag replicado `Player(src).state.pxdFines` = deuda pendiente (lo lee el HUD; se fija al cargar el personaje).
- Los exports que tocan la base de datos esperan: llámalos desde un hilo (`CreateThread` o un manejador de evento). FiveM lo admite entre recursos (`__cfx_async_retval` en `scheduler.lua`).

## 6. Parche de `qbx_police` (para que `/fine` cree multas pendientes)

`qbx_police` (commit `7fa438f`, el de `recipe-qbox.yaml`) cobra `/fine` del banco al momento. `pxd_justice` registra el **mismo** evento `police:server:IssueFine` con las mismas validaciones, y el parche hace que el manejador original se salga si `pxd_justice` está en marcha. Así el comando, el menú y la interfaz de `qbx_police` no cambian.

En `server/main.lua` (el texto buscado aparece **una sola vez**):

```diff
 RegisterNetEvent('police:server:IssueFine', function(targetSrc, lawViolated, fineAmount, notes)
+    if GetResourceState('pxd_justice') == 'started' then return end -- Próxima: multas en pxd_justice
     local src = source
```

Entrada para `scripts/update-plan.json` → `patches`:

```json
{
 "resource": "qbx_police",
 "path": "server/main.lua",
 "find": "RegisterNetEvent('police:server:IssueFine', function(targetSrc, lawViolated, fineAmount, notes)\n    local src = source\n",
 "replace": "RegisterNetEvent('police:server:IssueFine', function(targetSrc, lawViolated, fineAmount, notes)\n    if GetResourceState('pxd_justice') == 'started' then return end -- Próxima: multas en pxd_justice\n    local src = source\n",
 "requires": "pxd_justice",
 "why": "/fine crea multas pendientes en pxd_justice en lugar de cobrar al momento"
}
```

Entrada para `recipe-qbox.yaml` (sección «ARREGLOS DE PRÓXIMA», mismo estilo que las demás):

```yaml
  - action: replace_string # /fine crea multas pendientes en pxd_justice (docs/30)
    file: ./resources/[qbx]/qbx_police/server/main.lua
    mode: literal
    search: "RegisterNetEvent\\('police:server:IssueFine', function\\(targetSrc, lawViolated, fineAmount, notes\\)\\n    local src = source\\n"
    replace: "RegisterNetEvent('police:server:IssueFine', function(targetSrc, lawViolated, fineAmount, notes)\n    if GetResourceState('pxd_justice') == 'started' then return end -- Próxima: multas en pxd_justice\n    local src = source\n"
```

**Protección contra doble multa:** `pxd_justice` lee `qbx_police/server/main.lua` con `LoadResourceFile` y solo atiende el evento si encuentra el parche. Sin parche, `/fine` sigue funcionando como siempre (cobro inmediato) y en la consola aparece un aviso. Si se reinicia `qbx_police`, se vuelve a comprobar.

## 6 bis. Radares: parche **preparado, no aplicado**

Los radares siguen cobrando en el acto. Este cambio **no** está en `scripts/update-plan.json` ni en `recipe-qbox.yaml`, y `Config.radar.mode = 'instant'`. Cuando se decida, el parche hace que, con `Config.radar.mode = 'pending'`, el radar deje una multa pendiente en lugar de cobrar.

`qbx_police` commit `7fa438f` (`recipe-qbox.yaml`), `server/main.lua`, manejador `police:server:Radar` (líneas 163-170). El texto buscado (líneas 166-167) aparece **una sola vez** en el archivo; comprobado con el archivo de ese commit, y el resultado compila:

```diff
 RegisterNetEvent('police:server:Radar', function(fine)
     local src    = source
     local price  = sharedConfig.radars.speedFines[fine].fine
     local player = exports.qbx_core:GetPlayer(src)
+    if GetResourceState('pxd_justice') == 'started' and exports.pxd_justice:GetRadarMode() == 'pending' then -- Próxima: radar → multa pendiente (docs/30)
+        exports.pxd_justice:IssueSystemFine(player.PlayerData.citizenid, 'Radar de velocidad', math.floor(price), { source = 'radar', fine = fine })
+        return
+    end
     if not player.Functions.RemoveMoney('bank', math.floor(price), 'Radar Fine') then return end
     exports['Renewed-Banking']:addAccountMoney('police', price)
     exports.qbx_core:Notify(src, locale('info.fine_received', price), 'inform')
```

Entrada para `scripts/update-plan.json` → `patches` (**no añadida**):

```json
{
 "resource": "qbx_police",
 "path": "server/main.lua",
 "find": "    local player = exports.qbx_core:GetPlayer(src)\n    if not player.Functions.RemoveMoney('bank', math.floor(price), 'Radar Fine') then return end\n",
 "replace": "    local player = exports.qbx_core:GetPlayer(src)\n    if GetResourceState('pxd_justice') == 'started' and exports.pxd_justice:GetRadarMode() == 'pending' then -- Próxima: radar → multa pendiente (docs/30)\n        exports.pxd_justice:IssueSystemFine(player.PlayerData.citizenid, 'Radar de velocidad', math.floor(price), { source = 'radar', fine = fine })\n        return\n    end\n    if not player.Functions.RemoveMoney('bank', math.floor(price), 'Radar Fine') then return end\n",
 "requires": "pxd_justice",
 "why": "con Config.radar.mode = 'pending', el radar deja una multa pendiente en pxd_justice"
}
```

Notas para cuando se aplique:
- **Con el parche y `mode = 'instant'`,** todo sigue igual que hoy. El cambio de comportamiento solo llega al poner `Config.radar.mode = 'pending'` y reiniciar `pxd_justice`.
- **El importe** sale de la configuración de `qbx_police` en el servidor (`speedFines[fine]`). El cliente solo envía el índice, como ahora.
- **Si se aplica, hay que hacerlo en los dos sitios:** la entrada de `update-plan.json` y la de `recipe-qbox.yaml`, con el mismo estilo que el de §6. Después, probar en el juego que la multa aparece en TAB → Multas y que el banco no baja.

## 7. Lo que no cambia

- **Radar** (`police:server:Radar`): por ahora sigue cobrando del banco al momento la tarifa de `sharedConfig.radars.speedFines` que indica el cliente. Como el banco no puede quedar en negativo, sin saldo el cobro simplemente no ocurre. La conversión a multa pendiente está preparada (§6 bis), pero no aplicada.
- **`police:server:BillPlayer`** (facturas): son cobros de servicios, no multas; se tratarán con la facturación.
- **Expediente (`criminalrecord`)**: `qbx_police` solo lo toca al encarcelar. Una multa no es necesariamente un antecedente, así que no se modifica; `record_ref` queda para enlazar con el MDT.

## 8. Instalación (cfg)

```
ensure pxd_audit            # auditoría común (docs/34); antes de pxd_justice
ensure pxd_justice          # después de oxmysql, qbx_core y Renewed-Banking; antes de pxd_panel y pxd_hud
add_filesystem_permission pxd_updater write pxd_justice
add_ace group.admin pxd.justice.manage allow
```

Además: entrada `autostart` de `pxd_justice` en `scripts/update-plan.json`, el parche de §6 y regenerar `update-manifest.json`. `pxd_panel` y `pxd_hud` funcionan sin `pxd_justice` (la pestaña y el indicador no aparecen).

## 9. Prueba en el juego (pendiente)

1. Con dos personajes (uno policía de servicio, a < 5 m): `/fine` → la persona multada recibe «Has recibido una multa de $X…», el banco **no** baja, el HUD muestra «Multas: $X» y `SELECT * FROM pxd_fines` tiene la fila `pending`.
2. TAB → Multas: pagar una parte en efectivo y el resto con banco. Comprobar `paid`, `status`, el saldo del jugador y que la cuenta `police` de Renewed-Banking sube lo mismo.
3. Sin dinero: el pago se rechaza y la multa sigue `pending`.
4. Doble clic rápido en «Pagar»: solo un cobro.
5. `multa_corregir` y `multa_cancelar` desde la consola y con un usuario sin ACE (rechazado). Revisar `SELECT * FROM pxd_audit WHERE category = 'fines'` (y que `pxd_fine_events` no crece).
6. Quitar el parche de §6 y reiniciar: `/fine` vuelve a cobrar al momento y `pxd_justice` avisa en la consola.

## 10. Qué no se ha podido verificar desde aquí

- Comportamiento real en FXServer/MariaDB (solo pruebas con simuladores de `oxmysql`, `qbx_core` y `Renewed-Banking`).
- Que `affectedRows` de `MySQL.update.await` sea el número de filas **cambiadas** en la configuración real de oxmysql (las consultas solo cambian filas cuando el valor cambia de verdad, así que coincide en ambos casos).
- La posición del indicador del HUD frente a las notificaciones de ox_lib (también arriba a la derecha por defecto).
- El parche de radar (§6 bis): solo se ha comprobado que el texto buscado es único y que el archivo resultante compila. No se ha ejecutado en FXServer.
