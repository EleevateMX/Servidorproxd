# 37. Centro de administración (`pxd_admin` 0.2.0)

**Estado:** implementado y con pruebas automáticas (32 en Lua). No instalado en Nodecraft ni probado en FiveM.

## Por qué «no se encontraba»

1. **El panel no existía en el servidor hasta hoy.** `pxd_admin` llegó con el paquete 228b90f y no arrancó hasta el `pxd_update` del 2 de noviembre.
2. **`/admin` y `/noclip` eran de qbx_adminmenu.** `/admin` abría su menú de ox_lib, en inglés y distinto del nuestro. El nuestro solo se abría con F10.
3. **Casi todo pedía `/duty` antes.** Sin servicio, cada botón respondía «Activa el modo servicio», y el panel parecía no funcionar.
4. **Teclas guardadas.** FiveM guarda la tecla de cada comando la primera vez. El panel ahora usa un comando nuevo, `pxd_panel_admin` (F10), para no heredar asignaciones antiguas de `staff`.
5. **Permisos.** Solo veía el panel quien tenía `pxd.admin`, y `group.admin` lo tiene. El dueño entra en `group.admin` por la línea de txAdmin `{{addPrincipalsMaster}}`, con su identificador `fivem:`.
   - Si alguien no lo ve, en la consola: `pxd_admin_permisos <id>` dice qué rol y qué permisos tiene.
   - Sin permiso, `/admin` explica qué falta.

## Acceso

| Tecla o comando | Qué hace |
|---|---|
| **F10** o **`/admin`** | Centro de administración |
| **`/noclip`** (o `/volar`) | Vuelo de staff |
| **F9** | Soporte y reportes, igual que antes |
| `/qbxadmin` | Menú de Qbox, también accesible desde Mundo → Herramientas |

## Roles (ACE `pxd.admin.<permiso>`)

Los ACE de FXServer son **jerárquicos**: quien tiene `pxd.admin` tiene también `pxd.admin.kick`. Por eso ningún rol recibe `pxd.admin` a secas.

**Herencia:** superadministrador → administrador → moderador → soporte. Desarrollador es un rol aparte.

| Permiso | Sop. | Mod. | Admin | Superadmin | Dev |
|---|---|---|---|---|---|
| panel, reportes, ir/volver, traer, curar, mensajes | ✔ | ✔ | ✔ | ✔ | panel e ir |
| espectar, congelar, expulsar, advertir, identidad, noclip, anuncios, registro, gestionar vehículos | | ✔ | ✔ | ✔ | noclip y vehículos |
| banear, sacar vehículos, mundo, editor de props, economía (ver), menú Qbox | | | ✔ | ✔ | sacar vehículos, mundo y props |
| IP, titularidad de vehículos, corrección de dinero | | | | ✔ | |

**Grupos:**
- `group.support`, `group.mod` y `group.admin` ya existen en la receta de Qbox (`permissions.cfg`, con herencia admin → mod → support).
- `group.superadmin` y `group.dev` son nuevos.

## Cada acción, en el servidor

1. Se comprueba el permiso, sin importar lo que diga el cliente.
2. Se validan los tipos y el objetivo.
3. Las acciones sensibles exigen un **motivo de 3 a 200 caracteres**: espectar, expulsar, advertir, banear, levantar un baneo, corregir dinero y cambiar la titularidad.
4. Se registra en `pxd_audit` con categoría `admin`: responsable (licencia y nombre), objetivo (licencia, `vehicle:<matrícula>` o `ban:<id>`), fecha y motivo.
   - También queda en `data/staff-log.json`, que sirve de respaldo si `pxd_audit` no está.
   - El objetivo se anota antes de actuar: tras expulsar ya no hay identificadores.
5. Los eventos manipulados sin permiso no hacen nada ni dejan registro.

**Baneos:**
- Se guardan en la tabla `bans` de qbx_core, la misma que usa qbx_adminmenu y la que qbx_core comprueba al conectar.
- **Levantar un baneo** adelanta su fin; no borra la fila.
- Los baneos de txAdmin siguen en su web.

**Dinero:**
- Usa `AddMoney` y `RemoveMoney` de Qbox con el motivo `pxd-admin: …`, así que pxd_economy lo ve.
- Nunca deja saldo negativo.
- Máximo  000 000 por corrección.

**Noclip:**
- **Teclas:** W/A/S/D, Espacio sube, X baja, Shift va rápido y la rueda del ratón cambia la velocidad.
- Invisible para los demás (configurable); uno mismo se ve semitransparente.
- **Al salir restaura** la colisión, la visibilidad y la invencibilidad que había, y el congelado si lo puso el staff (state bag `pxd_frozen`).
- **Registro:** al activarlo, al desactivarlo y al desconectarse.

## Cambios en `permissions.pxd.cfg`

**Quitar** estas dos líneas: darían todos los permisos a `group.admin`.
```
add_ace group.admin pxd.admin allow
add_ace group.admin pxd.admin.all allow
```
**Añadir:**
```
# Centro de administración (docs/37): roles con herencia y permisos pxd.admin.<permiso>
add_ace group.support pxd.admin.panel allow
add_ace group.support pxd.admin.reports allow
add_ace group.support pxd.admin.players.goto allow
add_ace group.support pxd.admin.players.bring allow
add_ace group.support pxd.admin.players.heal allow
add_ace group.support pxd.admin.players.message allow
add_principal group.mod group.support
add_ace group.mod pxd.admin.players.spectate allow
add_ace group.mod pxd.admin.players.freeze allow
add_ace group.mod pxd.admin.players.kick allow
add_ace group.mod pxd.admin.players.warn allow
add_ace group.mod pxd.admin.players.identity allow
add_ace group.mod pxd.admin.noclip allow
add_ace group.mod pxd.admin.announce allow
add_ace group.mod pxd.admin.audit allow
add_ace group.mod pxd.admin.vehicles.manage allow
add_principal group.admin group.mod
add_ace group.admin pxd.admin.players.ban allow
add_ace group.admin pxd.admin.vehicles.spawn allow
add_ace group.admin pxd.admin.world allow
add_ace group.admin pxd.admin.props allow
add_ace group.admin pxd.admin.economy.view allow
add_ace group.admin pxd.admin.qbxmenu allow
add_principal group.superadmin group.admin
add_ace group.superadmin pxd.admin.players.ip allow
add_ace group.superadmin pxd.admin.vehicles.owner allow
add_ace group.superadmin pxd.admin.economy.correct allow
add_ace group.dev pxd.admin.panel allow
add_ace group.dev pxd.admin.players.goto allow
add_ace group.dev pxd.admin.noclip allow
add_ace group.dev pxd.admin.vehicles.spawn allow
add_ace group.dev pxd.admin.vehicles.manage allow
add_ace group.dev pxd.admin.world allow
add_ace group.dev pxd.admin.props allow
add_ace group.dev pxd.props.edit allow
# El dueño como superadministrador (cambia por tu identificador; lo ves con pxd_admin_permisos):
# add_principal identifier.fivem:TU_ID group.superadmin
```

## Parche de qbx_adminmenu (v0.1.0)

Libera `/admin` y `/noclip`. Su menú queda en `/qbxadmin` y en el panel.

| Archivo `server/commands.lua` | Busca | Cambia por |
|---|---|---|
| | `lib.addCommand('admin', {` | `lib.addCommand('qbxadmin', { -- Próxima: /admin abre el panel de pxd_admin` |
| | `lib.addCommand('noclip', {` | `lib.addCommand('qbxnoclip', { -- Próxima: /noclip es el de pxd_admin` |

Las dos búsquedas aparecen una sola vez en la fuente fijada, y el archivo resultante compila.

## Pendiente de comprobar en FiveM

- F10 y `/admin` abren el panel con una cuenta de cada rol. Usa `pxd_admin_permisos <id>` para revisar los permisos.
- Noclip: movimiento, velocidad, invisibilidad y que el personaje quede como antes, también dentro de un vehículo.
- Espectar y salir con F10.
- Advertencia en pantalla del jugador.
- Expulsar y banear (con reconexión rechazada por qbx_core); levantar el baneo.
- Corrección de dinero y su reflejo en `/economia`.
- Información y titularidad de un vehículo.
- Botón «Copiar» de coordenadas en el NUI de FiveM.
- «Datos en pantalla», editor de props y menú Qbox desde el panel.
