# 41. Economía viva: paga cada 30 minutos, impuestos y mercado fluctuante

**Estado:** implementado en `pxd_economy` 0.2.0 con 26 pruebas automáticas (`tests/lua/test_economy_live.lua`). No instalado en Nodecraft, no probado en FiveM.

## 1. Paga cada 30 minutos

| Regla | Valor (`Config.payroll`) |
|---|---|
| Cada cuánto | 30 minutos de **tiempo activo**: conectado, con personaje, no ausente y con derecho a paga |
| Importe | Sueldo del rango en qbx_core (`shared/jobs.lua`, pensado para 10 min) × 3. El ingreso por hora no cambia |
| Sin trabajo | Ayuda de $30 por ciclo (`unemployedAid`) |
| Con trabajo, fuera de servicio | No acumula ni cobra (`offDutyAid = 0`), salvo trabajos con `offDutyPay` |
| Ausente (AFK) | 10 minutos sin moverse 2 m ni girarse 15°: deja de acumular. Al volver sigue donde estaba |
| Quién paga | El Estado (dinero nuevo). `society[trabajo] = true` hace que pague la cuenta de la empresa en Renewed-Banking (A-1 de docs/31) |
| Impuesto | `Config.taxes.payroll` (0 por defecto) |
| Reconectar | El progreso se guarda en `pxd_payroll` y se recupera: no se reinicia |
| Doble paga | Imposible: la base de datos solo acepta un cobro por ciclo y personaje |

**Un solo dueño de la nómina.** Elegí nómina propia en `pxd_economy` y que qbx_core ceda la suya con un parche de una línea en su `sendPaycheck` (`if GlobalState.pxdPayroll then return end`). Cambiar solo `paycheckTimeout` a 30 no servía: qbx_core no descuenta impuestos, no distingue ausentes, no da desglose y paga a todos a la vez desde el arranque.

Protecciones para que nunca paguen los dos:
- Sin el parche, `pxd_economy` **no paga** y sigue pagando qbx_core (aviso en consola).
- Si `pxd_economy` se detiene, `GlobalState.pxdPayroll` pasa a `false` y qbx_core vuelve a pagar.
- Si el parche se aplicó sin reiniciar (qbx_core aún paga con su configuración en memoria), `pxd_economy` lo detecta por `qbx_core:server:onPaycheck` y cede la nómina hasta el siguiente arranque. Los primeros 11 minutos tras arrancar no se paga (el tiempo sí cuenta), para detectarlo antes.

**Lo que ve el jugador:** aviso «Día de paga» con el neto, el sueldo o la ayuda, el impuesto, las multas y facturas pendientes y cuándo es la siguiente.

**Para el HUD:** state bag `pxdPayday` del jugador (`active`, `remaining`, `interval`, `afk`, `eligible`) y export de cliente `GetPaydayMinutes()`.

**Registro:** cada paga entra en el libro de flujo con el motivo `pxd-nomina` (categoría «Nóminas» de `/economia`) y en `pxd_audit` (`economia` / `nomina`).

**Prueba en el servidor:** `pxd_nomina <id>` en la consola adelanta la paga de un jugador.

## 2. Mercado fluctuante

Precios de referencia de 25 bienes (materias primas, taller, herramientas, salud, alimentos, bebidas y combustible). Los 24 que son objetos usan ítems que existen en la receta de Qbox; el combustible aún no es un ítem.

Cada 15 minutos el precio de cada bien:
- sube con la demanda neta y baja con la oferta neta registradas (hasta ±3 %);
- vuelve un 5 % de la distancia hacia su precio base;
- reacciona a las noticias activas;
- tiene un ruido de ±0,4 %, no cambia más de un 5 % por tick y nunca sale de su mínimo y máximo.

**Noticias:** automáticas (10 plantillas en `Config.market.events`, 8 % de probabilidad por tick), por operaciones reales («Sube la demanda de agua: el precio aumenta un 3 %») o publicadas por otro sistema o el staff.

**Qué mueve ya el mercado (sin parches):**
- las compras en tiendas de ox_inventory (hook `buyItem`);
- repostar en ox_fuel (su export `setPaymentMethod`: se cobra exactamente lo mismo y se anota la demanda; al parar `pxd_economy`, ox_fuel recupera su cobro).

**Qué no hace todavía:** cambiar el precio que cobran las tiendas y los surtidores. En ox_inventory el precio sale de `data/shops.lua` y se envía al abrir la tienda; en ox_fuel lo calcula el cliente con `config.priceTick`. Cambiarlo exige sustituir esas partes, y se hará con los negocios y las gasolineras.

**Comandos:** `/mercado` (staff, `pxd.economy.view`) y `/mercado_evento <bien o categoría> <%> <minutos> <titular con {pct}>` (`pxd.economy.manage` o consola).

### Exports de servidor

| Export | Devuelve |
|---|---|
| `GetPrice(id, exact?)` | Precio entero ≥ 1 listo para cobrar (`exact` = con decimales). `id` = bien o nombre del ítem |
| `GetPrices()` | Lista de bienes con precio, base y variación |
| `RecordTrade(id, 'buy' \| 'sell', cantidad)` | `true` si se anotó. `buy` = un jugador compra (demanda) |
| `GetHistory(id, horas)` | `{ at, price, bought, sold }` para gráficas |
| `GetNews(límite, desdeId?)` | Titulares recientes con su efecto, para las apps de noticias y bolsa |
| `AddMarketEvent({ headline, good \| category, pct, minutes })` | Publica una noticia con efecto |
| `GetMarketIndex()` | 100 = todo en su precio base |
| `GetPaydayStatus(src)`, `MarkActive(src)` | Estado de la paga; otra señal de actividad para el anti-AFK |
| `GetTaxRate(tipo)`, `GetTaxSummary(horas)` | Tasa e importe recaudado |

Eventos de servidor: `pxd_economy:marketNews` (cada titular) y `pxd_economy:marketTick` (índice).

## 3. Impuestos (solo la base)

- Tasas en `Config.taxes`: `payroll` e `invoices`, las dos a 0. Tope del 50 %.
- En la paga se retiene del bruto. En las facturas lo paga el negocio: el cliente paga lo mismo y la empresa recibe el resto.
- Lo recaudado se registra siempre en `pxd_tax_ledger` y se ingresa en la cuenta `estado` de Renewed-Banking.
- La cuenta se crea con el export `CreateJobAccount` de Renewed-Banking 2.1.4, que admite cualquier id. **Limitación:** si Renewed-Banking no la deja disponible en esa sesión, el registro queda con `deposited = 0` y se avisa en consola; suele bastar con reiniciar.
- Con las tasas a 0 no se crea la cuenta ni ningún registro.
- `/economia` muestra los impuestos recaudados y el índice del mercado.

## 4. Datos

Tablas nuevas, creadas con `CREATE TABLE IF NOT EXISTS`: `pxd_payroll`, `pxd_tax_ledger`, `pxd_market_prices`, `pxd_market_history` y `pxd_market_news`. No se toca ninguna existente.

## 5. Instalación

1. Parche de qbx_core (`scripts/update-plan.json` y receta): `config/server.lua`, función `sendPaycheck`.
2. `pxd_update` y **reiniciar** el servidor. Hasta reiniciar sigue pagando qbx_core.
3. En la consola no debe salir «Paga de Próxima desactivada».

## 6. Solo se comprueba dentro de FiveM

- Que la paga llegue a los 30 minutos y qbx_core ya no pague cada 10.
- El aviso «Día de paga» y que el anti-AFK no castigue a quien rolea quieto (ajustar `afk`).
- Que comprar en una tienda y repostar muevan el precio en `/mercado`.
- Que repostar cobre lo mismo que antes.
- La creación de la cuenta `estado` al activar un impuesto.
