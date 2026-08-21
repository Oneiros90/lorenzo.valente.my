import cameraConfig from '../config/camera.json';
import { orbPosJS, orbRadius } from './orbs';
import { companyIndexFromPick, isCompanyPick } from './picks';
import type { CompanyConfig, PickId, SceneConfig, Vec3 } from './types';

export interface CameraPose {
  ro: Vec3;
  target: Vec3;
  focal: number;
}

export function isDesktopViewport(width = window.innerWidth): boolean {
  return width > cameraConfig.desktopBreakpoint;
}

export function getDeskPose(time: number): CameraPose {
  const desk = cameraConfig.desk;
  return {
    ro: [
      desk.ro[0] + 0.016 * Math.sin(time * 0.4),
      desk.ro[1] + 0.009 * Math.sin(time * 0.63 + 1.0),
      desk.ro[2]
    ],
    target: desk.target as Vec3,
    focal: desk.focal
  };
}

export function getFocusPose(
  id: PickId,
  time: number,
  companies: CompanyConfig[],
  scene: SceneConfig
): CameraPose | null {
  if (id === 0) return null;

  if (isCompanyPick(id, companies.length)) {
    const i = companyIndexFromPick(id);
    const company = companies[i];
    if (!company) return null;
    const r = orbRadius(company.years, scene);
    const center = orbPosJS(i, time, r, companies.length);
    const off = cameraConfig.orb.offset;
    return {
      ro: [center[0] + off[0], center[1] + off[1], center[2] + off[2]],
      target: center,
      focal: cameraConfig.orb.focal
    };
  }

  const preset = cameraConfig.presets[String(id) as '1' | '2' | '3'];
  if (!preset) return null;
  return {
    ro: preset.ro as Vec3,
    target: preset.target as Vec3,
    focal: preset.focal
  };
}

export function lookBasis(ro: Vec3, target: Vec3): { fw: Vec3; rt: Vec3; up: Vec3 } {
  let fw: Vec3 = [target[0] - ro[0], target[1] - ro[1], target[2] - ro[2]];
  const fl = Math.hypot(...fw) || 1;
  fw = fw.map((v) => v / fl) as Vec3;
  const upW: Vec3 = [0, 1, 0];
  let rt: Vec3 = [
    fw[1] * upW[2] - fw[2] * upW[1],
    fw[2] * upW[0] - fw[0] * upW[2],
    fw[0] * upW[1] - fw[1] * upW[0]
  ];
  const rl = Math.hypot(...rt) || 1;
  rt = rt.map((v) => v / rl) as Vec3;
  const up: Vec3 = [
    rt[1] * fw[2] - rt[2] * fw[1],
    rt[2] * fw[0] - rt[0] * fw[2],
    rt[0] * fw[1] - rt[1] * fw[0]
  ];
  return { fw, rt, up };
}

function lookRange(width = typeof window !== 'undefined' ? window.innerWidth : 1024) {
  return isDesktopViewport(width) ? cameraConfig.look.desktop : cameraConfig.look.mobile;
}

/**
 * Cursor (0..1) → yaw/pitch.
 * Config yawDeg/pitchDeg are desired total room coverage; pan span is
 * coverage minus current frustum FOV so narrow screens get more look range.
 */
export function mouseLookAngles(
  smX: number,
  smY: number,
  width = typeof window !== 'undefined' ? window.innerWidth : 1024,
  height = typeof window !== 'undefined' ? window.innerHeight : 768
): { yaw: number; pitch: number } {
  const range = lookRange(width);
  const aspect = width / Math.max(height, 1);
  const focal = cameraConfig.desk.focal;

  // Matches scene ray: uv.x ∈ [-aspect,aspect], uv.y ∈ [-1,1], rd ∝ fw*focal + uv
  const halfHFov = Math.atan(aspect / focal);
  const halfVFov = Math.atan(1 / focal);
  const halfCoverH = ((range.yawDeg * Math.PI) / 180) * 0.5;
  const halfCoverV = ((range.pitchDeg * Math.PI) / 180) * 0.5;
  const yawHalf = Math.max(halfCoverH - halfHFov, 0.12);
  const pitchHalf = Math.max(halfCoverV - halfVFov, 0.08);
  const pitchBias = (range.pitchBiasDeg * Math.PI) / 180;

  return {
    yaw: lerp(-yawHalf, yawHalf, smX),
    pitch: lerp(-pitchHalf, pitchHalf, smY) + pitchBias
  };
}

export function mouseLookBasis(
  smX: number,
  smY: number,
  width = typeof window !== 'undefined' ? window.innerWidth : 1024,
  height = typeof window !== 'undefined' ? window.innerHeight : 768
): { fw: Vec3; rt: Vec3; up: Vec3 } {
  const { yaw, pitch } = mouseLookAngles(smX, smY, width, height);
  const fw: Vec3 = [
    Math.sin(yaw) * Math.cos(pitch),
    Math.sin(pitch),
    -Math.cos(yaw) * Math.cos(pitch)
  ];
  return lookBasis([0, 0, 0], fw);
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function lerpVec3(a: Vec3, b: Vec3, t: number): Vec3 {
  return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
}

export function mixPose(a: CameraPose, b: CameraPose, t: number): CameraPose {
  return {
    ro: lerpVec3(a.ro, b.ro, t),
    target: lerpVec3(a.target, b.target, t),
    focal: lerp(a.focal, b.focal, t)
  };
}

export { cameraConfig };
