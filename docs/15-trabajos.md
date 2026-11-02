# 15. Trabajos y propiedades

Fase 2 de la hoja de ruta. Primero se usa lo **oficial de Qbox** (mantenido, en español); lo que falta lo programamos en **`pxd_jobs`**.

## Qué trabajos hay

Investigación (nov-2026): en las listas de trabajos civiles de los servidores de rol se repiten **reparto, pesca, minería, granja y leñador**, además de los clásicos de Qbox (policía, EMS, mecánico, taxi, camionero, grúa, basurero, autobús, periodista). La mayoría de servidores abre con 3–5 trabajos legales con gente y va sumando.

| Trabajo | Recurso | De dónde sale | Cómo se consigue en el juego | Pago |
|---|---|---|---|---|
| Policía (LSPD/BCSO/SASP) | `qbx_police` | Qbox (ya en la fase 1) | Lo asigna el staff o el jefe (`qbx_management`) | Sueldo por rango (qbx_core) |
| EMS | `qbx_ambulancejob` | Qbox (ya en la fase 1) | Staff / jefe | Sueldo por rango |
| Mecánico | `qbx_mechanicjob` | Qbox (receta oficial completa) | Staff / jefe | Sueldo por rango + reparaciones |
| Grúa | `qbx_towjob` | Qbox | Ayuntamiento → Empleo | Por vehículo remolcado |
| Taxi | `qbx_taxijob` | Qbox | Ayuntamiento → Empleo | Taxímetro |
| Camionero | `qbx_truckerjob` | Qbox | Ayuntamiento → Empleo | Por entrega |
| Basurero | `qbx_garbagejob` | Qbox | Ayuntamiento → Empleo | Por ruta |
| Autobús | `qbx_busjob` | Qbox | Ayuntamiento → Empleo | Por parada |
| Periodista | `qbx_newsjob` | Qbox | Ayuntamiento → Empleo | Sueldo por rango |
| Reciclaje | `qbx_recyclejob` | Qbox | Abierto a todos | Materiales |
| Buceo | `qbx_diving` + `qbx_divegear` | Qbox | Abierto a todos | Coral |
| Viñedo | `qbx_vineyard` | Qbox | Abierto a todos | Uvas / vino |
| Desguace | `qbx_scrapyard` | Qbox | Abierto a todos | Piezas |
| **Minero** | `pxd_jobs` | Propio | Alta en la cantera (Davis Quartz) | 35 $ por mineral |
| **Leñador** | `pxd_jobs` | Propio | Alta en el aserradero de Paleto | 30 $ por tronco |
| **Pescador** | `pxd_jobs` | Propio | Alta en el muelle de Del Perro | 45 $ por pescado |
| **Repartidor** | `pxd_jobs` | Propio | Alta en el depósito | 120 $ + 60 $/km |

Casas y apartamentos: **`qbx_properties`** (oficial). Crea sus tablas al arrancar y también quita el aviso de qbx_core «Table 'properties' does not exist». Con `qbx_spawn`, al crear un personaje nuevo se elige apartamento.

No verificados (pendientes): `qbx_hotdogjob` (el trabajo `hotdog` existe en qbx_core, pero no hay repositorio público) y un trabajo de granjero (no hay recurso oficial; candidato para `pxd_jobs`).

## pxd_jobs (trabajos propios)

- **Recolección** (minero, leñador, pescador): darse de alta → ir a un punto de trabajo → la animación dura lo que diga la config → se acumula carga → vender en el punto de venta.
- **Reparto**: darse de alta → recoger paquete en el depósito → seguir la ruta del mapa → entregar con **E**. Los destinos son las calles de la ruta oficial de basura de Qbox.
- Con **ox_target** (viene con Qbox) se interactúa mirando el punto; sin él, marcador + **E**. `/dejartrabajo` cerca del punto de alta para darse de baja.
- **El servidor valida todo:** que tengas el trabajo (principal en Qbox), la distancia a cada punto, que la tarea dure lo que tiene que durar, enfriamiento por punto, carga máxima, velocidad mínima de entrega (anti-teletransporte) y un **tope de 6000 $ por hora** (`Config.maxEarningsPerHour`).
- Paga con `exports.qbx_core:AddMoney(src, 'cash', …)` y avisa a `pxd_progress` (`Track(src, 'job_task', 1)`) para misiones y logros.
- Los trabajos se registran en Qbox al arrancar con `exports.qbx_core:CreateJobs(…, false)` (en memoria, sin tocar los archivos de qbx_core).

### Ajustar puntos desde el juego

Las coordenadas de la cantera, el aserradero, el muelle y el depósito son **aproximadas: hay que revisarlas en el juego**. Con el permiso `pxd.jobs.edit` (staff):

```
/pxd_jobpunto <miner|lumberjack|fisher|courier> <work|sell|drop|signon|depot>
```

Añade un punto donde estés (`work`, `drop`) o mueve el punto de venta, alta o depósito (`sell`, `signon`, `depot`). Se guarda en `pxd_jobs/data/points.json` y se aplica al momento a todos.

Pagos, tiempos, enfriamientos y puntos se cambian en `pxd_jobs/config.lua`.

## Instalar en el servidor que ya está en marcha

La receta solo se ejecuta al crear el servidor. En el servidor de Nodecraft que ya funciona:

1. **Trabajos oficiales:** en el gestor de archivos de Nodecraft, sube cada carpeta (`qbx_mechanicjob`, `qbx_towjob`, `qbx_taxijob`, `qbx_truckerjob`, `qbx_garbagejob`, `qbx_busjob`, `qbx_newsjob`, `qbx_recyclejob`, `qbx_diving`, `qbx_divegear`, `qbx_vineyard`, `qbx_scrapyard`, `qbx_properties`) a `resources/[qbx]/`. Se descargan de `https://github.com/qbox-project/<nombre>` → Code → Download ZIP (quitar el sufijo `-main` de la carpeta). No hace falta tocar el `server.cfg`: `ensure [qbx]` ya los arranca.
2. **pxd_jobs:** súbelo a `resources/[proxima]/` y añade `ensure pxd_jobs` y `add_ace group.admin pxd.jobs.edit allow` en el CFG Editor.
3. Reinicia el servidor desde txAdmin.
