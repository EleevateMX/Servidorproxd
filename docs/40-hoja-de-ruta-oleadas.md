# 40. Hoja de ruta por oleadas (plan del 2026-11-11)

Origen: la lista del propietario (economía viva, fábricas, bolsa, barrios, vida social, vehículos, Cayo Perico, teléfono), con NoPixel como referencia de calidad.

**Reglas:**
- Las mecánicas son inspiración. Nombres, diseño y código son de Próxima RP: nada de marcas ni textos de GTAHUB, NoPixel o Rockstar.
- Cada oleada se entrega instalable, con pruebas automáticas y una lista de pruebas en FiveM.
- Estados de cada sistema: implementado / instalado / verificado en consola / probado en FiveM.

## Oleada 1 · Cimientos (en curso)

| Sistema | Recurso | Qué incluye | Doc |
|---|---|---|---|
| Economía viva | `pxd_economy` | Paga cada 30 min con desglose y anti-AFK; mercado con precios que fluctúan por oferta, demanda y eventos; titulares; base de impuestos | 41 |
| Organizaciones y bandas | `pxd_orgs` | Crear desde el juego, miembros y rangos, fondos, identidad (color y tipografía), reputación | 42 |
| Interfaz común y HUD 2.0 | `pxd_ui`, `pxd_hud` | Notificaciones, text UI y progreso propios (los recursos de terceros los usan sin tocarlos); HUD a pie y en vehículo; ajustes del jugador | 43 |
| Vehículos | `pxd_garage` | Taller de personalización propio, tuning de motor con estadísticas, mecánicos por nivel | 44 |

## Oleada 2 · Economía circular e ilegal conectado

| Sistema | Depende de | Qué incluye |
|---|---|---|
| Empresas (`pxd_business`) | Economía, organizaciones | Registro, caja, empleados, stock, compras entre empresas con factura |
| Fábricas (5 tipos) | Empresas, mercado | Farmacéutica; metalúrgica; granja (cultivos y animales que producen en vida y al sacrificarlos; leche → queso y mantequilla); alimentos procesados; gasolineras (regular, extra y premium, con precio según mantenimiento y daño a coches de lujo con gasolina barata). Son trabajos abiertos a cualquiera, con paga base y extra del dueño. Producción diaria y automatizada |
| Bolsa de valores | Empresas, mercado | Empresas que cotizan desde cierto nivel; el precio sube o baja según su actividad real y eventos automáticos; invertir desde el teléfono; capitalización como requisito para tener fábricas |
| Barrios y territorios (`pxd_turf`) | Organizaciones | Mapa dividido en barrios; influencia por grafitis, dealers, venta puerta a puerta, patrullas, presencia y robos; recompensas (ingreso pasivo, catálogo ilegal, HQ); mapa de influencia; grafitis con la identidad de la organización |
| Apps del teléfono | Lo anterior | Trabajos (comparar salarios), Bolsa, Próxima Noticias (titulares con efecto en el mercado), Banco |

## Oleada 3 · Vida social, Estado y mundo

| Sistema | Qué incluye |
|---|---|
| Vida social | Matrimonio (oficiante NPC, queda en el perfil; divorcio en el ayuntamiento con aviso), funerales y CK oficial (R.I.P. ya preparado en la selección de personaje) |
| Elecciones | Convocatoria en el teléfono, candidatos con gabinete y requisitos, los 3 mejores por estadísticas, partido configurable, votación de 48 h en el ayuntamiento, gobernador con rangos. Los funcionarios de carrera conservan su puesto |
| El Estado como negocio | Necesidades (salud pública, tranquilidad, crecimiento), encargos a otras organizaciones, impuestos en la paga según la gestión |
| Vehículos 3.0 (resto) | App de carreras con horarios, mecánico a domicilio y asistencia en carretera por nivel |
| Ciudad viva | Sillas interactuables, teléfonos públicos con eventos, NPCs con actividad |
| Cayo Perico | Ciclo plantación → secado → laboratorio → contrabando (lancha más lenta con más carga, fardos que caen al agua, entrega aérea, escáner de las fuerzas del orden); niveles de contrabandista; negocios y barrios en la isla |

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Paga cada 30 min | La abona el sistema (el Estado). Pasará a depender del gobierno electo y los impuestos en la oleada 3 |
| Identidad | Nombres propios. Por ejemplo, «Próxima Noticias» en lugar de marcas del juego o de otros servidores |
| Secciones «Idea de video» de la lista | Fuera de alcance del servidor |

## Pendiente del propietario

- **Hosting:** la prueba de Nodecraft caducaba hacia el 4 de noviembre. Sin servidor no se puede instalar ni probar en FiveM.
- **Ropa y vehículos mod:** requieren assets con licencia. No se añade ninguno sin confirmarlo.
