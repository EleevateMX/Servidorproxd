# 42. Organizaciones y bandas (`pxd_orgs`)

**Estado:** implementado y con pruebas automáticas (27 en Lua, 6 en Vitest, 4 en Node). No instalado en Nodecraft ni probado dentro de FiveM.

Los jugadores crean su banda, grupo o club de motos desde el juego, con miembros, rangos, fondos, identidad visual y reputación. Es la base de los barrios y territorios (oleada 2), que leerán su identidad y le sumarán reputación.

## Quién es dueño de cada dato

| Dato | Dueño |
|---|---|
| Miembros y rangos | **qbx_core** (`player_groups`). Cada organización oficial es una banda `pxo_<id>` |
| Fondos | **Renewed-Banking**, cuenta con el mismo nombre que la banda |
| Ficha, identidad, reputación, estado, fundadores e historial | **pxd_orgs** (`pxd_orgs`, `pxd_org_founders`, `pxd_org_events`) |

Las tablas se crean con `CREATE TABLE IF NOT EXISTS`. Nada se borra: las rechazadas y disueltas quedan con ese estado.

## Flujo

1. **`/org`** abre la interfaz. Sin organización: invitaciones recibidas, «Crear organización» y el directorio.
2. **Fundar.** Tipo, nombre, emblema, color, tipografía, lema y cofundadores (personas cerca y sin banda).
   - Los cofundadores aceptan desde su `/org`.
   - Quien funda confirma. Entonces se cobra la tasa del banco y se crea la solicitud.
3. **Aprobación.** Por defecto, la solicitud queda **pendiente** hasta que el staff la aprueba (`Config.approval = 'staff'`). Con `'auto'` queda oficial al momento.
   - Si se rechaza, se devuelve la tasa, aunque quien la pagó esté desconectado.
4. **Oficial.** Se crea la banda en qbx_core, entran los fundadores (quien funda como líder) y se abre la cuenta.
5. **Gestión** desde `/org`: miembros, fondos, identidad, invitar y ajustes.

**Por qué aprobación del staff por defecto:** las bandas de un servidor de rol se regulan (D-3 del backlog), y así ninguna organización existe en qbx_core sin revisión. La solicitud ya exige nivel, tasa y cofundadores, para que al staff solo le lleguen peticiones serias.

## Requisitos para fundar (`Config.create`)

| Requisito | Valor | Notas |
|---|---|---|
| Nivel de personaje | 3 | De `pxd_progress`. Sin ese recurso no se exige |
| Tasa de registro | $25 000 del banco | Sale del sistema. Nunca deja saldo negativo |
| Fundadores | 2 en total, a 15 m | Todos sin banda |
| Espera entre solicitudes | 1 hora | Por personaje |
| Nombre | 3–28 caracteres | Letras, números, espacios, `-`, `.` y `&`. Único sin contar tildes ni separadores. No puede coincidir con una banda de qbx_core ni con la lista bloqueada |

El staff (`pxd.orgs.manage`) crea sin requisitos ni tasa, y es el único que puede crear el tipo **gubernamental**. El tipo **empresa** está reservado para la etapa B.

## Rangos y permisos (`Config.grades`)

| Rango | Nombre | Invitar | Expulsar y cambiar rangos | Retirar fondos | Identidad |
|---|---|---|---|---|---|
| 0 | Aspirante | | | | |
| 1 | Miembro | | | | |
| 2 | Veterano | ✔ | | | |
| 3 | Mano derecha | ✔ | ✔ | ✔ | ✔ |
| 4 | Líder | ✔ | ✔ | ✔ | ✔ |

- Aportar fondos puede cualquier miembro.
- Solo se actúa sobre rangos **inferiores** al propio, y nunca se asigna el rango 4: el liderazgo solo se **transfiere**.
- Quien lidera no puede salir: transfiere o disuelve. Disolver pide escribir el nombre; los fondos van a su banco.
- Los clubes de motos y las gubernamentales usan otros nombres de rango (`Config.gradeNames`).

## Identidad

- **Color:** paleta cerrada de 16 (`Config.colors`).
- **Tipografía:** 7 fuentes incluidas en el recurso (`Config.fonts`), incrustadas en `html/ui/orgs-fonts.css`. No se carga nada externo. Licencias en `pxd_orgs/LICENSES.md`.
- **Emblema:** 1–3 letras (por defecto, las iniciales).
- **Lema:** hasta 60 caracteres.

Para la oleada 2: `exports.pxd_orgs:GetIdentity(id)` y el evento `pxd_orgs:identityChanged`. Las fuentes se cargan desde `https://cfx-nui-pxd_orgs/html/ui/orgs-fonts.css`.

## Reputación y niveles

`exports.pxd_orgs:AddReputation(orgId, cantidad, motivo)` suma o resta (máximo 1000 por llamada, motivo obligatorio, auditado). Todavía no hay actividades que la den: llegarán con los barrios.

| Nivel | Reputación | Plazas |
|---|---|---|
| 1 | 0 | 8 |
| 2 | 500 | 12 |
| 3 | 1500 | 16 |
| 4 | 4000 | 22 |
| 5 | 9000 | 30 |

## Para otros recursos

**Exports de servidor:**

| Export | Devuelve |
|---|---|
| `GetOrg(id o 'pxo_N')` | Ficha pública o `nil` |
| `GetPlayerOrg(src o citizenid)` | Ficha y rango |
| `IsMember(src, org)` | `true` / `false` |
| `HasPermission(src, perm)` | `invite`, `manage`, `funds`, `identity` o `leader` |
| `GetIdentity(org)` | `{ id, slug, name, type, color, font, fontFamily, motto, emblem }` |
| `AddReputation(org, n, motivo)` | Nueva reputación y nivel |
| `ListOrgs({ type, status })` | Lista de fichas |
| `GetMembers(org)` | Miembros con nombre y rango |
| `Approve(src, id)`, `Reject(src, id, motivo)`, `Dissolve(src, id, motivo)` | Para `pxd_admin` (`src = 0` es la consola) |

**Export de cliente:** `exports.pxd_orgs:Open()`.

**Eventos de servidor:** `pxd_orgs:created`, `pxd_orgs:dissolved`, `pxd_orgs:identityChanged`, `pxd_orgs:reputationChanged`, `pxd_orgs:levelUp`.

**State bag replicado:** `Player(src).state.pxdOrg = { id, name, type, color, font, emblem, grade }`.

**Comandos de staff y consola:** `org_pendientes`, `org_aprobar <id>`, `org_rechazar <id> <motivo>`, `org_disolver <id> <motivo>`. También hay una pestaña «Solicitudes» en `/org` para quien tenga `pxd.orgs.manage`.

El panel TAB ya lista estas organizaciones en su pestaña «Organizaciones», porque son bandas de qbx_core. No se tocó `pxd_panel`.

## Decisiones técnicas (verificadas en las versiones fijadas)

- **Persistencia de la banda.** `qbx:cleanPlayerGroups "true"` hace que qbx_core borre al arrancar los miembros de bandas que no existen. Por eso se crea con `CreateGangs(…, true)`: el `true` la guarda en `qbx_core/shared/gangs.lua`, el mecanismo oficial de qbx_core. Al arrancar, `pxd_orgs` recrea la banda si falta y restaura el liderazgo.
- **Un jugador, una banda** (`qbx:max_gangs_per_player 1`): para invitar o cofundar hay que estar libre.
- **Cuenta bancaria.** `exports['Renewed-Banking']:CreateJobAccount` la crea en marcha. Pero `IsGangAuth` de Renewed-Banking 2.1.4 lee una copia de las bandas tomada al arrancar y falla con una banda nueva: el banco daría error a sus miembros hasta reiniciar. Con el parche de abajo se evita.
  - **Sin el parche**, `pxd_orgs` no abre la cuenta en marcha y lo avisa en consola. Los fondos quedan disponibles tras el siguiente reinicio, cuando Renewed-Banking crea la cuenta solo.
- **Menú de jefe de qbx_management:** no se registra. Va por ubicación y duplicaría la gestión de `/org`.
- **Seguridad:**
  - una sola puerta de entrada (`pxd_orgs:server:rpc`) con límite de frecuencia;
  - todo se valida en el servidor;
  - `nui_callback_strict_mode`;
  - React escapa todo el texto;
  - cada acción sensible queda en `pxd_org_events` y en `pxd_audit` (categoría `orgs`).
- **Interfaz en React + TypeScript** (`web/orgs`, compilada en `pxd_orgs/html`), como el inventario y los personajes. No se integró en `pxd_panel` porque su página es de solo lectura y esta tiene formularios, arrastre de estado y confirmaciones.

## Integración

1. `server.qbox.cfg`: `ensure pxd_orgs` después de `qbx_core`, `Renewed-Banking`, `pxd_progress`, `pxd_audit` y `pxd_economy`. Es solo para Qbox: añadir `pxd_orgs` a `QBOX_ONLY` en `tests/js/deploy.test.mjs`.
2. `scripts/update-plan.json`: `"pxd_orgs"` en `autostart`, después de `pxd_economy`.
3. `permissions.pxd.cfg`:
   ```
   add_filesystem_permission pxd_updater write pxd_orgs
   add_filesystem_permission pxd_updater write Renewed-Banking
   add_ace group.admin pxd.orgs.manage allow
   ```
4. Parche de Renewed-Banking 2.1.4 (`server/framework.lua`; el texto aparece una vez y el archivo parcheado compila):
   ```json
   { "resource": "Renewed-Banking", "path": "server/framework.lua",
     "find": "        return Gangs[gang].grades[grade] and Gangs[gang].grades[grade].bankAuth or Gangs[gang].grades[gradeNum] and Gangs[gang].grades[gradeNum].bankAuth",
     "replace": "        return Player.PlayerData.gang.bankAuth == true -- Próxima: vale también para las bandas creadas en marcha (pxd_orgs)",
     "requires": "pxd_orgs", "requiresVersion": "2.1.4",
     "why": "el banco no falla con organizaciones creadas en marcha (pxd_orgs)" }
   ```
   `PlayerData.gang.bankAuth` lo rellena qbx_core con el mismo dato (`gang.grades[grade].bankAuth`).
5. `tests/lua/run.lua`: añadir `'test_orgs'`.
6. Compilar la interfaz: `npm --prefix web/orgs install && npm --prefix web/orgs run build` (pruebas: `npm --prefix web/orgs test`).

## Solo verificable dentro de FiveM

- Que `CreateGangs(…, true)` escribe `qbx_core/shared/gangs.lua` y la banda sigue tras reiniciar con sus miembros.
- Que `CreateJobAccount` de Renewed-Banking deja la cuenta utilizable en la misma sesión (con el parche).
- Fundar con dos jugadores reales cerca, aprobar desde `/org` como staff y ver el rango en el panel TAB.
- Invitar, ascender, expulsar a alguien desconectado, transferir y disolver.
- Aportar y retirar, y que los movimientos aparecen en el banco y en `/economia`.
- Las tipografías dentro del CEF del juego y el foco del ratón al abrir y cerrar (Escape).
