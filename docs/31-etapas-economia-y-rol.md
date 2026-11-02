# 31. Backlog de las etapas A–E: economía y rol conectados

**Requisito previo:** las fases 0 y 1 deben estar instaladas en Nodecraft y probadas dentro de FiveM (docs/26, docs/32).
Las etapas se pueden **diseñar** a la vez, pero se **implementan** en este orden: A → B → C → D → E.

## Reglas que cumple todo sistema nuevo

1. Un solo dueño por cada tipo de dato:
   - personaje: qbx_core;
   - dinero personal: qbx_core;
   - cuentas de empresa: Renewed-Banking;
   - inventarios: ox_inventory;
   - vehículos: qbx_vehicles;
   - viviendas: qbx_properties;
   - teléfono: npwd;
   - progreso: pxd_progress;
   - identidad pública: pxd_interact;
   - multas: pxd_justice.
2. Persistencia en MariaDB: tablas con el prefijo `pxd_`, creadas con `CREATE TABLE IF NOT EXISTS`. Las migraciones nunca son destructivas y llevan un número de versión.
3. El servidor valida todo. El cliente solo pide.
4. Cada movimiento de dinero tiene **origen, destino, motivo y autor**. Se registra en Renewed-Banking (`handleTransaction`) y en la auditoría común.
5. Permisos con ACE `pxd.<módulo>.<acción>` y rangos de qbx_core. Están documentados.
6. Las interfaces usan el sistema de diseño común (`design/ui`). Ninguna muestra datos inventados.
7. Pruebas automáticas, más una prueba real en FiveM antes de marcar «probado».
8. Todo despliegue es reversible (pxd_updater con copia de seguridad, docs/27).

## Piezas comunes (antes de la etapa A)

| # | Tarea | Depende de |
|---|---|---|
| X-1 | ✔ implementado (docs/34) · **Auditoría común** `pxd_audit`: export `Log(actor, accion, objetivo, datos)`, tabla `pxd_audit` y consulta en pxd_admin. La usan multas, hospital, economía, propiedades y organizaciones | — |
| X-2 | **API de avisos** `pxd_ui:notify` que use el estilo común (ox_lib con el tema de Próxima en cuanto se integre `wt/oxlib`) | Fase 3 (interfaces) |
| X-3 | **Permisos**: tabla de ACE `pxd.*` y ayudante `HasPermission(src, perm)` | — |
| X-4 | **Dinero seguro**: función común `Charge(src, importe, motivo, {cash, bank})` y `Pay(cuenta, importe, motivo)` con comprobación de resultados y reembolso si falla el segundo paso. Ya existe en pxd_justice: se convierte en librería común | Multas |

## Etapa A · Sistema financiero integrado

| # | Tarea | Notas |
|---|---|---|
| A-1 | Nóminas pagadas con los fondos de la empresa: `paycheckSociety = true` en qbx_core para empleos de jugadores; reglas propias para los públicos (policía, EMS, ayuntamiento), con presupuesto del «Gobierno» | Configuración de qbx_core. Hay que decidir el presupuesto público |
| A-2 | Transferencias entre jugadores, con límites y auditoría | Renewed-Banking ya las tiene: se exponen en la app de banco (E-1) |
| A-3 | **Facturación** genérica: emisor (empresa o servicio), cliente, concepto, importe, estado y pago | Reutiliza el modelo de pxd_justice (pendiente, parcial, pagada) |
| A-4 | Pago de servicios: mecánico, taxi, médico… mediante factura | A-3 |
| A-5 | Ingresos de negocios: las ventas van a la cuenta de la empresa, no desaparecen | B |
| A-6 | Gastos de mantenimiento: propiedades, vehículos de empresa y locales | C; reglas por decidir |
| A-7 | Impuestos configurables (porcentaje por tipo de operación), desactivados por defecto | Decisión económica |
| A-8 | **Panel económico para el staff**: entradas y salidas de dinero por origen (nóminas, ventas, multas, tiendas, tuneo), dinero total en circulación y alertas de picos | X-1 y A-1…A-7 |
| A-9 | Corregir las fuentes de dinero «de la nada»: comisión del concesionario y `/paylawyer` | Parche o adaptador |

## Etapa B · Empresas y negocios de jugadores

| # | Tarea | Notas |
|---|---|---|
| B-1 | **Registro de empresas** `pxd_business`: nombre, tipo, dueño y socios, trabajo de qbx_core asociado y cuenta de Renewed-Banking (la del trabajo) | Una empresa = un trabajo de qbx_core + su cuenta. No hay saldo paralelo |
| B-2 | Contratar, despedir y ascender con qbx_management; menú de jefe para todas las empresas (hoy solo lo tienen lostmc y vagos) | `RegisterBossMenu` |
| B-3 | Rangos y permisos por empresa: caja, stock, precios, contratar | qbx_core grades + `bankAuth` |
| B-4 | Caja de la empresa = cuenta de Renewed-Banking | — |
| B-5 | Inventario comercial = alijo de ox_inventory de la empresa; compra de suministros a un proveedor (NPC o empresa) con factura | A-3 |
| B-6 | Venta de productos (tiendas de ox_inventory con dueño o caja registradora propia), con precios configurables por la empresa | ox_inventory shops |
| B-7 | Historial de operaciones y nómina pagada con la caja (A-1) | X-1 |
| B-8 | Interfaz de gestión (panel o app de empresas) | E-2 |
| B-9 | Permisos de instalaciones (puertas con ox_doorlock por trabajo y rango) | ox_doorlock |

## Etapa C · Propiedades e inmobiliaria (ampliando qbx_properties)

| # | Tarea | Notas |
|---|---|---|
| C-1 | **Catálogo** de casas y locales: semilla revisada que crea la inmobiliaria (trabajo `realestate`) con `/createproperty` o una herramienta del staff | Hoy no hay casas predefinidas |
| C-2 | Venta y alquiler con fondos validados (ya resuelto por P1-1 y P1-3) | ✔ base |
| C-3 | Copropietarios y llaves (keyholders de qbx_properties) | Existe |
| C-4 | Locales comerciales vinculados a empresas (B) | B-1 |
| C-5 | Comisión de los agentes inmobiliarios: un porcentaje de la venta va a su cuenta o la de la inmobiliaria, con registro | A-3 |
| C-6 | Alquiler periódico fiable (P1-3) con avisos de impago (sin embargos hasta definir reglas) | — |
| C-7 | Mobiliario: catálogo con requisitos por nivel (pxd_progress), reutilizando la decoración de qbx_properties | D (niveles) |
| C-8 | Historial de operaciones por propiedad | X-1 |

## Etapa D · Organizaciones y progresión

| # | Tarea | Notas |
|---|---|---|
| D-1 | **Organizaciones** `pxd_orgs` encima de los trabajos y bandas de qbx_core: tipo (legal, empresarial, gubernamental o criminal), fundadores, miembros, jerarquía y permisos | No se crea una segunda lista de miembros: se usa la de qbx_core |
| D-2 | Fondos: la cuenta de Renewed-Banking del grupo | — |
| D-3 | Creación regulada: requisitos de nivel, número de miembros y aprobación del staff para el estado «oficial» | pxd_progress, pxd_admin |
| D-4 | Reputación, nivel, objetivos y actividades, con beneficios por nivel (radio, almacenes, ranuras) | Reglas en la configuración |
| D-5 | Requisitos por nivel del personaje (tabla central que consultan los demás) | pxd_progress |
| D-6 | Certificaciones: autoescuela y limitador, especialidades de profesión y reputación | — |
| D-7 | Gestión desde el panel TAB (Organizaciones pasa de informativo a gestión) | pxd_panel |
| D-8 | Advertencias del staff e historial de gestión | X-1 |

## Etapa E · Teléfono y servicios integrados

Conserva la rama `wt/phone`: diseño propio y apps Dynasty 8, Emergencias y Taxi. **Antes de cualquier función comercial hay que revisar la licencia de npwd (CC-BY-NC-SA).**

| # | App | Datos reales de |
|---|---|---|
| E-1 | **Banco**: saldo, transferencias, historial, facturas, multas pendientes y cuentas de empresa autorizadas | qbx_core, Renewed-Banking, pxd_justice, A-3 |
| E-2 | **Empresas**: información, empleados, fondos, actividad y gestión según permisos | B |
| E-3 | **Inmobiliaria** (Dynasty 8): disponibles, propias, alquiler, contactar a un agente | qbx_properties, C |
| E-4 | **Emergencias**: policía y EMS (bomberos cuando existan), con seguimiento | Rama `wt/phone` + centralita (futuro) |
| E-5 | **Servicios**: taxi, mecánico y servicios disponibles | Rama `wt/phone` + A-4 |
| E-6 | Cámara y galería (requiere fivemanage) | ⏸ decisión del propietario: servicio externo, posible coste |

## Después de E

- Servicios públicos: MDT y expediente completo, juicios y abogados, bomberos y centralita de emergencias.
- Crimen reglado: territorios, drogas, lavado de dinero y mercados, todo validado en el servidor.
- Vida cotidiana: gimnasio, misiones dinámicas y eventos con inscripción.
