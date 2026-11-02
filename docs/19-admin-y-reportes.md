# 19. Soporte, reportes y panel de staff (`pxd_admin`)

## Para todos: F9 · Soporte

- **Pedir ayuda:** atascado, fallo o duda. Eliges categoría y lo cuentas.
- **Reportar a alguien:** por su **ID de servidor** o su **PROX-ID** (si `pxd_interact` está instalado, el PROX-ID sale de la metadata `pxd_id`).
- **Mis reportes:** estado (Nuevo, En curso, Cerrado), respuestas del staff y puedes contestar.
- Límites: 3 reportes cada 10 minutos, 3 abiertos a la vez y 6 respuestas por minuto (`config.lua`).
- Las respuestas del staff llegan como aviso en pantalla aunque el panel esté cerrado.

## Staff: F10 · Panel de staff

Solo con el ACE `pxd.admin`. Si un miembro del staff pulsa F9, ve el botón «Panel de staff».

| Vista | Qué hay |
|---|---|
| Jugadores | Búsqueda por ID, nombre, personaje, PROX-ID o trabajo. Ficha con trabajo y rango (y si está de servicio), efectivo, banco, nivel, tiempo jugado (total y hoy, de `pxd_progress`), ping, mundo (bucket), citizenid, licencia y Discord. Acciones: ir, traer, devolver, congelar, reanimar, vida, necesidades, heridas, espectar, mensaje privado y expulsar |
| Reportes | Activos / Nuevos / En curso / Cerrados. Reclamar, ir con quien reporta o con el reportado, responder y cerrar con nota. Aviso con sonido cuando entra uno nuevo |
| Herramientas | Noclip, invisible, ir al marcador, volver, sacar/reparar/borrar vehículo y anuncio a toda la ciudad |
| Registro | Quién hizo qué, a quién y cuándo (`data/staff-log.json`, últimas 1000) |
| Comandos | La lista de abajo |

Botón **De servicio / Fuera de servicio** abajo a la izquierda.

## Modo servicio (`/duty`)

- Pone el atuendo de staff (`Config.staffOutfit`, por modelo de personaje) y guarda la ropa anterior; al salir la restaura con `illenium-appearance` (exports `getPedAppearance` / `setPedAppearance`).
  - GTA no trae una prenda con el texto «STAFF»: los números del atuendo son de partida y hay que revisarlos en el juego. Lo que identifica al staff es la **etiqueta «STAFF» sobre la cabeza**, visible para todos los cercanos (state bag de jugador `pxd_staff`).
- Invencible mientras dure (`SetPlayerInvincible` + `SetEntityInvincible`).
- Sin servicio, los comandos y acciones de staff no funcionan, **salvo** `/duty`, el mensaje privado y expulsar (moderación de emergencia). El panel y los reportes sí se pueden atender fuera de servicio.

## Comandos (todos piden `pxd.admin`)

| Comando | Qué hace | Servicio |
|---|---|---|
| `/duty` | Entrar o salir de servicio | No |
| `/revivir [id]` | Reanima (qbx_medical `Revive`; sin él, resucita y cura) | Sí |
| `/vida [id]` | Salud y armadura al máximo y quita heridas (qbx_medical `Heal`) | Sí |
| `/llenarnecesidades [id]` | Hambre y sed 100, estrés 0 (metadata de Qbox + avisos al HUD) | Sí |
| `/wounds [id]` | Heridas por zona, sangrado y estado (state bags de qbx_medical) | Sí |
| `/tp <id>` | Ir con un jugador | Sí |
| `/tpm` | Ir al marcador del mapa | Sí |
| `/traer <id>` | Traer a un jugador | Sí |
| `/volver [id]` | Volver (o devolver) a la posición anterior | Sí |
| `/noclip` | Volar: W/A/S/D, Espacio sube, Ctrl baja, Shift rápido | Sí |
| `/invisible` | Invisible / visible | Sí |
| `/congelar <id>` | Congelar / descongelar | Sí |
| `/coche <modelo>` | Saca un vehículo (el cliente comprueba que el modelo existe) y da las llaves con qbx_vehiclekeys | Sí |
| `/dv` | Borra el vehículo en el que estás o el más cercano (máx. 10 m, lo comprueba el servidor) | Sí |
| `/reparar` | Repara y limpia el vehículo | Sí |
| `/anuncio <texto>` | Aviso a toda la ciudad | Sí |
| `/spectate <id>` | Espectar (la tecla del panel, F10, sale) | Sí |

No se duplican: los baneos (los gestiona **txAdmin** → Players → jugador → Ban), el menú de txAdmin ni qbx_adminmenu. Todo se valida en el servidor (ACE, servicio, jugador conectado, distancias) y queda en el registro.

## Permisos

```
add_ace group.admin pxd.admin allow
add_ace group.admin pxd.admin.kick allow   # opcional: expulsar
# o pxd.admin.all para todo
```

## Teclas

F9 (soporte) y F10 (staff), cambiables en Ajustes → Asignación de teclas → FiveM. Ojo: `qbx_vehicleradio` usa F9 para la radio dentro de los coches.

## Archivos

`data/reports.json` (últimos 500 reportes; se borran primero los cerrados) y `data/staff-log.json`. No se suben a git.

## Pendiente de comprobar en el juego

- Espectar a jugadores lejanos (el staff se acerca oculto bajo el suelo hasta que el otro entra en su alcance; si está en otro mundo/bucket, el servidor lo mueve a ese mundo y lo devuelve al salir).
- Que el atuendo por defecto se vea bien y que `illenium-appearance` restaure la ropa.
- La etiqueta «STAFF» con texto nativo (`SetDrawOrigin` + texto) a distintas distancias.
- Vista previa sin juego: `html/index.html?demo=1` (soporte), `?demo=1&staff=1` (staff; `&view=reports|tools|log|commands`, `&wounds=1`, `&announce=1`).
