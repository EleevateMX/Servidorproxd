# 22. Investigación: sistemas de GTAHUB y plan para Próxima RP

> Referencia de **mecánicas** (no de textos, nombres ni arte). Informe de investigación con fuentes públicas (fragmentos de búsqueda) y capturas del propietario, 2026-11-02.


## Cómo se ha hecho y sus límites

No he podido abrir directamente ninguna página. En esta sesión fallan por DNS `gtahub.gg`, `en.gtahub.gg`, `foro.gtahub.gg`, `news.gtahub.gg`, `discord.com`, `youtube.com`, `forum.cfx.re`, `libertycity.net`, `laps4.com` y `pnkfacil.com`. Si se quieren leer completas, hay que permitir esos dominios en la configuración de red de la sesión.

Todo lo que sigue sale de **fragmentos de resultados de búsqueda** (WebSearch, unas 40 consultas en español, inglés y portugués) y de las **capturas del usuario**.

Algunos datos con fecha:
- Varios hilos del foro tienen de 3 a 5 años, de la época en que GTAHUB funcionaba en RAGE:MP.
- GTAHUB migró a FiveM en 2026, tras el cierre de RAGE:MP. Dice que no usa scripts populares de FiveM: todo es desarrollo interno ([FAQ oficial](https://news.gtahub.gg/sites/FA99222693eM/), [short](https://www.youtube.com/shorts/EZvSg1fxB-4)).
- En la migración se conservan personajes, vehículos, propiedades, inventarios, dinero, organizaciones, niveles, rasgos faciales, «ítems con marcas adulteradas» y el historial de sanciones ([GTAMAD](https://www.gtamad.com/roleplay/ragemp-cierra-y-gtahub-ya-tiene-plan-asi-sera-la-transicion-a-fivem-para-los-jugadores/)).

Para la columna «Próxima/Qbox» he mirado `recipe-qbox.yaml` y los recursos `pxd_*`, y he tomado el resto de tu descripción. Incluye Renewed-Banking, qbx_cityhall, qbx_management, qbx_vehicleshop, qbx_garages, qbx_customs, qbx_medical, qbx_properties, npwd con npwd_qbx_garages, etc. No incluye ningún recurso de robos, drogas, cárcel ni bomberos.

**Leyenda:** Estado = Nada / Parcial / Hecho · Esfuerzo = S / M / L · Prioridad = 1 (alta) a 3 (baja).

---

## 1. Catálogo de sistemas

### Economía
| Sistema | Cómo funciona en GTAHUB | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Efectivo y banco | El dinero va en mano y en el banco. La app «Banco Fleeca» está en el teléfono. | Captura del usuario | Hecho (qbx_core + Renewed-Banking) | Solo darle estilo a la app del banco en npwd | S | 2 |
| Moneda premium (HUBS / HUBCoins) | Se compra con dinero real y se gasta en VIP, vehículos exclusivos, muebles y ranuras. Además se sortea en streams. | [en.gtahub.gg/shop](https://en.gtahub.gg/shop), [foro, topic 12771](https://gtahub.gg/topic/12771/donador-caja-hubs), [Kinguin](https://www.kinguin.net/es/category/106656/gtahub-15-gift-card) | Nada | Ver el aviso del punto 4: vender moneda virtual puede estar prohibido por la PLA de 2026 | M | 3 |
| Comercio legal en zonas permitidas | Lo legal se compra y vende con anuncios, en negocios, en zonas seguras o en el «HubCenter». | [Reglas, topic 22](https://foro.gtahub.gg/topic/22/reglas-servidor) | Parcial (ox_inventory permite dar objetos) | Un punto de mercado entre jugadores y una app de Anuncios | M | 2 |
| Foodtrucks | Los jugadores venden comida recorriendo la ciudad en un camión. | [GTAHUB 2.0](https://news.gtahub.gg/sites/implementacion-gtahub-20-disponible-hoy) | Nada | Un vehículo-negocio con stock, cocina y venta | M | 2 |
| Alquiler de propiedades y moteles | Se compran propiedades para alquilarlas o para abrir un motel propio, como inversión pasiva. | GTAHUB 2.0 (misma URL) | Nada | Contratos de alquiler y cobro periódico sobre qbx_properties | L | 2 |
| Casino | Llegó con GTAHUB 2.0. Sus mecánicas no se ven en las fuentes. | [Vídeo](https://www.youtube.com/watch?v=VbsRe-pIz9Y) | Nada | Juegos con fichas compradas con dinero del juego. No debe tener ningún vínculo con dinero real | L | 3 |

### Trabajos
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Trabajos públicos | Hay puntos de trabajo de leñador, pescador, minero, basurero, camionero y granja. El pago es en efectivo. | [Reglas](https://gtahub.gg/topic/22/reglas-servidor/3), [Pescador](https://gtahub.gg/topic/19/job-pescador) | Hecho (pxd_jobs + qbx_*) | — | — | — |
| Nivel por trabajo | La experiencia de un trabajo sube el nivel de ese trabajo, no el del personaje. | [topic 19038](https://gtahub.gg/topic/19038/experiencia) | Parcial (está por comprobar en pxd_jobs) | XP y nivel por trabajo con mejoras de pago o de herramientas | M | 1 |
| Mecánico y taller | Para tunear hay que ser de una facción de mecánicos y estar en un taller. Sin mecánico presente sale mucho más caro. Las reparaciones van por zonas (cristales, carrocería, motor). | [topic 7160](https://gtahub.gg/topic/7160/sistema-mec%C3%A1nico-taller), [topic 20840](https://gtahub.gg/topic/20840/sistema-taller-mec%C3%A1nicos) | Hecho (qbx_mechanicjob, qbx_customs) | Aplicar el recargo cuando no hay ningún mecánico en servicio | S | 2 |
| Periodismo (Weazel) | Hay un medio de noticias con canal y web propios. Un devblog presentó un «sistema Weazel News». | [Devblog en X](https://x.com/gtahub_en), [canal](https://www.youtube.com/@weazelnews-gtahub3226) | Parcial (qbx_newsjob) | Publicar artículos desde el teléfono o el panel | M | 3 |
| Empresas sin sistema | Hay una guía para llevar empresas de rol que no dependen de un trabajo automatizado. | [topic 4533](https://gtahub.gg/topic/4533/guia-gesti%C3%B3n-de-empresas-sin-sistemas) | Parcial (qbx_management) | Caja de la organización, nóminas y facturas | M | 2 |
| Actividades con horario (p. ej. «Rescate arriesgado 08-09hs») y avisos de incendio | Actividades de servicio que se avisan y solo se abren en una franja horaria. | Captura del usuario | Nada | Programador de actividades y avisos a los que estén de servicio. Bomberos no está en Qbox | L | 2 |

### Crimen
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Robo a jugadores | Se hace desde un menú «R – Robar». Requiere nivel 5 y estar en una organización ilegal. Tope de $9.000 por víctima cada 24 h. No se puede robar a jugadores de nivel 3 o menos, cerca de edificios gubernamentales ni a quien esté haciendo transporte. | [Reglas](https://foro.gtahub.gg/topic/22/reglas-servidor) | Nada | Acción de robo validada en el servidor con nivel, tope, cooldown y zonas | M | 1 |
| Secuestro | Exige nivel 7 como mínimo. No se puede matar (PK) al secuestrado si coopera. | Reglas (misma URL) | Parcial (qbx_police: esposar y escoltar) | Comprobar el nivel en el servidor y crear un estado de «retenido» | S | 2 |
| Golpes (de robos pequeños al banco central) | Atracos escalonados. | [en.gtahub.gg](https://en.gtahub.gg/), [vídeo](https://www.youtube.com/watch?v=Z8M31Q5Ddlw) | Nada | Atracos por niveles con requisitos de policía conectada y de equipo | L | 1 |
| Mercados negros y negocios ilegales rotativos | Los puntos van cambiando de sitio, hay que encontrarlos dentro del rol y se pueden «tomar». | [topic 14857](https://gtahub.gg/topic/14857/mercado-negro/), [vídeo](https://www.youtube.com/watch?v=e_VIy2qEoKk) | Nada | Rotación de ubicaciones, stock y captura por organizaciones | L | 1 |
| Dealers | Hay un «sistema de dealers» que se puede tomar. Los detalles no se ven. | [Vídeo](https://www.youtube.com/watch?v=o86G9fHH4r0) | Nada | NPC o puntos de venta controlados por organizaciones (suposición) | M | 2 |
| Graffiti y control de zonas | Grupos y motor clubs disputan un área que marca el sistema. Solo pelean los participantes y dentro del radio. La policía no acude. No se permiten alianzas, ni salir o subir a un vehículo, ni curarse durante la disputa. | [Reglas](https://foro.gtahub.gg/topic/22/reglas-servidor), [foro](https://foro.gtahub.gg/groups/testers) | Nada (sí hay «rey de la colina» en pxd_gamemodes) | Reutilizar la lógica de zona del rey de la colina en mundo abierto, con dueño, temporizador y recompensa | M | 1 |
| Marcas adulteradas | Hay objetos con «marcas adulteradas». Suposición: armas o vehículos con número de serie borrado. | [GTAMAD](https://www.gtamad.com/roleplay/ragemp-cierra-y-gtahub-ya-tiene-plan-asi-sera-la-transicion-a-fivem-para-los-jugadores/) | Nada (ox_inventory admite metadatos de serie) | Un flag de serie limado y su búsqueda en la base de datos policial | S | 3 |
| Cárcel con economía | Prisión con economía interna, trabajos, eventos y misiones. Dentro se permiten estafas entre presos y la zona interior no es segura. Acumular delitos federales puede acabar en cadena perpetua, que se ejecuta como CK. | [en.gtahub.gg](https://en.gtahub.gg/), [Reglas](https://foro.gtahub.gg/topic/22/reglas-servidor) | Parcial (encarcelamiento básico de Qbox, por verificar) | Trabajos para reducir condena, economaticket y contador de delitos federales | L | 2 |

### Organizaciones
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Crear una organización | Se crea desde TAB → Organizaciones, eligiendo banda/organización o empresa y poniendo nombre. Tipos: empresa, grupo, motor club (MC) y gubernamental. | [topic 138](https://gtahub.gg/topic/138/sistema-creaci%C3%B3n-de-organizaciones), [en.gtahub.gg](https://en.gtahub.gg/) | Parcial (sección en pxd_panel + qbx_management) | Creación por los propios jugadores, rangos del 1 al 10 y permisos | M | 1 |
| Nivel de organización | Las organizaciones tienen nivel. Por ejemplo, la radio se desbloquea en el nivel 2. | [Reglas](https://foro.gtahub.gg/topic/22/reglas-servidor) | Nada | XP de organización y desbloqueos por nivel | M | 1 |
| Organizaciones oficiales | El staff las selecciona. Requisitos: más de 3 meses de antigüedad, nivel 2, rangos 9-10 por encima del nivel 10 y sin sanciones graves. Una mafia tiene que haber sido antes un grupo. | [topic 4286](https://gtahub.gg/topic/4286/informaci%C3%B3n-organizaciones-oficiales) | Nada | Estado «oficial» y flujo de solicitud en el panel de admin | S | 2 |
| Advertencias | Con 3 advertencias la organización se elimina. | Reglas | Nada | Contador de advertencias por organización | S | 2 |
| Ranuras de organización | El máximo es 2 organizaciones; el paquete Gold da una más (fuente de terceros). | [laps4](https://www.laps4.com/preguntas-y-respuestas/que-es-gtahub), captura | Nada | Ver el punto 4 | S | 3 |
| Certificación de grupo | Hay pruebas para certificar un grupo legal o ilegal. | [Vídeo](https://www.youtube.com/watch?v=Sssx7-QBHZ0) | Nada | Un examen dentro del juego | S | 2 |

### Vehículos
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Concesionarios y garajes | Varios concesionarios con modelos clasificados de 1/5 a 5/5 y vehículos que se pagan con HUBS. App «Garaje público». | [topic 5866](https://gtahub.gg/topic/5866/vehiculos-con-hubs), captura | Hecho (qbx_vehicleshop, qbx_garages, npwd_qbx_garages) | — | — | — |
| Limitador de velocidad y certificación Básica | Hace falta la «Certificación Básica» para quitar el limitador. Las certificaciones se gestionan en TAB → Perfil → Certificaciones y también se piden para entrar en organizaciones gubernamentales. | Captura; [foro](https://foro.gtahub.gg/) | Nada (qbx_cityhall da licencias, que no es lo mismo) | Examen teórico y práctico, licencia en el perfil y limitador en el cliente aplicado por el servidor | M | 1 |
| Transferir vehículos y multas | Desde los ajustes se transfieren vehículos. Las multas aparecen en el perfil. | Captura | Parcial (qbx_police tiene multas) | Pantalla en el panel para transferir y ver multas | S | 2 |

### Propiedades
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Propiedades personales y de organización | Casas, apartamentos, oficinas, negocios, almacenes y búnkeres. Los jugadores sin VIP tienen 2 ranuras. | [Discord](https://discord.com/servers/gtahub-718528656590503956), [topic 12771](https://gtahub.gg/topic/12771/donador-caja-hubs) | Parcial (qbx_properties) | Propiedades de organización y almacenes | M | 2 |
| Decoración | Muebles que se colocan libremente. Algunos se desbloquean por nivel y otros son Premium. | [topic 107](https://gtahub.gg/topic/107/sistema-personalizaci%C3%B3n-de-viviendas) | Parcial (pxd_props es un editor, pero no está ligado a viviendas) | Reutilizar pxd_props para decorar interiores con catálogo y desbloqueo por nivel | M | 1 |
| App Dynasty 8 | Inmobiliaria en el teléfono. | Captura | Nada | Una app npwd que liste las propiedades de qbx_properties | S | 2 |

### Progresión
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Nivel de personaje | Se sube de nivel al alcanzar el umbral de XP **o** el de horas jugadas, lo que llegue antes. Una hora equivale a 1 XP. Hay también un nivel de cuenta que suma las horas de todos los personajes. Un servidor aparece listado con «EXP x3». | [topic 23271](https://gtahub.gg/topic/23271/informaci%C3%B3n-sistema-de-niveles-personajes), [topic 19038](https://gtahub.gg/topic/19038/experiencia), [5metrics](https://5metrics.dev/servers) | Parcial (pxd_progress) | La doble condición, el nivel de cuenta y un multiplicador por evento | S | 1 |
| Desbloqueos por nivel | Robar a partir del nivel 5, secuestrar a partir del 7, muebles según nivel, rangos altos de organización desde el nivel 10. | Reglas, topic 107 | Nada | Una tabla central de requisitos que consulten el resto de recursos | S | 1 |
| Recompensas diarias, logros y temporadas | Pase Gratis/Plus con misión del día y temporadas (Halloween). Los logros van por categorías. | Captura | Hecho (pxd_progress) | Contenido de temporadas | S | 2 |
| Habilidades y fitness | Hay habilidades y una barra de «Fitness». | Captura | Nada | Estadísticas con natives de GTA (resistencia, fuerza, etc.), que hay que verificar en native-decls | M | 2 |
| «XP incrementar gastos» | No se sabe qué es. Suposición: un potenciador de XP que se paga o que va ligado a gastar. | Captura | — | Hay que aclararlo con el usuario | — | 3 |

### Social y eventos
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Eventos creados por jugadores | Se crean en el Ayuntamiento con un editor de mapa y pasan por revisión del staff. No hay ninguna fuente pública; solo una lista de clips de eventos. | Captura; [lista de reproducción](https://www.youtube.com/playlist?list=PLfkrCbl3yUqblf3EsC8nD8aF5maz6LqpK) | Parcial (pxd_props, blueprints, pxd_gamemodes, pestaña Eventos) | Un flujo de propuesta → revisión → programación → activación con `pxd.mjs` | M | 1 |
| Eventos oficiales y de temporada | Ejemplos: el Mundial 2026, donde cada jugador elige selección una sola vez y suma a un ranking; fines de semana con premio por tiempo jugado. | [GTAMAD](https://www.gtamad.com/roleplay/el-mundial-2026-llega-a-gtahub-y-quien-no-elija-seleccion-desde-el-primer-dia-lo-pagara-caro-en-el-ranking/), [TikTok](https://www.tiktok.com/@gtahubgg) | Parcial | Eventos de facción con ranking global | M | 2 |
| Referidos, encuestas «Responde y gana» y mascotas | Aparecen en la interfaz. No hay detalle público. | Captura | Nada | Código de referido con recompensa diferida, encuestas y mascota acompañante | S/M | 3 |
| Figuras coleccionables | Coleccionables en el juego que se regalan con el VIP de Tebex. No he encontrado ninguna fuente pública. | Captura | Nada | Objetos coleccionables y una vitrina | S | 3 |

### Monetización y VIP
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Niveles VIP (Golden, Diamond…) | Dan ranuras de personaje, de organización y de propiedad, una prioridad que no está clara, muebles Premium y renovación automática. | Captura; [shop](https://en.gtahub.gg/shop) | Parcial (Plus en recompensas diarias) | Ventajas Tebex solo estéticas o de comodidad (ver el punto 4) | M | 2 |

### Salud y necesidades
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Signos vitales | Hambre, sed, energía, salud y armadura. El diseño de las barras se puede configurar. | Captura | Hecho (qbx_core + pxd_hud), salvo la energía | Añadir energía y sueño | S | 2 |
| Curación | Analgésicos, vendas y botiquín, pero el rol de las heridas sigue siendo obligatorio. | [topic 224](https://gtahub.gg/topic/224/sistema-curaci%C3%B3n) | Hecho (qbx_medical) | — | — | — |
| Heridas y recuperación de cuerpos | Un devblog presentó heridas localizadas y la recogida de cuerpos. | [X @gtahub_en](https://x.com/gtahub_en) | Parcial | Cadáveres que los EMS tienen que trasladar | M | 2 |
| Muerte de personaje (CK) y «cementerio» | El CK es permanente; el cementerio guarda los personajes muertos. Hay un sistema para borrar nombres de CK. | [Reglas](https://foro.gtahub.gg/topic/22/reglas-servidor), [GTAHUB 2.0](https://news.gtahub.gg/sites/implementacion-gtahub-20-disponible-hoy), captura | Parcial (pxd_multichar) | Archivar el personaje en vez de borrarlo, liberar su nombre y mostrar una lápida en la selección | S | 1 |

### Teléfono
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Apps | Llamadas, Mensajes, Contactos (con punto verde si el contacto está conectado), Anuncios, Cámara, Galería, Calculadora, Ajustes, Organizaciones, Taxi, Emergencias, Dynasty 8, Eventos, Banco, Recetas, Garaje. GTAHUB 2.0 añadió cabinas telefónicas. | [topic 66](https://gtahub.gg/topic/66/sistema-tel%C3%A9fono-celular), captura | Parcial (npwd cubre las básicas y el garaje) | Apps propias de Organizaciones, Taxi, Emergencias, Eventos, Recetas y Dynasty 8 | M | 1 |

### Staff y normas
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Tabla de sanciones | Cada artículo tiene una pena en minutos y un multiplicador por reincidencia (por ejemplo, PG 45 min +30 %; robos 240 min +100 %). El historial es permanente y limita el acceso a organizaciones gubernamentales. Al acumular 5 sanciones hay una consecuencia; el fragmento no dice cuál. | [topic 33460](https://gtahub.gg/topic/33460/informaci%C3%B3n-sanciones), [apelaciones](https://gtahub.gg/topic/26457/informaci%C3%B3n-apelaciones) | Parcial (panel de admin) | Calcular sanciones por artículo con escalado y apelaciones | M | 1 |
| Zonas seguras, CK/PKT y venganza | Las zonas seguras incluyen concesionarios y el exterior de la prisión. Tras morir, no se puede volver al lugar en 30 min (la policía, en 5 min). | Reglas | Nada | Polígonos de zona segura que bloqueen acciones agresivas en el servidor | S | 1 |
| F9, /duda y «mi conducta» | Soporte y reportes con F9, preguntas con /duda y una vista del propio historial de conducta. | Captura | Parcial (reportes) | Canal /duda y vista «mi conducta» | S | 2 |

### Interfaz
| Sistema | Cómo funciona | Fuente | Próxima | Qué falta | Esf. | Prio. |
|---|---|---|---|---|---|---|
| Ajustes | Limitador, renovación de VIP, ver la hora en el chat, avisos de servicio, borrar personaje (CK), transferir vehículos, cambiar nombre, enlazar Discord, tamaño de texto y HUD, diseño de barras. | Captura | Parcial (pxd_panel → Ajustes) | Completar las opciones | S | 2 |
| GTAHUB 2.0 (otros) | Aeropuerto con hangares, rappel, guantes, buceo con aletas y botellas, outfits. | [GTAHUB 2.0](https://news.gtahub.gg/sites/implementacion-gtahub-20-disponible-hoy) | Parcial (qbx_diving, illenium-appearance) | Rappel y hangares | M | 3 |

---

## 2. Las mecánicas más diferenciales de GTAHUB (por valor para Próxima)

1. **El nivel como llave de todo:** XP u horas, lo que llegue antes, y desbloqueos para robar, secuestrar, decorar y subir de rango. Es la base que hace que el resto funcione y Próxima ya tiene la mitad hecha.
2. **Organizaciones creadas por los jugadores**, con niveles, rangos, advertencias y estado «oficial» otorgado por el staff.
3. **Control de zonas y graffiti** con reglas de combate acotadas. Se puede reutilizar el rey de la colina.
4. **Mercados negros y negocios ilegales rotativos**, que se pueden tomar.
5. **Golpes escalonados**, de robos pequeños al banco central.
6. **Robo a jugadores reglado por el sistema**: tope diario, nivel mínimo y protección a novatos.
7. **Certificaciones**: la Básica para quitar el limitador y las que piden las organizaciones gubernamentales.
8. **Eventos de jugadores con editor y revisión del staff.** Es el punto fuerte natural de Próxima gracias a pxd_props y los blueprints.
9. **Cárcel con economía, trabajos y estafas**, y la cadena perpetua como CK.
10. **CK con cementerio**, liberación de nombres y multipersonaje.
11. **Sanciones con artículo, minutos y reincidencia**, más un historial «mi conducta» visible para el jugador.
12. **Propiedades decorables con desbloqueo por nivel, alquileres y moteles.**
13. **Teléfono con apps de servicio** (Taxi, Emergencias, Organizaciones, Eventos, Dynasty 8).
14. **Eventos de temporada con facciones y ranking**, como el Mundial.
15. **Actividades de servicio con horario y avisos de incendio.**

---

## 3. Lo que no se puede verificar públicamente

- Las ventajas exactas y precios de **Golden y Diamond**, la equivalencia **HUBS/HUBCoins** (podrían ser la misma moneda), la renovación automática y las «ranuras VIP» de organización. La regla de «2 organizaciones + 1 con Gold» viene solo de laps4, una fuente de terceros.
- **Hubnko Toys:** ninguna búsqueda devuelve el término.
- Referidos, «Responde y gana», mascotas, habilidades, Fitness, «XP incrementar gastos», recetas y la misión del día: solo los respaldan las capturas.
- El **editor de eventos del Ayuntamiento** y cómo es la revisión del staff.
- Cómo funcionan por dentro mercados negros, dealers, golpes, graffiti (temporizadores y recompensas), la cárcel y el casino.
- Las cifras actuales de niveles: el hilo de niveles tiene unos 4,5 años y contiene una contradicción interna. Las reglas tienen dos versiones distintas, de hace unos 166 y unos 274 días.
- Qué significa «marcas adulteradas»: lo de los números de serie es una suposición.
- El servidor brasileño. Solo constan `discord.gg/gtahubbrasil` y `@GTAHUB_BR`, enlazados desde en.gtahub.gg; no hay detalle de sistemas. De Pegasus solo hay un listado con el nombre «GTAHUB.GG 2.0 | PEGASUS» ([gs4u](https://www.gs4u.net/en/s/374413.html)).
- Las búsquedas sobre mascotas devolvieron un repositorio de GitHub (EleevateMX/oficinacentral) que no es el servidor de juego. Lo he descartado.

---

## 4. Aviso sobre monetización (no es consejo legal)

Lo que dicen las fuentes:
- Cfx.re exige **Tebex** como único proveedor de pagos ([docs.fivem.net](https://docs.fivem.net/docs/server-manual/setting-up-a-tebex-store/)).
- Según la **Creator PLA actualizada en enero de 2026**, citada por fuentes secundarias, se prohíben las cajas de botín o *gacha*, los sorteos de pago y la **venta de moneda virtual** ([GameServerKings](https://www.gameserverkings.com/knowledge-base/fivem/server-monetisation/), [PrismNews](https://www.prismnews.com/hobbies/gta/cfxre-creator-pla-update-threatens-fivem-and-redm-monetization-models)).
- Las guías de terceros desaconsejan las ventajas jugables de pago. No he encontrado una definición oficial de *pay-to-win*.

Partes de un modelo tipo GTAHUB que podrían chocar con esas normas:
- **Moneda premium (HUBS)** comprada con dinero real: es el riesgo más claro con la PLA de 2026.
- **Vehículos exclusivos de pago**, sobre todo si rinden mejor que los del juego.
- **Más ranuras de organización o de propiedades**, que dan capacidad económica o territorial.
- **Potenciadores de XP o «EXP x3» de pago**, y **muebles Premium** si dan alguna función.
- **Coleccionables que se regalan con VIP**, si son aleatorios. Lo aleatorio cae en la prohibición de *gacha*.
- La **prioridad en la cola** o ventajas vendidas por Patreon u otras vías fuera de Tebex.

Opciones de menor riesgo aparente: estética (ropa, colores, marcos de perfil), ranuras de personaje y comodidades sin efecto económico. Conviene confirmar con el texto vigente en fivem.net/terms y con Tebex antes de vender nada.

---

**Fuentes principales consultadas** (todas por fragmentos de búsqueda): en.gtahub.gg; en.gtahub.gg/shop; foro.gtahub.gg/topic/22; gtahub.gg/topic/138, 107, 66, 224, 4286, 4533, 5866, 7160, 12771, 14857, 19, 19038, 20840, 23271, 26457 y 33460; news.gtahub.gg (FAQ y GTAHUB 2.0); gtamad.com (2 artículos); x.com/gtahub_en; los vídeos de YouTube citados; docs.fivem.net; gameserverkings.com; prismnews.com.