# Diagnóstico técnico de Próxima RP

**Fecha:** 2 de noviembre de 2026. **Repositorio:** `EleevateMX/Servidorproxd`, rama `claude/stoic-wozniak-k6fi8y` (commit 4eaacf4). **Servidor:** Nodecraft.
Es un documento de solo lectura: para hacerlo no se ha cambiado nada, ni en el repositorio ni en el servidor.

## Cómo leer este documento

**Evidencia.** El estado de cada sistema se apoya en una de tres fuentes, de más a menos fuerte:
1. Lo que se ha visto en el juego o en la consola de Nodecraft, en capturas y registros que el propietario ha enviado en esta conversación.
2. El código fuente leído, citando archivo y línea.
3. Las pruebas automáticas: 231 en Lua y 44 en Node, todas sobre un FXServer simulado.

**Límite de acceso.** No tengo acceso directo a Nodecraft. Lo que digo sobre el servidor se apoya solo en esos registros y capturas.

**Estados.** Cada sistema lleva uno de estos:

| Estado | Significa |
|---|---|
| ✅ PROBADO | Se ha visto funcionar en el juego o en la consola. |
| 🟡 PENDIENTE | Está instalado y el código está revisado, pero nadie lo ha probado en el juego. |
| 🟠 PARCIAL | Funciona una parte; falta lógica o hay fallos conocidos. |
| 🎨 SOLO UI | Es interfaz o prototipo, sin lógica real detrás. |
| ⛔ NO EXISTE | No hay ningún recurso que lo haga. |
| 🔒 BLOQUEADO | Depende de algo que falta: decisión, permiso, pago o licencia. |

**Nada se marca como funcional sin evidencia.**

---

## 1. Plataforma y versiones reales

| Pieza | Versión | Evidencia |
|---|---|---|
| FXServer | artefacto **35245** | pie de txAdmin «fx: b35245» (captura) |
| txAdmin | **8.1.1** | consola y pie (captura) |
| Build del juego | **3258** activa; 3751 cambiada en el repositorio, no aplicada en el servidor | `server.qbox.cfg`; capturas con «b3258» |
| Base de datos | MariaDB **12.3.3** (MySQL de Nodecraft) | consola: «Database server connection established» |
| Framework | **Qbox**: qbx_core **v1.24.1** (release latest); compatible con QBCore mediante su puente | receta y clon; consola «Welcome to Qbox» |
| ox_lib / ox_target / ox_inventory / oxmysql / ox_doorlock / ox_fuel | 3.42.0 / 1.18.1 / **2.48.1** / 2.14.3 / 1.23.0 / 1.5.4 | tags; consola «Inventory has loaded 303 items» |
| Voz | pma-voice 7.0.1 + qbx_radio | consola |
| Teléfono | npwd **3.14.3** (tag fijo) + qbx_npwd + apps de garaje y correo | receta y consola |
| Banco | Renewed-Banking 2.1.4 | consola |
| Ropa | illenium-appearance 5.7.0 | consola y capturas |
| Recursos detectados | 71 al arrancar, antes del paquete de instalación | consola «Found 71 resources» |

**Riesgo de versiones.** Muchos recursos se descargan con `ref: main` o `release latest`, sin versión fija. Una reinstalación puede traer versiones distintas a las revisadas aquí. Además, algunos parches y overlays dependen de una versión exacta (por ejemplo, ox_inventory 2.48.1).

---

## 2. Árbol de recursos

Notas sobre las columnas:
- **Dependencias** recoge las declaradas en el fxmanifest y los exports que el recurso usa de verdad.
- **En Nodecraft** dice si consta como instalado o arrancado, según los registros.

### 2.1 Terceros (receta `recipe-qbox.yaml`)

| Carpeta | Recurso | Depende de | En Nodecraft |
|---|---|---|---|
| raíz | `ox.cfg`, `voice.cfg`, `misc.cfg`, `permissions.cfg`, `items.lua`, `qbox.sql` | — | sí |
| sistema | mapmanager, chat (del sistema), spawnmanager, baseevents, monitor (txAdmin) | — | arrancados (consola) |
| [ox] | ox_lib | — | arrancado |
| | oxmysql | — | arrancado; BD conectada |
| | ox_target | ox_lib | arrancado |
| | ox_inventory | ox_lib, oxmysql; qbx_core ≥1.18.1, qbx_vehicles ≥1.2.0 | arrancado |
| | ox_doorlock, ox_fuel | ox_lib (ox_fuel también ox_inventory) | arrancados |
| [qbx] | qbx_core | ox_lib, oxmysql; usa ox_inventory, qbx_vehicles, qbx_vehiclekeys, qbx_idcard, illenium, Renewed-Banking | arrancado |
| | qbx_medical, qbx_ambulancejob | qbx_core, ox_lib, ox_inventory, ox_target, Renewed-Banking | arrancados; qbx_ambulancejob dio un error al arrancar (abajo) |
| | qbx_police | qbx_core, ox_inventory, Renewed-Banking, qbx_vehiclekeys, ox_target, xt-prison | arrancado |
| | qbx_vehicleshop, qbx_vehicles, qbx_garages, qbx_vehiclekeys, qbx_customs | qbx_core, qbx_vehicles, ox_target, Renewed-Banking | arrancados |
| | qbx_spawn, qbx_cityhall, qbx_idcard, qbx_management, qbx_adminmenu, qbx_radialmenu, qbx_scoreboard, qbx_seatbelt, qbx_smallresources, qbx_density | qbx_core (+ ox_lib/ox_target) | arrancados |
| | qbx_hud | qbx_core | arrancado; luego pxd_hud lo sustituyó y lo detuvo (consola) |
| | **Fase 2:** qbx_mechanicjob, towjob, taxijob, truckerjob, garbagejob, busjob, newsjob, recyclejob, diving, divegear, vineyard, scrapyard, **qbx_properties** | qbx_core, ox_target, ox_inventory (qbx_properties: + qbx_garages, illenium) | subidos con el paquete; que estén arrancados no se ha visto en ninguna captura (`ensure [qbx]` debería hacerlo) |
| [standalone] | Renewed-Banking | qbx_core, ox_target | arrancado |
| | illenium-appearance | qbx_core | arrancado |
| | xt-prison | qbx_core, ox_inventory, ox_target, ox_doorlock, scully | arrancado |
| | scully_emotemenu, screencapture (sustituye a screenshot-basic), MugShotBase64, bob74_ipl, mana_audio, Renewed-Weathersync, vehiclehandler, safecracker, mhacking, ultra-voltlab | — | arrancados |
| [voice] | pma-voice, qbx_radio | qbx_radio: pma-voice, qbx_core | arrancados |
| [npwd] | npwd (necesita screenshot-basic y pma-voice), qbx_npwd | npwd, qbx_core, ox_inventory | arrancados |
| [npwd-apps] | npwd_qbx_garages, npwd_qbx_mail | qbx_garages, npwd | arrancados |
| [assets] | (no existe) | — | aviso «Couldn't find resource category [assets]» |

### 2.2 Propios ([proxima])

| Recurso | Qué hace | Depende de | Repositorio | En Nodecraft |
|---|---|---|---|---|
| pxd_loadscreen | Pantalla de carga | pxd_login (opc.) | ✔ | ✔ arrancado |
| pxd_login | Tarjetas al conectar y normas | qbx_core (opc.) | ✔ | ✔ arrancado |
| pxd_props | Editor de props y dashboard web | — | ✔ | ✔ arrancado |
| pxd_gamemodes | Modos de juego (F7) | baseevents; qbx_core, qbx_medical, ox_inventory, pxd_props, pxd_progress (opc.) | ✔ | ✔ arrancado |
| pxd_updater | Actualizador | permisos ACE y `add_filesystem_permission` | ✔ | ✔ arrancado |
| pxd_progress | Nivel, horas, recompensas y logros | qbx_core, ox_inventory (opc.) | ✔ | ✔ iniciado por el actualizador (consola) |
| pxd_restart | Avisos de reinicio | txAdmin | ✔ | ✔ iniciado (consola) |
| pxd_jobs | Minero, leñador, pescador, repartidor | qbx_core; pxd_interact u ox_target (opc.) | ✔ | ✔ iniciado (consola) |
| pxd_panel | Panel TAB | qbx_core, pxd_progress (opc.) | ✔ | ✔ iniciado (consola), versión anterior al rediseño |
| pxd_multichar | Selección y creación de personaje | **qbx_core, ox_lib, oxmysql** (obl.); qbx_spawn, qbx_properties, illenium | ✔ | ✔ iniciado y parche de qbx_core aplicado (consola), versión anterior al rediseño |
| pxd_hud | HUD | qbx_core, pma-voice, qbx_seatbelt (opc.) | ✔ | ✔ iniciado, sustituye a qbx_hud (consola), versión anterior |
| pxd_interact | Tecla E y ID PROX | qbx_core, ox_inventory (opc.) | ✔ | ✖ no instalado |
| pxd_voice | Doble N para gritar, J para susurrar | **pma-voice** | ✔ | ✖ no instalado |
| pxd_admin | F9 reportes, F10 staff, /duty | qbx_core, qbx_medical, illenium, pxd_progress (opc.) | ✔ | ✖ no instalado |
| pxd_inventory | Capa visual de ox_inventory (I) | ox_inventory 2.48.1 | ✔ | ✖ no instalado |
| pxd_chat | Chat de proximidad | **chat** (del sistema) | ✔ | ✖ no instalado |
| pxd_phone | Diseño del teléfono y apps Dynasty 8, Emergencias, Taxi | npwd 3.14.3, qbx_core, oxmysql | rama `wt/phone` (sin integrar) | ✖ |
| pxd_theme | Estilo de ox_lib y ox_target | ox_lib 3.42.0, ox_target 1.18.1 | rama `wt/oxlib` (sin integrar) | ✖ |
| pxd_blips | Nombres del mapa en español | — | rama `wt/blips` (sin integrar) | ✖ |

---

## 3. Matriz de funcionamiento

### 3.1 Probado en el juego o en la consola

| Sistema | Evidencia |
|---|---|
| Conexión, licencia y tarjetas de pxd_login | El propietario entra al servidor; antes se arregló un bloqueo en «Comprobando tu acceso» |
| Pantalla de carga (pxd_loadscreen) | Capturas de la carga |
| Qbox: creación de personaje (flujo original) | Consola: «TabeticEagle has created a character» |
| Apartamento inicial de qbx_properties y editor illenium | Capturas: pizarra de apartamentos y editor de ropa |
| Inventario ox_inventory (aspecto original) | Captura de los ítems iniciales; el propietario dice que «con F2 sale el de FiveM» |
| HUD pxd_hud (versión anterior) | Capturas: dinero, voz, hora y barras |
| Panel TAB con datos reales (versión anterior) | Captura con nivel 1, 2/100 XP, efectivo 500 y banco 5000 |
| pxd_progress cuenta el tiempo jugado | Captura: «Tiempo jugado 2 min» |
| Modos de juego: carrera | Captura del HUD «CARRERA · Vuelta 1/2 · CP 1/3» |
| pxd_updater: parches, arranque automático, sustitución de qbx_hud | Consola: «Ajustado qbx_core…», «Iniciado pxd_progress…», «qbx_hud detenido» |
| Voz por proximidad (pma-voice) | Indicador «Normal» en el HUD |
| Chat del sistema y `/me` | Captura con la sugerencia de `/me` |

### 3.2 Instalado, sin probar en el juego (🟡)

**Recursos propios:**
- **pxd_multichar.** Hay que confirmar con una captura que sale nuestra selección y no la de Qbox.
- **pxd_jobs.** Las coordenadas son aproximadas.
- **pxd_restart.**
- **pxd_props en el servidor** (dashboard y anclas).

**Recursos de Qbox (código revisado, sin probar en el juego):**
- **Trabajos de la fase 2:** los 13 recursos de qbx subidos con el paquete.
- **Cadena de vehículos:** compra → `player_vehicles` → garaje y depósito → llaves → maletero y guantera → tuneo. Revisada en el código.
- **Policía:** esposas, cachear, pruebas, ANPR y grúa.
- **EMS:** last stand, muerte, revivir y check-in en el hospital.
- **Banco y organizaciones:**
  - Renewed-Banking, con cuentas de empresa por trabajo y banda.
  - qbx_management: contratar, despedir y ascender.
- **Documentos:** DNI y carné, con reimpresión en el ayuntamiento.
- **Teléfono (npwd):** contactos, mensajes, llamadas, notas y Twitter.

### 3.3 Hecho en el repositorio, sin instalar en Nodecraft

- **Recursos nuevos:** pxd_interact, pxd_voice, pxd_admin, pxd_inventory y pxd_chat.
- **Rediseños** del panel, el HUD, la selección de personaje y la nueva pantalla de aparición.
- **Cambio de build a 3751.** Requiere editar el cfg a mano.

### 3.4 Parcial o con fallos (🟠)

| Sistema | Qué falla | Fuente |
|---|---|---|
| **Banco** | El saldo del banco puede quedar en negativo: multas, check-in y casas se cobran siempre | `qbx_core/config/server.lua:9` |
| **Casas** | Se puede comprar una casa sin dinero | `qbx_properties/server/property.lua:489` |
| | El alquiler no se cobra hasta el siguiente reinicio | `property.lua:470` |
| | No hay casas predefinidas: solo las crea el trabajo `realestate` con `/createproperty` | código |
| **Nóminas** | El dinero se crea de la nada (`paycheckSociety=false`), sin vínculo con la cuenta de la empresa | `qbx_core/server/loops.lua:48-74` |
| **Multas** | Se cobran al momento y no queda registro ni expediente; solo existe `criminalrecord {hasRecord, date}` | código |
| **Cárcel** | Duplicada: qbx_police y xt-prison registran a la vez `/jail` y `/unjail` y el mismo evento, por el orden de arranque | `qbx_police/server/main.lua:8` |
| **Radio** | El ítem `radio` no hace nada: apunta a `mm_radio`, que no está instalado. Igual con `jammer` y `radiocell` | `txAdminRecipe/items.lua:208` |
| **Policía** | Sus papeleras nunca se crean, porque ox_inventory arranca antes que qbx_police | `qbx_police/server/main.lua:660` |
| **EMS** | Al reaparecer en el hospital se pierde todo el inventario, efectivo incluido (`wipeInvOnRespawn`) | `config/server.lua:3` |
| | Las heridas y el sangrado no se conservan al reconectar | código |
| **Empresas** | No tienen menú de jefe salvo las bandas lostmc y vagos | código |
| | Editar los rangos está desactivado (`qbx:enableGroupManagement false`) | cfg |
| | El cfg limita a 1 trabajo y 1 banda por personaje | cfg |
| **Concesionario** | Funciona en modo autoservicio; el concesionario con vendedor `cardealer` está comentado | código |
| **Mecánico** | El desgaste de las piezas no se guarda | código |
| **Teléfono** | El mercado borra los anuncios al desconectarse | código |
| | No hay app de banco | código |
| **Progreso** | El logro «Estuve ahí» es imposible: nadie llama a `event_join` | código |
| | «Temporada completa» pide 28 días y la temporada tiene 14 | código |
| **Trabajos propios** | El tope de dinero por hora se reinicia al reconectar | código |

### 3.5 Solo interfaz (🎨)

**Selección de personaje:**
- Las ranuras «Plus» bloqueadas.

**Panel:**
- **Eventos:** son tarjetas fijas; no te puedes apuntar.
- **Organizaciones:** solo muestra información; no se pueden crear ni gestionar.
- **Ayuda:** cita comandos que no coinciden con el chat (`/ooc` frente a `/b`).

**Pantalla de carga:**
- La «radio» y el carrusel de avisos son decorativos.

**HUD:**
- No muestra multas: no existe un dato de multas pendientes que enseñar.

### 3.6 No existe (⛔)

**Emergencias y justicia:**
- Bomberos
- MDT o expedientes policiales
- Juicios y abogados: los trabajos `judge` y `lawyer` existen, pero vacíos
- Multas pendientes y facturas
- Centralita de avisos

**Negocios:**
- Negocios de jugadores con stock, caja y empleados
- Concesionario gestionado por jugadores
- Inmobiliaria con comisión

**Crimen:**
- Territorios
- Drogas
- Lavado de dinero: el ítem `black_money` existe, pero nada lo usa
- Contrabando
- Robos con escenario: solo están los minijuegos

**Organizaciones:**
- Creadas por los propios jugadores, con nivel

**Personaje y vehículos:**
- Requisitos por nivel
- Certificaciones y autoescuela
- Muerte permanente (CK) con cementerio

**Otros:**
- Seguros
- Casino

### 3.7 Bloqueado (🔒)

| Qué | Por qué |
|---|---|
| **Cámara, galería y notas de voz del teléfono** | Necesitan un token de fivemanage, que es un servicio externo. Hace falta que el propietario decida si lo usa y si paga. |
| **Cobrar con el teléfono npwd** | Su licencia CC-BY-NC-SA prohíbe el uso comercial. Hay que revisarlo antes de vender nada con Tebex. |
| **Ventajas de pago (Plus/VIP)** | Las normas de Cfx/Tebex prohíben vender moneda virtual y cajas de botín. Las ventajas jugables de pago tienen riesgo. |
| **Crimen organizado** | Depende de organizaciones con nivel, de los requisitos por nivel y de zonas seguras, y nada de eso existe todavía. |
| **Negocios** | Depende de decidir las reglas de la economía: banco sin saldo negativo, nóminas pagadas desde la cuenta de la empresa y a dónde va el dinero de las ventas. |

---

## 4. Mapa de conexiones entre sistemas

```
                         ┌───────────── qbx_core (PERSONAJE: citizenid, charinfo, metadata, job/gang, money) ─────────────┐
                         │                                                                                                │
   pxd_multichar ──crea/carga──►│◄── pxd_progress (metadata pxd_progress)   pxd_interact (metadata pxd_id, pxd_known)          │
   qbx_spawn/qbx_properties ────┤◄── qbx_medical (isdead/inlaststand)        pxd_hud (stress)   pxd_admin (lee todo)          │
                         │                                                                                                │
   DINERO: money=ítem ox_inventory (cash) · bank en qbx_core · cuentas de empresa en Renewed-Banking                       │
        ├─ nóminas (de la nada)   ├─ multas/check-in → cuenta police/ambulance   ├─ tiendas/tuneo/casas → desaparece      │
   VEHÍCULOS: qbx_vehicleshop → qbx_vehicles(player_vehicles) → qbx_garages → qbx_vehiclekeys → ox_inventory(trunk/glovebox)│
   CASAS: qbx_properties(properties, keyholders, alijo ox_inventory, garaje qbx_garages, decoración) ← qbx_spawn            │
   EMPRESAS: jobs/gangs qbx_core ← qbx_management (contratar) ; fondos solo en Renewed-Banking                              │
   POLICÍA: qbx_police → (multa inmediata, sin registro) ; xt-prison (cárcel) ; qbx_radio(pma-voice)                        │
   TELÉFONO: npwd + qbx_npwd (número = charinfo.phone) ; apps: contactos/mensajes/llamadas/garaje(lista)/correo            │
   INTERFAZ: ox_lib (avisos, menús) · ox_target (mirilla) · ox_inventory · npwd · pxd_* (NUI propias) · chat del sistema   │
                         └────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Qué falta para que el estado del personaje sea uno solo:**
1. **Una sola fuente para cada dato.** Por ejemplo, el dinero: el banco no debería poder quedar en negativo y los pagos deberían ir a cuentas de destino.
2. **Registros persistentes.** Multas, expediente, facturas y nóminas.
3. **Un único sistema de avisos.** Hoy hay al menos seis.
4. **Un único sistema de interacción, o una regla clara de cuál se usa para qué.** Hoy conviven ox_target y la E de pxd_interact.
5. **Un único panel de administración.** Hoy hay tres: txAdmin, qbx_adminmenu y pxd_admin.

---

## 5. Duplicidades e incompatibilidades

| Tema | Quién choca | Riesgo |
|---|---|---|
| Cárcel | qbx_police y xt-prison | Comandos y eventos dobles |
| `/anuncio` | pxd_admin y pxd_chat (con permisos distintos) | Cuál gana depende del orden de arranque |
| `/susurrar` | pxd_voice (cliente) y pxd_chat (servidor) | Probablemente cambia la voz en vez de mandar el texto |
| Admin | txAdmin, qbx_adminmenu y pxd_admin; `/report` y `/soporte` | Confusión y permisos dispersos |
| Interacción | ox_target y pxd_interact (E) | Dos formas de interactuar |
| Avisos | ox_lib/qbx, pxd_interact, pxd_admin, pxd_gamemodes, pxd_props y pxd_panel | Aspecto y posición incoherentes |
| HUD de voz | interfaz de pma-voice (`voice_enableUi 1`) y pxd_hud | Información doble |
| Buckets | pxd_admin usa `SetPlayerRoutingBucket` directamente | Se salta Qbox y el lobby de modos de juego |
| Ropa | illenium, quitar prenda de pxd_inventory y `/duty` de pxd_admin | La ropa podría guardarse mal (sin verificar) |
| Teclas | LMENU (ox_target y radio), K (maletero y agacharse), H (manos arriba y llaves), B (señalar y cinturón), E (varias), F9 (soporte y radio del coche) | Acciones que se disparan a la vez |
| Reglamento | pxd_login, pxd_loadscreen y pxd_panel | Tres copias que se desincronizan |
| Despliegue | Receta (`latest`/`main`) frente a parches y overlays de versión exacta | Una instalación nueva puede romper la interfaz del inventario |

---

## 6. Comparativa funcional con GTAHUB

El detalle y las fuentes están en `docs/22-investigacion-sistemas.md`. Clave de la columna «Fuente»:
- **D** = documentado públicamente: reglas, foro o noticias, citados por fragmentos de búsqueda porque sus dominios no se pudieron abrir desde aquí.
- **C** = visto en capturas del propietario.
- **I** = inferido.

| Área | GTAHUB | Fuente | Próxima hoy |
|---|---|---|---|
| Economía y banco | Banco, HUBCoins y comercio en zonas permitidas | D/C | 🟠 Banco sí; el saldo puede quedar en negativo y no hay app en el teléfono |
| Inventario e interacción | Inventario con personaje y ranuras de ropa; interacción con E | C | 🟡 Inventario original funcionando; capa propia sin instalar; E sin instalar |
| Personaje, documentos y progresión | Nivel por XP u horas; requisitos por nivel; certificaciones; CK con cementerio | D/C | 🟠 Nivel y horas sí; sin requisitos, sin certificaciones, sin cementerio |
| Viviendas y muebles | Casas decorables; muebles por nivel; alquileres y moteles | D | 🟠 qbx_properties con decoración; sin catálogo de casas y alquiler con fallo |
| Empresas de jugadores | Empresas, foodtrucks y gestión | D | ⛔ |
| Policía, EMS, bomberos y justicia | Sanciones con artículos; cárcel con economía; heridas | D | 🟠 Policía y EMS básicos; sin bomberos, MDT ni justicia |
| Organizaciones y bandas | Creadas por jugadores, con nivel, advertencias y estado oficial | D | 🎨 Solo informativo |
| Territorios e ilegales | Graffiti y zonas; mercados negros rotativos; dealers; golpes por niveles | D (detalle I) | ⛔ |
| Vehículos y mecánica | Concesionarios; certificación para el limitador; taller con recargo | D/C | 🟡 Cadena completa en código; sin certificaciones |
| Teléfono | Apps de servicio: Taxi, Emergencias, Dynasty 8, Banco, Eventos | C | 🟡 npwd básico; apps propias sin integrar |
| Trabajos y ocio | Trabajos públicos con nivel por trabajo; eventos; casino | D | 🟡 Muchos trabajos; sin nivel por trabajo; modos de juego propios |
| Administración | F9 soporte y reportes; sanciones con historial «mi conducta» | D/C | 🟡 pxd_admin sin instalar; sin sanciones por artículo |

---

## 7. Sistemas que faltan

Agrupados por bloque y ordenados por dependencias:

- **Base de economía:**
  - banco sin saldo negativo;
  - nóminas pagadas desde la cuenta de la empresa;
  - destino del dinero de cada venta;
  - app de banco en el teléfono.
- **Registros:** multas pendientes, facturas, expediente y MDT, y sanciones con historial.
- **Empresas de jugadores:** caja, empleados, stock, precios, menú de jefe para todos los trabajos y nómina.
- **Organizaciones de jugadores:** con nivel, rangos, advertencias y estado oficial.
- **Requisitos por nivel y zonas seguras.**
- **Certificaciones:** autoescuela y limitador de velocidad.
- **Casas:** catálogo predefinido y alquiler que funcione.
- **Crimen reglado:** robo a jugadores, territorios, drogas, lavado de dinero y mercados negros.
- **Bomberos y justicia:** juicios y abogados.
- **CK con cementerio y cambio de nombre.**

---

## 8. Prioridad (dependencias e impacto)

| Fase | Contenido | Por qué |
|---|---|---|
| **P0 · Seguridad del despliegue** | Copia de seguridad y vuelta atrás en el actualizador; versiones fijas en receta, paquete y parches; respetar los `config` editados la primera vez | Hoy un `pxd_update` puede pisar archivos sin forma de deshacerlo |
| **P1 · Arreglar lo instalado** | Banco sin saldo negativo; ítem radio; papeleras de policía; cárcel duplicada; alquiler de casas; `/anuncio` y `/susurrar`; un solo sistema de avisos; decidir ox_target frente a E; un solo panel de admin | Son fallos que se notan al jugar |
| **P2 · Probar en el juego** | Recorrer el plan de pruebas de la sección 10 con lo instalado y lo pendiente (interact, voice, admin, inventory, chat) | Nada se marca como funcional sin evidencia |
| **P3 · Economía conectada** | Nóminas desde la empresa, multas y facturas con registro, app de banco, catálogo de casas | Es la base de empresas, crimen y teléfono |
| **P4 · Empresas y organizaciones** | Negocios de jugadores; organizaciones creadas por jugadores con nivel; menú de jefe para todos | Es el corazón de un servidor como GTAHUB |
| **P5 · Progresión que da acceso** | Requisitos por nivel, certificaciones, zonas seguras, CK con cementerio | Hace falta antes de abrir el crimen |
| **P6 · Crimen y facciones** | Robo reglado, territorios, drogas, lavado, mercados; bomberos y justicia | Depende de P3–P5 |
| **P7 · Capa visual** | Integrar tema de ox_lib/ox_target, teléfono y mapa (ya hechos en ramas) | Solo cuando lo de debajo funcione |

---

## 9. Propuesta de integración (sin perder lo hecho)

**Una sola fuente por dato:**

| Dato | Quién manda |
|---|---|
| Personaje | qbx_core |
| Dinero | qbx_core y Renewed-Banking |
| Vehículos | qbx_vehicles |
| Casas | qbx_properties |
| Trabajos | qbx_core (jobs/gangs) |
| Cárcel | xt-prison |
| Teléfono | npwd |
| Progreso | pxd_progress |
| ID público | pxd_interact |

Los recursos `pxd_*` leen y escriben solo a través de los exports de esos recursos, nunca con SQL directo. Única excepción: lecturas de solo consulta ya justificadas.

**Contratos que hay que definir antes de conectar** (exports, eventos, datos y permisos):
1. **Economía:** reglas de cobro (sin saldo negativo); quién paga y quién cobra en cada operación; registro de transacciones con Renewed-Banking (`handleTransaction`).
2. **Justicia:** tabla de multas con estado (pendiente, pagada, recurrida), expediente y artículos. Un evento `pxd:justice:fineIssued` que lean el teléfono, el HUD y el panel.
3. **Empresas:** cuenta de la empresa = cuenta de Renewed-Banking del trabajo; contratar con qbx_management; nómina con `paycheckSociety=true`; stock en un alijo de ox_inventory.
4. **Organizaciones:** grupo de qbx_core (gang o job) con metadatos de Próxima: nivel, advertencias y estado oficial.
5. **Interfaz:** una sola API de avisos para todos los pxd_* que use el estilo común, y una regla de interacción: ox_target para el mundo de Qbox y E para objetos del suelo y jugadores.
6. **Permisos:** una tabla única de permisos ACE (pxd.*) documentada.

**Coordinación de agentes:**
- Cada tarea tiene un dueño de archivos.
- Los archivos compartidos (cfg, plan, manifiesto, `run.lua`) solo los toca el integrador.
- El diseño visual va separado de la lógica.
- Nada de recursos nuevos sin un contrato aprobado.

**Lo que se conserva sin rehacer:**
- Todos los pxd_* actuales.
- Las capas visuales de inventario, ox_lib, teléfono y mapa.
- El sistema de diseño.

Solo se corrigen los choques de la sección 5.

---

## 10. Plan de pruebas en FiveM

Se recorre en un servidor de pruebas con 2 jugadores. En cada caso se guarda una captura o un registro de consola como evidencia, y se marca ✅ o ❌.

1. **Arranque:** consola limpia, sin SCRIPT ERROR; todos los recursos «Started»; `pxd_update check` responde «al día».
2. **Personaje:** conectar → pantalla de carga → nuestra selección → crear → apartamento → editor de ropa → ciudad. Reconectar y elegir dónde aparecer.
3. **Economía:** comprar en una tienda; ingresar y sacar en el banco; nómina estando de servicio; comprobar que el saldo no pasa de 0.
4. **Vehículos:** comprar → llaves → guardar en el garaje → reiniciar el servidor → sacarlo del garaje o del depósito → maletero con objetos → tuneo guardado.
5. **Casas:** crear una con `realestate` → comprarla → dar llave al otro jugador → alijo → decorar → aparecer en ella.
6. **Empresa:** contratar a alguien con qbx_management → ponerlo de servicio → nómina → cuenta de la empresa en el banco.
7. **Policía:** esposar → cachear → multar (ver el registro) → encarcelar con `/jail` → salir.
8. **EMS:** dejar a alguien en last stand → reanimarlo → check-in → reconectar estando muerto.
9. **Teléfono:** número, contactos, mensaje y llamada entre dos jugadores; correo; apps propias.
10. **Interfaz y teclas:** I, TAB, F9, F10, E, flecha arriba, N y J; que no salgan dos acciones a la vez.
11. **Persistencia:** reiniciar el servidor y comprobar dinero, inventario, nivel, horas, ID PROX, conocidos y vehículos.
12. **Carga:** con 10 jugadores simulados o reales, mirar el uso de CPU en el resmon de txAdmin.

---

## 11. Despliegue en Nodecraft con vuelta atrás

**Antes de cada despliegue:**
1. Copia del servidor en Nodecraft (*Files & Backups → Backups*).
2. Copia de la base de datos (*Database*, exportar).
3. Anotar el commit que está instalado.

**Despliegue:**
4. Versión etiquetada en GitHub. `set pxd_updater_ref "<etiqueta>"` en el cfg, para no seguir la rama en movimiento.
5. Ventana de mantenimiento sin jugadores: `pxd_update check` → `pxd_update` → reiniciar.

**Vuelta atrás si algo falla:**
6. Restaurar la copia de Nodecraft y la de la base de datos.
7. O volver a la etiqueta anterior con `pxd_updater_ref`.

**Mejoras necesarias (P0):**
- El actualizador debe guardar una copia de cada archivo antes de escribirlo, en `pxd_updater/data/backup/<fecha>/`.
- Hay que añadir un `pxd_update rollback`.

**Entorno de pruebas:**
- La carpeta `servers/default` de Nodecraft, o un segundo servidor, con su propia base de datos de prueba.
- Nada llega a producción sin pasar el plan de pruebas.
