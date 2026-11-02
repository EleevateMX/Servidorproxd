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
- Entregable: `recipe-qbox.yaml` (receta Lean de Qbox + Próxima RP). **Hecho** — ver `docs/10-fase-1-qbox.md`.

## Fase 2 — Trabajos legales

**En marcha** — ver `docs/15-trabajos.md`. En `recipe-qbox.yaml` ya van los trabajos oficiales de Qbox y las casas; lo que Qbox no trae lo hace `pxd_jobs`:

| Prioridad | Trabajos | Estado |
|---|---|---|
| 1 | Policía, EMS, mecánico | Oficiales de Qbox (en la receta) |
| 2 | Taxi, camionero, grúa, basurero, autobús | Oficiales de Qbox (en la receta; se cogen en el ayuntamiento) |
| 3 | Periodista, reciclaje, buceo, viñedo, desguace | Oficiales de Qbox (en la receta) |
| Propios | Minero, leñador, pescador, repartidor | `pxd_jobs` (hay que revisar los puntos en el juego) |
| Casas | `qbx_properties` | Oficial de Qbox (en la receta) |

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

## Lista de referencia del propietario (estado)

Regla general: **ninguna interfaz por defecto de FiveM/ox**. Todo con la UI propia de Próxima (pxd_*, y ox_lib/ox_target/ox_inventory/npwd recompilados con nuestro diseño).

| Área | Punto | Estado |
|---|---|---|
| Base | Framework (Qbox, compatible con QBCore) | Hecho |
| Base | Voz (pma-voice + pxd_voice: N, doble N grito, J susurro) | Hecho |
| Base | Admin y logs (pxd_admin: F9/F10, /duty, registro de acciones) | Hecho |
| Base | Pantalla de carga con música y normas | Hecho |
| Trabajos | Taxi, basurero, minero, leñador, mecánico (grúa, tuneo, reparación) | Hecho (qbx_* + pxd_jobs) |
| Negocios de jugadores | Concesionarios, bares/discotecas/restaurantes con stock, talleres, tiendas de ropa, gasolineras | Pendiente (sistema de negocios: caja, empleados, stock, precios) |
| Necesidades | Hambre, sed, estrés; médico interactivo con EMS | Hecho (qbx_medical + EMS); heridas visibles para staff |
| Facciones legales | Policía (multas, esposas, celdas, radio, vehículos) | Hecho (qbx_police, xt-prison, qbx_radio) |
| Facciones legales | EMS (ambulancias, camillas, reanimación) | Hecho (qbx_ambulancejob/qbx_medical) |
| Facciones legales | Justicia y Gobierno (jueces, abogados, alcalde, licencias) | Pendiente (licencias básicas en qbx_cityhall) |
| Facciones legales | Bomberos | Pendiente (no hay recurso oficial de Qbox) |
| Ilegal | Bandas/mafias: territorios, drogas, lavado, contrabando (regulado) | Pendiente (ver docs/22) |
| Inmersión | NPCs de ambiente y eventos automáticos | Parcial (qbx_density; eventos en el panel) |
| Inmersión | Red social de anuncios tipo «Lifeinvader» | Parcial (apps de npwd; rediseño en curso) |
| Inmersión | Teléfono con mensajería, llamadas, cámara, banco, taxi | En curso (npwd rediseñado + apps propias) |
| Inmersión | Ropa y coches importados optimizados | Pendiente (necesita los paquetes; catálogo del propietario en Pack6) |
| Comunidad | Normativa clara (PG, MG, VDM, RDM, valorar la vida) | Hecho (Ayuda → Reglas del panel) |
| Comunidad | Discord organizado, staff imparcial | Fuera del servidor (Discord del propietario) |
