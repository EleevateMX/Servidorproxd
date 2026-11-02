# 38. Personajes: selección, creador y editor de apariencia (`pxd_multichar` 0.2.0)

**Estado:** implementado y con pruebas automáticas (Lua simulado + Vitest + capturas Playwright con datos simulados). **No probado dentro de FiveM.**

## Flujo

1. **Selección** («Mis personajes», arriba a la izquierda). Cada fila muestra:
   - número de ranura, icono de sexo, nombre y estado (Activo, Ranura disponible o R.I.P.);
   - al elegir una ranura libre se despliega «Crear personaje».

   A la derecha, la ficha con la última ubicación (calle y zona), trabajo, dinero, nivel y nacionalidad. En el centro se ve el ped real del personaje elegido; al cambiar de personaje el ped se limpia por completo (`SetPedDefaultComponentVariation` + `ClearPedDecorations`) antes de aplicar su apariencia.
2. **Creador**, en 6 secciones con vista previa inmediata:

   | Sección | Contenido |
   |---|---|
   | Identidad | nombre, apellido, sexo (solo `mp_m_freemode_01` / `mp_f_freemode_01`), fecha de nacimiento y nacionalidad |
   | Herencia | madre, padre, parecido de cara y tono de piel |
   | Rasgos | los 20 `SET_PED_FACE_FEATURE` agrupados por zona |
   | Piel | color de ojos y overlays con tipo, opacidad y color |
   | Cabello | peinado, variante, color, reflejos, cejas, barba y vello corporal |
   | Ropa | prendas y accesorios con rangos reales del modelo, más conjuntos iniciales |

   Además:
   - pie del panel: Anterior, Aleatorio, Restablecer (la sección) y Siguiente o Finalizar;
   - deshacer con Ctrl+Z (pila de 60 pasos);
   - cámara por sección (cuerpo, torso, rostro, cabello) y controles para girar, acercar y restaurar;
   - confirmación antes de crear.
3. **Guardado**, en este orden:
   1. validar en el servidor (`checkRegistration`);
   2. `qbx_core:server:createCharacter`;
   3. apariencia en `playerskins`, releída para comprobar que corresponde al citizenid cargado;
   4. cerrar el editor;
   5. volver al bucket 0;
   6. apartamento inicial (qbx_properties) o ubicación;
   7. aparecer;
   8. restaurar el HUD.

   Nunca hay dos pantallas a la vez.
4. **Aparición** («Elige dónde empezar»): vista aérea de la ciudad que se desplaza a cada opción. Nunca se ve la escena de selección detrás.

## Cómo se integra con illenium-appearance 5.7.0

- **Motor y persistencia:** illenium-appearance. Se usan sus exports de cliente `setPedAppearance` y `getPedAppearance`, y su formato (`playerskins.skin`).
- **El editor de illenium no se abre nunca:** ni `startPlayerCustomization`, ni `qb-clothes:client:CreateFirstCharacter` desde pxd_multichar.
- **Guardado:** lo hace el servidor de pxd_multichar con las mismas tres operaciones que `Framework.SaveAppearance` de illenium:
  1. todas las apariencias del personaje inactivas;
  2. borrar la del mismo modelo;
  3. insertar la nueva activa.

  Van en una transacción y después se releen. No se usa el evento `illenium-appearance:server:saveAppearance` porque no devuelve resultado y no se puede comprobar.
- **Carga al entrar:** la sigue haciendo illenium en `QBCore:Client:OnPlayerLoaded`.
- **Rangos reales, contados con natives:**
  - `GetPedHeadOverlayNum`, `GetNumHairColors`, `GetNumMakeupColors`;
  - `GetNumberOfPed(Prop)DrawableVariations` y `GetNumberOfPed(Prop)TextureVariations`;
  - paletas de color con `GetPedHairRgbColor` y `GetPedMakeupRgbColor`.

  La NUI manda la apariencia entera en cada cambio; el cliente la sanea (`PXDLook.sanitize`) con esos rangos y devuelve la versión válida.

## Coherencia entre Qbox e illenium

| Fallo | Resultado |
|---|---|
| Validación o `createCharacter` | No se crea nada; el editor sigue abierto con lo editado y el error |
| Guardar la apariencia, después de crear | 3 intentos. Si siguen fallando, el personaje existe y la próxima vez que se elija se abre el editor en modo «Completa tu apariencia» (`hasAppearance`), sin identidad editable, antes de aparecer |
| Desconexión durante el editor | Antes de crear: nada que limpiar. Después: igual que la fila anterior |
| Relectura distinta de lo guardado, o sin personaje cargado | Se responde error y se reintenta |

## Editor reutilizable

```lua
exports.pxd_multichar:OpenAppearanceEditor({
    sections = { 'hair' },          -- 'face' | 'skin' | 'hair' | 'clothes'
    title = 'Peluquería', price = 50,
    onSave = function(look) return true end,  -- gancho de cobro (pxd_economy:ChargeToAccount cuando se habilite)
})
```

- La identidad, el modelo y la herencia nunca se editan fuera de la creación: `PXDLook.restrict` descarta todo lo que no esté en `sections`.
- Sin `onSave` se guarda sin cobrar.
- No se ha conectado a ninguna tienda todavía.

## R.I.P.

- Tabla `pxd_character_status`, creada con `CREATE TABLE IF NOT EXISTS`. Vacía = todos activos.
- Un personaje con `status = 'dead'` se ve apagado como «Nombre (R.I.P.)» y no se puede jugar.
- **La mecánica de CK (quién lo marca y con qué autorización) no está implementada.**

## Configuración (`config.lua`)

- **`Config.creator.scene`:** sala del creador de GTA Online (402.86, −996.41, −99.0). **Pendiente de comprobar en el juego** que el encuadre no atraviesa paredes.
- **`Config.creator.bucketBase`** = 70000: bucket propio por jugador; pxd_gamemodes usa 60000+.
- **`Config.creator.portraitsDict`:** retratos de los padres por `https://nui-img/<txd>/<textura>` (comprobado en el código de FiveM, `NuiTxdSource.cpp`).
  - Los nombres de textura (`male_0`, `female_0`…) **no están verificados**. Si no cargan, solo se ve el nombre.
- **`Config.starterOutfits`:** vacío = el conjunto de qbx_core («Básico»). Añade solo valores comprobados en el juego.

## Interfaz

- **Código:** React + TypeScript en `web/multichar/`, fuera del recurso, porque el actualizador sube todo lo que hay dentro.
- **Compilación:** `npm run build:multichar` deja `html/index.html`, `html/assets/app.js` y `html/assets/app.css`, con nombres fijos.
- **Pruebas:** `npm run test:multichar` (Vitest).
- **Vista previa:** sirve `html/` por HTTP y abre `index.html?demo=1&view=`, con `view` = `select` | `free` | `create-identity` … `create-clothes` | `confirm` | `spawn` | `recover` | `barber`.

## Pruebas que requieren FiveM

1. Crear un personaje masculino y uno femenino (freemode).
2. Modificar herencia, rasgos (los 20 sliders deben cambiar la cara), piel, ojos y cabello.
3. Vestirlo y guardarlo.
4. Desconectar y reconectar: mismo rostro, cabello y ropa.
5. Elegir otro personaje: sin mezclar apariencias.
6. Entrar a la ciudad sin interfaces superpuestas, sin el editor de illenium después del apartamento (requiere el parche de qbx_properties) y con el HUD de vuelta.
7. Cámara del creador: dentro de la sala y con la cara bien encuadrada en «Rostro».
8. Retratos de los padres: si se ven o no.
