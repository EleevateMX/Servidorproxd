# 7. Próxima RP en un hosting oficial (paso a paso)

Para hasta 48 jugadores, siempre encendido. Unos 20 minutos una vez contratado.

## Lo que necesitas

| Qué | Detalle |
|---|---|
| **Cuenta de Cfx.re** | Gratis en [forum.cfx.re](https://forum.cfx.re). Con ella entras al portal y a txAdmin |
| **Clave de licencia** | Gratis en [portal.cfx.re](https://portal.cfx.re) → *Server Keys*. Hasta 48 plazas **no hace falta suscripción** (más de 48 requiere Element Club Argentum) |
| **Plan de FiveM en un proveedor autorizado** | Lista oficial: [fivem.net/server-hosting](https://fivem.net/server-hosting) |
| **Tu identificador** | Para ser admin. Si entras en txAdmin con tu cuenta de Cfx.re, la receta te añade sola |

### Cómo elegir el plan

- **Proveedor autorizado por Cfx.re.** Varias guías de 2026 citan seis: Nodecraft, Shockbyte, Nitrado, GPORTAL, ZAP-Hosting y xREALM. Es información de terceros: confírmalo en la lista oficial.
- **Producto «FiveM» con acceso a txAdmin.** Es lo que permite instalar Próxima RP con una sola URL. Si el proveedor no da txAdmin, hay plan B (más abajo).
- **Ubicación cerca de tus jugadores.** Para México y Latinoamérica, un centro de datos en Norteamérica suele dar mejor ping que uno en Europa.
- **Plazas: 48 o menos.** Coincide con lo que permite la licencia gratuita.
- **Base de datos: no hace falta por ahora.** Los recursos de Próxima guardan en archivos. Si más adelante añades Qbox, sí la necesitarás (muchos planes la incluyen).
- **Protección DDoS y copias de seguridad.** Pregunta si están incluidas.
- **Acceso a archivos (FTP o gestor web).** Sirve para actualizar y hacer copias.
- **Precio y RAM.** Varían por proveedor; no los he comparado. Próxima RP es ligero: no usa base de datos y los props se cargan en cada cliente.

## Instalación con txAdmin (recomendada)

1. Contrata el plan y entra en el panel del proveedor. Abre **txAdmin** (normalmente hay un botón; si no, puerto 40120 de tu servidor).
2. Inicia sesión con tu cuenta de Cfx.re y crea la contraseña de admin.
3. En el asistente de configuración elige **«Remote URL Template»** y pega:
   ```
   https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/recipe.yaml
   ```
4. Revisa la receta («Próxima RP») y sigue. Cuando lo pida, pega tu **clave de licencia**. No pedirá base de datos.
5. La receta:
   - descarga los recursos base oficiales y Próxima RP desde GitHub;
   - instala el fondo y el vídeo de la pantalla de carga (generados con Kling);
   - escribe `server.cfg` y `permissions.cfg`;
   - te añade como admin.
6. Antes de arrancar, en el editor de `server.cfg` que te muestra:
   - pon un token de 24+ caracteres en `set pxd_props_webToken "…"` si quieres el dashboard web y el comando `pxd`;
   - si quieres un servidor privado, pon un código en `set pxd_login_accessCode "…"`.
7. **Save & Run Server.** En FiveM: F8 → `connect IP:PUERTO` (los ves en el panel del proveedor).

### Añadir más staff

En txAdmin → CFG Editor → `permissions.cfg`, añade una línea por persona:
```
add_principal identifier.license:XXXXXXXX group.admin
```
El identificador aparece en txAdmin → Players al conectarse.

## Tienda Tebex (única forma permitida de cobrar)

Guía oficial: [Setting up a Tebex store](https://docs.fivem.net/docs/server-manual/setting-up-a-tebex-store/). Para conectar la tienda con el servidor:

1. En creator.tebex.io → **Integrations → Game Servers → Connect Game Server → Plugin**, ponle nombre y copia la clave secreta.
2. En txAdmin → CFG Editor → `server.cfg`, quita el `#` de la línea `sv_tebexSecret` y pega la clave.
3. Reinicia el servidor y pulsa **Continue** en Tebex. Si no se activa, revisa la consola; Tebex permite **Skip**.

La clave es secreta: nunca en git ni en capturas.

## Plan B: sin txAdmin (subida por FTP)

1. En el panel del proveedor crea un servidor FiveM «vacío» o «CFX Default» y pon tu clave de licencia.
2. Descarga este repo (GitHub → Code → Download ZIP).
3. Sube por FTP la carpeta `server-data/resources/[proxima]` a la carpeta `resources/` del servidor.
4. Copia en tu `server.cfg` las líneas de `server-data/server.hosting.cfg`:
   - sustituye los valores entre llaves dobles, o quítalos si el proveedor ya los gestiona;
   - mantén `set onesync on` y los `ensure`.
5. Sube `permissions.cfg` y añade tu identificador.
6. Opcional: descarga el arte con `node scripts/fetch-brand-assets.mjs` en tu PC y súbelo a `resources/[proxima]/pxd_loadscreen/html/assets/`.

## Actualizar Próxima RP más adelante

- Sube de nuevo `resources/[proxima]`, pero **no sobrescribas** `pxd_props/data/` ni `pxd_login/data/`: ahí están los layouts y los registros de jugadores.
- Reinicia desde txAdmin.

## Después de instalar: inyectar diseños desde Claude

Con el token puesto:

1. En tu `.env` local:
   ```
   PXD_URL=http://IP:PUERTO/pxd_props
   PXD_TOKEN=tu-token
   ```
2. Para que Claude lo haga desde la nube, añade la IP del servidor a los dominios permitidos del entorno (ver docs/06).

## Problemas típicos

- **«Remote URL Template» falla al descargar**: el proveedor puede bloquear GitHub; usa el plan B.
- **Aviso EOS/EOL**: pide al proveedor (o cambia en su panel) el build *recommended* más reciente.
- **No se ve la pantalla de carga con vídeo**: la receta no pudo descargar el arte; funciona igual con el fondo animado.
- **Los modos de juego no aíslan**: confirma `set onesync on` (algunos paneles tienen su propio interruptor de OneSync: actívalo).

## Actualizar Próxima RP sin subir archivos (`pxd_update`)

El recurso `pxd_updater` descarga desde GitHub lo que haya cambiado en los recursos `pxd_*` y los reinicia.

En txAdmin → **Live Console**:

| Comando | Qué hace |
|---|---|
| `pxd_update check` | Muestra qué cambiaría, sin tocar nada |
| `pxd_update` | Aplica: descarga, comprueba la huella SHA-256 de cada archivo, escribe todo (o nada si algo falla) y reinicia los recursos tocados. También baja el arte que falte |
| `pxd_update force` | Igual, pero sobrescribe también los `config.lua` que hayas editado a mano |

- Los `config.lua` que edites se respetan (el actualizador recuerda la versión que instaló).
- El arte (imágenes y vídeo) lo descarga `server/assets.js` con Node.js, porque las descargas de Lua cortan los archivos binarios. Si `pxd_update` dice que actualizó el propio `pxd_updater`, ejecútalo otra vez para bajar el arte.
- Si sale «No pude reiniciarme solo», escribe `ensure pxd_updater` y repite `pxd_update`; para que no vuelva a pasar, añade las líneas `command.stop` y `command.start` de abajo.
- Nunca toca `data/` (props guardados, jugadores).
- **Permisos de escritura.** Las versiones nuevas de FXServer no dejan que un recurso escriba en otro salvo que el `server.cfg` lo permita. Hacen falta estas líneas (vienen en `permissions.pxd.cfg`; en un servidor ya montado, pégalas en *CFG Editor* y reinicia):
  ```
  add_filesystem_permission pxd_updater write pxd_loadscreen
  add_filesystem_permission pxd_updater write pxd_login
  … (una por recurso: ver server-data/permissions.pxd.cfg)
  ```
  Si falta alguna, `pxd_update` dice exactamente qué línea añadir.
- **Recursos nuevos.** FXServer tampoco deja crear carpetas de recursos desde un script, así que los recursos nuevos (de Próxima o de terceros, como los trabajos de Qbox) se suben **una vez** con el paquete de instalación: `scripts/build-package.sh` genera un zip con `resources/[proxima]/…` y `resources/[qbx]/…`; súbelo a la carpeta del servidor y descomprímelo (no toca las carpetas `data/`). Después, `pxd_update` los mantiene al día.
- Los recursos del plan (`scripts/update-plan.json`) los arranca el actualizador en cada encendido, así que no hace falta añadir `ensure` al `server.cfg`. Si uno sustituye a otro (p. ej. `pxd_hud` a `qbx_hud`), para el antiguo.
- Ajustes en recursos de terceros (p. ej. `useExternalCharacters` de qbx_core para la pantalla de personajes): los hace y pide **reiniciar el servidor**.
- Si algo tiene varios pasos (el propio actualizador, recursos nuevos, terceros, arte), ve ejecutando `pxd_update` hasta que diga «Todo está al día».
- Necesita en el `server.cfg` (ya viene en las recetas nuevas):
  ```
  ensure pxd_updater
  add_ace resource.pxd_updater command.refresh allow
  add_ace resource.pxd_updater command.ensure allow
  add_ace resource.pxd_updater command.stop allow
  add_ace resource.pxd_updater command.start allow
  add_ace group.admin pxd.update allow
  ```
