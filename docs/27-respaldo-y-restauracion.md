# 27. Copias de seguridad y restauración (Nodecraft + MariaDB)

Objetivo: que cualquier cambio en producción se pueda deshacer. Hay **tres capas** de copia, de menor a mayor alcance:

| Capa | Qué protege | Cómo se hace | Cómo se vuelve atrás |
|---|---|---|---|
| 1. Copias de `pxd_updater` | Los archivos que escribe `pxd_update` (recursos `pxd_*`, ajustes y capas en terceros) | Automático en cada `pxd_update` (`pxd_updater/data/bk_*`) | `pxd_update rollback [id]` (docs/07) |
| 2. Copia del servidor en Nodecraft | Todos los archivos del servidor (recursos, cfg, `data/` de los recursos) | Panel de Nodecraft → *Files & Backups → Backups* | Restaurar esa copia desde el mismo panel |
| 3. Copia de la base de datos | Personajes, dinero, inventarios, vehículos, casas, teléfono… (MariaDB) | Exportación de la base de datos (abajo) | Importar la exportación |

La capa 1 **no** cubre la base de datos ni los archivos `data/*.json` de los recursos (Plus, ID PROX, reportes, props…): esos van en las capas 2 y 3.

> **No verificado:** las pantallas exactas de Nodecraft para crear, descargar y restaurar copias y para exportar o importar la base de datos. Lo que sí consta (captura del panel) es que existen las secciones *Files & Backups → Backups* y *Database*. Sigue los textos de esas pantallas; si algo no coincide con esta guía, manda una captura.

## Datos importantes fuera de la base de datos

Están en el disco y solo los protege la copia del servidor (capa 2):

- `resources/[proxima]/pxd_progress/data/plus.json`: Plus comprado (por licencia). **Crítico**: lo que se ha pagado.
- `resources/[proxima]/pxd_interact/data/ids.json`: índice de IDs `PROX-XXXX`, para que no se repitan.
- `resources/[proxima]/pxd_admin/data/reports.json` y `staff-log.json`: reportes y registro del staff.
- `resources/[proxima]/pxd_props/data/layouts.json`: escenarios y anclas.
- `resources/[proxima]/pxd_login/data/players.json`, `pxd_jobs/data/points.json`.
- `resources/[proxima]/pxd_updater/data/`: estado instalado y copias de la capa 1.
- `server.cfg`, `permissions*.cfg` y `ox.cfg`/`voice.cfg`: configuración del servidor (con secretos: no se suben a git ni al chat).

## Copia de la base de datos (MariaDB)

Elige una vía según el acceso que tengas:

1. **Desde el panel de Nodecraft** (*Database*): si ofrece «exportar/descargar», descarga el `.sql` y guárdalo con la fecha en el nombre (`proxima-AAAA-MM-DD-HHMM.sql`). *(Por verificar: si Nodecraft ofrece exportación y su formato.)*
2. **Con un cliente de escritorio** (HeidiSQL, DBeaver, MySQL Workbench), si la base de datos acepta conexiones externas. Los datos de conexión están en la cadena `mysql_connection_string` del `server.cfg` (usuario, contraseña, host y nombre). Usa «exportar base de datos como SQL» con estructura y datos. *(Por verificar: si el host de MariaDB de Nodecraft acepta conexiones desde fuera.)*
3. **Con `mysqldump`** desde un equipo con acceso:
   ```bash
   mysqldump --single-transaction --routines --triggers -h <host> -u <usuario> -p <base_de_datos> > proxima-AAAA-MM-DD.sql
   ```
   Pide la contraseña sin dejarla en el historial. `--single-transaction` hace una copia coherente sin bloquear las tablas.

Buenas prácticas:
- Haz la copia **con el servidor parado** o en un momento sin jugadores, para que no haya escrituras a mitad.
- Guarda al menos las 3 últimas y una semanal. Nunca las subas a git ni las compartas: contienen datos de jugadores.
- **Comprueba que la copia sirve:** abre el `.sql` y busca, por ejemplo, `CREATE TABLE` de `players`, `player_vehicles` y `properties`. Lo ideal es restaurarla de vez en cuando en una base de datos de pruebas.

## Restaurar

Orden recomendado (de más a menos alcance):

1. **Para el servidor** (txAdmin → Stop). Avisa a los jugadores antes.
2. **Base de datos:** importa el `.sql` en una base de datos **vacía** o sobre la actual (el `.sql` de `mysqldump` incluye `DROP TABLE IF EXISTS`, así que reemplaza las tablas). Si no estás seguro, importa primero en una base de datos de prueba.
3. **Archivos:** restaura la copia de Nodecraft (*Backups*) del mismo momento que la base de datos. Personajes y archivos `data/*.json` deben ser de la misma fecha para que no haya incoherencias (p. ej. Plus o IDs de personajes que ya no existen).
4. Arranca el servidor y revisa la consola: sin `SCRIPT ERROR`, base de datos conectada.
5. Ejecuta `pxd_update check` para ver que el actualizador está coherente (no apliques nada hasta revisar).

Si solo falló una actualización de `pxd_*` (sin tocar la base de datos), basta con `pxd_update rollback` y reiniciar.

## Checklist antes de cada despliegue a producción

- [ ] El cambio se ha probado en el servidor de pruebas con el plan de pruebas (sección 10 del diagnóstico) y hay evidencia (capturas o consola).
- [ ] Commit o etiqueta concretos decididos para `pxd_updater_ref` (docs/07, «Versión fija»).
- [ ] Copia del servidor en Nodecraft hecha y anotada (fecha y nombre).
- [ ] Copia de la base de datos hecha, con el nombre fechado, y comprobada.
- [ ] Anotados: commit instalado ahora, commit nuevo y las líneas de cfg que cambian.
- [ ] Ventana sin jugadores y aviso previo (pxd_restart avisa de los reinicios programados de txAdmin).
- [ ] `pxd_update check` revisado: archivos, ajustes de terceros, editables protegidos.
- [ ] Tras aplicar: consola limpia y las pruebas rápidas del plan (conectar, crear o cargar personaje, inventario, TAB, teléfono).

## Cómo volver atrás (resumen)

| Situación | Acción |
|---|---|
| Falló una actualización de `pxd_*` o un ajuste de terceros | `pxd_update rollback` (o `rollback <id>`) → reiniciar |
| La versión nueva tiene fallos pero los datos están bien | `set pxd_updater_ref "<commit anterior>"` → reiniciar → `pxd_update force` → reiniciar |
| Se corrompieron datos (dinero, inventarios, vehículos…) | Parar → restaurar la base de datos y la copia de Nodecraft del mismo momento → arrancar |
| No arranca el servidor | Restaurar la copia de Nodecraft; revisar la consola; si hace falta, la base de datos |
