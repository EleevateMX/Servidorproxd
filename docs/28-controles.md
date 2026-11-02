# 28. Controles de Próxima RP

Teclas definitivas. Todas son asignaciones de FiveM: cada jugador puede cambiarlas en *Ajustes → Asignación de teclas → FiveM*. Quien ya había entrado conserva la tecla que tenía guardada (FiveM no deja cambiarla desde el servidor); si sigue abriendo el inventario con F2, que la cambie ahí a I.

## Las cuatro principales

| Tecla | Acción | Recurso | Notas |
|---|---|---|---|
| **I** | Abrir / cerrar el inventario | ox_inventory (interfaz pxd_inventory) | Sentado delante en un vehículo abre la guantera (comportamiento de ox_inventory). Junto a un objeto tirado (≤ 1,2 m) abre también el suelo. No abre si estás muerto, esposado, en pausa o con el inventario ocupado (lo comprueba ox_inventory) |
| **Ctrl izq.** | Agacharse (alternar) | pxd_interact (estado `crouch` de qbx_crouch) | Sincronizado con los demás. No en vehículo, nadando, en el suelo ni muerto. El sigilo nativo de GTA se desactiva a pie |
| **E** | Interacción contextual | pxd_interact | Una pulsación = una acción. «E · Abrir maletero» abre el maletero directamente. Prioridades y casos en que cede la E: [18-interaccion-e-identidad.md](18-interaccion-e-identidad.md) |
| **B** | Recoger del suelo | pxd_interact | «B · Recoger botella de agua». Sin menú; lo valida el servidor. A pie; en vehículo B es el cinturón |

## Resto de teclas

| Tecla | Acción | Recurso |
|---|---|---|
| TAB | Panel de la ciudad | pxd_panel |
| F1 | Barra rápida | ox_inventory |
| 1–5 | Usar hueco de la barra rápida | ox_inventory |
| R | Recargar | ox_inventory |
| ↑ (flecha arriba) | Teléfono | npwd |
| N · doble N · J | Hablar · gritar · susurrar | pma-voice / pxd_voice ([21-voz.md](21-voz.md)) |
| Alt | Mirar (ojo) | ox_target |
| Z | Menú radial | ox_lib / qbx_radialmenu |
| F5 · X · G | Emotes · cancelar emote · efectos | scully_emotemenu |
| H | Manos arriba (a pie) · buscar llaves (en vehículo) | scully_emotemenu · qbx_vehiclekeys |
| U | Dejarse caer | scully_emotemenu |
| L | Cerrar / abrir el vehículo | qbx_vehiclekeys |
| B (en vehículo) | Cinturón | qbx_seatbelt |
| Y | Control de crucero | qbx_cruise |
| O | Cambiar de asiento | qbx_noshuff |
| Mayús + E | Empujar vehículo | qbx_vehiclepush |
| E corriendo | Placaje | qbx_tackle |
| E en un surtidor | Repostar | ox_fuel |
| F6 · F7 | Editor de props · modos de juego | pxd_props · pxd_gamemodes |
| F9 · F10 | Soporte · panel de staff | pxd_admin (F9 en un coche también es la radio de qbx_vehicleradio) |

## Conflictos resueltos

| Conflicto | Solución |
|---|---|
| F2 y K abrían inventario / maletero además de I | `inventory:keys` = `["I", "", "F1"]`: la tecla secundaria de ox_inventory queda sin asignar (el maletero va por E). ox_lib admite `""` como tecla por defecto (es su valor por defecto) |
| K agachaba (qbx_crouch) y Ctrl hacía la postura de scully y el sigilo de GTA | Ctrl izq. agacha (pxd_interact, mismo estado `crouch`), la tecla de qbx_crouch queda vacía, `scully_emotemenu:stanceKey ""` (scully no carga su módulo de postura) y el sigilo nativo (control 36) se desactiva a pie |
| B era «señalar» (scully) | `scully_emotemenu:pointKey ""` (scully no carga su módulo de señalar). En vehículo B sigue siendo el cinturón: la recogida solo funciona a pie |
| E: puertas de ox_doorlock, teletransportes, placaje, empujar, surtidores | pxd_interact cede la E: con aviso de ox_lib en pantalla, puerta al alcance, corriendo, con Mayús o a menos de 3 m de un surtidor |
| E: punto de trabajo junto a tu coche | Las zonas van antes que el maletero; el maletero sigue en la lista (rueda) |
| Flechas ↑/↓ elegían opción en pxd_interact y ↑ abre el teléfono | pxd_interact solo usa la rueda del ratón |
| ox_target tiene su propia opción de maletero | Es otra entrada (Alt + clic); conviven sin pisarse |

## Cambios fuera de nuestros recursos (para el integrador)

En el `server.cfg` / `server.qbox.cfg` (sustituye la línea actual de `inventory:keys`):

```cfg
setr inventory:keys ["I", "", "F1"]
setr scully_emotemenu:stanceKey ""
setr scully_emotemenu:pointKey ""
```

En qbx_smallresources v0.2.0, `qbx_crouch/client.lua` (deja la tecla de qbx_crouch vacía; su estado y su animación se siguen usando):

```diff
-  defaultKey = 'K',
+  defaultKey = '', -- Próxima: agacharse con Ctrl izquierdo (pxd_interact)
```

Alternativa sin tocar el archivo: no hacer el cambio. Entonces K y Ctrl agachan las dos (mismo estado, no se rompe nada), pero K no queda libre.

## Pendiente de probar en el juego

Nada de esto está probado en FiveM todavía (solo pruebas automáticas de la lógica y del servidor de B):

- I con la convar nueva: abre y cierra, guantera, y que la secundaria vacía no da avisos.
- Ctrl: la animación la ven los demás; apuntar y correr agachado; que no aparece el sigilo nativo.
- E: maletero en coches, furgonetas y modelos con motor delante; cerrado con llave; junto a puertas, surtidores y teletransportes.
- B: recogida con varios jugadores a la vez; objetos con metadata; inventario lleno.

## Teclas guardadas por FiveM (2026-11-02)

**Problema visto en el servidor:** F2 seguía abriendo el inventario y K seguía agachando, aunque las teclas por defecto ya eran I y nada.

**Causa:** `RegisterKeyMapping` solo aplica la tecla por defecto la **primera** vez que un jugador ve ese comando. Después, FiveM guarda la tecla en la configuración del jugador, y cambiar el valor por defecto no la borra:
- ox_inventory: `+inv` (F2) y `+inv2` (K);
- qbx_crouch: `+crouch` (K).

**Arreglo:** parches de `scripts/update-plan.json` que **renombran** esas combinaciones:
- `inv` → `pxd_inventario`;
- `inv2` → `pxd_inventario2`;
- `crouch` → `pxd_sin_tecla_crouch`.

La tecla antigua queda apuntando a un comando que ya no existe y no hace nada. El nombre nuevo toma su valor por defecto: I para el inventario, nada para el resto.

**Para el jugador:** si alguien había cambiado a mano la tecla del inventario en *Ajustes → Asignación de teclas → FiveM*, ahora verá la entrada nueva con I.
