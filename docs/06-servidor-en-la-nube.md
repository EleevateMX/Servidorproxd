# 6. Servidor en la nube

Sí: para que Próxima RP esté encendido 24/7 y entren otros jugadores, lo normal es alojarlo en la nube. Hay tres caminos, de más fácil a más control.

> Lo que no sirve: una sesión de Claude en la nube. Es temporal (se borra al rato), no acepta conexiones de jugadores y su red no puede descargar FiveM.

## Requisitos comunes (de la documentación oficial)

- **Clave de licencia** de [portal.cfx.re](https://portal.cfx.re) (gratis). En la nube no uses `sv_lan`.
- **Más de 48 plazas** requiere la suscripción *FiveM Element Club Argentum* o superior.
- **Puerto 30120 TCP y UDP** abierto.
- Si tu firewall o protección DDoS es estricta, permite las IP de Cfx.re publicadas en [static.cfx.re/ips.txt](https://static.cfx.re/ips.txt) (las actualizan con al menos un mes de aviso). Si no, no aparecerás bien en la lista de servidores.
- Artefactos actualizados: los que pasan 3 meses sin soporte no se pueden unir desde la lista.

## Opción A — Proveedor de hosting autorizado (lo más fácil)

Cfx.re publica sus socios autorizados en [fivem.net/server-hosting](https://fivem.net/server-hosting). Te dan un panel (normalmente con txAdmin) y tú:

1. Creas el servidor y pegas tu clave de licencia.
2. Subes la carpeta `server-data/resources/[proxima]` y fusionas nuestro `server.cfg` y `permissions.cfg` con el suyo.
3. Pones los secretos (`pxd_props_webToken`, `pxd_login_accessCode`) con `set` en su configuración.

Precio y plazas dependen del proveedor (no los he comparado).

## Opción B — VPS Linux con Docker (incluido en este repo)

En cualquier VPS con Docker:

```bash
git clone https://github.com/EleevateMX/Servidorproxd.git && cd Servidorproxd
```
```bash
cp deploy/.env.example deploy/.env
```
Rellena `deploy/.env`: `FX_LICENSE_KEY`, `PXD_PROPS_WEB_TOKEN` (24+ caracteres) y tus identificadores de staff en `FX_ADMIN_IDENTIFIERS`.
```bash
docker compose -f deploy/docker-compose.yml up -d --build
```

- La imagen descarga el build **recomendado** de FXServer para Linux (API oficial de versiones, la misma que usa txAdmin) y `cfx-server-data`.
- Los layouts de props y los registros del login viven en volúmenes: sobreviven a reinicios y actualizaciones.
- Actualizar FXServer o los recursos: `git pull` y repetir el `up -d --build`.
- Consola: `docker compose -f deploy/docker-compose.yml attach fxserver` (sal con Ctrl+P, Ctrl+Q).
- Aviso oficial: el FXServer de Linux es un «port de cortesía»; los arreglos llegan antes a Windows.

**Pendiente de verificar:** la imagen no se ha podido construir en esta sesión (sin Docker ni acceso a los servidores de FiveM). La primera construcción hay que hacerla en el VPS y revisar el registro.

## Opción C — VPS Windows

Entra por escritorio remoto y sigue la guía de Windows (`docs/02`): `.\scripts\setup-windows.ps1` y `.\scripts\run-windows.ps1`. En `secrets.cfg` pon tu clave de licencia y quita `sv_lan true`. Abre el 30120 TCP/UDP en el firewall de Windows y en el del proveedor.

## Seguridad en la nube

- No expongas la base de datos (el `docker-compose.yml` de la raíz solo escucha en `127.0.0.1`).
- El dashboard web de props va por el mismo puerto 30120: token largo, y compártelo solo con staff.
- Si usas txAdmin (puerto 40120), no lo dejes abierto a todo internet; restríngelo a tu IP.
- Copias de seguridad de los volúmenes `props-data` y `login-data` (o de las carpetas `data/`).

## Bonus: que Claude inyecte diseños directamente en tu servidor en la nube

Con el servidor en la nube y una dirección fija:

1. Pon en `.env` `PXD_URL=http://TU_IP:30120/pxd_props` y el token.
2. Para que una sesión de Claude en la nube llegue a tu servidor, añade tu IP o dominio a los dominios permitidos de la red del entorno (menú del entorno → Editar → Network access; [docs](https://code.claude.com/docs/en/cloud-environments#network-access)).
3. A partir de ahí, «describe la idea → blueprint → `pxd apply`» funciona sin tu PC.
