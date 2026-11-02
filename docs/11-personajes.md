# 11. Selección y creación de personaje (`pxd_multichar`)

Sustituye la pantalla de personajes de qbx_core (menús de ox_lib) por una propia de Próxima RP. Solo funciona con Qbox.

## Qué ve el jugador

- **Izquierda, «Tus personajes»:** sus personajes, las ranuras libres («Crear personaje») hasta el máximo que permite qbx_core y, opcionalmente, ranuras **Plus** bloqueadas con «Desbloquear», que abre la tienda.
- **Derecha, ficha:** número de ciudadano, nombre grande, trabajo y rango, sexo, nacionalidad y fecha de nacimiento, **nivel y XP**, **efectivo**, **banco** y **tiempo en la ciudad**. Abajo, **JUGAR** y **Eliminar**. Para eliminar hay que escribir el nombre completo.
- **Crear personaje:** formulario propio con nombre, apellido, sexo (cambia la vista previa al momento), nacionalidad (lista de qbx_core, con buscador) y fecha de nacimiento con límites.
- **Escena:** el personaje aparece en uno de los escenarios de `Config.scenes`, elegido al azar, con cámara de enfoque suave.
- Teclado: ↑/↓ cambia de ranura y Enter juega.

Vista previa sin juego: `pxd_multichar/html/index.html?demo=1`. También admite `&view=create`, `&view=locked` y `&view=delete`.

## Instalación

1. En **`qbx_core/config/client.lua`**, cambia:
   ```lua
   useExternalCharacters = true,
   ```
   Si no lo cambias, qbx_core sigue mostrando su menú y `pxd_multichar` no hace nada: avisa en rojo en la consola del servidor y del cliente.
2. En el `server.cfg`, después de qbx_core y de los recursos de Qbox:
   ```
   ensure pxd_multichar
   ```
3. Reinicia el servidor.

Dependencias: `qbx_core`, `ox_lib`, `oxmysql`. Opcionales: `illenium-appearance` (vista previa de la ropa), `qbx_spawn`, `qbx_apartments`, `pxd_loadscreen` (transición al cerrar la carga) y `pxd_progress` (nivel, XP y tiempo jugado).

## Cómo funciona

Reproduce el flujo de `qbx_core/client/character.lua` con los mismos callbacks y eventos de qbx_core:

| Paso | Qué usa |
|---|---|
| Lista de personajes y máximo de ranuras | `qbx_core:server:getCharacters` |
| Ropa de la vista previa | `qbx_core:server:getPreviewPedData` + `illenium-appearance:setPedAppearance` |
| Crear | `qbx_core:server:createCharacter` (qbx_core calcula el `cid`, comprueba el límite y da los objetos iniciales) |
| Jugar | `qbx_core:server:loadCharacter` y después qbx_apartments, qbx_spawn o la última posición |
| Eliminar | `qbx_core:server:deleteCharacter` (qbx_core comprueba que el personaje sea de esa licencia) |
| Volver a la pantalla (`/logout`) | evento `qbx_core:client:playerLoggedOut` |
| Primer personaje sin apartamentos | evento `qbx_core:client:spawnNoApartments` (lo registra este recurso, porque qbx_core no carga el suyo con personajes externos) |

Además:

- `pxd_multichar:server:setup` devuelve la lista de nacionalidades de `qbx_core/data/nationalities.lua` y el resumen de progreso de cada personaje. Ese resumen lo saca `exports.pxd_progress:SummaryFromMetadata(metadata)` a partir de la tabla `players`, solo con los personajes de la licencia que pregunta. Si `pxd_progress` no está iniciado, la ficha oculta el nivel y el tiempo jugado.
- `pxd_multichar:server:checkRegistration` valida el formulario en el servidor antes de crear: solo letras, de 2 a 25 caracteres, hasta 3 palabras, palabras prohibidas, nacionalidad de la lista, sexo 0 o 1 y fecha real dentro de los límites. Después, qbx_core vuelve a sanear los datos.
- La lógica pura (validación, formato, ranuras) está en `shared/multichar.lua` y se prueba en `tests/lua/test_multichar.lua`.

> Límite: igual que en qbx_core, alguien con un cliente modificado puede llamar directamente a `qbx_core:server:createCharacter` y saltarse las palabras prohibidas. qbx_core sí limita los tipos, las longitudes y el número de personajes.

## Configuración (`config.lua`)

| Opción | Para qué |
|---|---|
| `lockedSlotsShown` | Cuántas ranuras Plus bloqueadas se enseñan (0 = ninguna) |
| `storeUrl` | Enlace de la tienda (Tebex). Vacío = sin botón «Desbloquear». Al pulsarlo, FiveM pide confirmación antes de abrir el navegador |
| `enableDelete` | Permitir que el jugador borre personajes |
| `startingApartment` | Ofrecer apartamento al crear (solo si `qbx_apartments` está iniciado) |
| `dateMin`, `dateMax` | Fechas de nacimiento permitidas |
| `limitNationalities`, `defaultNationality` | Lista cerrada de nacionalidades y la elegida por defecto |
| `profanityWords` | Palabras no permitidas en nombre, apellido o nacionalidad |
| `scenes` | Escenarios: `pedCoords` (personaje) y `camCoords` (cámara) |

El número de personajes por jugador se configura en qbx_core (`config/server.lua → characters.defaultNumberOfCharacters` y `playersNumberOfCharacters`).
