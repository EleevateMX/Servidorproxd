# 2. Entorno de pruebas paso a paso

Objetivo: un servidor FiveM en tu PC, privado, para crear y probar modos de juego y escenarios. Unos 15 minutos.

## Windows (recomendado)

1. Instala [Git](https://git-scm.com/download/win) y, opcional, [Node.js 20+](https://nodejs.org).
2. Clona este repo y entra en la carpeta.
3. Ejecuta en PowerShell:
   ```powershell
   .\scripts\setup-windows.ps1
   ```
   Busca solo el build **recomendado** de FXServer (API oficial de versiones; para otro build: `-ArtifactUrl "<enlace>"`), lo descarga en `server/`, clona `cfx-server-data` en `server-data/resources/[cfx]/`, crea `server-data/secrets.cfg` con un token aleatorio (también en `.env`) y descarga el arte de la marca.
   Si `tar` no puede abrir el `.7z`, extráelo con 7-Zip dentro de `server/`.
4. Edita `server-data/permissions.cfg` y añade tu identificador al grupo `group.admin` (lo ves en la consola del servidor cuando te conectas).
5. Arranca:
   ```powershell
   .\scripts\run-windows.ps1
   ```
6. Abre FiveM, pulsa F8 y escribe `connect localhost:30120`.

## Linux

```bash
bash scripts/setup-linux.sh
```
```bash
bash scripts/run-linux.sh
```

## Qué incluye `server.cfg`

- `onesync on` (obligatorio para los modos de juego).
- `sv_lan true` en `secrets.cfg`: sin licencia y sin aparecer en la lista pública. Para que entren amigos por internet: pon tu clave de [portal.cfx.re](https://portal.cfx.re) en `sv_licenseKey`, quita `sv_lan` y abre el puerto 30120 TCP/UDP.
- Recursos base de `cfx-server-data` (mapmanager, chat, spawnmanager, basic-gamemode, baseevents, un mapa con spawns).
- Recursos de Próxima: `pxd_loadscreen`, `pxd_login`, `pxd_props`, `pxd_gamemodes`.

## En la nube

Para tenerlo 24/7 con más jugadores: [docs/06-servidor-en-la-nube.md](06-servidor-en-la-nube.md).

## Alternativa: txAdmin

Si arrancas `FXServer.exe` sin `+exec`, se abre txAdmin en el navegador (puerto 40120) con recetas listas (p. ej. Qbox). Útil para la fase RP con base de datos; para probar modos de juego no hace falta.

## Base de datos (solo si añades un framework)

```bash
docker compose up -d
```
MariaDB 11.4 en `127.0.0.1:3306` y Adminer en `http://127.0.0.1:8080`. Contraseñas en `.env` (`MARIADB_PASSWORD`, `MARIADB_ROOT_PASSWORD`). Cadena para oxmysql: ver `secrets.cfg.example`.

## Comprobar que todo funciona

| Qué | Cómo |
|---|---|
| Pantalla de carga | Al conectar ves PRÓXIMA RP con barra de progreso, consejos y voz de bienvenida |
| Login | La primera vez te pide aceptar las normas (y el código si definiste `pxd_login_accessCode`) |
| Bienvenida | Al entrar eliges ciudad, modos de juego o editor (staff) |
| Modos | F7 → crea «Todos contra todos» en la arena de prueba → Iniciar |
| Props | F6 (staff) → crea un layout → catálogo → coloca |
| Dashboard web | `http://localhost:30120/pxd_props/` con el token de `secrets.cfg` |

## Pruebas automáticas (sin el juego)

```bash
npm test          # 56 pruebas Lua (lógica + servidor simulado) y 8 del compilador de blueprints
npm run test:web  # abre las 6 interfaces en Chromium y guarda capturas
```
Requisitos: `lua5.4` y Node 20+. `test:web` necesita Playwright con Chromium.

## Problemas típicos

- **No arranca ningún recurso / «no license key»**: no estás en `server-data` al arrancar, o falta `+exec server.cfg` (usa los scripts `run-*`).
- **Los modos no aíslan a los jugadores**: revisa que `onesync` esté en `on`.
- **El dashboard web dice «API web desactivada»**: el token de `pxd_props_webToken` tiene menos de 24 caracteres.
- **Aviso EOS/EOL al conectar**: actualiza los binarios a un build recomendado reciente.
