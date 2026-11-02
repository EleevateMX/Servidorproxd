// Compilador de blueprints de Próxima RP.
// Un blueprint describe un layout con formas (línea, anillo, rejilla, ruta…) en
// coordenadas relativas a un ANCLA tomada en el juego con /ancla <nombre>.
// El resultado es un layout normal de pxd_props que se inyecta con importLayout.
//
// Marco local del ancla (frame "anchor", por defecto):
//   +x = a la derecha de donde mirabas, +y = hacia delante, +z = arriba.
// Con frame "world": +x = este, +y = norte (ejes del mapa).
// Ángulos en grados. En GTA V el rumbo 0 mira al norte y crece en sentido antihorario.

export const LIMITS = { maxProps: 1500, maxPoints: 200 };
export const POINT_KINDS = new Set(['spawn', 'team1', 'team2', 'grid', 'checkpoint', 'zone']);
const MODEL_RE = /^[A-Za-z0-9_]{3,64}$/;
const ID_RE = /^[a-z0-9_-]{2,40}$/;

const rad = (d) => (d * Math.PI) / 180;
const deg = (r) => (r * 180) / Math.PI;
const round = (v, d = 3) => Math.round(v * 10 ** d) / 10 ** d;
export const normAngle = (a) => {
  a = ((a % 360) + 360) % 360;
  return round(a > 180 ? a - 360 : a, 2);
};

class BlueprintError extends Error {
  constructor(where, msg) { super(`${where}: ${msg}`); this.name = 'BlueprintError'; }
}

const num = (v, where, name, def) => {
  if (v === undefined && def !== undefined) return def;
  if (typeof v !== 'number' || !Number.isFinite(v)) throw new BlueprintError(where, `«${name}» debe ser un número`);
  return v;
};
const vec = (v, where, name, def) => {
  if (v === undefined && def !== undefined) return def;
  if (!Array.isArray(v) || v.length < 2 || v.length > 3) throw new BlueprintError(where, `«${name}» debe ser [x, y] o [x, y, z]`);
  return [num(v[0], where, `${name}[0]`), num(v[1], where, `${name}[1]`), v[2] === undefined ? 0 : num(v[2], where, `${name}[2]`)];
};
const model = (m, where) => {
  if (typeof m !== 'string' || !MODEL_RE.test(m)) throw new BlueprintError(where, `modelo inválido «${m}»`);
  return m;
};

/** Crea la transformación local → mundo para un ancla. */
export function makeFrame(anchor, frame = 'anchor') {
  if (!anchor || ![anchor.x, anchor.y, anchor.z].every(Number.isFinite)) {
    throw new BlueprintError('anchor', 'el ancla necesita x, y, z numéricos');
  }
  const h = frame === 'world' ? 0 : (anchor.h || 0);
  // Vectores de GTA para el rumbo h: delante = (-sin h, cos h), derecha = (cos h, sin h).
  const fwd = [-Math.sin(rad(h)), Math.cos(rad(h))];
  const right = [Math.cos(rad(h)), Math.sin(rad(h))];
  return {
    heading: h,
    point: ([lx, ly, lz = 0]) => [
      round(anchor.x + lx * right[0] + ly * fwd[0]),
      round(anchor.y + lx * right[1] + ly * fwd[1]),
      round(anchor.z + lz),
    ],
    // Un yaw local (0 = mirando hacia +y local) pasa a yaw del mundo sumando el rumbo.
    yaw: (localYaw) => normAngle(localYaw + h),
  };
}

/** Yaw (en el marco local) para mirar en la dirección (dx, dy). */
const yawTowards = (dx, dy) => normAngle(deg(Math.atan2(-dx, dy)));

function propsFor(item, where) {
  const m = model(item.model, where);
  const out = [];
  const extra = {
    rx: num(item.rx, where, 'rx', 0), ry: num(item.ry, where, 'ry', 0),
    frozen: item.frozen !== false, collision: item.collision !== false, ground: item.ground === true,
  };
  const yawOffset = num(item.rz, where, 'rz', 0);
  switch (item.type) {
    case 'prop': {
      out.push({ at: vec(item.at, where, 'at'), yaw: yawOffset });
      break;
    }
    case 'line': {
      const a = vec(item.from, where, 'from'), b = vec(item.to, where, 'to');
      const len = Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]);
      let count = item.count;
      if (count === undefined) {
        const spacing = num(item.spacing, where, 'spacing');
        if (spacing <= 0) throw new BlueprintError(where, '«spacing» debe ser > 0');
        count = Math.floor(len / spacing) + 1;
      }
      count = num(count, where, 'count');
      if (count < 1 || !Number.isInteger(count)) throw new BlueprintError(where, '«count» debe ser un entero >= 1');
      const along = item.align === false ? 0 : yawTowards(b[0] - a[0], b[1] - a[1]);
      for (let i = 0; i < count; i++) {
        const t = count === 1 ? 0 : i / (count - 1);
        out.push({ at: [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t], yaw: along + yawOffset });
      }
      break;
    }
    case 'ring': {
      const c = vec(item.center, where, 'center', [0, 0, 0]);
      const r = num(item.radius, where, 'radius');
      const count = num(item.count, where, 'count');
      if (r <= 0 || count < 1 || !Number.isInteger(count)) throw new BlueprintError(where, 'radius > 0 y count entero >= 1');
      const [start, end] = Array.isArray(item.arc) ? [num(item.arc[0], where, 'arc[0]'), num(item.arc[1], where, 'arc[1]')] : [0, 360];
      const full = Math.abs(end - start) >= 360;
      const face = item.face || 'center';
      if (!['center', 'out', 'tangent', 'fixed'].includes(face)) throw new BlueprintError(where, 'face: center | out | tangent | fixed');
      for (let i = 0; i < count; i++) {
        const t = full ? i / count : (count === 1 ? 0 : i / (count - 1));
        const ang = rad(start + (end - start) * t);  // 0° = delante (+y), sentido horario visto desde arriba
        const dx = Math.sin(ang) * r, dy = Math.cos(ang) * r;
        let yaw = 0;
        if (face === 'center') yaw = yawTowards(-dx, -dy);
        else if (face === 'out') yaw = yawTowards(dx, dy);
        else if (face === 'tangent') yaw = yawTowards(dy, -dx);
        out.push({ at: [c[0] + dx, c[1] + dy, c[2]], yaw: yaw + yawOffset });
      }
      break;
    }
    case 'grid': {
      const o = vec(item.origin, where, 'origin', [0, 0, 0]);
      const rows = num(item.rows, where, 'rows'), cols = num(item.cols, where, 'cols');
      if (![rows, cols].every((n) => Number.isInteger(n) && n >= 1)) throw new BlueprintError(where, 'rows y cols enteros >= 1');
      const sp = Array.isArray(item.spacing) ? item.spacing : [item.spacing, item.spacing];
      const sx = num(sp[0], where, 'spacing'), sy = num(sp[1], where, 'spacing');
      for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) out.push({ at: [o[0] + c * sx, o[1] + r * sy, o[2]], yaw: yawOffset });
      break;
    }
    default:
      throw new BlueprintError(where, `tipo desconocido «${item.type}»`);
  }
  return out.map((p) => ({ model: m, local: p.at, yaw: p.yaw, ...extra }));
}

function pointsFor(item, where) {
  const kind = item.kind;
  if (!POINT_KINDS.has(kind)) throw new BlueprintError(where, `kind inválido «${kind}»`);
  const base = { kind };
  if (kind === 'zone') {
    base.radius = num(item.radius, where, 'radius', 20);
    if (base.radius < 1 || base.radius > 300) throw new BlueprintError(where, 'radius entre 1 y 300');
  }
  if (item.type === 'point') return [{ ...base, local: vec(item.at, where, 'at'), h: num(item.h, where, 'h', 0) }];
  if (item.type === 'route') {
    if (!Array.isArray(item.path) || item.path.length < 1) throw new BlueprintError(where, '«path» necesita al menos un punto');
    const pts = item.path.map((p, i) => vec(p, where, `path[${i}]`));
    return pts.map((p, i) => {
      const next = pts[i + 1] || pts[0];
      const h = pts.length > 1 ? yawTowards(next[0] - p[0], next[1] - p[1]) : 0;
      return { ...base, local: p, h };
    });
  }
  throw new BlueprintError(where, `tipo desconocido «${item.type}»`);
}

/**
 * Compila un blueprint. `anchors` = { nombre: {x,y,z,h} } (de GET /api/anchors).
 * Devuelve { layout, stats } listo para importLayout.
 */
export function compile(bp, anchors = {}) {
  if (!bp || typeof bp !== 'object') throw new BlueprintError('blueprint', 'se esperaba un objeto');
  if (!ID_RE.test(bp.id || '')) throw new BlueprintError('id', 'usa a-z, 0-9, _ o - (2-40 caracteres)');
  let anchor = bp.anchor;
  if (typeof anchor === 'string') {
    anchor = anchors[anchor];
    if (!anchor) throw new BlueprintError('anchor', `no existe el ancla «${bp.anchor}». Créala en el juego con /ancla ${bp.anchor}`);
  }
  const frame = makeFrame(anchor, bp.frame || 'anchor');
  if (!Array.isArray(bp.items) || bp.items.length === 0) throw new BlueprintError('items', 'añade al menos un elemento');

  const props = [];
  const points = [];
  bp.items.forEach((item, i) => {
    const where = `items[${i}]${item && item.type ? ` (${item.type})` : ''}`;
    if (!item || typeof item !== 'object') throw new BlueprintError(where, 'se esperaba un objeto');
    if (item.type === 'point' || item.type === 'route') {
      for (const p of pointsFor(item, where)) {
        const [x, y, z] = frame.point(p.local);
        const out = { kind: p.kind, x, y, z, h: round(((frame.yaw(p.h) % 360) + 360) % 360, 2) };
        if (p.radius !== undefined) out.radius = p.radius;
        points.push(out);
      }
    } else {
      for (const p of propsFor(item, where)) {
        const [x, y, z] = frame.point(p.local);
        props.push({ model: p.model, x, y, z, rx: p.rx, ry: p.ry, rz: frame.yaw(p.yaw), frozen: p.frozen, collision: p.collision, ground: p.ground });
      }
    }
  });
  if (props.length > LIMITS.maxProps) throw new BlueprintError('items', `demasiados props (${props.length} > ${LIMITS.maxProps})`);
  if (points.length > LIMITS.maxPoints) throw new BlueprintError('items', `demasiados puntos (${points.length} > ${LIMITS.maxPoints})`);
  // Los checkpoints conservan el orden en que aparecen en el blueprint.
  let order = 0;
  for (const p of points) if (p.kind === 'checkpoint') p.order = ++order;
  if (points.filter((p) => p.kind === 'zone').length > 1) throw new BlueprintError('items', 'solo puede haber una zona');

  const models = {};
  for (const p of props) models[p.model] = (models[p.model] || 0) + 1;
  return {
    layout: { id: bp.id, name: (bp.name || bp.id).slice(0, 60), active: bp.active === true, props, points },
    stats: { props: props.length, points: points.length, models },
  };
}

export { BlueprintError };
