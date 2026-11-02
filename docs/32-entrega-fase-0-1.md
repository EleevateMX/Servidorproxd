# 32. Entrega de las fases 0 y 1 a Nodecraft

**Versión:** `228b90f9dc334b62fcf69e2c83c7e752cf4256d4`.
**Paquete:** `proxima-fase-0-1-228b90f.zip`, que contiene `resources/[proxima]/` (18 recursos), `permissions.pxd.cfg` y `PROXIMA_VERSION.txt`.
**Estado:** preparada y **pendiente de autorización**. No se ha desplegado nada.

## 1. Estado de cada parte

**Columnas:**
1. Código implementado.
2. Pruebas automáticas aprobadas.
3. Instalado en Nodecraft.
4. Probado de verdad dentro de FiveM.
5. Listo para uso público.

| Parte | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Copias de seguridad, vuelta atrás y configs protegidas (pxd_updater 0.2.0) | ✔ | ✔ | ✖ | ✖ | ✖ |
| Versiones fijas (receta) | ✔ | ✔ | n/a (solo instalación nueva) | — | — |
| Banco sin saldo negativo, alquiler, cárcel única, papeleras, radio | ✔ | ✔ (texto comprobado en las versiones fijas) | ✖ | ✖ | ✖ |
| Desgaste de vehículos (pxd_compat) | ✔ | ✔ | ✖ | ✖ | ✖ |
| Hospital: reanimar no quita nada; reaparecer retira solo armas e ilegales | ✔ | ✔ | ✖ | ✖ | ✖ |
| Multas y deudas (pxd_justice, pestaña Multas, aviso en el HUD) | ✔ | ✔ | ✖ | ✖ | ✖ |
| Controles: I, Ctrl, E (maletero) y B (recoger) | ✔ | ✔ | ✖ | ✖ | ✖ |
| Arreglos P1 de pxd_* (comandos, estrés, topes, modos de juego, admin, progreso) | ✔ | ✔ | ✖ | ✖ | ✖ |
| Interacción con E e ID PROX, voz, admin F9/F10, inventario I, chat, rediseños | ✔ | ✔ | ✖ | ✖ | ✖ |

**Pruebas automáticas:** 295 en Lua y 48 en Node, todas sobre un FXServer simulado. **Ninguna** cuenta como prueba en el juego.

## 2. Antes de empezar: copias

Procedimiento detallado en `docs/27-respaldo-y-restauracion.md`.

1. **Sin jugadores conectados.** Anuncia el mantenimiento.
2. **Nodecraft → Files & Backups → Backups:** crea una copia completa del servidor y apunta su nombre.
3. **Nodecraft → Database:** exporta la base de datos (dump SQL) y guárdala fuera del servidor.
4. **Copia el `server.cfg` actual:** en CFG Editor, selecciona todo, copia y guárdalo en tu PC.
5. **Anota la versión instalada:** el commit del último paquete o `pxd_update check`.

## 3. Instalación

1. **Sube el paquete.** Archivos → `PrxmaRPQbox_E83FED.base` → sube `proxima-fase-0-1-228b90f.zip` y descomprímelo ahí. Sobrescribe:
   - `resources/[proxima]/…`;
   - `permissions.pxd.cfg`, junto al `server.cfg`.

   No toca las carpetas `data/`: props, jugadores, progreso, auditoría y multas.
2. **CFG Editor.** Añade `exec proxima.cfg` como última línea (sección 4) y guarda.
3. **Reinicia el servidor.** Arrancan los pxd_* que ya tenías, con el código nuevo. Los nuevos se inician en el paso 5. Guía detallada con resultados esperados y cuándo detenerse: `docs/33-guia-nodecraft.md`.
4. **Live Console:** `pxd_update check`.
   - Los archivos pxd_* deben estar «al día», porque el paquete es la misma versión.
   - Verás la lista de **parches pendientes** en recursos de terceros.
5. **Live Console:** `pxd_update`.
   - Aplica los parches **con copia de seguridad**.
   - Si alguno dice «no encuentra el texto» (versión distinta), **para y mándame la consola**.
6. **Reinicia otra vez** para que los parches de terceros surtan efecto.
7. **`pxd_update backups`:** debe aparecer la copia de los parches. Anota su id: con él se vuelve atrás.

## 4. Cambios exactos en el `server.cfg` (CFG Editor)

**Forma corta (recomendada):** añade `exec proxima.cfg` como última línea. `server-data/proxima.cfg` contiene todos los ajustes de abajo y, al ir al final, manda sobre los anteriores. Lo que sigue es la forma manual equivalente.

Parten del cfg que pegaste en esta conversación. En el texto de abajo no repito ninguna clave secreta.

**Cambiar:**
```cfg
setr illenium-appearance:locale "es-ES"
```
Antes ponía `"en"`.

**Quitar:**
- `ensure [assets]`: la carpeta no existe.
- `setr qbx:motd "…"`: la bienvenida la da pxd_chat, una vez.
- `set qbx_chat:joinMessage "…"` y `set qbx_chat:quitMessage "…"`: no hacen nada.
- `setr inventory:keys ["F2", "K", "F1"]`: lo sustituye el bloque de más abajo.
- Al final del archivo, las líneas `add_ace resource.pxd_updater …`, `add_ace group.admin pxd.update allow` y `add_ace group.admin pxd.jobs.edit allow`. Ya vienen en el nuevo `permissions.pxd.cfg`; dejarlas repetidas no rompe nada.

**Añadir justo debajo de `exec voice.cfg`:**
```cfg
# Próxima: la radio se habla con Bloq Mayús (Alt la usa la mirilla de ox_target)
setr voice_defaultRadio "CAPITAL"
# El modo de voz ya lo muestra pxd_hud
setr voice_enableUi 0
```

**Añadir justo debajo de `exec ox.cfg`:**
```cfg
# TAB panel · I inventario · E maletero e interacción · B recoger del suelo · F1 barra rápida (docs/28)
setr inventory:keys ["I", "", "F1"]
setr scully_emotemenu:stanceKey ""
setr scully_emotemenu:pointKey ""
setr inventory:screenblur false
```

**Añadir debajo de las líneas de chat del principio:**
```cfg
set chat_showJoins 0
set chat_showQuits 0
```

**Recomendado: fijar la versión que descarga el actualizador**, para que no se aplique nada nuevo sin revisar:
```cfg
set pxd_updater_ref "228b90f9dc334b62fcf69e2c83c7e752cf4256d4"
```

**Opcional:** `sv_enforceGameBuild 3751`, si aún no lo cambiaste.

**Permisos:** el nuevo `permissions.pxd.cfg` del paquete ya incluye:
- `add_filesystem_permission pxd_updater write …` para todos los pxd_* y para qbx_core, qbx_police, qbx_properties, qbx_ambulancejob, qbx_smallresources, ox_inventory, npwd e illenium-appearance;
- las ACE de staff, actualizador, trabajos y multas.

El cfg ya lo carga con `exec permissions.pxd.cfg`.

## 5. Pruebas dentro de FiveM (checklist)

Para cada prueba, apunta el resultado (✔/✖) y guarda una captura o la línea de consola como evidencia.

| # | Escenario | Acciones | Resultado esperado |
|---|---|---|---|
| 1 | Arranque | Reiniciar y leer la consola | Sin SCRIPT ERROR; pxd_* iniciados; parches aplicados |
| 2 | Conexión | Entrar al servidor | Pantalla de carga → selección de personaje de Próxima |
| 3 | Crear personaje | Datos → apartamento → ropa (en español, solo freemode) → ciudad | Sin pantallas superpuestas ni pantalla negra |
| 4 | Aparición | Reconectar → «Elige dónde empezar» | Apareces donde eliges |
| 5 | Inventario | Pulsar I (y F2) | I lo abre y lo cierra; F2 no hace nada; inventario con nuestro diseño |
| 6 | Agacharse | Ctrl izquierdo dos veces; K | Se agacha y se levanta; K no hace nada; otro jugador lo ve |
| 7 | Maletero | Ir a la parte trasera de tu coche con llaves → E | «E · Abrir maletero» → se abre el maletero directamente |
| 8 | Maletero cerrado | Coche ajeno cerrado → E | «Maletero cerrado»; no se abre |
| 9 | Recoger | Tirar un agua; otro jugador se acerca → B | «B · Recoger…» → pasa a su inventario sin abrir menús; dos a la vez no duplican |
| 10 | Banco sin saldo negativo | Comprar algo caro sin fondos (casa o tuneo) | Se rechaza; el saldo no baja de 0 |
| 11 | Multa con fondos | Un policía de servicio usa `/fine` | Multa **pendiente**; aviso al multado; HUD «Multas: $X» |
| 12 | Pagar multa | TAB → Multas → pagar parcial y luego el resto | Se descuenta; estado parcial y luego pagada; el dinero va a la cuenta `police` |
| 13 | Multa sin fondos | Multar a alguien sin saldo | Queda como deuda; no se cobra nada |
| 14 | Reanimación | Dejar KO a alguien → EMS reanima | No pierde nada |
| 15 | Reaparición | Morir con arma, agua, DNI y efectivo → reaparecer en el hospital | Conserva el efectivo, el DNI y el agua; pierde el arma; aviso de lo retirado |
| 16 | Cárcel | Policía: `/jail` | Un solo sistema (xt-prison) |
| 17 | Radio | Usar el ítem radio; hablar con Bloq Mayús | Se abre la radio de Qbox; Alt sigue siendo la mirilla |
| 18 | Alquiler | Alquilar una casa | Se cobra desde ese momento |
| 19 | Vehículo | Romper piezas → aparcar → reiniciar → sacar | Se conserva el desgaste |
| 20 | Voz | N, doble N, J | Normal, grito y susurro; el HUD lo muestra |
| 21 | Chat | Escribir; `/me`; `/susurrar`; `/b`; `/anuncio` (staff) | Proximidad correcta; sin «joined»; un solo `/anuncio` |
| 22 | Admin | F9 (reporte) y F10 (staff), `/duty`, `/ir` | Reporte recibido; etiqueta STAFF; comandos funcionan |
| 23 | Persistencia | Reiniciar el servidor | Dinero, inventario, nivel, horas, ID PROX, multas y vehículos intactos |

## 6. Vuelta atrás

Del más leve al más completo:

1. **Un parche o archivo concreto:** `pxd_update backups` → `pxd_update rollback <id>` → reiniciar. Solo restaura los archivos que nadie ha cambiado desde entonces; para forzarlo, `pxd_update rollback <id> force`.
2. **Todo Próxima:** vuelve a descomprimir el paquete anterior que tengas, o restaura la copia de Nodecraft del paso 2 y reinicia.
3. **Base de datos:** importa el dump del paso 2.
   - Las tablas nuevas `pxd_fines` y `pxd_fine_events` pueden quedarse: nada más las usa.
4. **server.cfg:** pega la copia del paso 2.4.

Si algo falla, manda la consola completa desde el arranque.
