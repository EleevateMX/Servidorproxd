# 14. HUD y teléfono

## HUD (`pxd_hud`)

Interfaz en pantalla de Próxima RP. **Sustituye a `qbx_hud`** (no deben estar los dos encendidos).

| Zona | Qué muestra |
|---|---|
| Sobre el minimapa | Efectivo y banco; al cambiar, aparece `+$500` / `-$120` unos segundos |
| Minimapa | El del juego, enmarcado con el borde y el destello de Próxima. Visible también a pie (`Config.minimapOnFoot`) |
| A la derecha del minimapa | Fecha (del jugador) y hora del juego; barras de salud, armadura (solo si tiene), comida, bebida, estrés (solo si tiene) y oxígeno (solo bajo el agua). Cambian de color al bajar de `Config.warn` y parpadean en crítico |
| Abajo al centro | Voz: micrófono (se ilumina al hablar), alcance de pma-voice (Susurro, Normal, Gritando) y canal de radio si está en uno. Va a la izquierda de la barra rápida de ox_inventory |
| Abajo a la derecha (en vehículo) | Calle, velocímetro (km/h o mph), combustible (aviso bajo `Config.lowFuel`), motor, cinturón/arnés (parpadea si vas sin él) y control de crucero |

Se oculta con el menú de pausa, al abrir el inventario y cuando el jugador no ha entrado con un personaje. Otros recursos pueden ocultarlo con `exports.pxd_hud:SetVisible(false)` (cliente).

### De dónde salen los datos (verificado en el código de cada recurso)

| Dato | Fuente |
|---|---|
| Comida, bebida, estrés, sesión iniciada | State bags `hunger`, `thirst`, `stress`, `isLoggedIn` que pone qbx_core |
| Dinero | `exports.qbx_core:GetPlayerData()`, eventos `QBCore:Player:SetPlayerData` y `hud:client:OnMoneyChange` |
| Voz | State bags `proximity` (`index`, `distance`, `mode`) y `radioChannel` de pma-voice |
| Cinturón y arnés | State bags `seatbelt` y `harness` de qbx_seatbelt |
| Crucero | Evento `seatbelt:client:ToggleCruise` de qbx_cruise (qbx_smallresources) |
| Combustible | `GetVehicleFuelLevel` (ox_fuel lo sincroniza) |
| Inventario abierto | Eventos de servidor `ox_inventory:openedInventory` / `closedInventory` |

### Estrés

Se mantiene el sistema de `qbx_hud` con los **mismos nombres de evento**, porque otros recursos lo usan: `hud:server:GainStress` (qbx_vehiclekeys al forzar coches) y `hud:server:RelieveStress` (qbx_medical). Sube al ir muy rápido sin cinturón y al disparar (probabilidad `Config.stress.chance`), con visión borrosa a partir de 50 y caídas al llegar a 100. Los trabajos de tipo `leo` no lo acumulan. El valor se guarda con `exports.qbx_core:SetMetadata(src, 'stress', valor)`, que también actualiza el state bag. Export de servidor: `exports.pxd_hud:ChangeStress(src, delta)`.

### Qué no hace (todavía)

- **Barra rápida (5 ranuras)**: es de ox_inventory. Su estilo va con el rediseño del inventario (tarea aparte).
- **Multas y avisos** arriba a la derecha: necesitan un sistema de facturas y de avisos que no está en la receta.
- Comandos de `qbx_hud` que se pierden: `/cash` y `/bank` (el dinero ya está siempre a la vista) y `/dev`, además de su menú de opciones (tecla I).

### Instalación

1. Quitar `qbx_hud`: en `recipe-qbox.yaml`, el paso que lo descarga; en un servidor ya montado, borrar o renombrar `resources/[qbx]/qbx_hud` (`ensure [qbx]` lo arrancaría).
2. Añadir `ensure pxd_hud` con los demás recursos de Próxima.
3. Configurar en `pxd_hud/config.lua` (unidad de velocidad, minimapa a pie, avisos, estrés).

Vista previa sin el juego: `html/index.html?demo=1` (a pie) y `?demo=1&vehicle=1` (en vehículo).

## Teléfono (npwd)

La receta instala **npwd 3.14.3** con `qbx_npwd`, que copia su `config.json` a `resources/[npwd]/npwd/config.json`. npwd viene compilado: tema, fondos y lista de apps internas están dentro de la compilación. **Sin recompilar** se puede cambiar:

| Qué | Dónde | Propuesta |
|---|---|---|
| Idioma por defecto | `general.defaultLanguage` | `es` (npwd trae `locale/es.json`) |
| Tecla | `general.toggleKey` | `UP` (flecha arriba; la de qbx_npwd era `m`). Quien ya entró conserva su tecla en Ajustes → Asignación de teclas → FiveM |
| Apps quitadas | `disabledApps` | `BROWSER` (como qbx_npwd) |
| Apps externas | `apps` | `npwd_qbx_mail`, `npwd_qbx_garages` |
| Contactos por defecto | `defaultContacts` (`display`, `number`, `avatar`) | Vacío: no hay números de servicio que respondan |

Archivo propuesto: `server-data/resources/[proxima]/pxd_hud/npwd/config.json`. Es el de qbx_npwd con el idioma en español. Se copia encima de `resources/[npwd]/npwd/config.json`.

**Tema y fondo.** El jugador los elige en Ajustes del teléfono. npwd trae los temas `default-light` y `taso-dark`; el oscuro es el que mejor encaja. Para el fondo hay opción de **fondo personalizado por URL**: tiene que ser `http(s)` y terminar en `.jpg`, `.png`, `.jpeg` o `.gif`. Fondo propio de Próxima, generado sin servicios de pago:

- `server-data/resources/[proxima]/pxd_hud/npwd/fondo-proxima.jpg` (1080×2340), con el SVG fuente al lado.
- URL para pegar en Ajustes → Fondo personalizado (cuando esté en GitHub):
  `https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/server-data/resources/%5Bproxima%5D/pxd_hud/npwd/fondo-proxima.jpg`
- Se regenera con `node scripts/generar-fondo-telefono.mjs <salida.svg> <salida.jpg>`.

Para que sea el fondo **por defecto** de todos, o para un tema con los colores de Próxima, habría que modificar y recompilar npwd (`apps/phone/src/config/default.json` y `themes.json`).

**Cámara.** Subir fotos usa un servicio externo de imágenes (por defecto Fivemanage, `images.url`) con la clave en la convar `SCREENSHOT_BASIC_TOKEN`. Esa clave va en `secrets.cfg` con `set`, nunca `setr`. Es un servicio de terceros: revisa sus condiciones y si tiene costo antes de activarlo.

### Apps de la referencia frente a lo que ya hay

| App | Estado |
|---|---|
| Llamadas, Mensajes, Contactos, Calculadora, Ajustes | Ya en npwd (`DIALER`, `MESSAGES`, `CONTACTS`, `CALCULATOR`, `SETTINGS`) |
| Cámara y Galería | Ya en npwd (`CAMERA`, con su galería de fotos); necesita el servicio de imágenes de arriba |
| Anuncios | Parecido: `MARKETPLACE` (anuncios de compraventa). npwd trae además `TWITTER`, `MATCH`, `NOTES` y `DARKCHAT` |
| Garaje | `npwd_qbx_garages` (ya en la receta) |
| Correo | `npwd_qbx_mail` (ya en la receta; no estaba en la referencia) |
| Banco | Falta como app. Renewed-Banking (en la receta) funciona en cajeros y bancos, no en el teléfono |
| Organizaciones, Eventos | Faltan en el teléfono; están en el panel de Próxima (`pxd_panel`) |
| Taxi, Emergencias | Faltan: necesitan un sistema de avisos (*dispatch*) y el trabajo de taxi |
| Inmobiliaria, Recetas | Faltan: dependen de propiedades y de un sistema de cocina |

Las que faltan se pueden hacer como **apps externas de npwd** (recursos propios que se añaden a `apps`), sin tocar npwd.
