<p align="center"><img src="brand/logo.svg" width="460" alt="Próxima RP"></p>

<p align="center"><b>Tu próxima vida empieza aquí.</b><br>Entorno de pruebas FiveM para crear modos de juego y escenarios de rol.</p>

## Qué hay aquí

| Recurso | Qué hace |
|---|---|
| `pxd_gamemodes` | Modos de juego en mundos aislados (routing buckets): todos contra todos, deathmatch por equipos, rey de la colina y carreras. Menú F7 + HUD |
| `pxd_props` | Editor de props en el juego (F6), dashboard web con mapa cenital y API para inyectar diseños |
| `pxd_login` | Login al conectar: código de acceso opcional + normas; pantalla de bienvenida |
| `pxd_loadscreen` | Pantalla de carga con progreso real, consejos, vídeo y voz de bienvenida |
| `scripts/pxd.mjs` | Comando para pasar de una idea a un escenario: blueprint → servidor, en vivo |

## Empezar

```powershell
.\scripts\setup-windows.ps1
```
```powershell
.\scripts\run-windows.ps1
```
En FiveM: F8 → `connect localhost:30120`. Guía completa: [docs/02-entorno-de-pruebas.md](docs/02-entorno-de-pruebas.md).

**En un hosting oficial con txAdmin:** en el asistente elige «Remote URL Template» y pega
`https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/recipe.yaml` ([guía](docs/07-hosting-oficial.md)).

**En la nube (VPS Linux con Docker):**
```bash
docker compose -f deploy/docker-compose.yml up -d --build
```
Antes rellena `deploy/.env` (ver [docs/06-servidor-en-la-nube.md](docs/06-servidor-en-la-nube.md)).

## Documentación

1. [Investigación: cómo se monta un servidor como GTAHUB](docs/01-investigacion.md)
2. [Entorno de pruebas paso a paso](docs/02-entorno-de-pruebas.md)
3. [Modos de juego](docs/03-modos-de-juego.md)
4. [Editor de props, dashboard y blueprints](docs/04-editor-de-props.md)
5. [Login, pantalla de carga e identidad](docs/05-login-carga-y-marca.md)
6. [Servidor en la nube](docs/06-servidor-en-la-nube.md)
7. [Hosting oficial paso a paso](docs/07-hosting-oficial.md)
8. [Kit de lanzamiento (portal, hosting, comandos)](docs/08-kit-lanzamiento.md)
9. [Hoja de ruta: de servidor base a rol completo](docs/09-hoja-de-ruta.md)
10. [Fase 1: Próxima RP + Qbox](docs/10-fase-1-qbox.md)
11. [Selección y creación de personaje](docs/11-personajes.md)
12. [Progreso: nivel, horas, recompensas y logros](docs/12-progreso.md)
13. [Panel de la ciudad (TAB)](docs/13-panel.md)
14. [HUD y teléfono](docs/14-hud-y-telefono.md)
15. [Trabajos y casas](docs/15-trabajos.md)
16. [Ficha del servidor en FiveM](docs/16-ficha-fivem.md)
22. [Investigación de sistemas y plan](docs/22-investigacion-sistemas.md)
26. [Consolidación: backlog P0/P1/P2](docs/26-consolidacion.md) · [auditoría](docs/auditoria/)
27. [Copias de seguridad y restauración](docs/27-respaldo-y-restauracion.md)
28. [Controles](docs/28-controles.md)
29. [Hospital](docs/29-hospital.md)
30. [Multas y deudas](docs/30-multas.md)
31. [Etapas A–E: economía y rol](docs/31-etapas-economia-y-rol.md)
32. [Entrega de las fases 0 y 1](docs/32-entrega-fase-0-1.md)
33. [Guía paso a paso en Nodecraft](docs/33-guia-nodecraft.md)

## Pruebas

```bash
npm test
```
Lógica y servidores simulados en Lua 5.4 (sin el juego) + compilador de blueprints en Node. `npm run test:web` abre todas las interfaces en Chromium.

## Aviso

Proyecto independiente. No usa nombre, marcas ni materiales de GTAHUB ni de Rockstar Games. FiveM y GTA V son de sus respectivos dueños; respeta el acuerdo de licencia de Cfx.re.
