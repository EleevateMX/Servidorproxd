# 26. Consolidación técnica: backlog P0/P1/P2

Este documento parte de la auditoría del 2 de noviembre de 2026 (`docs/auditoria/`). Cada hallazgo se ha **vuelto a comprobar contra el código** antes de entrar aquí.

Regla general: no se marca nada como funcional sin una prueba dentro de FiveM (sección 4).

## Estados

| Marca | Significado |
|---|---|
| ✔ código | Corregido en el repositorio y con prueba automática o simulada |
| ⏳ juego | Falta probarlo dentro de FiveM |
| ⏸ decisión | Necesita que el propietario decida |
| 🚧 en curso | En una rama de trabajo, sin integrar todavía |

## P0 · Proteger el proyecto (Fase 0)

| # | Tarea | Estado | Dónde |
|---|---|---|---|
| P0-1 | Copia de seguridad de cada archivo antes de escribir (pxd_* y terceros) | ✔ código · ⏳ juego | `pxd_updater` 0.2.0 |
| P0-2 | Escritura transaccional: si falla a mitad, deshace lo escrito | ✔ código · ⏳ juego | `pxd_updater` 0.2.0 |
| P0-3 | `pxd_update rollback [id]` y `pxd_update backups` | ✔ código · ⏳ juego | `pxd_updater` 0.2.0 |
| P0-4 | No sobrescribir los configs editados ni la primera vez; lista de archivos editables | ✔ código · ⏳ juego | `pxd_updater` 0.2.0 |
| P0-5 | Avisar cuando un parche no encuentra su texto; `requiresVersion` en los parches | ✔ código · ⏳ juego | `pxd_updater` 0.2.0 |
| P0-6 | **Versiones fijas** en `recipe-qbox.yaml` | ✔ código | ver abajo |
| P0-7 | Procedimiento de copia y restauración de archivos y MariaDB en Nodecraft | ✔ doc · ⏳ revisar en Nodecraft | `docs/27-respaldo-y-restauracion.md` |
| P0-8 | Fijar la versión que usa el servidor en producción (`set pxd_updater_ref "<commit>"`) | ⏸ decisión | sección 5 |

**Detalle de P0-6 (versiones fijas, comprobadas el 2 de noviembre de 2026):**
- **Releases por etiqueta**:
  - qbx_core v1.24.1, ox_lib v3.42.0, ox_inventory v2.48.1, ox_target v1.18.1, oxmysql v2.14.3, ox_doorlock v1.23.0.
  - Renewed-Banking v2.1.4, illenium-appearance v5.7.0, xt-prison v1.4.9.
  - qbx_vehicles v1.4.2, qbx_garages v1.1.4, qbx_management v1.4.0, qbx_spawn v0.1.1, qbx_customs v0.1.0, qbx_adminmenu v0.1.0, qbx_smallresources v0.2.0, qbx_density v1.0.1.
  - npwd_qbx_garages v1.1.0, npwd_qbx_mail v1.0.0, mana_audio v1.1.1, Renewed-Weathersync v1.1.8, vehiclehandler v1.4.7.
  - screencapture v0.17.2: es estable y también hace de `screenshot-basic`.
  - Antes todos se bajaban como «latest».
- **Ramas por commit**: los qbx_* y los demás recursos que se bajaban de `main` o `master` usan ahora `ref: <sha> # main fijado el 2026-11-02`. La receta descarga con `zipball/{ref}` de la API de GitHub, que admite commits (lo hace el motor de recetas de txAdmin).
- **Origen de cada versión**: es la que tienes instalada.
  - En las releases, la etiqueta más alta. Comprobé que su zip existe.
  - En las ramas, el commit actual.
- **Ojo**: tu servidor se instaló el 1 de noviembre, así que algún recurso podría estar un commit por detrás. Los parches comprueban el texto exacto: si no lo encuentran, avisan en vez de romper nada (P0-5).

## P1 · Errores críticos (Fase 1)

### Recursos de terceros

Se corrigen con **parches exactos**: los mismos en `scripts/update-plan.json` → `patches` y en `recipe-qbox.yaml`, en el bloque «ARREGLOS DE PRÓXIMA». No se modifica nada más del recurso.

| # | Problema | Comprobado en | Arreglo | Estado |
|---|---|---|---|---|
| P1-1 | El banco podía quedar en negativo | `qbx_core/config/server.lua:9` | `dontAllowMinus` incluye `bank` | ✔ código · ⏳ juego |
| P1-2 | Se podía comprar una casa sin fondos | `qbx_properties/server/property.lua:489` | Consecuencia de P1-1: ahora `RemoveMoney('bank')` falla sin saldo | ✔ código · ⏳ juego |
| P1-3 | El alquiler no se cobraba hasta el reinicio | `property.lua:470` (`startRentThread()` sin id) | Pasa `propertyId` | ✔ código · ⏳ juego |
| P1-4 | La cárcel estaba duplicada (qbx_police + xt-prison) | `qbx_police/server/main.lua:8` y `commands.lua:145` (comprobación según el orden de arranque) | Comprueba si xt-prison existe, no si ya ha arrancado | ✔ código · ⏳ juego |
| P1-5 | Las papeleras de policía no se registraban | `qbx_police/server/main.lua:660` | Registro también al arrancar qbx_police si ox_inventory ya está en marcha | ✔ código · ⏳ juego |
| P1-6 | El ítem radio usaba mm_radio, que no existe | `items.lua:208-235` | La radio abre qbx_radio; `jammer` y `radiocell` pasan a ser objetos normales | ✔ código · ⏳ juego |
| P1-7 | El desgaste de piezas no se guardaba | `qbx_mechanicjob/server/main.lua:139` (solo guarda con un evento antiguo); los hooks de qbx_garages no están en la v1.1.4 | Nuevo recurso `pxd_compat`: guarda el estado de cada vehículo con cambios, cada minuto como mucho y al apagar. 4 pruebas | ✔ código · ⏳ juego |
| P1-8 | Choque de teclas: Alt para la mirilla y para la radio | `voice.cfg` (`voice_defaultRadio "LMENU"`) | La radio se habla con **Bloq Mayús** (`setr voice_defaultRadio "CAPITAL"`) | ✔ código · ⏳ juego |
| P1-9 | Interfaz de voz duplicada | `voice_enableUi 1` | `setr voice_enableUi 0`: el modo de voz ya lo muestra pxd_hud | ✔ código · ⏳ juego |
| P1-10 | `ensure [assets]` apuntaba a una carpeta que no existe | `server.qbox.cfg` | Línea quitada | ✔ código |
| P1-11 | Tecla K: maletero (ox_inventory) y agacharse (qbx_crouch, a pie, sin convar) | `ox.cfg`; `qbx_crouch/client.lua:16` | — | ⏸ decisión (sección 3) |
| P1-12 | Al reaparecer en el hospital se pierde todo el inventario, efectivo incluido | `qbx_ambulancejob/config/server.lua:3` | — | ⏸ decisión |
| P1-13 | Las multas se rechazan si no hay saldo (efecto de P1-1) y no queda registro | `qbx_police/server/main.lua:626` | Multas pendientes y expediente → P2 | ⏸ decisión / P2 |

### Recursos propios (✔ código · ⏳ juego)

| # | Problema | Arreglo previsto |
|---|---|---|
| P1-20 | `/anuncio` estaba en pxd_admin y en pxd_chat | Un solo dueño: pxd_admin; pxd_chat lo pinta por evento. La ACE antigua `pxd.chat.announce` sigue valiendo |
| P1-21 | `/susurrar` estaba en pxd_voice (comando de cliente) y en pxd_chat | La tecla J pasa a `pxd_voice_whisper`; `/susurrar` es del chat |
| P1-22 | El tope de dinero por hora de pxd_jobs se reiniciaba al reconectar | Tope por licencia mientras el servidor está encendido |
| P1-23 | Cualquier cliente podía cambiarse el estrés con eventos de red | Límites en el servidor |
| P1-24 | pxd_gamemodes: cualquiera crea partidas, las armas las da el cliente y las bajas las informa el cliente | 1 partida por anfitrión y 30 s entre creaciones; armas dadas por el servidor; bajas validadas (misma partida, ≤300 m, frecuencia). **Pendiente**: validar las bajas con los eventos de daño del servidor |
| P1-25 | pxd_admin cambiaba de bucket saltándose Qbox y el lobby | `SetPlayerBucket` y salida limpia de la partida |
| P1-26 | Había logros imposibles (`event_join`, 28 frente a 14 días) | Corrección |
| P1-27 | La ayuda del panel cita `/ooc` y no menciona F9 | Corrección |
| P1-28 | Eventos de red de nuestros recursos sin validar | Revisados. Comandos de staff renombrados para no chocar con qbx_core/qbx_adminmenu: `/ir`, `/irmarcador`, `/volar`, `/borrarvehiculo` |

## P2 · Siguiente (tras P0/P1 y las pruebas en el juego)

**Economía conectada**
- P2-1: Multas pendientes y facturas con registro, expediente (`criminalrecord` → historial) y pago posterior.
- P2-2: Nóminas desde la cuenta de la empresa (`paycheckSociety = true`) y menú de jefe para todos los trabajos.
- P2-3: App de banco en el teléfono, leyendo de Renewed-Banking.
- P2-4: Catálogo de casas predefinidas, creado por la inmobiliaria o con una semilla revisada.

**Arquitectura común**
- P2-5: Una sola API de avisos: ver el contrato en la sección 6.
- P2-6: Regla de interacción: ox_target para el mundo de Qbox y la E de pxd_interact para objetos del suelo y jugadores.
- P2-7: Una sola fuente del reglamento; hoy está en tres sitios.
- P2-8: pxd_multichar sin SQL directo, donde haya API.
- P2-9: Reparto entre los paneles de administración: txAdmin, qbx_adminmenu y pxd_admin (sección 6).

**Integraciones y contenido**
- P2-10: Integrar por partes las ramas `wt/oxlib`, `wt/phone` y `wt/blips`: cada una con su plan de pruebas y su vuelta atrás.
- P2-11: El Plus vive solo en `data/plus.json`: llevarlo a la BD y hacer copia de seguridad.
- P2-12: Eventos con inscripción real (`event_join`).

## 3. Decisiones del propietario

1. **Tecla K.** Opciones:
   - mover el maletero a otra tecla;
   - dejar las dos (agacharse solo actúa a pie, pero el maletero también se usa a pie).
2. **Inventario al morir y reaparecer en el hospital.** Opciones:
   - mantener el borrado (más duro);
   - conservar el efectivo y los objetos personales;
   - borrar solo armas e ilegales.
3. **Multas sin saldo.** Opciones:
   - rechazarlas (como ahora);
   - crear una deuda pendiente (P2-1).
4. **Teléfono.**
   - La cámara y la galería necesitan fivemanage, un servicio externo que puede ser de pago.
   - La licencia de npwd no es comercial: revisarla antes de vender con Tebex.

## 4. Pruebas en FiveM

Usa la plantilla de `docs/auditoria/2026-11-02-diagnostico-tecnico.md` (sección 10). Cada fila debe tener:
- escenario;
- requisitos;
- acciones;
- resultado esperado;
- resultado observado;
- evidencia (captura o registro);
- problemas;
- estado.

## 5. Despliegue: nada sale a Nodecraft sin autorización

- **Ojo:** `pxd_update` descarga **la rama por defecto del repositorio**, que es donde se integra este trabajo. Para no aplicar cambios sin revisar:
  - no ejecutes `pxd_update` hasta aprobar la entrega;
  - o fija la versión en el cfg: `set pxd_updater_ref "<commit aprobado>"`.
- **Orden de cada entrega**:
  1. Copia de Nodecraft y de MariaDB (docs/27).
  2. `pxd_update check`.
  3. `pxd_update`.
  4. Reiniciar.
  5. Pruebas.
  6. Si algo falla: `pxd_update rollback` y restaurar las copias.
- **Cambios en el cfg** (los hace el propietario en el CFG Editor):
  - `add_filesystem_permission pxd_updater write qbx_police`
  - `add_filesystem_permission pxd_updater write qbx_properties`
  - `add_filesystem_permission pxd_updater write pxd_compat`
  - `setr voice_defaultRadio "CAPITAL"`
  - `setr voice_enableUi 0`
  - quitar `ensure [assets]`

## 6. Contratos entre sistemas (borrador de la Fase 2)

| Dominio | Dueño (fuente de verdad) | Cómo lo usan los demás |
|---|---|---|
| Personaje | qbx_core | `exports.qbx_core:GetPlayer`, metadata; nada de SQL directo salvo lecturas justificadas |
| Dinero personal | qbx_core | `AddMoney`/`RemoveMoney` comprobando el resultado; sin saldo negativo |
| Cuentas de empresa | Renewed-Banking | `addAccountMoney`/`removeAccountMoney`/`handleTransaction` |
| Inventarios | ox_inventory | exports y hooks de ox_inventory |
| Vehículos | qbx_vehicles | `CreatePlayerVehicle`, `GetPlayerVehicles`; desgaste guardado por pxd_compat |
| Viviendas | qbx_properties | sus eventos y callbacks; parches solo para fallos |
| Teléfono | npwd | apps externas que leen de los dueños de arriba |
| Progresión | pxd_progress | `GetProfile`, `Track`, `AddXP` |
| Identidad pública | pxd_interact | `GetPublicId`, `Knows` |
| Cárcel | xt-prison | su API; qbx_police ya no registra la suya |
| Administración | txAdmin: baneos, avisos y servidor · qbx_adminmenu: herramientas de desarrollo · pxd_admin: soporte F9, reportes, `/duty` y registro de staff | permisos ACE `pxd.*` documentados |
| Avisos | (P2-5) API `pxd_ui:notify` → ox_lib con el estilo común | todos los pxd_* |
| Auditoría | (P2) registro común de acciones sensibles: dinero, staff, propiedades | un export y un archivo o BD |
