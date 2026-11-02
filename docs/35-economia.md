# 35. Economía conectada (etapa A): `pxd_economy`

**Estado:** implementado y con pruebas automáticas (20 en Lua). No instalado en Nodecraft, no probado en FiveM.

## Qué hace

| Pieza | Backlog | Cómo |
|---|---|---|
| **Facturas** | A-3, A-4 | Un trabajador de servicio factura a un cliente cercano. La factura queda **pendiente**: no se cobra sola. El cliente paga todo o una parte (efectivo o banco) y el dinero entra en la **cuenta del trabajo en Renewed-Banking**, con un movimiento en su historial. |
| **Cobro seguro** | X-4 | `PXDMoney.chargeToAccount` (export `ChargeToAccount`): comprueba el saldo, cobra, marca y luego ingresa. Si falla cualquier paso, devuelve el dinero. Nunca deja saldo negativo. |
| **Flujo de dinero** | A-8 (base) | Escucha cada cambio de dinero de qbx_core (`QBCore:Server:OnMoneyChange`), lo agrupa por hora, motivo, tipo y sentido, y lo guarda cada minuto. Los movimientos desde $25 000 se guardan aparte y salen en la consola. |
| **Resumen para el staff** | A-8 | `/economia [horas]`: lo que entra, lo que sale, el neto (dinero creado o retirado), un desglose por categoría con los motivos principales, el dinero en circulación y los movimientos grandes. |

Todas las acciones con facturas quedan en `pxd_invoice_events` y, si `pxd_audit` está en marcha, también en la auditoría común (categoría `economia`).

## Uso en el juego

- **`/factura`:** abre el formulario (ID del cliente, importe y concepto). También vale `/factura <id> <importe> <concepto>`.
  - Trabajos que facturan por defecto: mecánico, grúa, taxi, EMS, inmobiliaria, concesionario y abogado.
  - La policía no factura: multa con pxd_justice.
- **`/facturas`:** tus facturas pendientes, con un botón para pagar (importe y forma de pago) y el historial. Si tu trabajo factura, también ves sus facturas abiertas y puedes cancelarlas si las emitiste tú o eres jefe.
- **`/factura_cancelar <id> [motivo]`:** staff (`pxd.economy.manage`) o consola.
- **`/economia [horas]`:** staff (`pxd.economy.view`) o consola. Por defecto, 24 horas.

## Reglas

| Regla | Valor (`config.lua`) |
|---|---|
| Importe máximo | $50 000 |
| Facturas abiertas de un mismo trabajo a un mismo cliente | 5 |
| Distancia máxima al emitir | 5 m, mismo bucket |
| Pago | Lo pedido, limitado a lo que falta; estados pendiente → parcial → pagada |
| Intereses, recargos o cobros automáticos | No hay |

## Datos

Tablas nuevas, creadas con `CREATE TABLE IF NOT EXISTS`. No toca ninguna existente.

| Tabla | Contenido |
|---|---|
| `pxd_invoices` | Facturas |
| `pxd_invoice_events` | Historial de cada factura |
| `pxd_money_flow` | Acumulado por hora |
| `pxd_money_large` | Movimientos grandes |

## Cómo clasifica el dinero

| Categoría | De dónde sale |
|---|---|
| Nóminas | qbx_core paga la nómina sin motivo y justo después lanza `qbx_core:server:onPaycheck`. Ese ingreso se reclasifica como nómina |
| Efectivo del inventario | Con ox_inventory, el efectivo es el ítem `money` y qbx_core se sincroniza con `SetMoney('cash', n, 'Sync cash with inventory')`. La diferencia se calcula con el saldo conocido. Aquí entran juntas tiendas, entregas y robos en efectivo: el motivo real no llega a qbx_core |
| Multas y facturas | Por su motivo (`pxd-multa-<id>`, `pxd-factura-<id>`) |
| Otras | Patrones en `Config.categories`. Lo que no encaja queda en «otros», con su motivo visible en `/economia` para ir afinando |

**Pendiente de verificar en el servidor real:** los textos de motivo que usan los recursos de terceros (concesionario, tuneo, Renewed-Banking…). Ajustar los patrones con lo que muestre `/economia`.

## Pendiente de la etapa A

| # | Estado |
|---|---|
| A-1 Nóminas con fondos de la empresa | **Decisión del propietario:** presupuesto de los trabajos públicos. `paycheckSociety` sigue en `false`. Activarlo sin fondos dejaría sin cobrar a los empleados (qbx_core no paga si la cuenta no llega) |
| A-2 Transferencias | Ya existen en Renewed-Banking; quedan para la app de banco (E-1) |
| A-5 Ventas de negocios, A-6 mantenimiento, A-7 impuestos | Dependen de las etapas B/C y de decisiones económicas |
| A-8 Cuentas de empresa en el resumen | Saldo total de Renewed-Banking: pendiente de verificar su tabla |
| A-9 Dinero «de la nada» | Aparecerá en `/economia` como entradas sin salida: primero se mide, luego se corrige |

## Instalación en el servidor en marcha

1. Subir `pxd_economy` (va en el paquete).
2. Pegar las líneas nuevas de `permissions.pxd.cfg`: el permiso de escritura y las dos ACE.
3. `pxd_update`, que lo añade al arranque, y reiniciar.
4. Comprobar en la consola: sin errores de `pxd_economy`, y `economia` (desde la consola) muestra el resumen.
