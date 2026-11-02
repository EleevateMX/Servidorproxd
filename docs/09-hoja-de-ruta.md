# 9. Hoja de ruta: de servidor base a rol completo

Idea: crecer poco a poco. Primero lo que ya existe y funciona (Qbox y sus recursos oficiales); lo propio de Próxima RP se programa encima, donde aporta algo distinto.

## Fase 0 — Base en línea (ahora)

- Nodecraft PRO 2GB (Miami) + receta `recipe.yaml`.
- Login, pantalla de carga, modos de juego, editor de props, tienda Tebex en revisión.
- Objetivo: comprobar el hosting, la marca y que la gente entra y juega.

## Fase 1 — Framework de rol (Qbox)

- Instalar **Qbox** con el MySQL que incluye Nodecraft. Probablemente toque subir al plan de 3 GB.
- La receta oficial *Qbox Lean* trae el núcleo: `qbx_core`, ox_lib/ox_inventory/oxmysql, voz (`pma-voice`), teléfono (npwd), llaves de vehículos, concesionario, ayuntamiento, DNI, policía, EMS y sistema médico.
- Adaptar los recursos de Próxima:
  - `pxd_login`: desactivar la bienvenida (`Config.welcomeScreen = false`), porque Qbox trae selección de personaje; mantener normas y código de acceso.
  - `pxd_gamemodes`: dentro de las partidas, no usar la muerte de Qbox (`qbx_medical`) ni tocar el inventario RP (las armas del modo no son objetos de ox_inventory). **Hay que programarlo y probarlo.**
  - `pxd_props`: sin cambios.
- Entregable: `recipe-qbox.yaml` (receta Lean de Qbox + Próxima RP) y guía de migración.

## Fase 2 — Trabajos legales

Ya existen en la receta completa de Qbox; se activan uno a uno, configurados y probados:

| Prioridad | Trabajos |
|---|---|
| 1 | Policía, EMS, mecánico |
| 2 | Taxi, camionero, grúa, basurero |
| 3 | Autobús, noticias, reciclaje, buceo, viñedo |

Con cada trabajo: sus escenarios (comisaría, hospital, taller) con el editor de props o blueprints, y MLO si hacen falta.

## Fase 3 — Economía y vida en la ciudad

- Garajes, propiedades/vivienda, gestión de empresas (`qbx_management`), tienda de tuneo, venta de vehículos.
- Ajustar sueldos y precios para que la economía no se rompa.

## Fase 4 — Crimen y contenido propio

- Robos y actividades ilegales de Qbox (tiendas, joyería, banco, drogas), con normas claras.
- **Lo propio de Próxima RP:** eventos con modos de juego, trabajos exclusivos, misiones diseñadas con blueprints y recompensas de Tebex **cosméticas** (sin ventaja en el juego).

## Cómo trabajamos cada sistema

1. Me describes la idea.
2. Compruebo si ya existe en Qbox o en un recurso oficial; si no, lo programo con pruebas.
3. Se prueba en el servidor (o en tu PC) antes de abrirlo a la gente.
4. Se documenta en `docs/` y se sube al repo.

## Nombres de recursos

Sacados de las recetas oficiales de Qbox (`Qbox-project/txAdminRecipe`: `qbox.yaml` y `qbox-lean.yaml`). Hay que revisar en cada fase que sigan existiendo y su configuración actual.
