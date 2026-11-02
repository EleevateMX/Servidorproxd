# 30 · Multas y deudas pendientes (`pxd_justice`)

Las multas dejan de ser un cobro instantáneo: quedan guardadas, se pagan completas o por partes y, si el jugador no tiene dinero, se convierten en deuda pendiente. Nunca hay saldo negativo, intereses, embargos ni sanciones automáticas (pendiente de definir las reglas de la economía).

| Pieza | Qué hace |
|---|---|
| `pxd_justice` (nuevo) | Tablas, emisión, pago seguro, consultas, cancelación/corrección y auditoría |
| `pxd_panel` → pestaña **Multas** | Deuda pendiente, multas abiertas con «Pagar con banco / en efectivo» e importe, historial y búsqueda para autoridades |
| `pxd_hud` | Indicador discreto arriba a la derecha «Multas: $X» (solo si hay deuda) |
| `qbx_police` (tercero) | Parche de una línea para que `/fine` lo atienda `pxd_justice` (ver §6) |

## 1. Estado

| | Estado |
|---|---|
| Lógica, tablas, pagos, permisos, panel y HUD | ✔ código · ✔ pruebas simuladas (`tests/lua/test_justice.lua`) · ⏳ **probar en el juego** |
| Parche de `qbx_police` | ⏳ lo aplica el updater/receta (sin el parche `pxd_justice` **no** atiende `/fine`, ver §6) |
| Radar y `BillPlayer` de `qbx_police` | Siguen como están (§7) |
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

**`pxd_fine_events`** — auditoría: `fine_id`, `action` (`issue`, `pay`, `pay_failed`, `edit`, `cancel`), autor (`actor_citizenid`, `actor_name`; consola = `NULL`/«consola»), `amount`, `detail` (motivo o forma de pago) y `created_at`.

Si en el futuro hay una auditoría común (por ejemplo en `pxd_compat`), basta con cambiar `audit()` en `server/main.lua` para escribir allí también; esta tabla se puede mantener como histórico. No se ha duplicado nada: hoy no existe esa auditoría común.

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
| `GetFineEvents(fineId)` | Auditoría de una multa |

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

## 7. Lo que no cambia

- **Radar** (`police:server:Radar`): cobra del banco al momento la tarifa que el cliente indica de `sharedConfig.radars.speedFines`. Adaptarlo obligaría a duplicar esa configuración y fiarse de un dato del cliente; se deja igual. Como el banco no puede quedar en negativo, sin saldo el cobro simplemente no ocurre.
- **`police:server:BillPlayer`** (facturas): son cobros de servicios, no multas; se tratarán con la facturación.
- **Expediente (`criminalrecord`)**: `qbx_police` solo lo toca al encarcelar. Una multa no es necesariamente un antecedente, así que no se modifica; `record_ref` queda para enlazar con el MDT.

## 8. Instalación (cfg)

```
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
5. `multa_corregir` y `multa_cancelar` desde la consola y con un usuario sin ACE (rechazado). Revisar `pxd_fine_events`.
6. Quitar el parche de §6 y reiniciar: `/fine` vuelve a cobrar al momento y `pxd_justice` avisa en la consola.

## 10. Qué no se ha podido verificar desde aquí

- Comportamiento real en FXServer/MariaDB (solo pruebas con simuladores de `oxmysql`, `qbx_core` y `Renewed-Banking`).
- Que `affectedRows` de `MySQL.update.await` sea el número de filas **cambiadas** en la configuración real de oxmysql (las consultas solo cambian filas cuando el valor cambia de verdad, así que coincide en ambos casos).
- La posición del indicador del HUD frente a las notificaciones de ox_lib (también arriba a la derecha por defecto).
