# CLAUDE.md — Próxima RP (repositorio Servidorproxd)

Entorno de pruebas FiveM de **Próxima RP**: modos de juego, editor de props, login y pantalla de carga. Léelo antes de cambiar nada. Documentación en `docs/`.

## Comandos

```bash
npm test                 # Lua 5.4 (tests/lua) + Node (tests/js). Obligatorio antes de cada commit
npm run test:web         # capturas de las 6 interfaces con Chromium (si tocas html/)
node scripts/pxd.mjs …   # anchors | list | get | compile | apply | activate | remove (ver docs/04)
```

## Estructura

| Ruta | Contenido |
|---|---|
| `server-data/server.cfg` | Configuración del servidor de pruebas (sin secretos) |
| `server-data/resources/[proxima]/pxd_*` | Recursos propios |
| `tools/blueprint.mjs` | Compilador de blueprints (formas → layout) |
| `blueprints/` | Diseños listos para inyectar |
| `tests/lua/fx_stub.lua` | Simulador mínimo de FXServer para probar `server/*.lua` |

Patrón de los recursos: la lógica va en `shared/*.lua` **pura** (sin natives, recibe `now`) y se prueba con Lua; `server/` y `client/` son pegamento delgado.

## Flujo «idea → escenario en el juego»

Cuando el usuario describa un escenario (circuito, arena, decorado de un evento…):

1. Pide el **ancla**: que se ponga en el sitio en el juego y escriba `/ancla <nombre>` mirando hacia «delante». Comprueba con `node scripts/pxd.mjs anchors`.
2. Escribe `blueprints/<id>.json` (formato en docs/04): marco local +x derecha, +y delante, metros. Usa `ground: true` en terreno irregular.
3. `node scripts/pxd.mjs compile blueprints/<id>.json` para revisar cantidades, luego `apply` (y `activate` si debe verlo todo el mundo; para arenas de modos de juego no hace falta).
4. Si va a ser arena, incluye los puntos que el modo necesita (team1/team2 + zone para KOTH; grid + route de checkpoints para carreras).
5. Para cambios: edita el blueprint y `apply --overwrite`.

Necesita `PXD_TOKEN` en `.env` y el servidor encendido. Desde una sesión en la nube normalmente no hay acceso al servidor del usuario: entonces deja el blueprint compilado y dale el comando.

## Reglas

1. **No inventar** natives, eventos, convars, modelos ni armas. Verifícalos en `citizenfx/fivem` (`ext/native-decls`, `ext/natives`) o en `citizenfx/fivem-docs`. Si no se puede, márcalo como pendiente o compruébalo en tiempo de ejecución (como `IsModelInCdimage` en el catálogo).
2. **Secretos** solo en `server-data/secrets.cfg` y `.env` (ignorados por git). Tokens con `set`, nunca `setr`.
3. **El servidor manda**: toda acción del cliente se valida en el servidor (tipos, permisos ACE, distancias, límites).
4. **NUI**: `nui_callback_strict_mode 'true'` y texto de usuario siempre con `textContent`.
5. **Identidad propia**: nada de nombres, logos ni material de GTAHUB o Rockstar.
6. **Sin servicios de pago** (generación de imágenes, vídeo, voz…) sin pedirlo el propietario.
7. Textos de interfaz y docs en español; código e identificadores en inglés.
