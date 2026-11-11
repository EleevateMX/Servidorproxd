# 45. Entrega de la oleada 1

- **Paquete:** `proxima-oleada-1-544d211.zip`. Trae los 26 recursos `resources/[proxima]/*` del commit `544d211`, más `permissions.pxd.cfg` y `proxima.cfg` (fijado a `544d211`). No lleva datos persistentes.
- **Recursos nuevos:** `pxd_garage`, `pxd_ui` y `pxd_orgs`.
- **Estado:** implementado y con pruebas automáticas (494 en Lua y 81 en Node). **No instalado ni probado en FiveM.**

## Qué trae

| Sistema | Resumen | Doc |
|---|---|---|
| Economía viva | Paga cada 30 min de tiempo activo con desglose; mercado de 25 bienes que fluctúa; impuestos a 0 % | 41 |
| Organizaciones y bandas | `/org`: fundar, miembros y rangos, fondos, identidad, reputación | 42 |
| Interfaz y HUD 2.0 | Avisos, indicación de tecla, progreso y diálogos propios; HUD a pie y en vehículo; `/hud`, `/hudcine` | 43 |
| Vehículos | Taller propio con vista previa, tuning con estadísticas, mecánicos por nivel | 44 |
| Rangos de staff | `/darrango`, `/quitarrango`, `/checkas` | 37 |

## Instalación

**0. Antes de empezar**
- Sin jugadores conectados.
- Copia de Nodecraft y dump de la base de datos. Esta entrega crea tablas nuevas.

**1. Subir el paquete.** Sube el zip a `servers/PrxmaRPQbox_E83FED.base/`, descomprímelo y acepta sobrescribir. En `resources/[proxima]` debe haber 26 carpetas.

Si pusiste tu línea `add_principal … group.superadmin` en `permissions.pxd.cfg`, vuelve a añadirla, o mejor ponla en `server.cfg`.

**2. Restart.** Lee los permisos nuevos: el actualizador recibe permiso de escritura en `qbx_customs`, `qbx_mechanicjob` y `Renewed-Banking`, y `pxd_admin` puede aplicar rangos.

**3. Live Console: `pxd_update`.**
Deberías ver:
- 14 «Ajustado …»:
  - `qbx_core/config/server.lua` (nómina);
  - `ox_lib/resource/interface/client/*.lua` (×9, interfaz);
  - `qbx_customs` (×2);
  - `qbx_mechanicjob/server/main.lua`;
  - `Renewed-Banking/server/framework.lua`;
- «Iniciado pxd_ui / pxd_garage / pxd_orgs»;
- una copia de seguridad nueva. Apunta su id.

🛑 Detente si sale «no está el texto esperado», «falta el permiso» o un SCRIPT ERROR.

**4. Restart.** En el arranque no debe haber ningún aviso de `pxd_admin` sobre configuración faltante.

## Pruebas dentro de FiveM

| # | Prueba | ✔ si… |
|---|---|---|
| 1 | HUD a pie | Anillos de estado, brújula con calle, dinero, «Paga en N min» |
| 2 | HUD en vehículo | Velocímetro, marcha, combustible, cinturón, luces |
| 3 | `/hud` y `/hudcine` | Ajustes que se guardan; modo cine oculta todo |
| 4 | Avisos y progreso | Cualquier aviso de Qbox, la indicación de tecla y una barra de progreso (por ejemplo, reparar) salen con el diseño de Próxima |
| 5 | Paga | A los 30 min activos llega «Día de paga» con desglose; qbx_core ya no paga cada 10 min. Para probar desde la consola: `pxd_nomina <id>` |
| 6 | AFK | 10 min quieto: el contador de paga no avanza |
| 7 | `/mercado` (staff) | Lista de precios; comprar en una tienda o repostar mueve la demanda |
| 8 | `/org` | Fundar con otro jugador cerca; el staff la aprueba; aparece el rango |
| 9 | Organización | Invitar, ascender, aportar y retirar fondos, cambiar color y tipografía |
| 10 | Taller (E en un taller del mapa) | Interfaz nueva; cada cambio se ve en el coche; «Salir» lo deja como estaba |
| 11 | Pagar en el taller | Cobra el total, guarda y persiste tras guardar y sacar del garaje |
| 12 | Tuning | Las estadísticas cambian al montar motor o turbo |
| 13 | `/mecanico` | Muestra nivel y experiencia |
| 14 | `/darrango`, `/checkas` | Rango aplicado al momento; permisos en ✔ |

## Pendiente y no verificado

- Si las estadísticas del taller reflejan los mods (los natives existen; falta verlo en el juego).
- Los fondos de una organización recién aprobada: con el parche deberían estar disponibles en la misma sesión; si no, tras el siguiente reinicio.
- El precio dinámico en tiendas y surtidores llega con las empresas (oleada 2).
- Menús contextuales, radial, scoreboard y banco siguen con el tema anterior.

## Volver atrás

- **Parches de terceros:** `pxd_update rollback <id del paso 3>`. ox_lib, qbx_core y los demás vuelven a su comportamiento original.
- **Lo demás:** restaura la copia de Nodecraft.
- **Tablas nuevas:** `pxd_payroll`, `pxd_market_*`, `pxd_tax_ledger`, `pxd_orgs*` y `pxd_mechanic_*` pueden quedarse.
