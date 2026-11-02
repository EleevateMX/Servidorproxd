# 23. Teléfono de Próxima RP

El teléfono es **npwd 3.14.3** (el de la receta Qbox), con el diseño de Próxima encima y tres apps propias. Se abre con la **flecha arriba** (`toggleKey: "UP"`, ver docs/14).

## Qué cambia

- **Inicio propio:** reloj grande con fecha, cuadrícula de 4 columnas con iconos propios (SVG) y nombres en español, dock inferior (Mensajes, Llamadas, Contactos, Cámara) y globos de aviso con nuestro color.
- **Cuerpo del teléfono** dibujado con CSS: bordes redondeados, isla superior y brillo cian. Sustituye a los marcos PNG de npwd.
- **Fondo** propio (Kling, autorizado por el propietario) en `pxd_phone/html/img/fondo.jpg`. Se usa en el inicio aunque el jugador elija otro fondo en Ajustes.
- Las apps de npwd (Mensajes, Llamadas, Contactos, Anuncios, Cámara con galería, Notas, Calculadora, Bleeter, Citas, Darkchat, Ajustes) y las externas de Qbox (Garaje, Correo) se abren igual que antes. Las que npwd tenga desactivadas (`disabledApps`) no salen.

## Apps propias

| App | Qué hace | Quién recibe | Validación en el servidor |
|---|---|---|---|
| **Dynasty 8** | Propiedades en venta o alquiler (de `qbx_properties`) y «Mis propiedades» (dueño o con llave). «Marcar en GPS» | — | Lee la tabla `properties`; las coordenadas salen de la base de datos |
| **Emergencias** | Aviso a Policía (`type 'leo'`) o Servicios médicos (`type 'ems'`) con texto opcional | Jugadores de ese tipo **de servicio** (`GetDutyCountType`) | Posición del servidor, texto limpio (140), 1 aviso/min |
| **Taxi** | Pedir un taxi con nota; los taxistas de servicio ven la cola y aceptan | Trabajo `taxi` de servicio (`GetDutyCountJob`) | Una petición abierta por cliente, caduca a los 10 min, 1 cada 30 s; si el taxista se desconecta vuelve a pendiente |

Quien atiende recibe un aviso de Qbox (`exports.qbx_core:Notify`) y un punto en el mapa con ruta (3 min para emergencias, hasta 10 min para taxi). Todo se configura en `pxd_phone/config.lua`.

## Cómo funciona por dentro

No se recompila npwd (el entorno no deja instalar sus dependencias y su licencia es CC-BY-NC-SA). En su lugar:

1. `pxd_phone` **no tiene página NUI propia**. Sirve `html/phone.css`, `html/phone.js` e `html/img/*` por `https://cfx-nui-pxd_phone/…` y atiende las llamadas de las apps en `https://pxd_phone/<acción>`.
   - Comprobado en citizenfx/fivem: `nui-resources/src/ResourceUI.cpp` registra `cfx-nui-<recurso>` y los callbacks para todo recurso aunque no tenga `ui_page`; el modo estricto solo se activa si hay `ui_page`; `RPCSchemeHandler.cpp` y `NUISchemeHandler.cpp` responden con `access-control-allow-origin: *`. Es el mismo mecanismo que usa npwd para sus apps externas (`useExternalApps.tsx`).
2. Un **parche exacto** añade las dos etiquetas al `index.html` de npwd:
   - Recurso `npwd`, archivo `dist/html/index.html`.
   - Busca `<link rel="stylesheet" href="./assets/index-b0f1ff4a.css">` (nombre exacto de la build 3.14.3: si npwd cambia de versión, el parche no se aplica y el teléfono queda como el original).
   - Lo aplica `pxd_updater` (plan `patches`) y la receta (`replace_string`) con el mismo texto.
3. `phone.js` añade su propia capa dentro de `#phone` y deja la cuadrícula de npwd en el DOM (oculta) para saber qué apps hay y sus avisos. Navega cambiando el hash (`HashRouter` de npwd). Solo toca clases estables de npwd: `.Phone`, `.PhoneFrame`, `#phone`, `.PhoneAppContainer`.

## Instalación en el servidor en marcha

1. Subir `pxd_phone` (paquete de instalación).
2. En `server.cfg` (ya en `permissions.pxd.cfg`):
   ```
   add_filesystem_permission pxd_updater write npwd
   add_filesystem_permission pxd_updater write pxd_phone
   ```
3. Reiniciar, `pxd_update` (aplica el parche de `index.html`) y **reiniciar otra vez** (o al menos npwd): los jugadores cargan el nuevo `index.html` al conectar.
4. `pxd_phone` lo arranca el actualizador (plan `autostart`); en instalaciones nuevas, `ensure pxd_phone` va en `server.qbox.cfg` después de npwd. Depende de `oxmysql` (Dynasty 8) y de `qbx_core`.

## Vista previa

`vendor/npwd-phone/demo.html` reproduce el esqueleto del DOM de npwd (sin su código) con datos de ejemplo: `?view=d8`, `?view=sos`, `?view=taxi&driver=1`.

## Pendiente

- **Banco** (Renewed-Banking no trae app de npwd), **Organizaciones** y **Eventos** (ya están en el panel TAB): se pueden añadir como vistas propias con el mismo patrón.
- No probado dentro del juego: posición de la capa con el zoom de Ajustes, rendimiento del observador del DOM, y que ningún recurso más cambie `index.html` de npwd.
- Licencia de npwd: CC-BY-NC-SA 4.0 (no comercial). No se redistribuye su código; solo se añaden dos etiquetas a la instalación del propietario. Si el servidor se monetiza, conviene revisar la licencia.
