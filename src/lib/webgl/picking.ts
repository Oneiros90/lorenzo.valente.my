import { lookBasis, type CameraPose } from './camera';
import { BRD_C, OCT_C, TAB_C, orbPosJS, orbRadius } from './orbs';
import { SOCIAL_ORB_RADIUS, socialPosJS } from './socials';
import { MAX_COMPANY_ORBS, SOCIAL_PICK_BASE, companyPickId } from './picks';
import type { CompanyConfig, PickId, SceneConfig, SocialConfig, Vec3 } from './types';

export { BRD_C, OCT_C, TAB_C, orbPosJS, orbRadius };

const TAB_HALF: Vec3 = [0.218, 0.03, 0.158];
const TAB_TILT = 0.5;

const BRD_HALF: Vec3 = [0.248, 0.026, 0.248];
const BRD_PIECE_TOP = 0.1;
const OCT_YAW = Math.atan2(0.0 - OCT_C[0], 2.1 - OCT_C[2]);
const OCT_PICK: { p: Vec3; r: number }[] = [
  { p: [0, 0.16, 0.01], r: 0.085 },
  { p: [-0.07, 0.25, 0], r: 0.036 },
  { p: [0.07, 0.25, 0], r: 0.036 },
  { p: [0, 0.06, 0], r: 0.08 },
  { p: [-0.08, 0.12, 0], r: 0.048 },
  { p: [-0.08, 0.17, 0.02], r: 0.04 }
];

function dot3(a: Vec3, b: Vec3): number {
  return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

function add3(a: Vec3, b: Vec3): Vec3 {
  return [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
}

function rotYaw(v: Vec3, yaw: number): Vec3 {
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  return [c * v[0] + s * v[2], v[1], -s * v[0] + c * v[2]];
}

function octWorldFromLocal(local: Vec3): Vec3 {
  return add3(OCT_C, rotYaw(local, OCT_YAW));
}

export function hitBox(ro: Vec3, rd: Vec3, mn: Vec3, mx: Vec3): number {
  let t0 = 0;
  let t1 = 1e9;
  for (let i = 0; i < 3; i++) {
    const inv = 1 / rd[i];
    let a = (mn[i] - ro[i]) * inv;
    let b = (mx[i] - ro[i]) * inv;
    if (a > b) [a, b] = [b, a];
    t0 = Math.max(t0, a);
    t1 = Math.min(t1, b);
  }
  if (t1 < t0 || t1 <= 0) return Infinity;
  return t0 > 0 ? t0 : t1;
}

export function hitSphere(ro: Vec3, rd: Vec3, center: Vec3, radius: number): number {
  const oc: Vec3 = [ro[0] - center[0], ro[1] - center[1], ro[2] - center[2]];
  const b = dot3(oc, rd);
  const d = b * b - (dot3(oc, oc) - radius * radius);
  if (d < 0) return Infinity;
  let t = -b - Math.sqrt(d);
  if (t < 0) t = -b + Math.sqrt(d);
  return t > 0 ? t : Infinity;
}

function hitOBBRotX(ro: Vec3, rd: Vec3, center: Vec3, half: Vec3, rotX: number): number {
  const c = Math.cos(rotX);
  const s = Math.sin(rotX);
  const ox = ro[0] - center[0];
  const oy = ro[1] - center[1];
  const oz = ro[2] - center[2];
  const lo: Vec3 = [ox, c * oy - s * oz, s * oy + c * oz];
  const ld: Vec3 = [rd[0], c * rd[1] - s * rd[2], s * rd[1] + c * rd[2]];
  return hitBox(lo, ld, [-half[0], -half[1], -half[2]], [half[0], half[1], half[2]]);
}

function hitTablet(ro: Vec3, rd: Vec3): number {
  return hitOBBRotX(ro, rd, TAB_C, TAB_HALF, TAB_TILT);
}

function hitBoard(ro: Vec3, rd: Vec3): number {
  const mn: Vec3 = [
    BRD_C[0] - BRD_HALF[0],
    BRD_C[1] - BRD_HALF[1],
    BRD_C[2] - BRD_HALF[2]
  ];
  const mx: Vec3 = [
    BRD_C[0] + BRD_HALF[0],
    BRD_C[1] + BRD_HALF[1] + BRD_PIECE_TOP,
    BRD_C[2] + BRD_HALF[2]
  ];
  return hitBox(ro, rd, mn, mx);
}

function hitOctopus(ro: Vec3, rd: Vec3): number {
  let best = Infinity;
  for (const { p, r } of OCT_PICK) {
    best = Math.min(best, hitSphere(ro, rd, octWorldFromLocal(p), r));
  }
  return best;
}

export function cameraRay(
  px: number,
  py: number,
  canvas: HTMLCanvasElement,
  pose: CameraPose,
  viewBias = 0
): { ro: Vec3; rd: Vec3 } {
  const { fw, rt, up } = lookBasis(pose.ro, pose.target);
  const res: [number, number] = [canvas.width, canvas.height];
  const scaleX = canvas.width / Math.max(innerWidth, 1);
  const scaleY = canvas.height / Math.max(innerHeight, 1);
  const aspect = res[0] / res[1];
  const uv: [number, number] = [
    (2 * px * scaleX - res[0]) / res[1] - viewBias * 0.5 * aspect,
    (2 * (innerHeight - py) * scaleY - res[1]) / res[1]
  ];
  let rd: Vec3 = [
    fw[0] * pose.focal + uv[0] * rt[0] + uv[1] * up[0],
    fw[1] * pose.focal + uv[0] * rt[1] + uv[1] * up[1],
    fw[2] * pose.focal + uv[0] * rt[2] + uv[1] * up[2]
  ];
  const dl = Math.hypot(...rd) || 1;
  rd = rd.map((v) => v / dl) as Vec3;
  return { ro: pose.ro, rd };
}

export function pick(
  clientX: number,
  clientY: number,
  time: number,
  canvas: HTMLCanvasElement,
  companies: CompanyConfig[],
  scene: SceneConfig,
  pose: CameraPose,
  viewBias = 0,
  socials: SocialConfig[] = []
): PickId {
  const { ro, rd } = cameraRay(clientX, clientY, canvas, pose, viewBias);
  let best = Infinity;
  let id: PickId = 0;
  const test = (t: number, pickId: PickId) => {
    if (t < best) {
      best = t;
      id = pickId;
    }
  };
  test(hitTablet(ro, rd), 1);
  test(hitBoard(ro, rd), 2);
  test(hitOctopus(ro, rd), 3);
  for (let i = 0; i < companies.length; i++) {
    const r = orbRadius(companies[i].years, scene);
    test(hitSphere(ro, rd, orbPosJS(i, time, r, companies.length), r), companyPickId(i) as PickId);
  }
  for (let i = 0; i < socials.length; i++) {
    test(hitSphere(ro, rd, socialPosJS(i, time), SOCIAL_ORB_RADIUS), SOCIAL_PICK_BASE + i);
  }
  return id;
}

export function buildOrbUniforms(companies: CompanyConfig[], scene: SceneConfig) {
  const colorsA = new Float32Array(MAX_COMPANY_ORBS * 3);
  const colorsB = new Float32Array(MAX_COMPANY_ORBS * 3);
  const radii = new Float32Array(MAX_COMPANY_ORBS);
  const n = Math.min(companies.length, MAX_COMPANY_ORBS);
  for (let i = 0; i < n; i++) {
    colorsA.set(companies[i].colorA, i * 3);
    colorsB.set(companies[i].colorB, i * 3);
    radii[i] = orbRadius(companies[i].years, scene);
  }
  return { colorsA, colorsB, radii, count: n };
}
