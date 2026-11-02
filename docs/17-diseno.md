# 17. Diseño: Próxima UI

Una sola forma de verse en todas las pantallas del juego. Muestra con todos los componentes y capturas: `design/proxima-ui.html` (ábrela en el navegador desde el repo).

## Reglas

- **Superficies oscuras y sólidas**, texto grande y con contraste. Nada de `backdrop-filter`: la página de la NUI es transparente sobre el juego, CEF no difumina el juego y deja rectángulos oscuros (era el «rectángulo negro» del panel y el de encima del dinero). El desenfoque del juego detrás del panel se hace con `TriggerScreenblurFadeIn/Out`, como ox_inventory.
- **Colores con significado:** cian (estrella `#5ce1ff`) para información y foco; magenta (nova `#ff4fd8`) para la acción principal; oro (`#ffc857`) para lo premium (Plus, tienda). Verde, ámbar y rojo solo para estados.
- **Tipografía:** Sora para títulos y cifras grandes; Inter para todo lo demás. Ambas con licencia SIL OFL (`design/ui/fonts/`).
- **Textos en español** y siempre con `textContent`.

## Archivos

| Qué | Dónde |
|---|---|
| Tokens y componentes (fuente única) | `design/ui/proxima-ui.css` |
| Fuentes (woff2 + licencias) | `design/ui/fonts/` |
| Copia en cada recurso con NUI | `<recurso>/html/ui/proxima-ui.css` y `proxima-fonts.css` (fuentes en base64 para que `pxd_update` las trate como texto) |
| Sincronizar | `node scripts/sync-ui.mjs` (las pruebas fallan si una copia está desactualizada) |

Componentes: `px-btn` (primary, secondary, ghost, gold, danger, xl), `px-card`, `px-badge`, `px-tag`, `px-kbd`, `px-bar`, `px-input`, `px-toast`, `px-eyebrow`, `px-title`. Los reinicios van en `:where()` para no pisar los estilos de cada recurso.

## Pantallas

- **Panel (TAB):** panel sólido sobre el juego oscurecido y desenfocado; barra de color arriba; barra lateral más oscura.
- **HUD:** dinero y necesidades en una fila encima del minimapa (mismo ancho), fecha y hora a la derecha, micrófono abajo al centro con la tecla N, velocímetro abajo a la derecha. La barra rápida es de ox_inventory.
- **Personajes:** tarjetas sólidas, nombre grande en Sora.
- **Dónde aparecer (nuevo):** tras JUGAR, tarjetas con imagen: última ubicación, tus casas y puntos de la ciudad (`pxd_multichar/config.lua` → `Config.spawnPoints`). Sustituye la pizarra de qbx_spawn. Usa sus mismos callbacks (`qbx_spawn:server:getLastLocation`, `getProperties`) y eventos (`qbx_properties:server:enterProperty`).
- **Apartamento inicial (nuevo):** misma pantalla para elegir el apartamento gratis de qbx_properties (sustituye su pizarra «Available apartments»). Textos en español en `Config.apartmentTexts`.
- **Chat:** tema `proxima` del chat del sistema (`pxd_chat`), ver más abajo.
- **Editor de ropa (illenium-appearance):** tema `proxima` y español (`setr illenium-appearance:locale "es-ES"`); al crear personaje solo modelos freemode (`Ped = false`), el menú de peds queda para staff (`Config.PedMenuGroup`).

## Crear personaje: pasos, uno detrás de otro

1. **Datos** (nuestro formulario).
2. **Dónde empezar:** el apartamento inicial en nuestra pantalla (si qbx_core da apartamento inicial y qbx_properties está iniciado).
3. **Aspecto:** el editor de ropa. Lo abre qbx_properties (`qb-clothes:client:CreateFirstCharacter`) justo después de colocarte en tu apartamento.
4. **Entrada a la ciudad** desde tu apartamento.

El orden apartamento → aspecto es el de qbx_properties: tras `qbx_properties:server:apartmentSelect` abre el editor él mismo. Hacerlo al revés abriría el editor dos veces o exigiría modificar qbx_properties.

Antes salían a la vez la pizarra de apartamentos y el editor, porque el personaje se cargaba (`QBCore:Server:OnPlayerLoaded`) sin apartamento y qbx_properties enseñaba su pizarra mientras ya estaba abierto el editor. Ahora el apartamento se elige y se crea **antes** de cargar, como hace qbx_properties.

A prueba de fallos (probado en `tests/lua/test_multichar_client.lua`, que ejecuta el cliente con natives simuladas):
- si no se puede leer la configuración de qbx_properties, se usa su pizarra (una sola pantalla);
- si qbx_core rechaza la creación, se vuelve a la pantalla de personajes con un aviso;
- si la pantalla se quedara en negro, a los 6 s se vuelve a mostrar;
- una opción falsa enviada desde la NUI se ignora.

## Chat (`pxd_chat`)

- Escribir sin comando = tu personaje habla: solo lo leen quienes estén a 12 m (lo comprueba el servidor, y nadie oye a través de mundos distintos, p. ej. una partida).
- Si no te conocen, ven «Desconocido · PROX-XXXX» (`pxd_interact`).
- `/me` (de qbx_core, con texto 3D) también sale en el chat cercano; `/do`, `/susurrar` (3 m), `/gritar` (30 m), `/b` (fuera de personaje, local), `/anuncio` (staff, ACE `pxd.chat.announce`).
- Sin avisos de entrada y salida (`set chat_showJoins 0`, `set chat_showQuits 0`). Anti-spam en el servidor. Bienvenida una sola vez por sesión (sustituye al motd de qbx_core, que salía repetido).
- El aspecto es un tema del chat del sistema (`chat_theme` en el fxmanifest, el mismo mecanismo que `chat-theme-example` de cfx-server-data).

## Imágenes

Miniaturas de la pantalla de aparición generadas con Kling (`kling-image-v3_0_omni`, 1K) a petición del propietario y guardadas comprimidas en `pxd_multichar/html/assets/`.
