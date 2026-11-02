import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { compile, makeFrame, normAngle } from '../../tools/blueprint.mjs';

const near = (a, b, eps = 0.01) => assert.ok(Math.abs(a - b) <= eps, `${a} ≈ ${b}`);

test('marco del ancla: delante, derecha y rumbo siguen la convención de GTA', () => {
  // Rumbo 90 = mirando al oeste: delante = -x, derecha = +y.
  const f = makeFrame({ x: 100, y: 200, z: 30, h: 90 });
  const [x1, y1] = f.point([0, 10]);
  near(x1, 90); near(y1, 200);
  const [x2, y2, z2] = f.point([5, 0, 2]);
  near(x2, 100); near(y2, 205); near(z2, 32);
  assert.equal(f.yaw(0), 90);
  assert.equal(normAngle(270), -90);
});

test('frame world ignora el rumbo del ancla', () => {
  const f = makeFrame({ x: 0, y: 0, z: 0, h: 123 }, 'world');
  assert.deepEqual(f.point([3, 4, 0]), [3, 4, 0]);
});

test('línea por separación, alineada con su dirección', () => {
  const { layout } = compile({
    id: 'l1', anchor: { x: 0, y: 0, z: 0, h: 0 },
    items: [{ type: 'line', model: 'prop_mp_cone_02', from: [0, 0], to: [0, 20], spacing: 5 }],
  });
  assert.equal(layout.props.length, 5);
  assert.equal(layout.props[4].y, 20);
  assert.equal(layout.props[0].rz, 0); // mira hacia +y (norte)
});

test('anillo mirando al centro y en arco', () => {
  const { layout } = compile({
    id: 'r1', anchor: { x: 0, y: 0, z: 0, h: 0 },
    items: [
      { type: 'ring', model: 'prop_tyre_wall_01', radius: 10, count: 4 },
      { type: 'ring', model: 'prop_mp_cone_02', radius: 10, count: 3, arc: [-90, 90], face: 'fixed' },
    ],
  });
  const [n, e] = layout.props;
  near(n.y, 10); near(n.x, 0);
  assert.equal(Math.abs(n.rz), 180); // en el norte, mira al sur
  near(e.x, 10); assert.equal(e.rz, 90); // en el este, mira al oeste (rumbo 90)
  const arc = layout.props.slice(4);
  near(arc[0].x, -10); near(arc[2].x, 10);
});

test('rejilla y props sueltos con giro local', () => {
  const { layout, stats } = compile({
    id: 'g1', anchor: { x: 10, y: 10, z: 5, h: 180 },
    items: [
      { type: 'grid', model: 'prop_box_wood02a', rows: 2, cols: 3, spacing: [2, 4] },
      { type: 'prop', model: 'prop_bench_01a', at: [0, 5, 1], rz: 90, ground: true },
    ],
  });
  assert.equal(stats.props, 7);
  assert.deepEqual(stats.models, { prop_box_wood02a: 6, prop_bench_01a: 1 });
  const bench = layout.props[6];
  near(bench.y, 5); near(bench.z, 6); assert.equal(bench.rz, -90); assert.equal(bench.ground, true);
});

test('rutas de checkpoints numeradas en orden y zona única', () => {
  const { layout } = compile({
    id: 'c1', anchor: { x: 0, y: 0, z: 0, h: 0 },
    items: [
      { type: 'route', kind: 'checkpoint', path: [[0, 10], [10, 10], [10, 0]] },
      { type: 'point', kind: 'zone', at: [0, 0], radius: 15 },
      { type: 'point', kind: 'grid', at: [0, -5], h: 0 },
    ],
  });
  const cps = layout.points.filter((p) => p.kind === 'checkpoint');
  assert.deepEqual(cps.map((p) => p.order), [1, 2, 3]);
  assert.equal(layout.points.find((p) => p.kind === 'zone').radius, 15);
  assert.throws(() => compile({
    id: 'c2', anchor: { x: 0, y: 0, z: 0 },
    items: [{ type: 'point', kind: 'zone', at: [0, 0] }, { type: 'point', kind: 'zone', at: [1, 1] }],
  }), /una zona/);
});

test('errores claros: ancla inexistente, modelo raro, tipo desconocido, límites', () => {
  assert.throws(() => compile({ id: 'x1', anchor: 'plaza', items: [{ type: 'prop', model: 'prop_a', at: [0, 0] }] }, {}), /\/ancla plaza/);
  const a = { x: 0, y: 0, z: 0 };
  assert.throws(() => compile({ id: 'x1', anchor: a, items: [{ type: 'prop', model: 'rm -rf', at: [0, 0] }] }), /modelo inválido/);
  assert.throws(() => compile({ id: 'x1', anchor: a, items: [{ type: 'spiral', model: 'prop_a' }] }), /tipo desconocido/);
  assert.throws(() => compile({ id: 'Mal Id', anchor: a, items: [] }), /id/);
  assert.throws(() => compile({ id: 'x1', anchor: a, items: [{ type: 'grid', model: 'prop_a', rows: 50, cols: 50, spacing: 1 }] }), /demasiados props/);
});

test('los blueprints de ejemplo compilan con un ancla ficticia', () => {
  const dir = new URL('../../blueprints/', import.meta.url);
  const files = readdirSync(dir).filter((f) => f.endsWith('.json'));
  assert.ok(files.length >= 2);
  for (const f of files) {
    const bp = JSON.parse(readFileSync(new URL(f, dir), 'utf8'));
    const anchors = { [bp.anchor]: { x: 0, y: 0, z: 0, h: 0 } };
    const { stats } = compile(bp, anchors);
    assert.ok(stats.props + stats.points > 0, f);
  }
});
