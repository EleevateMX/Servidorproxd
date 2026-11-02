# 10. Fase 1: Próxima RP + Qbox

Rol completo (personajes, dinero, inventario, voz, teléfono, policía, EMS, concesionario, ayuntamiento) sobre **Qbox**, con los recursos de Próxima integrados.

## Instalar en Nodecraft (txAdmin)

1. **Base de datos:** en Nodecraft → *Files & Backups → Database*, crea/consulta la base MySQL y apunta host, puerto, usuario, contraseña y nombre.
2. txAdmin → nueva instalación → **Remote URL Template**:
   ```
   https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/recipe-qbox.yaml
   ```
3. Pega la clave de licencia y los **datos de la base de datos** cuando los pida.
4. En el `server.cfg` final pon `pxd_props_webToken` (24+ caracteres) y, si quieres, `qbx:discordLink`.
5. **Save & Run Server**.

Plan recomendado: Nodecraft 3 GB (Qbox + MySQL + voz + teléfono pesan más que la versión base).

## Qué cambia en Próxima RP con Qbox

| Recurso | Comportamiento con Qbox |
|---|---|
| `pxd_login` | Mantiene normas y código de acceso. La bienvenida se desactiva sola (`Config.welcomeScreen = 'auto'`): Qbox trae selección de personaje |
| `pxd_loadscreen` | Sigue siendo la pantalla de carga (la de la receta oficial se quita). La cierra `qbx_core` al abrir la selección de personaje |
| `pxd_gamemodes` | Ver abajo |
| `pxd_props` | Sin cambios |

### Modos de juego y Qbox (`server/bridge.lua`, `client/bridge.lua`)

- **Mundos aislados** con `exports.qbx_core:SetPlayerBucket` (mantiene el estado `instance` de Qbox). Rango alto (`Config.bucketBase = 60000`) para no chocar con viviendas u otras instancias.
- **Para entrar** hace falta personaje cargado, no estar herido ni esposado.
- **Inventario:** al entrar se guarda el arma del inventario (`ox_inventory:disarm`), se activa `weaponWheel(true)` (modo de ox_inventory pensado para minijuegos) y se bloquea el inventario (`invBusy`). Las armas de la partida son del juego y se quitan al salir: **no tocan el inventario RP**.
- **Muerte:** Qbox no deja morir, deja «caído». Dentro de la partida eso cuenta como baja (sin duplicar con baseevents), y al reaparecer el servidor llama a `exports.qbx_medical:Revive` y te mueve al spawn. Sin sangrado ni efectos de daño mientras juegas.
- **Al salir** se revive a quien siga caído y se restaura todo.

Todo verificado leyendo el código de `qbx_core`, `qbx_medical` y `ox_inventory` (octubre 2026) y probado con el simulador (`tests/lua/test_gamemodes_server.lua`, bloque «con Qbox»). **Pendiente:** probarlo en el servidor real.

## Pantalla de carga: carrusel de arte (Kling)

Además del fondo y el vídeo, rota cuatro imágenes: `slide-policia`, `slide-emergencias`, `slide-taller`, `slide-barrio` (Kling `kling-image-v3_0_omni`, guardadas en Higgsfield). Los títulos describen la imagen, no prometen funciones.

## Siguientes pasos (fase 2)

Activar y configurar trabajos de Qbox uno a uno (policía, EMS y mecánico primero) y diseñar sus escenarios con el editor de props. Ver `docs/09-hoja-de-ruta.md`.
