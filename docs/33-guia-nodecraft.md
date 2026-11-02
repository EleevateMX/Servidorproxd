# 33. Guía paso a paso: instalación de prueba en Nodecraft (fases 0 y 1)

- **Paquete:** `proxima-fase-0-1-228b90f.zip` (recursos del commit `228b90f`; `proxima.cfg` añadido después). Está verificado: es idéntico al commit `228b90f9dc33…` (181 archivos), trae los 18 recursos pxd_*, `permissions.pxd.cfg` y `proxima.cfg`, y no lleva datos persistentes; en las carpetas `data/` solo hay archivos `.gitkeep` vacíos.
- **Tipo de instalación:** **de prueba**, sin jugadores. No es para uso público.
- **Si te detienes:** en cada «🛑 DETENTE» no sigas. Copia la consola o haz una captura y mándamela.

---

## Paso 0 · Preparación (10 min)

1. Anuncia el mantenimiento y espera a que no quede nadie conectado. **Deberías ver:** 0 jugadores en txAdmin.
2. **Nodecraft → Files & Backups → Backups:** crea una copia completa. **Deberías ver:** la copia en la lista, con la fecha de hoy. Apunta su nombre.
   - 🛑 DETENTE si la copia falla o no aparece.
3. **Nodecraft → Database:** exporta la base de datos y descarga el `.sql` a tu PC. **Deberías ver:** un archivo `.sql` de más de 0 KB.
   - 🛑 DETENTE si no puedes exportar.
4. **txAdmin → CFG Editor:** selecciona todo, copia y pégalo en un `.txt` de tu PC (`server-cfg-antes.txt`).
5. ¿Editaste a mano algún `config.lua` de un recurso `pxd_*`? Si es así, descárgalo ahora: el paquete lo sobrescribe.

## Paso 1 · Subir el paquete (5 min)

1. **Archivos →** `servers/PrxmaRPQbox_E83FED.base` → **Upload** → `proxima-fase-0-1-228b90f.zip`.
2. Descomprímelo en esa misma carpeta y acepta sobrescribir.
3. Comprueba:
   - `resources/[proxima]` tiene **18 carpetas** (entre ellas `pxd_compat` y `pxd_justice`);
   - junto al `server.cfg` está `permissions.pxd.cfg` con fecha de hoy;
   - junto al `server.cfg` está `proxima.cfg`;
   - existe `PROXIMA_VERSION.txt` y dice `228b90f`.
   - 🛑 DETENTE si faltan carpetas o los archivos quedaron dentro de otra subcarpeta.
4. Borra el `.zip`.

## Paso 2 · server.cfg: una sola línea (2 min)

El paquete trae `proxima.cfg` con todos los ajustes (teclas, voz, chat, idioma de la ropa, versión fijada del actualizador).

En **CFG Editor**, añade como **última línea** del archivo:
```cfg
exec proxima.cfg
```
Al ir al final, sus valores mandan sobre los anteriores (por ejemplo, el antiguo `inventory:keys ["F2", "K", "F1"]`). No hace falta borrar nada más.

Opcional, solo para limpiar avisos: quita `ensure [assets]` (la carpeta no existe). La lista completa de cambios está en `docs/32` §4, por si prefieres editarlo a mano.

Guarda. **Deberías ver:** «Saved» sin avisos del validador.
- 🛑 DETENTE si el validador marca un error.

## Paso 3 · Primer reinicio (5 min)

**Reinicia** el servidor y mira la **Live Console** hasta que termine de arrancar.

**Deberías ver:**
- arrancan los pxd_* que ya tenías: loadscreen, login, props, gamemodes, updater, progress, restart, jobs, panel, multichar y hud. Ya llevan el código nuevo;
- `pxd_hud sustituye a qbx_hud: qbx_hud detenido.`

**Normal en este paso:** los **recursos nuevos todavía no arrancan** (pxd_compat, pxd_justice, pxd_interact, pxd_voice, pxd_admin, pxd_inventory, pxd_chat). El actualizador aún tiene guardada la lista de arranque anterior; se actualiza en el paso 4.

Avisos que ya existían y no importan:
- `Couldn't find resource category [assets]` (ya no debería salir);
- `could not load locales/es.json`;
- `Table 'properties'…`.

- 🛑 DETENTE si aparece cualquier `SCRIPT ERROR` en un recurso `pxd_*`, `qbx_*` u `ox_*`, o si un pxd_* no arranca.

## Paso 4 · Aplicar los arreglos de terceros (5 min)

1. Live Console: `pxd_update check`. **Deberías ver:** los archivos al día, la lista de **parches pendientes** y que no hay archivos bloqueados.
   - 🛑 DETENTE si dice que hay archivos pxd_* por actualizar: el paquete no coincide con la versión fijada.
2. Live Console: `pxd_update`. **Deberías ver:**
   - «Ajustado qbx_core/config/server.lua…»;
   - lo mismo para qbx_properties, qbx_police, ox_inventory/data/items.lua, qbx_ambulancejob y qbx_smallresources;
   - una copia de seguridad creada.
   - 🛑 DETENTE si sale «no encuentra el texto», «falta el permiso» o «No se pudo escribir».
   - Además: «Iniciado pxd_compat / pxd_justice / pxd_interact / pxd_voice / pxd_admin / pxd_inventory / pxd_chat».
3. Live Console: `pxd_update backups`. **Deberías ver:** al menos una copia «aplicada». **Apunta su id.**
4. **Reinicia** otra vez. **Deberías ver:**
   - los **18** pxd_* arrancados;
   - `pxd_justice`: tablas `pxd_fines` y `pxd_fine_events` listas;
   - ningún aviso de `wipeInvOnRespawn` ni ningún SCRIPT ERROR.
   - 🛑 DETENTE si falta algún pxd_* o aparece un SCRIPT ERROR.

## Paso 5 · Pruebas en el juego (40–60 min, idealmente con 2 jugadores)

Recorre las 23 pruebas de `docs/32` §5. Primero estas:

| Orden | Prueba | ✔ si… | 🛑 si… |
|---|---|---|---|
| 1 | **I** inventario | Se abre y se cierra con I; F2 no hace nada | No abre, o se abren dos inventarios |
| 2 | **Ctrl izq.** agacharse | Se agacha y se levanta; el otro jugador lo ve; K no hace nada | Queda bloqueado agachado o en sigilo |
| 3 | **E** maletero | Detrás de tu coche: «E · Abrir maletero» → abre el maletero | Abre otro menú, o lo abre con el coche cerrado |
| 4 | **B** recoger | Uno tira un agua y el otro pulsa B → pasa a su inventario | Se duplica, o desaparece sin llegar |
| 5 | **B a la vez** | Los dos pulsan B sobre el mismo objeto | Lo reciben los dos |
| 6 | **Multa y pago parcial** | Pendiente → pagar una parte → «parcial» → pagar el resto → «pagada» | Se cobra dos veces, o el saldo baja de 0 |
| 7 | **EMS reanima** | No pierde nada | Pierde objetos |
| 8 | **Reaparecer en el hospital** | Conserva efectivo, DNI, teléfono y agua; pierde el arma; aviso de lo retirado | Pierde efectivo o documentos |
| 9 | **Reinicio** | Tras reiniciar: dinero, inventario, nivel, multas y vehículos intactos | Falta algo |
| 10 | **Consola** | Sin SCRIPT ERROR durante todas las pruebas | Cualquier SCRIPT ERROR |

**Evidencia de cada prueba:** una captura en el juego y la línea de consola correspondiente. Mándamelas: yo marco la prueba como «probada» solo con evidencia.

## Si algo sale mal: volver atrás

| Situación | Qué hacer |
|---|---|
| Falla un arreglo de terceros (paso 4) | `pxd_update rollback <id del paso 4.3>` → reiniciar |
| Falla algo de Próxima tras el paso 3 | Restaura la copia de Nodecraft del paso 0.2 → reiniciar |
| Datos dañados (dinero, inventarios) | 🛑 No hagas nada más y avísame. Restaurar la base de datos (dump del paso 0.3) solo con autorización |
| El cfg da problemas | Pega `server-cfg-antes.txt` en CFG Editor → reiniciar |

Las tablas nuevas `pxd_fines` y `pxd_fine_events` no afectan a nada más; pueden quedarse aunque vuelvas atrás.
