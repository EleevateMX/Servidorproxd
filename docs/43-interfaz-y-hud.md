# 43. Interfaz común (`pxd_ui`) y HUD 2.0 (`pxd_hud`)

**Estado:** implementado y con pruebas automáticas (16 en Lua, 22 en Vitest, 7 en Node) y capturas en 1280×720, 1920×1080 y 2560×1080. **No instalado en Nodecraft ni probado dentro de FiveM.**

## 1. Auditoría: qué interfaces seguían siendo las de serie

| Interfaz | Quién la usa (comprobado en su código) | Decisión |
|---|---|---|
| Avisos de ox_lib (`lib.notify`) y de qbx_core (`exports.qbx_core:Notify` → evento `ox_lib:notify`) | Todo Qbox | **Sustituida ahora** por `pxd_ui` |
| Indicación de tecla (`lib.showTextUI`) | qbx_radialmenu, qbx_garages, qbx_vehicleshop, qbx_customs, qbx_management | **Sustituida ahora** |
| Barra y círculo de progreso (`lib.progressBar`, `lib.progressCircle`) | Trabajos, médicos, mecánicos, robos | **Sustituida ahora** (la lógica sigue en ox_lib) |
| Diálogo de confirmación (`lib.alertDialog`) | qbx_vehicleshop, qbx_management, pxd_economy | **Sustituida ahora** |
| Menú contextual (`lib.registerContext`) y formulario (`lib.inputDialog`) | qbx_garages, qbx_vehicleshop, qbx_management, pxd_economy, pxd_admin | **Después.** Quedan con el tema de Próxima (`pxd_theme`). Su contrato es mucho mayor: submenús, metadatos, 12 tipos de campo y foco de teclado |
| Menú de teclado (`lib.registerMenu`) | qbx_customs (29 usos) | **Después**, junto con el tuneo propio (docs/44) |
| Menú radial (`lib.addRadialItem`) | qbx_radialmenu, qbx_garages | **Después.** Tematizado |
| Prueba de habilidad (`lib.skillCheck`) | Robos y ganzúas | **Después.** Tematizada |
| qbx_scoreboard, qbx_idcard | NUI propia de cada uno | **Después** (pxd_panel ya cubre la lista de jugadores) |
| Renewed-Banking | NUI propia (Svelte) | **Después**: app de banco del teléfono (etapa E-1) |
| Cinturón, velocímetro, combustible | qbx_seatbelt, ox_fuel (solo datos) | **Sustituidos ahora** por el HUD 2.0 |

## 2. `pxd_ui`: interfaz común propia

Recurso nuevo con su página en React + TypeScript (`web/pxd-ui`, compilada en `pxd_ui/html` con nombres fijos).

**Exports de cliente:**

| Export | Qué hace |
|---|---|
| `Notify({ title, description, type, duration, id, position })` | Aviso. Con el mismo `id` no se apila: se sustituye y muestra «×2» |
| `ShowTextUI(text, { position })`, `HideTextUI()`, `IsTextUIOpen()` | Indicación de tecla. `[E]` se dibuja como tecla |
| `Progress(data)`, `ProgressCircle(data)` | Devuelven `true` si terminó y `false` si se canceló. Con ox_lib arrancado delegan en él (animaciones, props, bloqueo de controles) |
| `ProgressActive()`, `CancelProgress()` | Estado y cancelación |
| `Confirm({ header, content, cancel, labels })` | Diálogo. Devuelve `'confirm'` o `'cancel'` |

Desde el servidor: `TriggerClientEvent('pxd_ui:client:notify', src, { title, description, type })`.

**Seguridad:** el texto de terceros nunca se inserta como HTML. Se limpian etiquetas y códigos de color, se acotan longitudes y solo se aceptan colores `#hex` o `rgb()`.

### Adaptador de ox_lib

Los recursos de terceros no se tocan. Nueve parches mínimos en cuatro archivos de **ox_lib 3.42.0** (`resource/interface/client/`) hacen que, si `pxd_ui` está arrancado, la parte visual la dibuje `pxd_ui`. Si no lo está, o si `pxd_ui` no atiende la llamada, ox_lib usa su interfaz original.

| Archivo | Parches | Contrato |
|---|---|---|
| `notify.lua` | 1 | `OxNotify(payload)`. El sonido lo sigue reproduciendo ox_lib |
| `textui.lua` | 2 | `OxTextUI(options)` y `OxTextUIHide()`. `lib.isTextUIOpen` no cambia |
| `progress.lua` | 3 | `OxProgress(nuiMessage)`, `OxProgressCancel()` y el evento local `pxd_ui:oxProgressComplete`. La duración la cuenta el cliente de `pxd_ui` en Lua: aunque la página fallara, el progreso termina. Animaciones, props, bloqueo de controles y el resultado `true`/`false` siguen en ox_lib |
| `alert.lua` | 3 | `OxAlert(data)`, `OxAlertClose()` y el evento local `pxd_ui:oxAlertResult`. La promesa y el tiempo límite siguen en ox_lib; el foco lo toma `pxd_ui` |

- Textos exactos: `web/pxd-ui/adapter/ox_lib-3.42.0.json` (para `scripts/update-plan.json`) y `web/pxd-ui/adapter/recipe-steps.yaml` (para `recipe-qbox.yaml`).
- Verificado contra el zip oficial: cada búsqueda coincide **una vez**, también como expresión regular de la receta, y los cuatro archivos parcheados compilan.

## 3. HUD 2.0 (`pxd_hud` 0.2.0)

| Zona | Contenido | Fuente |
|---|---|---|
| Sobre el minimapa | Anillos de salud, armadura, hambre, sed, estrés y oxígeno. Armadura, estrés y oxígeno solo aparecen cuando aplican | Natives y state bags de qbx_core (los mismos que el inventario) |
| Junto al minimapa | Voz (modo, alcance, radio), hora del juego e ID PROX | pma-voice / pxd_voice, `pxdId` de pxd_interact |
| Arriba al centro | Brújula con puntos cardinales, calle y zona | `GetGameplayCamRot`, `GetStreetNameAtCoord`, `GetNameOfZone` + `GetLabelText` |
| Arriba a la derecha | Efectivo y banco, cuenta atrás de la paga, multas y facturas pendientes | qbx_core; state bags `pxdPayday` (segundos), `pxdFines`, `pxdInvoices` |
| Abajo a la derecha (en vehículo) | Velocidad, RPM, marcha, combustible, cinturón, motor, carrocería, luces, seguro y control de crucero | Natives; `Entity(veh).state.fuel` de ox_fuel; `seatbelt`/`harness` de qbx_seatbelt; evento de qbx_cruise |
| Minimapa | El del juego, con marco propio | — |

- **Si un dato no existe, no se dibuja.** Sin `pxdPayday` no hay cuenta atrás; sin multas ni facturas no hay avisos.
- **Rendimiento:** bucle normal cada 250 ms y bucle rápido (brújula; velocidad, RPM y marcha en vehículo) cada 80–150 ms. A la página solo se envían los cambios.
- **Ajustes del jugador:** `/hud` abre el panel (mostrar u ocultar cada elemento, tamaño del 80 al 130 %, modo cine) y `/hudcine` alterna el modo cine. Se guardan en su equipo con KVP.
- **Se conservan:** export `SetVisible` y evento `pxd_hud:client:visible` (los usan pxd_multichar y el inventario), los eventos de estrés y `ChangeStress`. Nuevos: `IsVisible`, `GetSettings`, `SetCinema`.
- Natives comprobados en `natives.json`.

## 4. Integración (archivos compartidos)

| Archivo | Cambio |
|---|---|
| `server.qbox.cfg` | `ensure pxd_ui` (antes de `pxd_hud`) |
| `tests/js/deploy.test.mjs` | Añadir `'pxd_ui'` a `QBOX_ONLY` |
| `scripts/update-plan.json` | `pxd_ui` en `autostart` (antes de `pxd_hud`) y los 9 parches del JSON del adaptador |
| `permissions.pxd.cfg` y `permissions.cfg` | `add_filesystem_permission pxd_updater write pxd_ui` (el de `ox_lib` ya existe) |
| `recipe-qbox.yaml` | Los 9 pasos de `recipe-steps.yaml`, después de descomprimir ox_lib |

`pxd_hud/html/assets/` es una carpeta nueva y `pxd_ui` un recurso nuevo: van en el paquete de instalación (el actualizador no crea carpetas).

## 5. Pendiente y solo verificable en FiveM

- Que los avisos, indicaciones, progreso y diálogos de Qbox salgan con la interfaz nueva y ya no con la de ox_lib.
- Que un progreso con animación termine y se cancele (tecla X) igual que antes.
- Que el diálogo de `pxd_ui` reciba el ratón y el teclado, y que al cerrarlo vuelva el control al juego.
- Posición real del marco del minimapa y de los anillos en 16:9 y 21:9 con distintas zonas seguras.
- Marcha y RPM en motos, barcos y aeronaves; valor del seguro (`GetVehicleDoorLockStatus`) con qbx_vehiclekeys.
- Nombres de calle y zona según el idioma del juego del jugador.
- El panel `/hud` no está enlazado todavía desde `pxd_panel` → Ajustes.
- Menú contextual, formulario, menú de teclado, radial y prueba de habilidad siguen con el tema de `pxd_theme`.

## Desarrollo

```bash
cd web/pxd-ui
npm ci
npm test            # Vitest
npm run build       # compila pxd_ui/html y pxd_hud/html y actualiza build-stamp.json
node scripts/shots.mjs <carpeta>   # capturas con datos simulados
```
