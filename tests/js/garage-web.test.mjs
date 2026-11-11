// Interfaz del taller (web/garage → pxd_garage/html). docs/44-vehiculos.md
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sourceHash } from '../../web/garage/scripts/source-hash.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const res = join(root, 'server-data/resources/[proxima]/pxd_garage');

test('taller: el build versionado corresponde a las fuentes (npm run build en web/garage)', () => {
  const stamp = JSON.parse(readFileSync(join(root, 'web/garage/build-stamp.json'), 'utf8'));
  assert.equal(stamp.sources, sourceHash());
});

test('taller: nombres fijos, rutas relativas y todo declarado en el fxmanifest', () => {
  assert.deepEqual(readdirSync(join(res, 'html/assets')).sort(), ['app.css', 'app.js']);
  const html = readFileSync(join(res, 'html/index.html'), 'utf8');
  assert.match(html, /src="\.\/assets\/app\.js"/);
  assert.match(html, /href="\.\/assets\/app\.css"/);
  assert.doesNotMatch(html, /https?:\/\//, 'sin recursos externos');
  const fx = readFileSync(join(res, 'fxmanifest.lua'), 'utf8');
  for (const f of ['html/index.html', 'html/assets/app.js', 'html/assets/app.css', 'html/ui/*.css']) assert.ok(fx.includes(`'${f}'`), `fxmanifest sin ${f}`);
  assert.match(fx, /nui_callback_strict_mode 'true'/);
});

test('taller: la interfaz solo usa los callbacks que registra el cliente y no trae precios propios', () => {
  const js = readFileSync(join(res, 'html/assets/app.js'), 'utf8');
  const lua = readFileSync(join(res, 'client/main.lua'), 'utf8');
  const registered = [...lua.matchAll(/RegisterNUICallback\('([a-z]+)'/g)].map((m) => m[1]).sort();
  assert.deepEqual(registered, ['apply', 'camera', 'close', 'orbit', 'reset', 'set']);
  for (const name of registered) assert.ok(js.includes(`"${name}"`), `la interfaz no llama a ${name}`);
  assert.doesNotMatch(js, /window\.fetch\s*=/);
});

test('taller: cada clave del catálogo es una propiedad de lib.getVehicleProperties (ox_lib)', () => {
  const lua = readFileSync(join(res, 'shared/garage.lua'), 'utf8');
  const keys = [...lua.matchAll(/\{ key = '([A-Za-z0-9]+)'/g)].map((m) => m[1]);
  // Propiedades que devuelve ox_lib 3.42.0 (resource/vehicleProperties/client.lua).
  const oxlib = new Set(['plateIndex', 'paintType1', 'paintType2', 'color1', 'color2', 'pearlescentColor', 'interiorColor', 'dashboardColor',
    'wheelColor', 'wheels', 'windowTint', 'xenonColor', 'neonEnabled', 'neonColor', 'extras', 'tyreSmokeColor', 'modSpoilers', 'modFrontBumper',
    'modRearBumper', 'modSideSkirt', 'modExhaust', 'modFrame', 'modGrille', 'modHood', 'modFender', 'modRightFender', 'modRoof', 'modEngine',
    'modBrakes', 'modTransmission', 'modHorns', 'modSuspension', 'modArmor', 'modNitrous', 'modTurbo', 'modSubwoofer', 'modSmokeEnabled',
    'modHydraulics', 'modXenon', 'modFrontWheels', 'modBackWheels', 'modCustomTiresF', 'modCustomTiresR', 'modPlateHolder', 'modVanityPlate',
    'modTrimA', 'modOrnaments', 'modDashboard', 'modDial', 'modDoorSpeaker', 'modSeats', 'modSteeringWheel', 'modShifterLeavers', 'modAPlate',
    'modSpeakers', 'modTrunk', 'modHydrolic', 'modEngineBlock', 'modAirFilter', 'modStruts', 'modArchCover', 'modAerials', 'modTrimB', 'modTank',
    'modWindows', 'modDoorR', 'modLivery', 'modRoofLivery', 'modLightbar', 'livery']);
  assert.ok(keys.length > 50);
  for (const k of keys) assert.ok(oxlib.has(k), `«${k}» no es una propiedad de ox_lib`);
  for (const k of ['plate', 'bodyHealth', 'engineHealth', 'fuelLevel', 'model', 'lockState']) assert.ok(!keys.includes(k), `«${k}» no debe ser personalizable`);
});
