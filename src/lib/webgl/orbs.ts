import type { SceneConfig, Vec3 } from './types';

/** Must match `TAB_C` / `BRD_C` / `OCT_C` / `orbPos()` in scene.frag.glsl. */
export const TAB_C: Vec3 = [-1.02, 0.96, 0.90];
export const BRD_C: Vec3 = [0.58, 0.805, 0.82];
export const OCT_C: Vec3 = [1.12, 0.8, 1.1];

export function orbRadius(years: number, scene: SceneConfig): number {
  return scene.orbRadiusBase + years * scene.orbRadiusPerYear;
}

/** Depth offsets by visual slot (oldest = 0, left). Must match scene.frag.glsl. */
const ORB_Z_OFF = [0.14, -0.11, 0.07, -0.16, 0.10, -0.08, 0.12, -0.09];

/**
 * Horizontal row, oldest on the left (CV list is newest-first).
 * Depth is staggered so they are not a straight line.
 */
export function orbPosJS(i: number, time: number, radius: number, count = 4): Vec3 {
  const n = Math.max(count, 1);
  const slot = n <= 1 ? 0.5 : (n - 1 - i) / (n - 1);
  const vis = n <= 1 ? 0 : n - 1 - i;
  const x = -0.52 + slot * 0.68;
  const z = 0.9 + ORB_Z_OFF[vis]!;
  return [x, 0.795 + radius + 0.015 * Math.sin(time * 1.3 + i * 1.9), z];
}
